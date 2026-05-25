---
name: branch-flow-gate
source: superpowers-plus
augment_menu: true
triggers:
  - "open a PR"
  - "open an MR"
  - "open a pull request"
  - "merge request"
  - "create a branch"
  - "ship this"
  - "ship it"
  - "deploy this"
  - "deploy to prod"
  - "release this"
  - "release to staging"
  - "release to production"
  - "push to prod"
  - "push to production"
  - "push this to prod"
  - "land this"
  - "land it"
  - "get this out"
  - "ready to merge"
  - "promote dev"
  - "promote staging"
  - "promote to main"
  - "promote to staging"
  - "dev to staging"
  - "staging to main"
  - "merge to main"
  - "merge to staging"
  - "merge to dev"
  - "cherry-pick"
  - "port to"
  - "port PR"
  - "back-sync"
  - "back sync"
  - "mirror to"
  - "hotfix"
  - "revert on main"
  - "forward-port"
  - "forward port"
  - "rebase"
  - "rebase onto"
  - "rebase staging"
  - "rebase main"
anti_triggers:
  - "merge conflict resolution"
  - "git merge upstream"
description: "Refuses unsafe branch/PR/push actions BEFORE they happen: branching off the wrong base, -v2/-v3 retry suffixes after a failed merge, back-sync/mirror names, source-target pairs that skip the canonical promotion flow (dev -> staging -> main here), hotfix/revert to main without a paired forward-port. Triggers on: open a PR, ship/promote/deploy/release/push to prod, cherry-pick/back-sync/rebase across environments. Writes .branch-flow-cleared sentinel consumed by the pre-push hook. CAVEAT: local gate enforces direct git push only; gh/glab UI/API merges happen SERVER-SIDE and need branch protection to cover that surface. Sits between branch-sync-gate (pull-before-work) and finishing-a-development-branch (post-implementation handoff)."
summary: "Hard gate on (source, target) pairs for any branch creation, PR opening, or push to dev/staging/main. Refuses the patterns that produced the prior 13-PR network-graph mess: -vN retries, back-syncs, mirrors, wrong-base branches, unpaired hotfix/revert. Run tools/branch-flow-preflight.sh before every action."
coordination:
  group: engineering
  order: 1
  requires: ["branch-sync-gate"]
  enables: ["finishing-a-development-branch", "progressive-code-review-gate"]
  internal: false
composition:
  consumes: [source-branch, target-branch, repo-policy]
  produces: [preflight-sentinel, merge-plan, sanitization-report]
  capabilities: [preflight-enforcement, lane-validation, sequence-planning, sanitization-scan]
  priority: 100
  optional: false
  requires_all: false
---

# branch-flow-gate -- The Only Flow That Exists

> **Wrong skill?** Single feature PR ceremony -> `finishing-a-development-branch`. Pre-commit code review -> `progressive-code-review-gate`. Pull before resuming -> `branch-sync-gate`. Branch-name regex check -> `git-branch-conventions`.

**Announce at start:** "I'm using **branch-flow-gate**. Running preflight before any branch action. (Local gate covers direct pushes; PR/UI merges rely on server-side branch protection.)"

## The Canonical Flow

```text
feature/* or fix/*   --PR-->  dev  --QA-->  PR-->  staging  --QA-->  PR-->  main
```

Three branches. One direction. Four lanes (this section + reference.md):

| Lane | When | Source pattern | Target | Forward-port |
|---|---|---|---|---|
| **feature** | Normal work | `feat/*`, `feature/*`, `fix/*`, `bugfix/*`, `chore/*`, `doc(s)/*`, `test/*`, `perf/*`, `refactor/*`, `exp/*` (off `dev`) | `dev` | n/a (already canonical) |
| **hotfix** | P0 prod bug | `hotfix/*` (off `main`) | `main` | REQUIRED paired `forward/hotfix-*` to dev (enforced: preflight refuses hotfix PR until the forward branch exists on origin). Wall-clock SLA for the forward-port merge: 8h, advisory. |
| **bot** | Dependabot/Renovate landing on main | bot branch on main | `main` (accepted) | REQUIRED `forward/bot-*` to dev. SLA 8h, advisory. |
| **revert** | Bad merge to undo | `revert/*` (off the affected branch tip) | The branch where the bad merge landed | REQUIRED paired `forward/revert-*` to dev if reverting on main (enforced by preflight). SLA 8h, advisory. |

A "forward-port" is a normal feature-lane PR -- `forward/*` off `dev`, target `dev`, picking the file diff that landed out-of-band. Forward-ports re-enter the canonical flow forward; they are NOT back-syncs.

## Mandatory Preflight (BEFORE every branch creation or PR)

```bash
# 1. Run the preflight script with intended (source, target). Refuses bad pairs.
tools/branch-flow-preflight.sh <source-branch> <target-branch>
# Exits 0 + writes .branch-flow-cleared on PASS.
# Exits non-zero on FAIL with a specific reason.

# 2. Confirm branch protection on target (informational)
gh api repos/<owner>/<repo>/branches/<target>/protection | jq .

# 3. For cross-repo cherry-picks ONLY: sanitization scan
FILES="$(git diff --name-only origin/<target>..HEAD)"
git diff origin/<target>..HEAD | grep -E '^\+' | \
    grep -nE '(internal|secret|codename|token)-[a-z0-9-]{6,}'
git diff origin/<target>..HEAD | grep -E '^\+' | \
    LC_ALL=C grep -nP '[^\x00-\x7F]'  # non-ASCII (GitLab hooks reject)
# Fix any hits before pushing. See reference.md sanitization recipe.
```

