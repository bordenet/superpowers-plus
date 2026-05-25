# branch-flow-gate -- Reference

Lane details, sanitization rules, failure modes, recipes. Parent
`skill.md` is the procedure; this file holds the playbook.

## Lane Definitions (Authoritative)

### Feature lane

Source: `feature/<desc>`, `fix/<desc>`, or any conventional prefix
(`chore/`, `docs/`, `test/`, `perf/`, `refactor/`).
Branch from: `origin/dev`. Target: `dev`.
After merge: `--delete-branch=true`. Promote `dev -> staging -> main`
once QA clears at each step.

### Hotfix lane

Source: `hotfix/<desc>`. Branch from: `origin/main`. Target: `main`.
**Coupling**: A paired `forward/hotfix-<desc>` MUST exist on origin
against `dev` BEFORE the hotfix PR can be merged to main. Forward-port
deadline: same shift. If skipped at 3am, log a follow-up issue with an
SLA -- never silently leave dev divergent.

### Bot lane

Bots (Dependabot, Renovate, security scanners) often target the default
branch. If that's `main`, after the bot PR lands:
- Open `forward/bot-<pkg>-<ver>` off `origin/dev`, cherry-pick the bot's
  diff, PR to `dev` within the same shift.
- Long-term fix: configure the bot to target `dev`
  (`.github/dependabot.yml: target-branch: dev`).

### Revert lane

Source: `revert/<sha>` or `revert/<desc>`. Branch from: tip of the branch
where the bad merge landed. Target: same branch.
Coupling: if reverting on `main`, open paired `forward/revert-<sha>` to
`dev` so dev does not re-introduce the bad change on the next promotion.

## Sanitization (for cross-repo cherry-picks)

```bash
# Anti-leak triggers in added lines (replace with FAKE-LEAK-PATTERN-FOR-TEST):
grep -nE '(internal|secret|codename|token|password|apikey)-[a-z0-9-]{4,}' -- <files>
grep -nE 'AKIA[0-9A-Z]{16}|sk_live_|ghp_|glpat-' -- <files>      # known token shapes
LC_ALL=C grep -nP '[^\x00-\x7F]' -- <files>                      # non-ASCII
```

Test-fixture placeholder rule: tests for "leak detection" write their
OWN pattern to a config file at runtime. The placeholder string in the
test fixture only needs to MATCH what the test writes -- it does NOT
need to look like a real secret. Use `FAKE-LEAK-PATTERN-FOR-TEST`.

Platform-path drops:

```bash
# GitHub -> GitLab port: drop .github/
git checkout <target-branch> -- .github/
# GitLab -> GitHub port: drop .gitlab-ci.yml + .gitlab/
git checkout <target-branch> -- .gitlab-ci.yml .gitlab/
```

## Failure Modes

### F1. Retry spiral / branch sprawl

PR rejected -> create `<branch>-v2` -> retry. Each retry leaves a stale
branch on the remote. The preflight rejects `-vN` suffixes outright.
**Action:** `git commit --amend` (or new commit) + `git push --force-with-lease`.

### F2. Sibling SHAs from rebase-merge promotion

Rebase-merge rewrites committer/date. dev and staging end up with
DIFFERENT SHAs for content-identical commits (siblings, not
ancestor/descendant). Ancestor-aware tooling breaks.
**Action:** `--merge` on promotion PRs. Acceptable to rebase or squash
on feature->dev if repo policy prefers.

### F3. Strict branch protection + pre-existing divergence

`required_status_checks.strict = true` requires PR head be descendant
of base. If dev and staging are already siblings (F2 history), a
`dev -> staging` PR is BEHIND and won't merge.
**Action:** open a one-time documented convergence forward-port:
branch off `origin/dev`, merge `origin/staging` into it (resolve in
favor of canonical content), refresh baselines if needed, PR to `dev`
(NOT staging). After it merges, promote `dev -> staging` cleanly.

### F4. EI/OP waivers fire on pull_request event only

Workflows that pull `EI_WAIVERS` from PR body get an empty value on the
post-merge `push` event. Push-event CI fails even though PR CI passed.
**Action:** In the SAME PR that introduces the content change, also
regenerate detector baselines (`node test/ei-move-detector.test.js
--update`) and commit them.

### F5. Anti-leak hook rejects literal company-internal strings

Test fixture embeds `<company>-internal-secret-codename`. Server-side
hook scans the diff and rejects with opaque "Prevented by server hooks."
**Action:** Replace with `FAKE-LEAK-PATTERN-FOR-TEST`. The test logic
writes its own pattern at runtime; the placeholder only matches what
the test writes.

### F6. Server hook target-specific rejection

Hook blocks merges into `dev` but allows them into `main`. Same MR
retargeted may merge.
**Action:** User-only opt-in. The agent does NOT autonomously retarget
across lanes -- that violates the canonical flow. Surface the hook's
behavior and let the user decide.

