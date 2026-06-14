---
name: session-handoff
source: superpowers-plus
augment_menu: true
auto_invoke: true
triggers:
  - "starting work on"
  - "let me check this repo"
  - "let me check the repo"
  - "switching to"
  - "picking this up"
  - "what's new in"
  - "what changed in"
  - "first-touch"
  - "/sp-session-handoff"
anti_triggers:
  - "continuing work on"     # branch-sync-gate handles RESUME
  - "resuming work on"       # branch-sync-gate handles RESUME
  - "picking up where I left off"   # branch-sync-gate (engineer's own context)
description: "Cold-start advisory: surfaces commits on remote-tracking refs that landed in the last 24 hours and are NOT yet on any local branch. Catches the incident-2026-1507 pattern where a sibling machine pushed work between sessions and the next session edited blind. Read-only; never blocks."
summary: "Per-repo first-touch sibling-activity check. Lists actionable handoff commits grouped by ref. Composes with branch-sync-gate (RESUME path) and runs BEFORE it in the session-start chain."
coordination:
  group: session-start
  order: -1
  requires: []
  enables: ["branch-sync-gate"]
  internal: false
composition:
  consumes: [git-state]
  produces: [sibling-activity-summary]
  capabilities: [advisory]
  priority: 50
---

# Session Handoff

> **Wrong skill?** Resuming an explicit prior context -> `branch-sync-gate` (fetches + checks behind/diverged). Per-branch budget doc -> `hotfix-charter`. Per-commit LOC ceiling -> `pre-push-loc-gate`. Cumulative branch vs ticket estimate -> `scope-tripwire`.

A first-touch advisory that asks: **what landed in this repo since I last looked?** Lists commits on remote-tracking refs from the last 24 hours that are NOT yet reachable from any local branch -- the actionable handoff set. Run it BEFORE editing on a cold start.

## When this fires (vs. `branch-sync-gate`)

| Verb / phrase | Skill | Why |
|---|---|---|
| "let me check this repo" / "starting work on..." / "what's new in..." | **session-handoff** | Cold start; engineer needs to see what landed |
| "continuing work on..." / "resuming where I left off..." | `branch-sync-gate` | Explicit resume; fetch + behind/diverged check |
| `/sp-session-handoff` (explicit) | **session-handoff** | Manual invocation |
| `/sp-sync` (explicit) | `branch-sync-gate` | Manual invocation |

Both should run when both verbs are present. Session-handoff runs first (`order: -1`), reports the sibling-activity summary, then branch-sync-gate handles the fetch + alignment workflow.

## Quick start

```bash
# Manually, from the repo root
tools/session-handoff-check.sh

# With assurance line when no activity found
tools/session-handoff-check.sh --verbose

# Wider window (default: "24 hours ago")
SESSION_HANDOFF_WINDOW="7 days ago" tools/session-handoff-check.sh

# Skip the git fetch (offline or hostile network)
SESSION_HANDOFF_NO_FETCH=1 tools/session-handoff-check.sh
```

## What it shows

Output (stderr; nothing on stdout):

```
session-handoff: sibling activity detected (window: 24 hours ago)
  (Read these commits before editing -- they may overlap your planned work.)

  origin/fix/incident-2026-1507-intro-protection
    2026-06-09T14:32  user@example.com  fix: greeting registration race
    2026-06-09T15:14  user@example.com  test: add ceiling-hit case

  origin/main
    2026-06-10T11:22  user@example.com  Merge commit message

  Tip: `git log <ref> --since="24 hours ago"` for full detail.
```

Silent when no commits match (unless `--verbose`).

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `SESSION_HANDOFF_WINDOW` | `24 hours ago` | Any `git log --since=` expression |
| `SESSION_HANDOFF_VERBOSE` | `0` | `1`: print assurance line when no activity |
| `SESSION_HANDOFF_NO_FETCH` | `0` | `1`: skip `git fetch` (uses stale local refs) |
| `SESSION_HANDOFF_FETCH_TIMEOUT` | `10` | Wall-clock budget for fetch (seconds) |

## Exit codes

| Exit | Meaning |
|---|---|
| 0 | Activity surfaced; OR no activity; OR fetch failed (advisory only -- never blocks) |
| 2 | Not in a git repo, OR invalid env var, OR git log error |

## Composition with peer skills

`session-handoff` is the COLD-START half of the session-orientation pair:

```
+-- session-start group --------------------+
|                                            |
|  [order: -1]  session-handoff              |  <-- "what landed since I left?"
|       |                                    |
|       v   produces: sibling-activity       |
|                                            |
|  [order:  0]  branch-sync-gate             |  <-- "now fetch + reconcile"
|                                            |
+--------------------------------------------+
```

Both skills running back-to-back is intended ergonomics. The incident-2026-1507 pattern would have been caught by this skill firing on cold-start verbs.

## Why this exists

The 2026-06-10 incident-2026-1507 involved two machines doing parallel work on the same hotfix branch. Branch-sync-gate did not fire because the engineer never said "continuing" or "resuming" -- it was a cold start with edit verbs ("let me look at..."). The sibling commits sat invisible on the feature branch while the engineer started a second parallel implementation. Hours of fork-merge confusion followed.
