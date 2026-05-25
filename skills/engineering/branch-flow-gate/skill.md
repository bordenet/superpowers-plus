---
name: branch-flow-gate
source: superpowers-plus
augment_menu: true
auto_invoke: true
triggers:
  - "create a branch"
  - "checkout -b"
  - "git checkout -B"
  - "new branch"
  - "branch off"
  - "branched from"
  - "open a PR"
  - "open an MR"
  - "open a pull request"
  - "merge request"
  - "ship this"
  - "ship it"
  - "deploy this"
  - "deploy to prod"
  - "release this"
  - "release to staging"
  - "release to production"
  - "push to prod"
  - "push to production"
  - "land this"
  - "land it"
  - "get this out"
  - "ready to merge"
  - "promote dev"
  - "promote staging"
  - "promote to main"
  - "promote to staging"
  - "merge to main"
  - "merge to staging"
  - "cherry-pick"
  - "port to"
  - "back-sync"
  - "back sync"
  - "mirror to"
  - "start a hotfix"
  - "cut a hotfix"
  - "revert on main"
  - "forward-port"
  - "forward port"
  - "rebase onto"
anti_triggers:
  - "merge conflict resolution"
  - "git merge upstream"
  - "git pull --rebase"
  - "interactive rebase"
  - "rebase this comment"
description: "Trusted-advisor gate for branch and PR hygiene. Auto-invokes when the user mentions creating a branch, opening a PR, shipping/promoting/deploying, cherry-picking, rebasing, hotfixing, or back-syncing. Suggests and explains in-script (preflight always exits 0) and writes a .branch-flow-cleared sentinel that pre-push Gate 3 hard-consumes on pushes to dev/staging/main. Three escape hatches: per-branch ack file (touch .git/base-advisory-ack-<branch>), GIT_BASE_OVERRIDE=1 env var, or use an exempt prefix (hotfix/, release/, backport/, tagged-release/) which is exempt from the base-alignment advisory and typically does not target dev/staging/main. Multi-team config via .git-guidance.yml (currently only default_base is read). Uses git first-parent chain to verify branch base (not naive merge-base). Advises on retry-suffix branches (-vN), back-sync/mirror naming, server-regex compliance, anti-leak fixtures, and loop-on-identical-error retries."
summary: "Branch/PR-hygiene advisor: auto-invokes on intent. Preflight script always exits 0; pre-push Gate 3 refuses pushes to dev/staging/main without a valid .branch-flow-cleared sentinel. Run tools/branch-flow-preflight.sh before branch creation / PR / push."
coordination:
  group: engineering
  order: 1
  requires: ["branch-sync-gate"]
  enables: ["finishing-a-development-branch"]
  internal: false
composition:
  consumes: [source-branch, target-branch]
  produces: [preflight-sentinel, advisory-log]
  capabilities: [advisory-hygiene, base-alignment-check, sanitization-scan, identical-error-stop]
  priority: 100
  optional: false
  requires_all: false
---

# branch-flow-gate -- Trusted Advisor (auto-invoked)

> **Wrong skill?** Branch-name regex check alone -> `git-branch-conventions`. Pull before resuming work -> `branch-sync-gate`. Per-team flow specifics -> team's own documentation.

**Announce at start:** "I'm using **branch-flow-gate** to advise on branch hygiene. (Auto-invoked by intent. The preflight script never blocks; the sentinel it writes is consumed by pre-push Gate 3 on pushes to dev/staging/main.)"

## Core Principle

This skill **strongly recommends** branching patterns that keep teams aligned but **never mandates or precludes** deviation when a developer has a valid reason. Every advisory exits 0 from the skill / preflight script. Every advisory includes an explicit escape hatch.

> **Honest disclosure -- this is advisory in-script, hard-blocking at push time.** The preflight writes a `.branch-flow-cleared` sentinel which is consumed by `pre-push` Gate 3 on pushes to `dev`/`staging`/`main`. Without a valid sentinel for the pushed SHA, Gate 3 **refuses the push**. Hotfix/release/backport branches don't push to those canonical targets so are de-facto exempt; if your flow pushes hotfixes directly to `main`, use a `hotfix/*` branch name (auto-exempt) or set `GIT_BASE_OVERRIDE=1`.

## Auto-Invocation

This skill fires on intent:
- Creating a branch (`checkout -b`, `git checkout -B`, "branch off ...")
- Opening a PR/MR ("open a PR", "merge request", "ready to merge")
- Shipping ("ship this", "deploy", "push to prod", "release", "promote ...")
- Cross-environment moves ("cherry-pick", "back-sync", "forward-port", "rebase onto ...")
- Hotfix / revert language

When the user mentions any of these in conversation, this skill activates before the action and advises.

## What It Advises On

| Check | When it fires | What it suggests |
|---|---|---|
| **Base alignment** | Branch is not on the required base's first-parent chain | Rebase onto the recommended base, OR acknowledge if the deviation is intentional |
| **Retry suffix** | Branch name ends in `-vN` | Recover the original branch via amend + force-with-lease |
| **Back-sync / mirror naming** | Name matches `back-sync/*`, `sync/*`, `mirror/*`, etc. | Use forward-port semantics (branch off destination, pull source forward) |
| **Anti-leak patterns** | Diff contains literal `<word>-internal-*`, `*-secret-*`, etc. | Use `FAKE-LEAK-PATTERN-FOR-TEST` placeholder |
| **Non-ASCII in diff** | Added lines contain non-ASCII | GitLab ASCII-only commit-msg hook may reject |
| **Identical error loop** | Two consecutive opaque errors after retry | STOP and diagnose before retrying again |

