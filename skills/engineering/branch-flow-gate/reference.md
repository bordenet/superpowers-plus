# branch-flow-gate -- Reference

Universal release-management hygiene. FLOW-AGNOSTIC by design: each
team picks its own promotion shape; this skill stays out of that
decision.

## What's Universal vs Team-Specific

| Concern | Universal (this skill) | Team-Specific (NOT this skill) |
|---|---|---|
| Branch naming matches server regex | YES (server hook enforces; we mirror locally) | Which prefix you pick for a given task |
| No `-vN` retry sprawl | YES | n/a |
| No back-sync/sync/mirror names | YES | What you call your forward-port |
| Anti-leak literal scrub | YES | Which patterns your test fixtures actually need |
| Stop on identical opaque errors | YES | What's "identical" in a specific tool's output |
| Delete source branch on merge | YES (advisory) | Whether long-lived branches use a different lifecycle |
| Which target branch | NO | team A uses dev/staging/main; legacy uses release/<v> |
| Promotion sequence | NO | Per-team flow docs |
| Hotfix lane shape | NO | Each team's incident-response procedure |

## Team Flow Examples (informational only)

### team A (modern) (modern flow)

```text
feat/* off dev --MR--> dev --QA--> staging --QA--> main
```

team A follows the same flow as `bordenet/superpowers-plus`. Their
flow doc (if separate) is authoritative for source/target pairings.

### Legacy teams (waterfall via develop + tag-based releases)

```text
feat/* off develop --MR--> develop --QA on develop--> develop --MR--> main
                                       (cut release tag on main)
```

Legacy teams use `develop` as the integration branch and `main` as
the release tip; release "branches" in this repo are actually annotated
tags on `main` (e.g. `v1.2.0`).

If your team needs literal `release/<version>` BRANCHES (long-lived
release branches with backport flows), check this repo's GitLab
push_rule -- the current server-side branch-name regex is
`(main|develop|(feat|fix|exp|doc|perf|chore)/.+)`. `release/*` is NOT
in that allowlist. To use release branches in this repo, ask the
GitLab project admin to update the regex first; until then, the
server hook will reject pushes regardless of what this skill does.

This skill does NOT prefer one over the other. It only enforces the
patterns both teams agree are mistakes.

## Failure Modes

### F1. Retry spiral

PR rejected -> create `<branch>-v2` -> retry. Each retry pollutes the
network graph. The preflight refuses `-vN` suffixes.
**Recovery:** `git commit --amend` or new commit on the EXISTING
branch + `git push --force-with-lease`.

### F2. Back-sync / mirror naming

Branch names like `back-sync/*`, `sync/*`, `mirror/*`,
`chore/back-sync-*` get rejected. Use forward-port semantics:
branch off the destination, pull in the changes from the source,
PR forward.

### F3. Anti-leak hook rejects test fixtures

Server-side `prevent_secrets=true` hook scans diffs for token-shaped
strings. A test fixture embedding
`<company>-internal-secret-codename` will be rejected on merge.
**Fix:** use `FAKE-LEAK-PATTERN-FOR-TEST`. The test's hook-config
writes the pattern at runtime; the fixture string only needs to
MATCH that config -- it doesn't need to look like a real secret.

### F4. ASCII-only commit-message hook

Server hook rejects commit messages with non-ASCII (em-dashes, smart
quotes, emoji). Use `--` not the em-dash.
**Audit:** `LC_ALL=C grep -nP '[^\x00-\x7F]' <(git log --format=%B)`.

### F5. 5 MB file-size hook

Server rejects pushes with files >5 MB.
**Audit:** `git ls-files -s | awk '{print $NF}' | xargs -I{} stat -f%z {} | sort -n | tail`.
Use Git LFS for large binaries.

### F6. Loop-on-opaque-error

Same error on retry. Same again. Hours wasted.
**Fix:** TWO identical opaque errors -> STOP. Diagnose:
- Sanitization (F3)
- ASCII compliance (F4)
- File size (F5)
- Branch-name regex (F2)

Use `tools/branch-flow-preflight.sh --identical-check "$ERR1" "$ERR2"`
to compare with volatile-bit stripping (UUIDs, SHAs, ISO-8601, pod
names, ports, request-ids, urns, PIDs, tmp paths).

### F7. Mirror assumption between independent repos

This repo is SELF-CONTAINED. Do not bulk-port from
`bordenet/superpowers-plus` or `mbordenet/superpowers-callbox`.
Cherry-pick the SPECIFIC commits the user named. Each cherry-pick
enters this repo's canonical flow (whatever YOUR team's flow is).

### F8. Forgetting `--remove-source-branch`

Source branches accumulate. The network graph fills.
**Fix:** Always pass `--remove-source-branch` on `glab mr merge`.

### F9. Stale `.branch-flow-cleared` sentinel after additional commits

Pre-push Gate 3 pins the sentinel to a specific SHA. Any commit (including `--amend`, `--fixup`, `rebase -i`) after running the preflight invalidates the sentinel; the next push to dev/staging/main fails with `branch-flow sentinel SHA != pushed SHA. Branch tip moved since preflight.`
**Fix:** Re-run `tools/branch-flow-preflight.sh <source> <target>` after every commit immediately before pushing. In a fast-iteration debug loop, defer running the preflight until you are ready to push the final commit.

