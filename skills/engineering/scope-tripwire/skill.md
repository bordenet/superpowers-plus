---
name: scope-tripwire
source: superpowers-plus
augment_menu: true
auto_invoke: true
triggers:
  - "scope tripwire"
  - "scope drift"
  - "diff vs estimate"
  - "/sp-scope-tripwire"
anti_triggers:
  - "feature spec"
  - "linear estimate calibration"
description: "Pre-push advisory gate that compares the branch's cumulative diff against the linked Linear ticket's point-estimate. Warns when LOC exceeds N times the estimate (default 2x at 200 LOC/point). Surfaces the incident-2026-1507 failure mode (1pt ticket -> +8,750 LOC) at push time without blocking by default."
summary: "Advisory-by-default gate (block-mode in the dogfood repo). Reads Linear estimate via GraphQL, caches in .git/, fail-opens on every error path. Layered alongside pre-push-loc-gate (per-commit raw LOC) and hotfix-charter (per-branch budget doc)."
coordination:
  group: push-gates
  order: 0
  requires: []
  enables: []
  internal: false
composition:
  consumes: [branch-context, linear-ticket]
  produces: [scope-tripwire-finding]
  capabilities: [gates-quality]
  priority: 50
---

# Scope Tripwire

> **Wrong skill?** Per-commit raw-LOC cap -> `pre-push-loc-gate` (`tools/pre-push-loc-gate.sh`). Per-branch charter doc -> `hotfix-charter`. Branch naming -> `git-branch-conventions`. Code review -> `code-review-battery`.

A pre-push gate that asks one question: **does this push's cumulative diff blow past the linked Linear ticket's estimate?** Catches the incident-2026-1507 failure mode where a 1-point ticket grew to +8,750 / -4,195 LOC across 73 files -- the per-commit LOC gate missed it because individual commits stayed under 500 LOC; the symptom was the branch as a whole.

## Quick start

**Default behavior:** advisory only (warn mode) -- the gate prints a structured stderr line and lets the push proceed. The engineer is the gate; the script just makes the ratio visible at push time.

**To enable:**

```bash
# Option 1: sole pre-push hook
ln -sf $REPO_ROOT/tools/scope-tripwire-check.sh .git/hooks/pre-push
chmod +x .git/hooks/pre-push

# Option 2: chained alongside the LOC gate (RECOMMENDED if you already run it)
cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
$REPO_ROOT/tools/pre-push-loc-gate.sh "$@" || exit $?
$REPO_ROOT/tools/scope-tripwire-check.sh "$@" || exit $?
EOF
chmod +x .git/hooks/pre-push
```

`install.sh` does NOT auto-wire pre-push hooks in this repo today (no central wiring exists). Adoption is opt-in per the snippet above. Extending install.sh to auto-wire is filed as a follow-up TODO.

## What it does

For every push:

1. **Resolve a Linear ref from the branch name.** Regex `[A-Z]+-[0-9]+` against `git symbolic-ref --short HEAD`. Multi-ref: first match wins (override with `SCOPE_TRIPWIRE_REF=`). No match -> advisory and exit 0.
2. **Check the cache.** `.git/scope-tripwire-cache/<REF>.json` with TTL (default 1h). Within TTL: skip API.
3. **Fetch from Linear** (GraphQL). 5-second curl timeout. Fail-open: timeout, network, non-200, GraphQL errors, no estimate, ticket not found -> stderr advisory, exit 0. Every failure mode caches a `reason` (`api_down|not_found|no_estimate|ok`) to prevent re-hammering.
4. **Compute cumulative LOC** against the base branch. Base auto-resolves via `@{upstream}` -> `origin/main` -> `origin/HEAD`. Repos using `dev` as the main branch get the right base via `@{upstream}` without code changes.
5. **Compare** against `LOC_PER_POINT * estimate * SCOPE_TRIPWIRE_RATIO` (default 200 * estimate * 2.0).
6. **Mode dispatch:** `warn` -> stderr advisory + exit 0. `block` -> exit 1 unless bypassed.

## Mode dispatch (precedence)

1. `SCOPE_TRIPWIRE_MODE=warn|block` env var (highest)
2. `.scope-tripwire-mode` file at repo root (one line: `warn` or `block`; committed -- survives fork/mirror)
3. (removed in plus: no automatic mode detection based on remote URL)
4. Default -> `warn`

**Default behavior:** superpowers-plus defaults to `warn` mode (advisory-only, not blocking). This reflects the design decision to inform engineers of scope drift rather than forcibly block pushes. Enable `block` mode per-repo by committing a `.scope-tripwire-mode` file or setting `SCOPE_TRIPWIRE_MODE=block` if your workflow requires hard enforcement.

## Configuration

