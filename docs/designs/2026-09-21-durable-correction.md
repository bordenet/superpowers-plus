# Durable correction design

## Decision

Add one automatic redirect skill, `durable-correction`, and demote `no-empty-promises` to explicit invocation. The redirect is driven by a human reporting recurrence or process failure, not by the agent noticing promise-shaped words in its own draft.

## Trigger boundary

The router uses explicit recurrence and failed-prior-fix phrases such as "this keeps happening," "same mistake again," and "you said this was fixed." Operational repetition ("run the tests again") and first-time defects are excluded. This keeps ordinary typo fixes and review comments lightweight while treating credible recurrence as a process signal.

`no-empty-promises` was not extended because its language-first detector can fire without a human correction and its remedy assumes that every failure should edit a skill. The new mechanism selects the control that owns the failure, which may be a test, validator, hook, source generator, CI gate, or skill.

## Procedure and evidence

The procedure separates urgent repair from prevention. A repair may contain immediate harm, but the agent may say `prevented` only after a persistent, proximate, falsifiable, executable, proportional, and generalized control is installed. Validation must show that the original failure is rejected, valid behavior still works, and the mechanism runs at the real workflow boundary.

The three resolution states are intentionally distinct:

- `contained`: immediate defect fixed; prevention not proven
- `prevented`: durable control plus negative and positive evidence
- `unresolved`: a named blocker remains

This prevents a repaired happy path from being presented as recurrence prevention.

## Recurrence after the redirect

If the failure returns after a prior control, the control itself becomes suspect. The skill requires evidence about why it did not run, detect, or block, then moves enforcement closer to the failure: prose to executable check, advisory to blocking, downstream to source boundary, manual to automatic, or exact example to causal invariant. Rewording the same failed checklist is insufficient without evidence that wording caused the miss.

## Composition

The redirect stays independent and delegates specialized work:

- `systematic-debugging` for technical root cause and repair
- `failure-autopsy` for a novel or disputed process cause
- `verification-before-completion` before resolution claims
- `evolution-loop` for wider pattern capture after the concrete control exists
- `receiving-code-review` for normal feedback below the recurrence threshold

## Alternatives rejected

1. Extend `no-empty-promises`: too coupled to agent-authored phrasing and hard-codes skill edits as the durable response.
2. Split detection and remediation into two skills: increases routing and composition failure modes without a clear independent use for either half.
3. Require a full post-mortem for every correction: creates false positives and ceremony for ordinary defects.

## Validation scenarios

| Scenario | Expected behavior |
|---|---|
| "This is the third time the same mistake happened" | Redirect wins over ordinary debugging; repair and prevention tracks open. |
| "You said this was fixed already and it happened again" | Failed-control recurrence; prior control is tested and enforcement escalates. |
| "The build has an unexpected failure" | Ordinary `systematic-debugging`; no redirect ceremony. |
| "There is a typo in the heading" | Local correction and verification only. |
| Deadline plus recurrence | Urgent repair may ship as `contained`; prevention cannot be claimed until proven. |

### Worked escalation

Human: "You said this was fixed already and it happened again. We need to ship today."

Expected agent behavior:

1. Classify as failed-control recurrence.
2. Repair or contain the current release defect.
3. Inspect why the prior control failed instead of repeating it.
4. Add a closer executable control and exercise it with the original failure and a valid case.
5. Report `contained` if only the release repair is complete, or `prevented` only with both-path evidence.

The static guidance fixture and router tests encode these obligations. The design was also compared against RED transcripts for a normal typo, a first recurrence under deadline pressure, and recurrence after a checklist; those baselines showed that the missing behavior was durable prevention under pressure, not basic defect correction.

## Behavioral test results

Fresh-agent GREEN tests loaded the finished skill before answering:

- In the deadline recurrence, the agent classified `failed-control recurrence`, repaired the canonical generator source, replaced the checklist with a blocking generated-output consistency check, required negative and positive cases, verified real CI/commit-gate invocation, and held status at `contained` until that evidence passed.
- In the first isolated typo, the agent made the one-word correction, searched for remaining occurrences, verified the narrow diff, and explicitly declined post-mortem ceremony.

Compared with the RED deadline baseline, the material change was that durable prevention was no longer deferred until after release. Compared with the RED typo baseline, the lightweight behavior was preserved.

The sanitized RED/GREEN outputs are persisted in `test/fixtures/skill-guidance/durable-correction/behavioral-results.json`. `test/durable-correction-behavior.test.js` makes the claimed behavioral differences executable: it requires failed-control classification, blocking enforcement, negative and positive cases, real-boundary execution, an evidence-limited status, and the ordinary-typo control case.
