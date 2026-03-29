# Multi-Agent Initiatives — Master Plan

> **Purpose:** Single source of truth for ALL multi-agent initiatives in superpowers-plus.
> **Updated:** 2026-03-29
> **Rule:** Every multi-agent initiative MUST be listed here. If it's not here, it doesn't exist.

## All Four Initiatives

| # | Initiative | Branch | Ship Priority | Status | Planning Docs |
|---|-----------|--------|--------------|--------|---------------|
| 1 | **Forked Debugging** | `feat/forked-debugging-superpower` | P1 — ship when experiments validate | Waves 1–4 complete, experiments pending | [Design Spec](../specs/2026-03-29-forked-debugging-design.md) · [TODO](../../plans/forked-debugging-TODO.md) · [Experiment Matrix](../../exercises/forked-debugging/experiment-matrix.md) · [Results](../../exercises/forked-debugging/results-comparison.md) |
| 2 | **Brainstorming Ensemble** | `feat/multi-agent-skill-upgrades` | P2 — ship first among skill upgrades (lowest risk) | Prototype complete, experiments pending | [TODO](todo-brainstorming.md) · [Ensemble Mode](../../skills/engineering/brainstorming/references/ensemble-mode.md) |
| 3 | **Planning Council** (writing-plans) | `feat/multi-agent-skill-upgrades` | P3 — ship second (medium risk, high leverage) | Prototype complete, experiments pending | [TODO](todo-writing-plans.md) · [Council Mode](../../skills/productivity/plan-and-execute/references/planning-council-mode.md) |
| 4 | **Parallel Dispatch** (subagent-driven-dev) | `feat/multi-agent-skill-upgrades` | P4 — ship last (highest risk, code merges) | Prototype complete, experiments pending | [TODO](todo-subagent-driven-development.md) · [Parallel Mode](../../skills/engineering/subagent-driven-development/references/parallel-dispatch-mode.md) |

## Shared Artifacts (used by all four)

| Artifact | Location | Purpose |
|----------|----------|---------|
| Multi-Agent Activation Rubric | `skills/_shared/multi-agent-activation-rubric.md` | When to escalate from single-agent to multi-agent |
| Evidence Schema | `skills/_shared/evidence-schema.md` | Structured evidence output (primarily for debugging, reusable) |
| Fork-Readiness Rubric | `skills/_shared/fork-readiness-rubric.md` | Debugging-specific fork decision (extends activation rubric) |
| Multi-Agent Strategy Doc | [multi-agent-skill-strategy.md](multi-agent-skill-strategy.md) | Architecture for initiatives 2–4 |
| Experiments Plan | [experiments.md](experiments.md) | Evaluation plan for initiatives 2–4 |

## Ship Order & Rationale

1. **Forked Debugging** — most novel capability; independent of others; validates core orchestration patterns
2. **Brainstorming Ensemble** — lowest risk (output is ideas, not code); validates synthesis quality
3. **Planning Council** — medium risk; better plans → better downstream execution; validates role-scoped parallelism
4. **Parallel Dispatch** — highest risk (code merges); highest reward when correct; needs strongest infrastructure

This order maximizes learning velocity: each initiative's lessons feed the next.

## Dependencies Between Initiatives

```
Forked Debugging ──(patterns)──→ Brainstorming Ensemble
                                      │
                                      ├──(synthesis lessons)──→ Planning Council
                                      │                              │
                                      └──(activation rubric)─────────┤
                                                                     │
                                                            ├──(plan quality)──→ Parallel Dispatch
                                                            │
                                                            └──(orchestration)──→ Parallel Dispatch
```

- Forked Debugging → Brainstorming: conductor pattern, evidence schema, bounded forking constraints
- Brainstorming → Planning Council: synthesis strategy lessons, duplicate detection approach
- Planning Council → Parallel Dispatch: plan decomposition feeds task isolation analysis
- All share: activation rubric, cost caps, kill thresholds, operator readability standards

## Remaining Work Summary

| Initiative | TODO Items Total | P1 (Critical) | P2 (Important) | P3 (Deferred) | Experiments Needed |
|-----------|-----------------|---------------|----------------|---------------|-------------------|
| Forked Debugging | 23 (12 done) | 0 remaining | 4 remaining | 7 remaining | 15 cells × 3 runs = 45 |
| Brainstorming | 16 | 5 | 5 | 6 | 3 cells × 3 runs = 9 |
| Planning Council | 15 | 5 | 5 | 5 | 3 cells × 3 runs = 9 |
| Parallel Dispatch | 15 | 5 | 5 | 5 | 3 cells × 3 runs = 9 |
| **TOTAL** | **69** | **15** | **19** | **23** | **72 experiment runs** |

## Decision Gates

No initiative ships to main without passing ALL of these:

| Gate | Criteria |
|------|----------|
| **Design review** | Harsh review completed, findings addressed |
| **Prototype validated** | At least 1 experiment run produces expected results |
| **Cost bounded** | Multi-agent mode stays within per-skill cost cap |
| **Quality improvement proven** | Multi-agent output rated higher than single-agent on complex tasks |
| **No regression on simple tasks** | Activation rubric correctly stays single-agent on simple tasks |
| **Operator readable** | Final output clarity ≥ single-agent |
| **Fallback works** | Graceful degradation to single-agent if multi-agent fails |

## Open Cross-Cutting Questions

- [ ] Should all four initiatives merge to dev independently, or batch into a single "multi-agent release"?
- [ ] How do we measure cumulative cost impact when multiple skills use multi-agent in a single session?
- [ ] Should the activation rubric be session-aware (lower threshold if session has budget, raise if depleted)?
- [ ] How do we prevent activation rubric score inflation (agents learning to always score ≥5)?
