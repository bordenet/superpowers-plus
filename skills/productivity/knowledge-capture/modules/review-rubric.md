# Module: review rubric

Load before Phase 4 (review). Minimum 2 rounds, maximum 3. Dispatch a sub-agent
reviewer or do an explicit role switch — the drafter does not review their own
draft in the same pass.

## Checks

| # | Check | Severity if failed |
|---|-------|--------------------|
| 1 | Every body claim traces to a Source Notes entry or a linked reference | critical |
| 2 | No unsourced assertions stated as fact | critical |
| 3 | BLUF is present, is 1-2 sentences, and states the actual bottom line | critical |
| 4 | All P0 coverage areas are addressed in the article | critical |
| 5 | No provenance tags (`[sme-stated]` / `[inferred]`) inline in the body | major |
| 6 | Failure Modes section has symptom + cause + recovery for each row | major |
| 7 | Terminology matches how the SME used it (no invented synonyms) | major |
| 8 | No marketing language, filler openers, or hedge words | minor |
| 9 | Headings follow the BLUF template order | minor |
| 10 | Links resolve (run link verification) | major |

## Gate

Proceed to Phase 5 only with **0 critical and 0 major findings**. Minor
findings may ship with a note, at the interviewee's discretion.

## Round protocol

1. Run all checks, list findings with severity.
2. Present to interviewee; ask about gaps or disagreements.
3. Fix → re-review changed sections only.
4. If round 3 still has critical/major findings, stop and escalate to the
   interviewee rather than shipping.
