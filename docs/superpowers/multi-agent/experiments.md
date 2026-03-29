# Multi-Agent Skill Experiments

> **Purpose:** Structured evaluation comparing single-agent vs multi-agent modes.
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29

## Experiment Grid (9 cells × 3 runs = 27 total runs)

### plan-and-execute (3 cells)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| WP-1 | Simple utility function | "Add a string sanitizer utility" | A (single-agent) |
| WP-2 | Medium feature (3 components) | "Add rate limiting with UI config, API middleware, and DB schema" | B (close call) |
| WP-3 | Large cross-service with migration | "Replace auth system across 4 services with SSO, including data migration and rollback" | B (clear win) |

### subagent-driven-development (3 cells)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| SD-1 | Independent file changes | "Add logging to 3 independent services (no shared code)" | B (parallelism win) |
| SD-2 | Moderately coupled feature | "Add notification system: shared types, separate UI and backend" | Close call |
| SD-3 | Tightly coupled refactor | "Rename core entity across all layers (DB, API, UI, tests)" | A (serial wins) |

### brainstorming (3 cells)

| ID | Scenario | Description | Expected Winner |
|----|----------|-------------|----------------|
| BS-1 | Vague feature request | "How should we improve our onboarding experience?" | B (diversity win) |
| BS-2 | Architecture redesign | "Should we move from monolith to microservices?" | B (coverage win) |
| BS-3 | Simple UI change | "Add a dark mode toggle" | A (over-brainstorming) |

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

## Anti-Success: What Would Disprove Multi-Agent Value?

If experiments show ANY of these, multi-agent should NOT ship:
- Multi-agent quality ≤ single-agent on complex tasks (the strongest case)
- Multi-agent costs > 3× with ≤ marginal quality improvement
- Synthesis layer consistently produces worse output than individual branches
- Duplicate detection fails to catch > 30% of actual duplicates
- Human evaluators consistently prefer single-agent output clarity

## Analysis Plan

After all 27 runs:
1. Compute per-metric averages by condition and scenario
2. Statistical significance test (paired t-test, n=3 per cell — acknowledge low power)
3. Qualitative analysis of best/worst cases
4. Identify failure patterns (when does multi-agent consistently hurt?)
5. Produce candid recommendation with confidence intervals
