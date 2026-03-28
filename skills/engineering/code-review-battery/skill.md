---
name: code-review-battery
description: Use when reviewing code changes to dispatch parallel specialized reviewers instead of a single monolithic review — provides deeper, more precise findings across 5 focused lenses
summary: Dispatches 5 specialist reviewers (Defect Finder, Design Critic, Guardian, Standards Enforcer, Performance Analyst) in parallel with source context for ripple analysis. Aggregates findings with triple-filter prioritization and Round 2 escalation.
triggers:
  - code review battery
  - battery review
  - parallel review
  - dispatch reviewers
  - specialist review
  - multi-reviewer
  - review with battery
anti_triggers:
  - requesting code review
  - receiving code review
coordination:
  enables:
    - progressive-code-review-gate
  requires: []
source: superpowers-plus
---

# Code Review Battery

> **Wrong skill?** File-protocol review handoff → `code-review`. Reviewing a PR inline → `providing-code-review`. Pre-commit gate → `progressive-code-review-gate`.

Dispatch 5 specialized reviewer agents in parallel, each focused on a distinct set of review dimensions. A triage coordinator selects which reviewers to activate based on the diff, then aggregates findings into a unified report.

**Why this exists**: A single reviewer tries to evaluate everything simultaneously, leading to shallow coverage, inconsistent focus, and ~40% false positive rates. Specialized reviewers with focused prompts produce deeper analysis with near-zero false positives.

## When to Use

- When `requesting-code-review` or `progressive-code-review-gate` triggers a review
- When you want a thorough review of staged changes, a commit range, or a PR diff
- When reviewing someone else's code

## Scope Exclusions

- File-protocol review handoff → `code-review`
- Inline PR review → `providing-code-review`
- Pre-commit lint/tests → `pre-commit-gate`

## Procedure

### Phase 1: Triage

Analyze the diff and select reviewers:

| Reviewer | Focus | Activate When |
|----------|-------|---------------|
| **Defect Finder** | Correctness, edge cases, concurrency | Any code change |
| **Design Critic** | Factoring, complexity, API design | Adds/modifies classes, functions, public APIs |
| **Guardian** | Security, blast radius, backwards compat | Any code change |
| **Standards Enforcer** | Docs, test quality, observability | Always |
| **Performance Analyst** | Performance, logging | DB, loops, caching, network I/O, or >500 LOC |
| **Monolith** (on-demand) | All dimensions | `--all` flag or manual request |

**Decision rules:** Docs-only → Standards Enforcer only. Config-only → Guardian only. Any code → Defect Finder + Guardian + Standards Enforcer + conditionally Design Critic and Performance Analyst.

**Overrides:** `--all` (force all), `--only=<name>`, `--skip=<name>`, `--round1-only` (skip escalation).

State your triage decision before dispatching:
```
**Triage**: Activated: [list] | Skipped: [list] | Reason: [1-2 sentences]
```

### Phase 2: Diff + Source Context + Dispatch

Sub-agents have NO conversation context. Pass diff + source context inline.

**1. Capture diff:** `git diff --cached`, `git diff HEAD~1`, or `git diff main..HEAD`