The preflight script enforces:
- `target in {dev, staging, main}`
- `feature/*` and `fix/*` -> only `dev`
- `dev` -> only `staging`
- `staging` -> only `main`
- `hotfix/*` -> `main` (and a paired `forward/hotfix-*` MR must exist)
- `revert/*` -> matches its base (paired forward-port required if reverting on main)
- `forward/*` -> only `dev`
- ANY OTHER (source, target) PAIR IS REJECTED.

**Plus**: a `verify_base()` check confirms the source branch was actually **branched off the expected base** (feature/fix/forward branches off `origin/dev`; hotfix/revert-to-main off `origin/main`). The check uses `git merge-base` against all three canonical refs and picks the most-recent ancestor. A branch named `feat/foo` that was actually cut from `origin/staging` is REFUSED with a precise error naming the inferred base. This closes the gap where the previous version validated branch NAMES but not branch ORIGINS.

## Mandatory Behaviors

1. **Run the preflight script BEFORE every branch creation or PR.** Without `.branch-flow-cleared` for the planned (source, target), do not proceed. **The sentinel is single-use per push** -- once you push and the gate passes, re-run the preflight for the NEXT promotion or PR. Pre-push hook reads the sentinel and refuses if SHA or target differs.

2. **`--delete-branch=true` ONLY on feature/fix/forward/hotfix/revert branches.** NEVER on `dev`, `staging`, or `main`. Promotion PRs (`dev -> staging`, `staging -> main`) leave the source intact.

3. **`--merge` strategy on promotion PRs.** Preserves ancestry. Never rebase (creates sibling SHAs). Never squash on promotions (loses provenance).

4. **Fix the existing branch on a failed merge.** `git commit --amend` or new commit + `git push --force-with-lease`. NEVER create `-v2`, `-v3`.

5. **Stop on the SECOND identical opaque error.** "Identical" = same HTTP status code AND same error-body substring after stripping IDs/timestamps.

6. **Bot landings on main require forward-port within 8h (advisory).** Land at 02:00 -> open `forward/bot-<pkg>` -> `dev` ideally within 8h.

7. **NEVER target staging or main from a feature/fix branch.** The preflight will refuse; do not bypass.

## Red Flags (you are about to break the flow)

| Thought | Reality |
|---------|---------|
| "I'll branch off staging just this once" | Preflight will refuse. Off dev only. |
| "I'll target main directly because it's just a dep bump" | Bot lane. Bot config retargets to dev OR open a forward-port within shift. |
| "I need to back-sync main to dev" | That's a forward-port. Open `forward/bot-*` or `forward/hotfix-*` to dev. |
| "I'll create chore/promote-X-to-Y-v2" | Fix v1 in place. `git push --force-with-lease`. |
| "Rebase-merge will be cleaner" | Sibling SHAs. Use --merge on promotions. |
| "I'll force-push to dev to clean it up" | Branch protection blocks it. Preflight does NOT cover raw `git push --force`. Server-side protection is the backstop -- if it doesn't refuse, STOP and escalate. |
| "I'll merge via the GitHub/GitLab UI to bypass the pre-push hook" | Local pre-push Gate 3 fires only on direct `git push`. Server-side PR merges (gh/glab) DO NOT traverse it -- branch protection is required to enforce there. |
| "Same error twice, but this retry will work" | No. Stop. Diagnose: sanitization, retarget legality, platform paths. |
| "Test fixture needs a realistic secret string" | No. `FAKE-LEAK-PATTERN-FOR-TEST`. The hook config writes the pattern at test time. |

## Hotfix Recipe (P0 production)

```bash
# 1. Branch off main (the ONE legal direct-off-main case) and fix
git checkout -B hotfix/<short-desc> origin/main
# ... edits, commit ...
git push -u origin hotfix/<short-desc>
# 2. FORWARD-PORT BRANCH FIRST (preflight requires it):
git checkout -B forward/hotfix-<short-desc> origin/dev
git cherry-pick <hotfix-commit-sha>
git push -u origin forward/hotfix-<short-desc>
tools/branch-flow-preflight.sh forward/hotfix-<short-desc> dev
gh pr create --head forward/hotfix-<short-desc> --base dev \
  --title "forward-port: hotfix <short-desc>"
# 3. NOW open the hotfix PR (preflight verifies the forward branch exists):
tools/branch-flow-preflight.sh hotfix/<short-desc> main
gh pr create --head hotfix/<short-desc> --base main \
  --title "hotfix: <short-desc>"
# 4. Merge both within 8h. --delete-branch=true on both.
```

## Bot Landing Recovery (Dependabot/Renovate on main)

```bash
git checkout -B forward/bot-<pkg>-<ver> origin/dev
git cherry-pick <bot-merge-sha>
gh pr create --head forward/bot-<pkg>-<ver> --base dev \
  --title "forward-port: bot bump of <pkg> from main"
```

Long-term: retarget the bot to `dev` (`.github/dependabot.yml: target-branch: dev`).

## When the Flow Was Broken Before You Arrived

If you inherit divergence (main has commits dev/staging lack):
1. ASK the user how to reconcile. Do NOT autonomously open back-syncs.
2. Acceptable options (user picks): revert the off-flow commit; one-time documented convergence forward-port via dev; accept the divergence and document.
3. Resume canonical flow from the chosen base state.

## Failure Modes

See `reference.md` for the catalogue (F1-F12) and concrete sanitization regex list.

## Companion Skills

- `branch-sync-gate` -- pull-gate (REQUIRED before branch-flow-gate)
- `finishing-a-development-branch` -- handoff ceremony (gates its Step 4 Option 2)
- `progressive-code-review-gate` -- cr-battery + sentinel
- `git-branch-conventions` -- branch-name regex check (complementary)
