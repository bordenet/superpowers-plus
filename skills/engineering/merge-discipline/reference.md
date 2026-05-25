# merge-discipline -- Reference

Detailed failure modes, concrete recipes, and the war stories that justify
the parent skill's rules. The skill is the procedure; this file holds the
evidence.

## The One Flow

```text
feature/* or fix/*  --PR-->  dev  --QA-->  PR-->  staging  --QA-->  PR-->  main
```

Three branches, one direction. There is no other shape this should ever take.

## Failure Modes

### F1. Branching off the wrong base

**Trap**: You need to fix a bug in main. You branch off main, fix it, open
a PR to main.

**Why it's wrong**: It skips dev QA. It skips staging QA. The fix never
gets exercised by the canonical CI sequence. Future merges from dev that
touch the same code will conflict because the fix lives on main but not
on dev.

**Right action**:
- Branch off `origin/dev`.
- Apply the fix.
- PR to dev.
- After dev QA: PR dev -> staging.
- After staging QA: PR staging -> main.

If main is currently broken in production and dev has not been QA'd, that
is a process problem, NOT a branching problem. Ask the user; do not
shortcut.

### F2. Direct landing on main (e.g. dependabot)

**Trap**: A tool (Dependabot, security bot, Renovate) opens a PR with base
`main`. The PR auto-merges via the tool's own auth. main moves ahead of
dev and staging.

**Why this is dangerous**: Future dev -> staging -> main promotions either
(a) skip the bot's change (it's already there) or (b) conflict on it.
The natural reflex is "back-sync main to dev so they're aligned" -- but
back-syncs are not part of this flow.

**Right action**:
- ASK the user whether they want the bot landing reverted, or accepted
  and reconciled.
- If accepted: do NOT back-sync. Instead, open a topic branch off dev,
  cherry-pick the bot's change (just the file diff), PR to dev. Then
  promote dev -> staging -> main normally. The cherry-pick re-enters
  the canonical line.
- Long-term: configure the bot to target dev, not main.

### F3. The retry spiral / branch sprawl

**Trap**: PR is BLOCKED/BEHIND. You create a new topic branch, push, retry.
Still fails. Create v3. Then v4.

**Why**: Every retry leaves a stale branch on the remote (unless
`--delete-branch=true`, which you forgot). The network graph fills with
parallel paths.

**Right action**:
- Identify why the first PR failed (CI test, hook reject, ancestry).
- Fix THE EXISTING BRANCH: `git commit --amend` or new commit.
- `git push --force-with-lease`.
- Never create `-v2`, `-v3`. The branch you have is the branch you fix.

### F4. Rebase-merge on a promotion PR produces sibling SHAs

**Trap**: You auto-merge dev -> staging with `--rebase`. GitHub rewrites
committer/date. staging's HEAD is a NEW SHA, sibling of dev's HEAD with
identical content.

**Why**: When promotion needs to converge histories (so cross-branch
tooling can see "this commit is on both"), siblings don't satisfy that.
Content-identical but SHA-divergent branches confuse `git log --all`,
`git merge-base`, and ancestry-aware tooling.

**Right action**:
- Use `--merge` (merge commit) on PROMOTION PRs.
- This preserves the source SHA as a parent of the merge commit.
- Network graph shows the actual flow.

### F5. Strict branch protection vs naive PR creation

**Trap**: required_status_checks.strict = true means PR head MUST be a
descendant of base. If dev and staging have diverged via earlier
mistakes, a `dev -> staging` PR shows BEHIND and won't merge.

**Why this happens**: Earlier sibling-creating merges (F4) put dev and
staging on sibling lines, not ancestor lines.

**Right action**: Do NOT compound the divergence with a fresh chain of
topic branches. Instead:
- Identify the LAST common ancestor of dev and staging.
- Decide whether dev's content or staging's is the right end-state.
- Build ONE topic branch off the chosen tip; merge the other in;
  open ONE PR to advance both branches to the converged state.
- Going forward, use `--merge` for all promotions so this doesn't recur.

### F6. EI/OP waivers fire on PR event only