ALL advisories print a soft message and exit 0. The script never blocks.

## Escape Hatches (in order of permanence)

1. **Per-branch acknowledgement** (most common):
   ```bash
   touch .git/base-advisory-ack-<branch-slug>
   ```
   The advisory will not repeat for this branch.

2. **One-shot override** (when you know what you're doing this time):
   ```bash
   GIT_BASE_OVERRIDE=1 git push
   ```
   Document the reason in your PR description.

3. **Exempt prefix** (documented deviation lane):
   - `hotfix/*` (emergency production patch)
   - `release/*` (release branch)
   - `backport/*` (backporting to older release)
   - `tagged-release/*` (release-tag work)

   Branches with these prefixes skip the base advisory entirely.

## Mandatory Preflight (BEFORE every branch creation or PR)

```bash
# Auto-mode (checks current branch against required base from config):
tools/branch-flow-preflight.sh

# Explicit pair-mode:
tools/branch-flow-preflight.sh <source-branch> <target-branch>

# Identical-error stop helper:
tools/branch-flow-preflight.sh --identical-check "$ERR1" "$ERR2"
```

Always exits 0. Writes `.branch-flow-cleared` sentinel that pre-push Gate 3 consumes on pushes to `dev`/`staging`/`main`. The sentinel must match the pushed commit's SHA; missing or stale (SHA-mismatched) sentinels == refused push.

## Multi-Team Config

For repos with heterogeneous flows, commit `.git-guidance.yml` at the repo root:

```yaml
default_base: origin/dev
```

**Currently only `default_base:` is read.** A richer per-team mapping (with `teams:` and per-team `exempt_prefixes:`) is planned but not yet implemented in `tools/branch-flow-preflight.sh`. Until then, legacy teams needing a different base must set it as the repo-wide `default_base` and use the hardcoded exempt prefixes (`hotfix/`, `release/`, `backport/`, `tagged-release/`).

## Hook Installation (advisory; not required)

To get advisory output automatically:

**Lefthook** (`lefthook.yml`):
```yaml
post-checkout:
  commands:
    branch-base-advisory:
      run: ./tools/branch-flow-preflight.sh
pre-push:
  commands:
    branch-base-advisory:
      run: ./tools/branch-flow-preflight.sh
```

**Husky** (`package.json`):
```json
"husky": {
  "hooks": {
    "post-checkout": "./tools/branch-flow-preflight.sh",
    "pre-push": "./tools/branch-flow-preflight.sh"
  }
}
```

post-checkout fires once when the branch is created (before any work is invested). pre-push fires once per push (last local chance to notice). Neither of these advisory hooks blocks.

> Note: This repo's `tools/pre-push` (installed via `tools/install-hooks.sh`) is the **authoritative** path. It runs Gate 3 which consumes `.branch-flow-cleared` and **does** block when the sentinel is missing/stale on pushes to dev/staging/main. The Lefthook/Husky integrations above are for contributors who want advisory output earlier in the workflow; they do not replace the in-tree hook. **If `tools/pre-push` is not installed in this clone, Gate 3 does not fire and pushes to dev/staging/main rely entirely on PR review** -- see reference.md F10. **Server-side enforcement (CI runners, merge-queue automation, bot merges) requires a server-side hook or branch-protection rule -- the local sentinel does not propagate.**

## Anti-Patterns to Avoid (in the skill, not the user)

- **`exit 1` in a guidance hook** -- if it can block, it's enforcement, not guidance.
- **Repeating the advisory on every checkout** -- once per branch, at creation. Repetition trains dismissal.
- **No escape hatch** -- a tool with no override breeds resentment.
- **Not suppressing `hotfix/*`** -- every advisory tool that fires on emergencies loses developer trust.
- **Raw `merge-base` without first-parent filtering** -- false negatives when dev/main share recent history.
- **Blocking CI status check** -- surface advisories as PR annotations or comments, never required checks.

## When the Advisory Should Be Heeded vs. Ignored

| Situation | Action |
|---|---|
| Just-branched feature off dev | Advisory should be quiet (or PASS) |
| Forgot to fetch + dev moved -> stale-but-correct base | Advisory says "rebase recommended"; you can ignore for now |
| Cut from staging because of an integration test | Heed the advisory and rebase OR acknowledge with `touch .git/base-advisory-ack-<branch>` |
| P0 hotfix at 3am off main | Use `hotfix/` prefix; advisory exempts |
| Renaming `-v2` retry to canonical name | Heed and `git branch -m`; recover via amend + force-with-lease |

## Companion Skills

- `branch-sync-gate` -- pull-gate (REQUIRED before this skill)
- `git-branch-conventions` -- branch-name regex check
- `finishing-a-development-branch` -- handoff ceremony
- `progressive-code-review-gate` -- cr-battery + sentinel

## Failure Modes

See `reference.md` for the catalogue and concrete advisory examples.
