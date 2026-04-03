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
  group: code-quality
  order: 1
  enables:
    - progressive-code-review-gate
    - verification-before-completion
  requires: []
  escalates_to: []
  internal: false
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
- When `verification-before-completion` detects the implementation→presentation transition and no valid sentinel exists for HEAD

**Gate chain position 3 of 4:**

| Gate (order) | Self-fires when | Short-circuit if |
|---|---|---|
| 1. `design-triad` | About to commit to a design before coding | Already ran this session |
| 2. `progressive-harsh-review` | About to present a non-code deliverable | Already ran on this artifact |
| **3. `code-review-battery`** | **About to present/commit/push code** | **Valid sentinel for HEAD exists** |
| 4. `verification-before-completion` | About to write any results-presenting response | Sentinel SHA == HEAD → skip re-dispatch |

**One-per-unit rule:** Battery fires at most once per coherent unit of work. If a valid `.code-review-cleared` sentinel exists for HEAD, the gate is already satisfied — do not re-dispatch.

## Procedure

### Phase 0: Sentinel Check (canonical skip gate — run before dispatching anything)

This is the canonical skip gate for the one-per-unit rule. Callers (`requesting-code-review`, `finishing-a-development-branch`, `progressive-code-review-gate`) should run this before dispatching. If a caller does not implement Phase 0 explicitly, the agent should apply this decision manually before invoking battery.

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

| Sentinel state | Decision |
|----------------|----------|
| `NO CLEARANCE` | Run battery (proceed to Phase 1). |
| Sentinel SHA ≠ HEAD SHA | Run battery (battery is stale). |
| Sentinel valid for HEAD but `WORKTREE_DIRTY` | Run battery (staged/unstaged changes exist that were not reviewed). |
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` | **Skip.** Battery already ran on the current code. Note the clearance and skip to Phase 6. |
| Malformed | Delete `.code-review-cleared`, run battery. |

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

**Mandatory activation (not subject to triage exclusion):**

- **Design Critic** is ALWAYS activated when changes touch: interfaces, public APIs, contracts, message schemas, shared state types, or cross-module boundaries.
- **Guardian** is ALWAYS activated when changes touch: retry logic, circuit breakers, rollback behavior, deployment config, feature flags, authentication/authorization, or state machine transitions.

**Overrides:** `--all` (force all), `--only=<name>`, `--skip=<name>`, `--round1-only` (skip escalation).

State your triage decision before dispatching:

```markdown
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
3. If 2+ reviewers flag the same location, **keep both** and check for **convergence**:
   - **True convergence** (promote to at least Important): reviewers reached the finding through *different reasoning paths* — e.g., one found it via data flow analysis, another via error handling review. The evidence snippets and rationale must differ.
   - **Echo convergence** (do NOT promote): reviewers cite the same evidence snippets, use near-identical phrasing, or clearly derived their finding from the same analytical path. This indicates shared context bias, not independent validation. Keep both findings at their original severity.
4. Note clean dimensions ("✅ No issues")
5. **Severity normalization**: Re-evaluate each finding against the shared severity definitions (provided to all reviewers). Reclassify when a reviewer's label doesn't match:
   - **Critical** = broken RIGHT NOW if shipped (wrong output, data loss, crash, security hole)
   - **Important** = breaks UNDER CONDITIONS (missing guard, incomplete fix, correctness risk)
   - **Minor** = works but violates standards (style, naming, missing docs/tests, observability)
   - If a reviewer labeled a finding Critical but it's a process/standards gap (e.g., "no tests added"), downgrade to Important or Minor. Note the reclassification: `[Reclassified: Critical → Minor — missing tests are a standards gap, not a production defect]`
   - True convergent findings (step 3) are promoted to at least Important. Echo convergent findings retain their original severity.
6. **Triple-filter** each Important/Critical finding and classify:

| Finding | CX Impact | Complexity | Testability | Action |
|---------|-----------|------------|-------------|--------|
| #1 ... | Fixes dead-air | +3 lines | Clearer tests | **Implement** |
| #3 ... | None | Adds abstraction | Marginal | **Defer** |