**2. Source context for ripple analysis** (#1 missed-finding cause = reviewing diff in isolation):
- Fields SET/RESET/NULLED → grep all READERS
- Threshold comparisons → grep all PRODUCERS of crossing values
- Stateful code → full state type + transitions
- Changed signatures → all callers
- Cross-module calls → full callee body (or signature + state-mutating/throwing/early-return branches if budget-constrained)

**3. Dispatch ALL activated reviewers simultaneously** via `sub-agent-code-reviewer` (Augment) or `Task()` (Claude). Each gets: reviewer prompt + full diff + source context.

### Phase 3: Aggregate

After all reviewers return:
1. Sort findings: **Critical → Important → Minor**, then by file path
2. Prefix each with `[Reviewer Name]`
3. If 2+ reviewers flag the same location, **keep both** (different lenses provide complementary insight) and mark as **convergent** → promote to at least Important
4. Note clean dimensions ("✅ No issues")
5. **Severity normalization**: Re-evaluate each finding against the shared severity definitions (provided to all reviewers). Reclassify when a reviewer's label doesn't match:
   - **Critical** = broken RIGHT NOW if shipped (wrong output, data loss, crash, security hole)
   - **Important** = breaks UNDER CONDITIONS (missing guard, incomplete fix, correctness risk)
   - **Minor** = works but violates standards (style, naming, missing docs/tests, observability)
   - If a reviewer labeled a finding Critical but it's a process/standards gap (e.g., "no tests added"), downgrade to Important or Minor. Note the reclassification: `[Reclassified: Critical → Minor — missing tests are a standards gap, not a production defect]`
   - Convergent findings (step 3) are promoted to at least Important regardless.
6. **Triple-filter** each Important/Critical finding and classify:

| Finding | CX Impact | Complexity | Testability | Action |
|---------|-----------|------------|-------------|--------|
| #1 ... | Fixes dead-air | +3 lines | Clearer tests | **Implement** |
| #3 ... | None | Adds abstraction | Marginal | **Defer** |

- **Implement**: Passes all 3 filters. **Propose exact code change.**
- **Defer**: Good finding but doesn't pass all 3. Document for future work.
- **Reject**: Correct observation but fix adds more complexity than it removes.

7. For each **Implement** finding, preserve the reviewer's **Regressions Risked** and **Durable Check** fields in the report. If multiple reviewers converge on the same finding, merge their regression analyses and pick the most actionable durable check.

**Tightening**: If total findings >10, suppress Minor findings from the report body. Still count them in the summary line. Never suppress Critical or Important. State "Tightening applied: [N] Minor findings suppressed" in the report.

**Report format**: Header (activated/skipped reviewers) → Critical → Important → Minor (full, or "[N] Minor findings suppressed") → Clean Dimensions → Action Classification table → Durable Checks summary → Live Metrics → Summary (`Findings: [N] Critical, [N] Important, [N] Minor ([N] suppressed) | Metrics: durable=[N]% or N/A, convergent-count=[N], unresolved-critical=[N]`).

**Metrics**: Durable check rate (≥50%), convergent finding count, unresolved Critical count (target: 0). Offline: precision ≥75%, high-sev precision ≥80%, Round 2 yield ≤20%.

### Phase 4: Escalation (Round 2)

If ANY trigger fires after Round 1, re-dispatch a focused reviewer:

| Trigger | Re-run | Why |
|---------|--------|-----|
| >2 state/flag findings | Defect Finder (interaction-path focus) | Systemic timing/ordering |
| >3 test quality issues | Standards Enforcer (mock-focused) | Shared mock infrastructure |
| >50 lines removed or functions deleted | Guardian (deletion focus) | Callers may depend on removed behavior |
| "Pre-existing" issues flagged | Defect Finder (lifecycle focus) | Deeper structural gaps |

Re-dispatch with focused instruction (diff slice + refreshed context + trigger signal). Append under `### Round 2 Findings`. Skip if `--round1-only`, all clean, or diff <20 lines.

### Phase 5: Convergence

**STOP** when: unresolved Critical = 0, last 2 passes <20% new high-sev, durable check rate ≥50%.
**CONTINUE** if escalation trigger fires or Critical remains. **ESCALATE TO HUMAN** after 3 passes.

### Gap Analysis

Monolith found something no specialist found → propose candidate pattern. Known exercise missed → candidate pattern. Recurring false positive → anti-pattern candidate. All go to `candidates/`.

### Error Handling

Reviewer fails → note, don't retry. Diff >3000 lines → warn, suggest chunks. Empty diff → skip.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Sub-agent returns no findings on complex diff | Verify diff + source context was passed inline — sub-agents have no conversation context |
| False positives from isolated diff review | Include source context (callers, field readers) per Phase 2 — isolation is the #1 cause |
| Convergence never reached | Escalate to human after 3 passes |
| Monolith finds issues specialists missed | Log as gap-analysis candidate for specialist prompt improvement |

## Companion Skills

- **progressive-code-review-gate**: Primary consumer (dispatches this battery pre-commit)
- **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
- **code-review**: File-protocol review (alternative dispatch method)
