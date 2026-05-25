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
  - "merge to dev"
  - "cherry-pick"
  - "port to"
  - "back-sync"
  - "back sync"
  - "mirror to"
  - "hotfix"
  - "revert on main"
  - "forward-port"
  - "forward port"
  - "rebase"
  - "rebase onto"
anti_triggers:
  - "merge conflict resolution"
  - "git merge upstream"
description: "TRUSTED-ADVISOR for branch and PR hygiene. Auto-invokes when the user mentions creating a branch, opening a PR, shipping/promoting/deploying, cherry-picking, rebasing, hotfixing, or back-syncing. Suggests and explains; NEVER blocks. Every check exits 0. Three escape hatches: per-branch ack file (touch .git/base-advisory-ack-<branch>), GIT_BASE_OVERRIDE=1 env var, or use an exempt prefix (hotfix/, release/, backport/, tagged-release/). Multi-team config via .git-guidance.yml maps team/prefix to required base; defaults to origin/dev. Uses git first-parent chain to verify branch base (not naive merge-base). Advises on retry-suffix branches (-vN), back-sync/mirror naming, server-regex compliance, anti-leak fixtures, and loop-on-identical-error retries. Surfaces the same outcome a senior engineer would by looking over your shoulder -- orient, explain, suggest -- not a compliance gate."
summary: "Trusted-advisor gate: auto-invokes on branch/PR/promotion intent. Always exits 0. Suggests; never blocks. Run tools/branch-flow-preflight.sh before branch creation / PR / push."
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

**Announce at start:** "I'm using **branch-flow-gate** to advise (not block) on branch hygiene. (Auto-invoked by intent. Exits 0 either way.)"

## Core Principle

This skill **strongly recommends** branching patterns that keep teams aligned but **never mandates or precludes** deviation when a developer has a valid reason. Every check exits 0. Every advisory includes an explicit escape hatch. The goal is the same outcome a senior engineer would produce by looking over your shoulder -- orient, explain, suggest -- not a compliance gate.

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

Always exits 0. Writes `.branch-flow-cleared` sentinel as a check-receipt (audit trail, not enforcement).

## Multi-Team Config

For repos with heterogeneous flows, commit `.git-guidance.yml` at the repo root:

```yaml
default_base: origin/dev

teams:
  team-a:
    base: origin/dev
    exempt_prefixes: [hotfix/, release/]
  legacy-waterfall:
    base: origin/develop
    exempt_prefixes: [hotfix/, tagged-release/]
```

The script reads this file (when present) and picks the right `required_base` for the team / branch prefix. Falls back to `origin/dev` if no config or no match.

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

post-checkout fires once when the branch is created (before any work is invested). pre-push fires once per push (last local chance to notice). Neither blocks.

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
