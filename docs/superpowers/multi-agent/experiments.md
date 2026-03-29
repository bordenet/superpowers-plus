# Multi-Agent Skill Experiments

> **Purpose:** Structured evaluation comparing single-agent, multi-agent, and stronger baseline conditions.
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29

## Experimental Conditions

| Condition | Description | Cost Profile |
|-----------|-------------|-------------|
| **A** | Single-agent (status quo) | 1.0× baseline |
| **B** | Multi-agent (selected design: role-scoped parallel) | 1.5–2.5× depending on skill |
| **C** | Single-agent draft + parallel critics (draft once, critique in parallel) | ~1.3–1.8× (cheaper coordination than B) |
| **D** | 2 competing full outputs + judge (independent full attempts, judge picks best) | ~2.0× (high redundancy, strong synthesis forcing) |
| **E** | Serial + adversarial review (single-agent + existing harsh review loop) | ~1.2× (no multi-agent overhead, reuses existing tooling) |

**Why conditions C–E exist:** The initial harsh review (§8.1 Finding 1) identified that rejected designs (naive fan-out, random brainstorming) were weak strawmen. Conditions C–E are legitimate alternatives that could outperform B at lower cost. If C or E beats B, multi-agent role-scoping adds complexity without value.

### Condition applicability by skill

| Skill | A | B | C | D | E |
|-------|---|---|---|---|---|
| plan-and-execute | ✅ | ✅ Planning Council | ✅ Draft plan + parallel risk/test critics | ✅ 2 full plans + judge | ✅ Plan + progressive-harsh-review |
| subagent-driven-development | ✅ | ✅ Parallel Dispatch | ✅ Implement serially + parallel code reviewers | ✅ 2 parallel implementations + merge-best | ✅ Serial + progressive-code-review-gate |
| brainstorming | ✅ | ✅ Lens Ensemble | ✅ Single brainstorm + parallel devil's advocates | ✅ 2 independent brainstorms + synthesize | ✅ Brainstorm + adversarial-search review |

## Experiment Grid (9 scenarios × 5 conditions × 3 runs = 135 total runs)

### plan-and-execute (3 scenarios)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| WP-1 | Simple utility function | "Add a string sanitizer utility" | A or E (multi-agent overhead not justified) |
| WP-2 | Medium feature (3 components) | "Add rate limiting with UI config, API middleware, and DB schema" | B or C (close call — C may match B at lower cost) |
| WP-3 | Large cross-service with migration | "Replace auth system across 4 services with SSO, including data migration and rollback" | B (clear win — too many dimensions for single perspective) |

### subagent-driven-development (3 scenarios)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| SD-1 | Independent file changes | "Add logging to 3 independent services (no shared code)" | B (parallelism directly reduces latency) |
| SD-2 | Moderately coupled feature | "Add notification system: shared types, separate UI and backend" | C or E (merge risk makes B risky; critics catch issues cheaper) |
| SD-3 | Tightly coupled refactor | "Rename core entity across all layers (DB, API, UI, tests)" | A or E (serial wins; parallelism causes merge pain) |

### brainstorming (3 scenarios)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| BS-1 | Vague feature request | "How should we improve our onboarding experience?" | B (lens diversity adds value) |
| BS-2 | Architecture redesign | "Should we move from monolith to microservices?" | B or D (multi-dimensional; D forces independent reasoning) |
| BS-3 | Simple UI change | "Add a dark mode toggle" | A or E (over-brainstorming wastes time) |

## Metrics

| Metric | Type | Collection Method |
|--------|------|------------------|
| **Output quality** | 1–5 rating | Human blind evaluation (evaluator doesn't know condition) |
| **Completeness** | % of expected sections present | Checklist comparison |
| **Risks caught** | Count | Compare risk lists between A and B |
| **Contradictions** | Count | Manual review of merged output |
| **Duplicate content** | % | Structural comparison of branch outputs |
| **Token cost** | Count | Sum across all agents |
| **Wall-clock time** | Seconds | Timestamp diff |
| **Downstream success** | Pass/fail | Did the plan/code execute without major rework? |

## Execution Protocol

1. **Randomize condition order** — don't always run A first
2. **Fresh agent context** per cell — no cross-contamination
3. **Same scenario description** — identical prompt for A and B
4. **3 runs per cell** — statistical stability
5. **Record full traces** — for post-hoc analysis
6. **Blind human scoring** — evaluator doesn't know which condition produced output
7. **Record failures** — especially cases where multi-agent HURTS

## Success Criteria (must ALL hold before shipping multi-agent as default)

| Criterion | Threshold |
|-----------|-----------|
| Multi-agent ≥ single-agent quality on complex tasks | Rating ≥ 4.0 vs ≥ 3.5 |
| Multi-agent catches more risks on complex tasks | ≥ 2 additional risks |
| Multi-agent ≤ 2.5× token cost | Hard cap |
| Multi-agent doesn't hurt simple tasks | Quality ≥ single-agent OR correctly stays single-agent |
| No scenario where multi-agent is strictly worse on ALL metrics | Zero such scenarios |
| Operator readability ≥ single-agent | Rating difference > -0.5 |
| False risk rate (noise) ≤ acceptable | ≤ 30% of flagged risks are non-issues on human review |

## Anti-Success: What Would Disprove Multi-Agent Value?

If experiments show ANY of these, multi-agent should NOT ship:

- Multi-agent quality ≤ single-agent on complex tasks (the strongest case)
- Multi-agent costs > 3× with ≤ marginal quality improvement
- Synthesis layer consistently produces worse output than individual branches
- Duplicate detection fails to catch > 30% of actual duplicates
- Human evaluators consistently prefer single-agent output clarity
- **Condition C or E beats B** on complex tasks at lower cost (this means role-scoping adds complexity without value)

## Analysis Plan

After all 135 runs (9 scenarios × 5 conditions × 3 runs):

1. Compute per-metric averages by condition and scenario
2. Pairwise comparisons: B vs A (does multi-agent help?), B vs C/D/E (is role-scoping the right *kind* of multi-agent?)
3. Statistical significance test (paired t-test, n=3 per cell — acknowledge low power; Bonferroni correction for 10 pairwise comparisons)
4. Cost-effectiveness frontier: plot quality vs cost for all 5 conditions
5. Qualitative analysis of best/worst cases per condition
6. Identify failure patterns (when does multi-agent consistently hurt?)
7. Produce candid recommendation: which condition wins per scenario complexity tier?

### Phased Execution (recommended)

Full 135-run grid is expensive. Run in phases:

1. **Phase 1 (27 runs):** A vs B only on all 9 scenarios. If B never wins, stop.
2. **Phase 2 (27 runs):** Add C on all 9 scenarios. If C ≥ B everywhere, stop (simpler wins).
3. **Phase 3 (54 runs):** Add D and E. Full comparison for final recommendation.