| Env var | Default | Purpose |
|---|---|---|
| `LOC_PER_POINT` | 200 | Starter calibration. Tune per team after observing N merged PRs. |
| `SCOPE_TRIPWIRE_RATIO` | 2.0 | Multiplier on (LOC_PER_POINT * estimate). |
| `SCOPE_TRIPWIRE_MODE` | auto | `warn` (advisory) or `block` (exit 1 on overage). |
| `SCOPE_TRIPWIRE_BYPASS` | 0 | `=1`: acknowledged bypass in block mode. Logs to evasion.log. |
| `SCOPE_TRIPWIRE_SKIP` | 0 | `=1`: skip the gate entirely. No API call, no diff scan. Logs to evasion.log. |
| `SCOPE_TRIPWIRE_REF` | auto | Override branch-name parsing (e.g., `PROJ-1234`). |
| `SCOPE_TRIPWIRE_BASE` | auto | Override base branch resolution. |
| `SCOPE_TRIPWIRE_CACHE_TTL` | 3600 | Cache TTL in seconds. `0` forces re-fetch. |
| `LINEAR_API_URL` | api.linear.app/graphql | Override API endpoint. |
| `LINEAR_API_KEY` | from environment | Linear API token. Missing -> fail-open advisory. |

## Exit codes (stable contract)

| Mode | Result | Bypass/Skip | Exit | stderr |
|---|---|---|---|---|
| any | no ref / no key / API down / no estimate / not found | n/a | 0 | advisory line |
| any | within threshold | n/a | 0 | silent |
| `warn` | exceeds threshold | n/a | 0 | structured advisory with ticket+LOC+ratio |
| `block` | exceeds threshold | unset | 1 | refusal with remediation options |
| `block` | exceeds threshold | `BYPASS=1` | 0 | warning + evasion.log append |
| any | `SKIP=1` | yes | 0 | warning + evasion.log append |
| any | invalid env / not in git repo | n/a | 2 | error |

## Evasion log

`BYPASS` and `SKIP` both append one line to `.git/scope-tripwire-evasion.log`:

```
2026-06-10T20:15:00Z BYPASS incident-2026-1507 LOC=8750 EST=1 RATIO=43.7 BRANCH=fix/incident-2026-1507-... USER=engineer@example.com
```

The log is **`.git`-local and never pushed**. This is a *trust-the-engineer* gate, not central enforcement -- the log exists so the same engineer can grep their own history. Aligns with the INFORM-not-BLOCK framing.

## What this gate is NOT

- **Not a security gate.** Bypass is one env var away; the audit trail is local-only.
- **Not a sizing oracle.** `LOC_PER_POINT=200` is a starter; teams will calibrate. The gate is advisory by default for exactly this reason.
- **Not a replacement for code review.** Scope drift is a process signal; reviewers still need to look at what changed.
- **Not multi-ticket-aware.** A branch matching `incident-2026-1507` and `INFRA-99` compares against the first ref's estimate only (with a stderr note). Sum-of-estimates is deferred.

## Composition with peer gates

| Gate | When | What it gates |
|---|---|---|
| `hotfix-charter-check.sh` | pre-commit | `hotfix/*` and `fix/incident-*` branches need a HOTFIX-CHARTER.md doc |
| `pre-push-loc-gate.sh` | pre-push | Per-commit raw LOC ceiling (default 500) |
| **`scope-tripwire-check.sh`** | **pre-push** | **Cumulative branch LOC vs Linear ticket estimate** |

The three gates are independent signals: charter forces upfront articulation, LOC gate catches single oversize commits, scope-tripwire catches cumulative drift. All three can fire on the same push without conflict.

## Failure modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Linear API down | Push prints "Linear API unreachable" advisory, succeeds | Wait for Linear; cached as `api_down` for `SCOPE_TRIPWIRE_CACHE_TTL` to prevent re-hammering |
| Ticket re-estimated after cache | Gate uses stale estimate | `rm .git/scope-tripwire-cache/PROJ-NNNN.json` to force refresh |
| Branch has no Linear ref (chore/, doc/, exp/) | Advisory "no Linear ref" + exit 0 | Expected; use `SCOPE_TRIPWIRE_REF=` if you want the gate to compare against a specific ticket anyway |
| Engineer bypassing repeatedly | `.git/scope-tripwire-evasion.log` grows | Behavior signal; raise in 1:1 or retro. Log is local-only on purpose. |

## Why this exists

The 2026-06-10 incident-2026-1507 hotfix shipped a 1-point ticket as +8,750 / -4,195 LOC across 73 files. The per-commit LOC gate (shipped same day) didn't catch it because each individual commit stayed under 500. The scope-tripwire is the cumulative complement: it asks "is the BRANCH bigger than the TICKET said it would be?", which is the right question for scope-drift detection.

The gate is advisory by default per the 20260610-18 design pivot. We want engineers to *see* the ratio at push time and use their judgment. The incident-2026-1507 retrospective is the source-of-truth: `docs/retrospectives/incident-2026-1507-cr-battery-false-positives.md`.
