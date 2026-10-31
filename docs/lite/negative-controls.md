# Score repeated negative controls in consistent units

Proposed scoring clarification for a future approved experiment. The
[planning hold](README.md), [host isolation](measurement-isolation.md) and
[control-validity requirements](evaluation-validity.md) apply. No evaluations run
as part of this documentation change.

## Unit and aggregation

Before execution, freeze N distinct negative cases with expected outcome "no skill
invocation", and R scheduled repeats per case per arm. The proposal is N = 10 and
R = 2 for F (standalone Full) and C (the description candidate). Changing either
requires approval before scored calls; these figures do not authorize spend.

Freeze the scored observation window and any separately recorded startup setup
before calls. A negative expectation must be valid for that entire window. If
mandatory startup behavior cannot be separated from the scored task, mark the
negative set INVALID and re-plan; do not silently exclude bootstrap skills after
observing results.

For each arm, a repeat fails if any skill is actually invoked in that window. A case fails if
**any** of its R scheduled repeats fails. Count each distinct case once, regardless
of how many repeats or skill events failed. Define f and c as the failed-case
counts in F and C, respectively. Both use the same N-case denominator.

The proposed one-case allowance is exactly:

`c <= min(N, f + 1)`

Use integer counts for acceptance. Report the corresponding rates as `100*f/N`
and `100*c/N` percent; the allowance is `100/N` percentage points. With ten cases,
that is ten percentage points, not one percentage point. Do not compare a rate
to an unconverted count or use rounded displayed rates to decide acceptance.

Report failed-repeat counts out of N*R and raw skill-invocation events separately.
They are diagnostic measurements, not substitutes for f and c. Two invocations in
one repeat still fail only one repeat; two failed repeats of the same case still
fail only one case. Preserve each case/repeat observation so the totals are auditable.

## Deterministic execution and missing data

Pair arms by the same frozen case/repeat IDs and use fresh sessions with matched
configuration. Interleave the scheduled pairs in the predeclared order. If the
approved schedule spans batches, aggregate all R repeats for each case using the
same any-repeat rule; do not choose a favorable batch or average batch percentages.

A missing, crashed, timed-out or unobservable repeat makes the comparison INVALID.
It is never a clean negative or a smaller denominator. Do not substitute a retry
for an unfavorable result. Any replacement experiment requires a new declared
schedule and separately approved calls/spend; retain the original invalid record.
Extra unscheduled observations cannot improve the scored result retroactively.

## Boundary examples (N = 10, R = 2)

| f | c | One-case criterion | Reason |
|---:|---:|---|---|
| 0 | 0 | Meets | No extra failed case |
| 0 | 1 | Meets | Exactly one extra failed case |
| 0 | 2 | Fails | Two extra failed cases |
| 1 | 2 | Meets | 20% versus 10%, within the ten-point allowance |
| 1 | 3 | Fails | 30% versus 10%, beyond the allowance |
| 10 | 10 | Meets this relative bound only | Both arms fail every negative; this is not evidence of good absolute precision |
| 0 | unknown | INVALID | A missing C repeat cannot be scored as zero |

If both C repeats fail on the same case, c increases by one, not two. If separate
cases each fail once, c increases by two. The same aggregation applies to F.

Meeting this relative criterion alone never yields overall PASS. Apply all validity,
core, listing, router and positive-pair criteria, and report Full's absolute false
positives separately. Any additional absolute precision ceiling must be declared
and approved before execution; do not invent one after seeing the data. The owner
must explicitly accept the proposed allowance and aggregation before they are used.
This replaces the historical draft phrase "false-positive rate plus one case".
