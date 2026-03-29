# Confidence Scoring Calibration Guide

> **Purpose:** Shared calibration reference for all evidence confidence scores across investigator skills.
> **Used by:** All investigator skills, evidence-adjudicator, debug-conductor.

## Universal Calibration Table

| Score | Label | Evidence Requirements | Example |
|-------|-------|----------------------|---------|
| 0.9–1.0 | **Near-certain** | Reproduced deterministically + all disconfirming addressed + no evidence gaps | Bug reproduced 3/3, control experiment confirms, deployment timestamp matches exactly |
| 0.8–0.9 | **Strong** | Strong correlation + reproduction OR strong correlation + expert confirmation | Deployment within 5min of incident + logs show the exact error introduced |
| 0.7–0.8 | **Solid** | Multiple independent evidence sources agree, minor gaps acceptable | Timeline, logs, and metrics all point to same cause; one trace is missing |
| 0.5–0.7 | **Moderate** | Reasonable hypothesis with supporting evidence but significant gaps remain | Config change correlates but haven't tested whether reverting fixes it |
| 0.3–0.5 | **Weak** | Plausible based on limited evidence; needs more investigation | "This looks like a timing issue" based on log timestamps only |
| 0.1–0.3 | **Speculative** | Educated guess without direct evidence | "Maybe the network changed" with no network metrics available |
| 0.0–0.1 | **No basis** | No evidence; pure speculation | Should never be submitted as evidence |

## Per-Evidence-Type Calibration

### Timeline Evidence (timeline-trace-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| Deployment within 30min of incident | 0.7 | +0.1 if within 5min | -0.2 if >2hr gap |
| Complete trace (all services accounted) | +0.15 | — | -0.1 per missing service |
| No trace gaps | +0.1 | — | -0.05 per gap |
| Temporal correlation confirmed | +0.1 | — | — |

### LLM Behavior Evidence (llm-behavior-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| Prompt diff explains misselection | 0.6 | +0.15 if semantic analysis confirms ambiguity | -0.1 if other prompt changes also occurred |
| Context utilization correlation | 0.5 | +0.2 if threshold clearly separates success/failure | -0.1 if correlation is weak |
| Tool description A/B test | 0.8 | +0.1 if deterministic | — |

### Telephony Evidence (telephony-flow-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| SIP trace shows exact failure point | 0.75 | +0.1 if multiple calls show same pattern | -0.1 if only 1 call sampled |
| RTP packet analysis confirms direction | 0.8 | — | -0.15 if tcpdump is incomplete |
| Call state machine divergence found | 0.7 | +0.15 if event ordering is deterministic | -0.1 if timing-dependent |

### State Evidence (state-consistency-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| Cross-source comparison shows discrepancy | 0.7 | +0.1 if discrepancy is deterministic | -0.1 if intermittent |
| Replication lag measured and exceeds SLA | 0.65 | +0.15 if lag explains exact inconsistency window | — |
| Cache re-fill from stale replica confirmed | 0.8 | +0.1 if cache TTL matches observation | — |

### Infra Evidence (infra-config-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| Config change within incident window | 0.7 | +0.15 if exact config key matches failure mode | -0.2 if multiple changes in window |
| Resource exhaustion at threshold | 0.75 | +0.1 if correlated with error rate | — |
| Cloud provider silent change | 0.5 | +0.2 if provider confirms | -0.1 if inferred only |

### Experiment Evidence (reproduction-experiment-investigator)

| Evidence | Base Confidence | Boost | Penalty |
|----------|----------------|-------|---------|
| 3/3 reproduction | 0.9 | +0.05 if control experiment also passes | — |
| 2/3 reproduction | 0.6 | — | -0.1 if environment differs from prod |
| 1/3 reproduction | 0.35 | — | -0.1 if environment differs from prod |
| 0/3 reproduction | 0.1 | — | — (hypothesis likely wrong) |

## Aggregation Rules (for evidence-adjudicator)

When combining evidence across types:

1. **Independent sources multiply confidence:** If timeline and infra evidence independently support the same hypothesis, combined confidence ≈ 1 - (1 - conf_A) × (1 - conf_B)
2. **Correlated sources don't stack:** If two evidence items came from the same log file, don't double-count
3. **Reproduction trumps correlation:** Experiment evidence (reproduction) always outranks observational evidence (timeline, logs)
4. **Disconfirming evidence subtracts:** net = supporting - (disconfirming × relevance_weight)

## Calibration Caveats

1. These scores are **starting values** based on engineering judgment, not empirical calibration
2. True calibration requires comparing predicted confidence to actual correctness across many investigations
3. Until calibrated empirically: **prefer underconfidence to overconfidence** (err toward lower scores)
4. Kill threshold (0.3) and accept threshold (0.8) are operational gates enforced by the conductor (see `fork-readiness-rubric.md` for canonical values)