### F7. `.github/` paths on GitLab target (or vice versa)

Cherry-pick from GitHub repo to GitLab repo includes `.github/workflows/`.
GitLab hook rejects as cross-platform pollution.
**Action:** drop the platform-specific paths from the cherry-pick.

### F8. Mirror assumption between independent repos

Two repos that USED to mirror are now independent. Bulk-port imports
20+ unrelated commits.
**Action:** cherry-pick the SPECIFIC commits the user named. Each
cherry-pick enters the destination's canonical flow.

### F9. CI flake on a promotion

Flaky test fails dev->staging promotion. The skill forbids `-v2`.
**Action:** Re-run the failed CI job. After two flake re-runs, escalate
to the user. NEVER admin-merge a red CI without explicit user say-so.

### F10. Forgetting `--delete-branch=true`

Source branches accumulate on remote. Network graph fills.
**Action:** ALWAYS `--delete-branch=true` on `gh pr merge` (or
`--remove-source-branch` on `glab mr merge`) EXCEPT for promotion PRs
where the source is `dev` or `staging` (those branches stay).

### F11. Loop-on-opaque-error

Same generic error on retry. And again.
**Action:** TWO consecutive identical errors -> STOP. Identical = same
HTTP status + same error-body substring after stripping IDs/timestamps.
`tools/branch-flow-preflight.sh --identical-check err1 err2`
formalizes this.

### F12. Bot-landing CVE vuln window

Dependabot lands a CVE fix on main at 02:00. Dev carries the vuln until
forward-port merges.
**Action:** Forward-port is a same-shift obligation. Long-term: retarget
the bot to dev so the vuln window closes itself.

## Recipes

### Recipe 1: feature/fix lane

```bash
git fetch origin
git checkout -B feature/<desc> origin/dev
# ... work ...
git push -u origin feature/<desc>
tools/branch-flow-preflight.sh feature/<desc> dev
gh pr create --head feature/<desc> --base dev --title "feat: <desc>"
gh pr merge --merge --auto --delete-branch=true
# After dev QA clears:
tools/branch-flow-preflight.sh dev staging
gh pr create --head dev --base staging --title "promote: dev -> staging"
gh pr merge --merge --auto              # NO --delete-branch=true
# After staging QA clears:
tools/branch-flow-preflight.sh staging main
gh pr create --head staging --base main --title "promote: staging -> main"
gh pr merge --merge --auto              # NO --delete-branch=true
```

### Recipe 2: hotfix lane (with mandatory forward-port)

```bash
# 1. Hotfix branch off main
git checkout -B hotfix/<desc> origin/main
# ... fix, push ...
git push -u origin hotfix/<desc>
# 2. Forward-port branch FIRST (preflight requires it):
git checkout -B forward/hotfix-<desc> origin/dev
git cherry-pick <hotfix-sha>
git push -u origin forward/hotfix-<desc>
tools/branch-flow-preflight.sh forward/hotfix-<desc> dev
gh pr create --head forward/hotfix-<desc> --base dev
# 3. Now the hotfix PR (preflight now passes):
tools/branch-flow-preflight.sh hotfix/<desc> main
gh pr create --head hotfix/<desc> --base main
# 4. Merge both same-shift. --delete-branch=true on both.
```

### Recipe 3: bot-landing recovery (after the fact)

```bash
git checkout -B forward/bot-<pkg>-<ver> origin/dev
git cherry-pick <bot-merge-sha>
git push -u origin forward/bot-<pkg>-<ver>
tools/branch-flow-preflight.sh forward/bot-<pkg>-<ver> dev
gh pr create --head forward/bot-<pkg>-<ver> --base dev \
    --title "forward-port: bot bump of <pkg>"
gh pr merge --merge --auto --delete-branch=true
```

## Out of Scope (documented for future)

- **Release branches** (`release/v*`): not covered. Define as follow-up.
- **Stacked PRs**: not covered. Use single linear branches off `dev`.
- **Merge queue tooling**: --merge survives queue rebasing; queue-specific
  behavior is repo-by-repo.

## Anti-Pattern: The Network-Graph Disgrace

One session produced 13 PRs and 10+ topic branches for what should have
been 3 PRs. Causes (each preflight-rejected now):
- Branched off staging/main multiple times.
- Used rebase-merge on promotions (sibling SHAs).
- Created `-v2`/`-v3` branches on every retry.
- Opened back-sync PRs (main -> dev/staging) instead of forward-ports.
- Forgot `--delete-branch=true` on most merges.
- Looped 5+ times on the same opaque server-hook error.

`tools/branch-flow-preflight.sh` rejects every one of these.
Run it before every branch creation and every PR.