**Trap**: A workflow declares `EI_WAIVERS: ${{ github.event_name ==
'pull_request' && github.event.pull_request.body || '' }}`. You put
`EI-WAIVER: <skill> -50% -- reason` in the PR body. PR CI passes. PR
merges. Post-merge push event runs the same job, body is unavailable,
waivers are empty, detector fails.

**Cost**: dev (or wherever the merge landed) goes red after the merge.
Subsequent PRs inherit the red status until baseline is refreshed.

**Right action**: In the SAME PR that introduces the content change:
```bash
node test/ei-move-detector.test.js --update
node test/operative-move-detector.test.js --update
git add test/ei-baseline.json test/operative-baseline.json
git commit -m "chore: refresh detector baselines"
```
Now the post-merge push CI has nothing to detect.

### F7. Anti-leak hook rejects literal company-internal strings in test fixtures

**Trap**: Test fixture embeds `"<company>-internal-secret-codename"`.
Local tests pass. On push or merge, server-side anti-leak hook scans
the diff, matches the pattern, rejects with opaque "Prevented by server
hooks."

**Right action**: Use a generic placeholder:
```bash
echo "FAKE-LEAK-PATTERN-FOR-TEST" > "$PAT_FILE"
```
The test's hook config writes whatever pattern it wants to detect --
the placeholder needs to MATCH the test's expected pattern, not
look like a real secret. Sanitize ESPECIALLY on cross-repo cherry-picks.

### F8. Server hook target-specific rejection

**Trap**: MR rejected with opaque error on every retry. detailed_merge_status
is mergeable, no conflicts. You try five strategies, all identical errors.

**Right action**: The hook may block specific target branches but allow
others. Retarget:
```bash
glab api -X PUT projects/<id>/merge_requests/<iid> -f target_branch=main
```
If it merges, the hook was target-specific. NOTE: this only works if
the user's flow accepts that landing target.

### F9. .github/ paths on a GitLab target (or vice versa)

**Trap**: Cherry-picking from GitHub origin to a GitLab repo includes
`.github/workflows/*.yml` changes. The GitLab server hook rejects on
merge as cross-platform pollution.

**Right action**: Drop platform-specific files before pushing:
```bash
git checkout <target-branch> -- .github/
git commit --amend --no-edit
```
Only substantive (non-CI-config) changes should land in the target.

### F10. Mirror assumption when repos have diverged

**Trap**: Two repos that USED to be mirrors are now independent. You assume
dev's content from repo A belongs on dev of repo B and try a bulk port.

**Right action**: Cherry-pick the SPECIFIC commits the user wants ported.
Identify them by intent (e.g., "the 3-bug fix from PR #891"), not by
branch state. Each cherry-pick goes through the destination's canonical
flow: feature branch off dev -> dev -> staging -> main.

### F11. Forgetting --delete-branch=true

**Trap**: Source branch left on remote after merge. After 10 such merges,
the network graph fills with stale topic branches.

**Right action**: Always:
```bash
gh pr merge <n> --merge --auto --delete-branch=true
glab mr merge <iid> --remove-source-branch --yes
```

### F12. Loop-on-opaque-error

**Trap**: API returns generic error. You retry. Same error. You retry with
an irrelevant flag change. Same error.

**Right action**: TWO consecutive identical errors = stop and diagnose.
- Read the merge_ref / dry-run merge commit.
- Search the diff for anti-leak patterns (F7).
- Try retargeting (F8).
- Drop platform-specific paths (F9).
- Escalate to the user with a focused question.

## Recipes

### Recipe: Feature/fix that lands on main

The canonical flow has three PRs. None of them is optional.

```bash
# 1. Branch off dev
git fetch origin
git checkout -B feat/my-feature origin/dev

# 2. Work, commit, push
# ... edits ...
git commit -m "feat: my feature"
git push -u origin feat/my-feature

# 3. PR 1: feature -> dev
gh pr create --head feat/my-feature --base dev --title "feat: my feature"
gh pr merge --merge --auto --delete-branch=true

# --- QA on dev runs ---
# --- User signs off ---

# 4. PR 2: dev -> staging
gh pr create --head dev --base staging --title "promote dev to staging"
gh pr merge --merge --auto

# --- QA on staging runs ---
# --- User signs off ---

# 5. PR 3: staging -> main
gh pr create --head staging --base main --title "promote staging to main"
gh pr merge --merge --auto
```

