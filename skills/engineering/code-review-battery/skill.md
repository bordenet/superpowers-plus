---
name: code-review-battery
description: "Use when reviewing code changes to dispatch parallel specialized reviewers instead of a single monolithic review — provides deeper, more precise findings across focused lenses. Invoke as: /sp-cr-battery [min-score] [--security|--no-security] [--mode=bug-fix|feature] (optional 1.0–10.0 quality threshold, default 7.0; default 9.2 in Bug Fix Review Mode). Bug Fix Mode auto-activates on hotfix/* and fix/TICKET-* branches."
summary: Dispatches up to 6 specialist reviewers (Defect Finder, Design Critic, Guardian, Standards Enforcer, Performance Analyst, AttackerPersona) in parallel with source context for ripple analysis. AttackerPersona is signal-driven (security-sensitive diffs) and toggleable via --security/--no-security. Aggregates findings with triple-filter prioritization and Round 2 escalation.
triggers:
  - /sp-cr-battery
  - /sp-deepreview
  - code review battery
  - battery review
  - parallel review
  - dispatch reviewers
  - specialist review
  - multi-reviewer
  - review with battery
aliases: [CRB, review-battery]
anti_triggers:
  - requesting code review
  - receiving code review
coordination:
  group: code-quality
  order: 1
  enables:
    - progressive-code-review-gate
    - verification-before-completion
  requires: []
  escalates_to: []
  internal: false
source: superpowers-plus
augment_menu: true
composition:
  consumes: [code-changes]
  produces: [review-feedback]
  capabilities: [dispatches-review, parallel-review]
  priority: 25
---

# Code Review Battery

> **Wrong skill?** File-protocol review handoff → `code-review`. PR inline → `providing-code-review`. Pre-commit gate → `progressive-code-review-gate`. Full-repo security audit → `repo-security-scan` or `/sp-devsec-audit`. **Slash commands:** `/sp-cr-battery [min-score]` (primary; optional 1.0–10.0 quality threshold, default 7.0), `/sp-deepreview` (legacy).

Dispatch up to 6 specialized reviewer agents in parallel, each focused on a distinct set of review dimensions. A triage coordinator selects which reviewers to activate based on the diff, then aggregates findings into a unified report.

**Why this exists**: A single reviewer tries to evaluate everything simultaneously, leading to shallow coverage, inconsistent focus, and ~40% false positive rates. Specialized reviewers with focused prompts produce deeper analysis with near-zero false positives.

## When to Use

- When `requesting-code-review` or `progressive-code-review-gate` triggers a review
- When you want a thorough review of staged changes, a commit range, or a PR diff
- When reviewing someone else's code
- When `verification-before-completion` detects the implementation→presentation transition and no valid sentinel exists for HEAD

**Gate chain position 3 of 4:**

| Gate (order) | Self-fires when | Short-circuit if |
|---|---|---|
| 1. `debate` | About to commit to a design before coding | Already ran this session |
| 2. `progressive-harsh-review` | About to present a non-code deliverable | Already ran on this artifact |
| **3. `code-review-battery`** | **About to present/commit/push code** | **Valid sentinel for HEAD exists** |
| 4. `verification-before-completion` | About to write any results-presenting response | Sentinel SHA == HEAD → skip re-dispatch |

**One-per-unit rule:** Battery fires at most once per coherent unit of work. If a valid `.code-review-cleared` sentinel exists for HEAD, the gate is already satisfied — do not re-dispatch.

## Procedure

### Phase 0: Sentinel Check (canonical skip gate — run before dispatching anything)

Callers should run this before dispatching; if they don't, apply manually.