- **Implement**: Passes all 3 filters. **Propose exact code change.**
- **Defer**: Good finding but doesn't pass all 3. Document for future work.
- **Reject**: Correct observation but fix adds more complexity than it removes.

1. For each **Implement** finding, preserve the reviewer's **Regressions Risked** and **Durable Check** fields in the report. If multiple reviewers truly converge on the same finding (different reasoning paths), merge their regression analyses and pick the most actionable durable check.

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

### Correlated-Failure Detection

After synthesis, scan all reviewer outputs for **shared blind spots**:

1. **Evidence overlap check:** If ≥3 reviewers cite the same evidence snippets (same file + same line range) for their ONLY findings, flag `⚠️ CORRELATED EVIDENCE — reviewers may share a blind spot outside the cited region`. Expand the review scope to adjacent modules.
2. **Phrasing similarity check:** If 2+ reviewers use near-identical phrasing for different findings (copy-paste reasoning), flag `⚠️ ECHO REASONING — findings may reflect shared analytical bias, not independent analysis`. Require at least one reviewer to re-examine from a different entry point.
3. **Clean-sweep suspicion:** If ALL reviewers report zero findings, flag `⚠️ UNANIMOUS CLEAN — verify reviewers examined different evidence slices`. Check that each reviewer's output references different source files or code paths.

Correlated-failure flags do NOT change verdicts directly — they trigger expanded scope or re-examination. The goal is to surface shared blind spots, not to manufacture findings.

### Phase 6: Finalize Verdict + Write Sentinel

**Prerequisite:** Correlated-Failure Detection has completed and no re-examination was triggered.

If final verdict is `PASS` or `PASS_WITH_NITS` (all nits resolved):

```bash
# Run AFTER Correlated-Failure Detection — only if no re-examination was triggered
# The SHA must be the commit being reviewed/pushed (usually HEAD on the current branch).
# If you are reviewing a specific ref that differs from HEAD, use that ref's SHA.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
VERDICT="PASS"           # or PASS_WITH_NITS — set this once, use it below
REVIEWED_SHA=$(git rev-parse HEAD 2>/dev/null)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "v1|${REVIEWED_SHA}|${VERDICT}|${TIMESTAMP}" > "${REPO_ROOT}/.code-review-cleared"
echo "✅ Sentinel written: v1|${REVIEWED_SHA:0:8}|${VERDICT}|${TIMESTAMP}"
```

The pre-push hook reads `.code-review-cleared` and validates format (`v1`), SHA (must match the ref being pushed), and verdict (`PASS` or `PASS_WITH_NITS`). **Do not skip this step** — without the sentinel, the push will be blocked.

If verdict is `REJECT` or `PASS_WITH_FIXES`: do NOT write the sentinel. Fix all Critical/Important findings, re-dispatch, then write sentinel when the re-run passes.

### Gap Analysis

Monolith found something no specialist found → propose candidate pattern. Known exercise missed → candidate pattern. Recurring false positive → anti-pattern candidate. All go to `candidates/`.

### Error Handling

Reviewer fails → note, don't retry. Diff >3000 lines → warn, suggest chunks. Empty diff → skip.

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| All reviewers agree | No disagreements found | Force second-order critique: each reviewer must name ≥1 plausible failure mode or state why none exists — but the explanation must cite a specific property of the change (e.g., "pure rename, no callers affected"), not a generic "it's straightforward." Artificial dissent without reasoning is noise; generic dismissal is rubber-stamping |
| Duplicate findings | Same issue from 3 reviewers | Deduplicate in synthesis, attribute first finder |
| Reviewer fatigue | Later reviewers less thorough | Randomize dispatch order |
| Missing source context | Review diff without callers | Include grep results for all touched functions |
| Over-scoping | Reviewing unchanged code | Focus on diff + directly impacted callers only |

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
- **micro-harsh-review**: Per-batch review