Three PRs. Three branches end at the same content (the latest merge
commit on each). The network graph shows three parallel lines that
converge at promotion points. Clean.

### Recipe: Cross-repo cherry-pick port

The port still goes through the destination's canonical flow.

```bash
# 1. Identify the SPECIFIC commits to port (not a branch range)
SOURCE_COMMITS=("0d1f9b9d")

# 2. Branch off destination's dev tip
git checkout -B fix/port-from-upstream destination/dev

# 3. Cherry-pick + sanitize
for c in "${SOURCE_COMMITS[@]}"; do
    git cherry-pick "$c"
done

# Sanitize anti-leak triggers
sed -i 's/<company>-internal-secret-codename/FAKE-LEAK-PATTERN-FOR-TEST/g' tests/*.bats

# Drop platform-specific paths
git checkout destination/dev -- .github/ 2>/dev/null || true
git commit --amend --no-edit

# 4. Push to fix/* (matches server-side branch-name policies)
git push -u destination fix/port-from-upstream

# 5. Open PR to destination's DEV. Not main. Not staging. Dev.
glab mr create --source-branch fix/port-from-upstream --target-branch dev --yes

# 6. After merge: promote dev -> staging -> main per Recipe 1.
```

### Recipe: dev/staging/main caught siblings, need to converge

This is the cleanup recipe when the flow was already broken before you
arrived. Do this ONCE, then return to the canonical flow.

```bash
# 1. Decide which tip has the canonical content
#    Usually it's main (production state), but ASK the user.
CANONICAL_TIP="origin/main"

# 2. Build ONE convergence branch off dev (NOT main -- we want this to
#    go through the canonical flow forward, not back-sync).
git checkout -B fix/converge-flow origin/dev
git merge "$CANONICAL_TIP" --no-ff -m "fix: re-base dev on canonical main"
# Resolve any conflicts in favor of the canonical content.

# 3. Refresh baselines
node test/ei-move-detector.test.js --update
git add test/ei-baseline.json test/operative-baseline.json
git commit -m "chore: refresh baselines after convergence"

# 4. cr-battery
tools/run-battery.sh --verdict PASS --min-score 9.4

# 5. PR to dev (NOT a back-sync)
git push -u origin fix/converge-flow
gh pr create --head fix/converge-flow --base dev --title "fix: converge flow"
gh pr merge --merge --auto --delete-branch=true

# 6. After dev QA: promote dev -> staging -> main per Recipe 1.
```

This re-enters the canonical flow forward, instead of back-syncing.

## Anti-Pattern: What This Session Produced

```text
main:    --o-------o-------o-------o-------o-------o------>
            \     /       /         \     /       /
staging: ----o---o-------o-----------o---o-------o-->
              \         /             \         /
dev:     ------o-------o---------------o-------o-->
                \     /                 \     /
                 \   /                   \   /
            chore/{promote,back-sync,baseline-sync,update-detector}-{v1,v2,v3,...}
            ^ 10+ topic branches, half not deleted on merge
```

Every back-sync arrow is a violation of the canonical flow. Every -v2
topic branch is a retry that should have been an amend. Every
rebase-merge created sibling SHAs. The same end-state could have been
ONE feature PR + dev promotion + staging promotion = 3 PRs in a clean
linear graph.

The cost of skipping this skill's pre-flight: hours of debugging,
manual cleanup, and a network graph the user called "a fucking disgrace."

**Plan the sequence. Use ONE topic branch per direction. Delete on merge.
Three PRs total. That is the discipline.**

## Companion: When YOU broke the flow this session

If you (the agent) are reading this AND you have already opened
back-sync PRs or branched off staging/main, you have already failed.
Recovery:

1. STOP creating more branches.
2. Apologize concisely to the user. They are right to be angry.
3. Delete every orphaned topic branch on the remote (`gh api -X DELETE`).
4. Document the inherited divergence honestly.
5. Resume work via the canonical flow from this point forward.

There is no other way back.