| Sentinel state | Decision |
|----------------|----------|
| `NO CLEARANCE` | Run battery (proceed to Phase 1). |
| Sentinel SHA ≠ HEAD SHA | Run battery (battery is stale). |
| Sentinel valid for HEAD but `WORKTREE_DIRTY` | Run battery (staged/unstaged changes exist that were not reviewed). |
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` | **Skip.** Battery already ran on the current code. Note the clearance and skip to Phase 6. |
| Malformed | Delete `.code-review-cleared`, run battery. |

### Phase 0.5: BugPath Mode Detection

Run immediately after the sentinel check. Detect whether this is a targeted bug fix, then set the mode before triage.

See `reference.md > BugPath Detection Snippet` for the detection script.

| Signal | BugPath Mode trigger |
|--------|---------------------|
| Branch prefix `hotfix/*` | Active |
| Branch prefix `fix/<TICKET>-*` | Active |
| Explicit flag `--mode=bug-fix` | Active |
| Explicit flag `--mode=feature` | Inactive (overrides branch detection) |

**When BugPath Mode is active:**
- **BugPath Verifier** is added to the activated reviewer set (mandatory — not skippable via `--skip`)
- Default threshold raises from 7.0 to **9.2** unless `--min-score` is explicitly provided
- Path-coverage floor applies to the score (see Phase 3 scoring)
- **SCOPE-SKIP**: surface as Important: `"BugPath Verifier SCOPE-SKIP — manual path-coverage review required"`. Score floor skipped; -1.5 aggregate.

**Output executive summary first** (see `reference.md > Executive Summary Template`). State mode: `**BugPath Mode: ACTIVE** | Branch: fix/TICKET | Threshold: 9.2 | BugPath Verifier: mandatory`. Also support `--mode=bug-fix` / `--mode=feature`.

### Phase 1: Triage

Analyze the diff and select reviewers:

| Reviewer | Focus | Activate When |
|----------|-------|---------------|
| **Defect Finder** | Correctness, edge cases, concurrency | Any code change |
| **Design Critic** | Factoring, complexity, API design | Adds/modifies classes, functions, public APIs |
| **Guardian** | Security, blast radius, backwards compat | Any code change |
| **Standards Enforcer** | Docs, test quality, observability | Always |
| **Performance Analyst** | Performance, logging | DB, loops, caching, network I/O, or >500 LOC |
| **AttackerPersona** | Credential-flow, AI-agent boundary, ident-vs-value, cookie/session, revival re-validation, CWE tagging | Any security signal (see `reference.md`) or `--security` flag |
| **BugPath Verifier** | Root cause, fix coverage, sibling bugs, regression test | BugPath Mode active (see Phase 0.5) — mandatory, not skippable |
| **Monolith** (on-demand) | All dimensions | `--all` flag or manual request |

**Decision rules:** Docs-only → Standards Enforcer only. Config-only → Guardian (+ Standards Enforcer / Defect Finder only if a metric/alarm or other dispatch signal below is present). Any code → Defect Finder + Guardian + Standards Enforcer + conditionally Design Critic and Performance Analyst.

**Signal-driven dispatch** (additive — a signal activates its reviewer(s); it never deactivates one already selected above). Scan the diff for these signals and route accordingly:

| Diff signal | Reviewer(s) | Owns |
|---|---|---|
| Metric/counter/event definition, or `.emit(`/`.inc(`/`publish(` call | Defect Finder + Standards Enforcer | Producer Trace, metric liveness, emission symmetry |
| Alarm/threshold definition, or an error branch that emits a metric or feeds an alarm | Guardian + Standards Enforcer | Alarm-feeding isolation, failure-mode differentiation, multi-provider coverage |
| External-dependency call / SDK error classifier (429, 5xx, provider error shapes) | Guardian | Multi-provider predicate coverage, monitoring blast radius |
| Field set to `null`/`0`/`false`/reset | Defect Finder + Guardian | Consumer trace, cross-cutting regressions |
| Public signature / interface / message schema / shared type change | Design Critic + Guardian | API design, backward compat |
| Loop over I/O, DB query, cache, network call, or >500 LOC | Performance Analyst | N+1, payload bloat, blocking I/O |
| File rename/move/delete | Guardian (inbound-reference focus) | Broken external consumers |
| Test-only change | Standards Enforcer (+ Defect Finder for revert-safety) | Mock fidelity, revert-safety |
| Security-class signal (caller-supplied URL, dynamic SQL identifier, new MCP tool/IPC, secret read, cookie/session, `_disabled/` revival) | AttackerPersona | Credential-flow, AI-agent boundary, ident-vs-value; tags + threat-model severity multiplier |

When no signal and no default activates a reviewer, skip it and say why in the triage line.

**Mandatory:** Guardian always on auth/retry/config/flags/state-machines. Design Critic always on interfaces/APIs/schemas/cross-module boundaries (Standard Mode).

**Design Critic in Bug Fix Mode (SUPPRESSED by default):** Re-activate only on API-change signals (see `reference.md > Design Critic Re-Activation (Bug Fix Mode)` for the detection snippet). If matched: activate + prefix triage with `⚠️ Design Critic re-activated on bug fix (API-change signal detected).` If not: state `Design Critic: SKIPPED (Bug Fix Mode — no API-change signals)`.

**Overrides:** `--all` (force all), `--only=<name>`, `--skip=<name>`, `--round1-only` (skip escalation), `--security` (force AttackerPersona on), `--no-security` (force AttackerPersona off), `--mode=bug-fix` (force Bug Fix Mode), `--mode=feature` (force Standard Mode). `--skip=BugPath Verifier` is silently ignored in Bug Fix Mode (the reviewer is mandatory).

State your triage decision before dispatching:

```markdown
**Triage**: Activated: [list] | Skipped: [list] | Reason: [1-2 sentences]
```

### Phase 2: Diff + Source Context + Dispatch

Sub-agents have NO conversation context. Pass diff + source context inline.

**1. Capture diff:** `git diff --cached`, `git diff HEAD~1`, or `git diff main..HEAD`

**2. Source context** (reviewing diff in isolation = #1 missed-finding cause): SET/RESET/NULLED → grep READERS; DEFINED symbols → grep PRODUCERS (zero producers = dead definition, mandatory finding); changed signatures → all callers; stateful code → full state + transitions.

**3. Inbound reference scan** (mandatory on renames/moves/deletes): `git diff --diff-filter=RD --name-only main..HEAD` for old paths, then grep across the entire repo. **MUST scan outside the changed directory** — hits outside the diff are mandatory CRITICAL findings. Include results in every reviewer's context.

**4. Dispatch ALL activated reviewers simultaneously** via `sub-agent-code-reviewer` (Augment) or `Task()` (Claude). Each gets: reviewer prompt + full diff + source context + inbound reference scan results.

### Phase 3: Aggregate

After all reviewers return:

1. Sort Critical→Important→Minor by file path; prefix each with `[Reviewer Name]`
2. 2+ reviewers at same location: keep both. **True convergence** (different reasoning paths) → promote to ≥ Important. **Echo convergence** (same evidence/phrasing) → retain original severity.
3. Clean dimensions need an `evidence` block — "no issues" without verifiable evidence → unverifiable, capped at 7.0.
4. **Severity**: Critical = broken RIGHT NOW (data loss, crash, security); Important = breaks UNDER CONDITIONS (incomplete fix, correctness risk); Minor = standards gap (style, tests). Elevate dead metrics/blinded alarms to Important. Downgrade process-gap findings (e.g. "no tests") from Critical. True-convergent findings promote to ≥ Important.
5. **Triple-filter** each Important/Critical finding on CX impact, complexity, and testability, then classify:

- **Implement**: Passes all 3 filters. **Propose exact code change.**
- **Defer**: Good finding but doesn't pass all 3. Document for future work.
- **Reject**: Correct observation but fix adds more complexity than it removes.

6. For each **Implement** finding, preserve the reviewer's **Regressions Risked** and **Durable Check** fields in the report. If multiple reviewers truly converge on the same finding (different reasoning paths), merge their regression analyses and pick the most actionable durable check.

**Tightening**: If total findings >10, suppress Minor findings from the report body. Still count them in the summary line. Never suppress Critical or Important. State "Tightening applied: [N] Minor findings suppressed" in the report.

**Report format**: Executive Summary → Header (activated/skipped reviewers) → Critical → Important → Minor (full, or "[N] Minor findings suppressed") → Clean Dimensions → Action Classification table → Durable Checks summary → Live Metrics → Summary (`Findings: [N] Critical, [N] Important, [N] Minor ([N] suppressed) | Metrics: durable=[N]% or N/A, convergent-count=[N], unresolved-critical=[N]`).

**Executive Summary** (MANDATORY first element): See `reference.md > Executive Summary Template` for the box format. Include BugPath Coverage row only in BugPath Mode. ACTION is a single plain-English sentence. VERDICT: `PASS`, `PASS_WITH_NITS`, `PASS_WITH_FIXES`, `REJECT`.

**Metrics**: Durable check rate (≥50%), convergent finding count, unresolved Critical count (target: 0). Offline: precision ≥75%, high-sev precision ≥80%, Round 2 yield ≤20%.
**Score** (after all fix rounds): `10.0 − (Critical×2.5) − (Important×1.5) − (Minor×0.25) − (durable<50% ? 0.5 : 0)`, floor 0.0. Calibration: 0 findings → 10.0; 1 Important → 8.5; 1 Critical → 7.5; 2 Importants + low durable → 6.5. Extract threshold from invocation (e.g. `/sp-cr-battery 8.5` → 8.5; default 7.0 or 9.2 in BugPath Mode). Score < threshold → abort Phase 6.

**BugPath Mode path-coverage floor** (BugPath Mode only — applied after standard formula): Extract `path_coverage` from the BugPath Verifier's structured output. Apply the cap: `INSUFFICIENT` (<3/4 dimensions verified) → cap aggregate at **6.5**; `PARTIAL` (3/4 verified) → cap at **8.0**; `FULL` (all 4 verified) → no cap. `SCOPE-SKIP` or `N/A` → no floor applied.

### Phase 4: Escalation (Round 2)

If ANY trigger fires after Round 1, re-dispatch a focused reviewer:

| Trigger | Re-run |
|---------|--------|
| >2 state/flag findings | Defect Finder (interaction-path focus) |
| >3 test quality issues | Standards Enforcer (mock-focused) |
| >50 lines removed, or renamed/moved/deleted files without inbound scan | Guardian (deletion/inbound-reference focus) |
| "Pre-existing" issues flagged | Defect Finder (lifecycle focus) |
| Diff adds/changes metric, alarm, or error-handling branch emitting metrics | Standards Enforcer (observability focus) |

Re-dispatch with focused instruction (diff slice + refreshed context + trigger signal). Append under `### Round 2 Findings`. Skip if `--round1-only`, all clean, or diff <20 lines.

### Phase 5: Convergence

**STOP** when: unresolved Critical = 0, last 2 passes <20% new high-sev, durable ≥50%. **CONTINUE** if escalation trigger fires or Critical remains. **ESCALATE TO HUMAN** after 3 passes.

### Correlated-Failure Detection

After synthesis, scan for **shared blind spots**:
- ≥3 reviewers cite the same evidence → flag `⚠️ CORRELATED EVIDENCE`. Expand scope to adjacent modules.
- 2+ use near-identical phrasing → flag `⚠️ ECHO REASONING`. Re-examine from different entry points.
- All reviewers zero findings → flag `⚠️ UNANIMOUS CLEAN`. Verify different evidence slices.

Flags trigger re-examination, not verdict changes.

### Phase 6: Finalize Verdict + Write Sentinel

**Prerequisite:** Correlated-Failure Detection has completed and no re-examination was triggered.

**Preserve the run (before sentinel write):**

1. Determine the verdict from this MR's score vs threshold: PASS if score >= threshold; PASS_WITH_NITS if at or above threshold but nits flagged; REJECT or PASS_WITH_FIXES otherwise.
2. Write a JSON envelope to `.cr-battery-runs/<HEAD-sha>.json` (per-engineer durable record; the directory is gitignored).

Schema: See `reference.md > Phase 6: Run Envelope Schema` for the full JSON envelope format.

Every finding AND clean-dimension verdict MUST carry an `evidence` block. Expectation types: `count`, `exit_code`, `match`, `absent`, `exact`. `verifiable: false` → capped at 7.0 by verifier, not falsified.

**Verifier replay:** `tools/run-battery.sh` invokes `verify-cr-battery-evidence.js` on the envelope. FALSIFIED claims abort the sentinel write (exit 1); unverifiable claims are capped at 7.0 (exit 0). Bug Fix Mode: mandatory. Standard Mode: graceful degrade (skipped if `.cr-battery-runs/` absent).

Run sentinel write: `tools/run-battery.sh --verdict PASS --min-score <threshold>`. ❌ Never write `.code-review-cleared` directly.

**Timing:** Sentinel becomes stale after commit — re-run before push. `REJECT`/`PASS_WITH_FIXES`: fix all Critical/Important, re-dispatch, then write sentinel.

**Gap Analysis:** Monolith finds what specialists missed → `candidates/`. Reviewer fails → note. Diff >3000 lines → warn + suggest chunks. Empty diff → skip.

## Anti-Patterns

See `reference.md` for the 5 anti-patterns (all-agree, duplicates, fatigue, missing-context, over-scoping) with detection + correction columns. Moved to the companion file to keep this skill under the per-skill line budget.

## Failure Modes

See `reference.md` for the 4 standard failure modes (no-findings, FPs-from-isolation, convergence-stuck, monolith-vs-specialist) with fixes. Moved to the companion file alongside the Anti-Patterns table.

## Companion Skills

- **progressive-code-review-gate**: Primary consumer (dispatches this battery pre-commit)
- **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
- **inter-agent-review-protocol**: File-protocol review (alternative dispatch method)
- **micro-harsh-review**: Per-batch review