### F10. Preflight script missing in this clone

If `tools/branch-flow-preflight.sh` is not installed (fresh clone, partial sync, or a downstream consumer), the skill's "Mandatory Preflight" instructions point at a phantom command. Pre-push Gate 3 detects this and skips with `(skipped - tools/branch-flow-preflight.sh not present in this repo)`.
**Fix:** Run `tools/install-hooks.sh` (or the equivalent install path for your platform) to materialize the script and the hook. Until then, pushes to dev/staging/main land without the gate firing -- relying entirely on PR review.

### F11. Cascade-chasing forward-ports after a promotion

After a successful dev -> staging -> main promotion cycle, the standard cleanup is to forward-port main back to staging and dev so the next feature branch starts from an aligned base. **Do exactly two forward-port PRs and STOP:**

1. `main -> staging` (forward-port)
2. `main -> dev` (forward-port)

**Anti-pattern:** opening additional forward-ports after the first two -- e.g. a `forward/converge-main-with-staging` PR that merges staging's new forward-port merge-commit back into main -- creates an infinite cascade. Each forward-port adds a merge commit to the destination, which the source is then "behind" on; chasing that gap with another forward-port immediately creates the next gap. This is the "13-PR network-graph disgrace" pattern.

**Verification heuristic:** if all three branch trees match, content is aligned. The HEAD SHAs will always differ slightly because each branch carries different merge-commit topology -- that's expected and benign.

```bash
git rev-parse origin/main^{tree}     # -> 85ffd6aa...
git rev-parse origin/staging^{tree}  # -> 85ffd6aa...  (same hash = aligned)
git rev-parse origin/dev^{tree}      # -> 85ffd6aa...
```

Note: this check is meant to be run *immediately after the two forward-port PRs*, not as a long-running invariant. If dev's tree later drifts because a new feature has landed there post-forward-port, that is **expected and not a cascade-chasing signal** -- the next legitimate promotion cycle realigns it.

**Fix when caught mid-cascade:** stop. Do not open the next forward-port PR. Already-merged cascade PRs do not need reverting -- they are benign merge commits, and the next legitimate dev -> staging -> main cycle (when real content ships) naturally absorbs them.

## Sanitization (for cross-repo cherry-picks)

```bash
# Anti-leak triggers (server-side prevent_secrets=true will reject):
grep -nE '(internal|secret|codename|token|password|apikey)-[a-z0-9-]{4,}' -- <files>
grep -nE 'AKIA[0-9A-Z]{16}|sk_live_|ghp_|glpat-' -- <files>
LC_ALL=C grep -nP '[^\x00-\x7F]' -- <files>   # non-ASCII
```

Server-side hooks also enforce:
- ASCII-only commit messages (no em-dashes; use `--`)
- 5 MB max file size
- LFS-tracked binaries only

## Recipes (Universal Hygiene)

### Recipe A: Fix a failed merge WITHOUT branch sprawl

```bash
# DO NOT create feat/foo-v2.
git commit --amend                          # or: git commit -m "fix: address review"
git push --force-with-lease origin <branch>
# Re-trigger CI, re-request review.
```

### Recipe B: Cross-repo cherry-pick with sanitization

```bash
git checkout -B feat/port-from-upstream origin/<your-target>
git cherry-pick <sha>
# Sanitize anti-leak triggers
sed -i 's/<company>-internal-secret-codename/FAKE-LEAK-PATTERN-FOR-TEST/g' tests/*
# Drop platform-specific paths if porting GitHub -> GitLab
git checkout origin/<your-target> -- .github/ 2>/dev/null || true
git commit --amend --no-edit
git push -u origin feat/port-from-upstream
tools/branch-flow-preflight.sh feat/port-from-upstream <your-target>
glab mr create --source-branch feat/port-from-upstream --target-branch <your-target> --yes
glab mr merge --remove-source-branch --yes
```

### Recipe C: Two-strikes-out on opaque errors

```bash
ERR1=$(my-merge-command 2>&1)
# (change one variable: sanitize, retarget, drop a file...)
ERR2=$(my-merge-command 2>&1)
tools/branch-flow-preflight.sh --identical-check "$ERR1" "$ERR2"
# If identical: STOP. Diagnose. Don't retry blindly.
```

## What This Reference DOES NOT Cover

- team A (modern)'s dev/staging/main promotion sequence (team A's flow doc)
- Legacy waterfall release-branch cut-and-ship procedure (legacy docs)
- Hotfix paired forward-port (team A (modern) only)
- Bot-landing forward-port SLA (team-specific)
- Convergence recipes for sibling-SHA divergence (team-specific)

If your team needs any of those rules enforced, codify them in YOUR
team's own skill. This skill is the universal baseline; team
specializations live separately.

## Anti-Pattern History

The agent once produced a 13-PR network-graph disgrace on
`bordenet/superpowers-plus` by violating most of F1-F8 in one
session. Every retry spawned a new topic branch, back-syncs
proliferated, sanitization was missed on cross-repo cherry-picks,
and the same opaque server-hook error got retried five times before
anyone diagnosed it.

Each of those mistakes is now refused at the preflight script.
Run it.
