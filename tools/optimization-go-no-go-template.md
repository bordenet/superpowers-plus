# Phase 0 Decision-Gate Template

> Use this template at the end of Phase 0 to record the go/no-go decision
> per the plan's P0.7 hard-gate. ALL gates must hold to proceed.

## Phase 0 outputs (must all be present)

- [ ] `optimization-baseline-v1` git tag on dev tip
- [ ] `tools/optimization-baseline/baseline-cost-YYYYMMDD.tsv`
- [ ] `tools/optimization-baseline/baseline-ledger-YYYYMMDD.tsv`
- [ ] `test/ei-baseline.json` + `test/operative-baseline.json` populated
- [ ] `test/ei-move-detector.test.js` + `test/operative-move-detector.test.js` GREEN
- [ ] `test/hub-anchor-validator.test.js` GREEN
- [ ] `test/skill-invocation-smoke.test.js` GREEN; coverage ≥80%
- [ ] All in-scope skills have goldens in `test/golden-compression/`
- [ ] `tools/optimization-classification.tsv` complete (reviewer-confirmed)
- [ ] `test/skill-invocation-fixtures.json` reviewer-confirmed
  (verified_by ≠ "auto-seed (...)" for every entry)

## Hard gates (ALL must pass to proceed)

| Gate | Threshold | Status | Evidence |
|------|-----------|--------|----------|
| Harness coverage | ≥80% in-scope | | run output |
| Detectors green on baseline | EI + Op + Hub-anchor + Smoke all PASS | | CI run |
| Classification reveals reducible content | ≥8k aggregate tokens of DEC+COMP | | `tools/optimization-classification.tsv` aggregate |
| Engineering economics | est_program_hours × $150/hr < est_annual_savings (tokens × freq × $3/MTok) | | calculation |

## Recommendation

- [ ] GO — all gates pass; proceed to Phase 1 pilot
- [ ] ABORT — at least one gate fails; revert any in-flight changes,
      restore from `optimization-baseline-v1` tag, document residual
      headroom for future re-evaluation.

## Calculation: economics

```
tokens_saved_per_skill   = ${TOKENS_SAVED}
in_scope_skills          = ${IN_SCOPE_COUNT}
load_freq_per_week_user  = 50    (plan default)
weeks_per_year           = 52
active_users             = ${ACTIVE_USERS}
input_price_per_mtok     = 3     ($USD, Sonnet 4.6 input)

annual_token_savings = tokens_saved_per_skill × in_scope_skills × load_freq × 52 × users
annual_dollar_savings = annual_token_savings × 3e-6

program_hours = ${PROGRAM_HOURS}
program_cost  = program_hours × 150

GATE: program_cost < annual_dollar_savings ?
```

Document inputs and the computed result in your decision memo.
