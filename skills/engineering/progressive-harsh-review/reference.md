# Progressive Harsh Review reference

## Project-min override

A repository minimum raises only the PASS floor. It does not change the REJECT band or critical veto.

- A generic PASS below the project floor becomes PASS_WITH_FIXES.
- A score below 7 remains REJECT under every floor.
- A score meeting the higher floor may PASS if all other convergence conditions hold.

Example: 8.3 under a 9.2 floor is PASS_WITH_FIXES; 6.8 is REJECT; 9.5 may PASS.

## Scoring output format

For each persona, emit one compact table with C/S/V/B/OR scores, one finding per dimension, and the weighted calculation. Then report:

- rounds completed;
- each persona's weighted score and the equal-weight mean;
- generic verdict and active project floor;
- vetoes and correlation flags;
- final verdict;
- fixes verified in the artifact;
- remaining blockers or open risks.

## Anti-Patterns

| Anti-pattern | Correction |
|---|---|
| Soft review with no score below 7 | Recalibrate against a known-bad example. |
| Same comment for three iterations | Escalate to a structural fix. |
| Style-only findings | Check logic, omissions, and failure handling first. |
| Perfection paralysis | Enforce the three-round cap and escalate. |
| Missing context | Read the complete artifact and relevant repository evidence. |

## Companion skills

- `code-review-battery`: code review.
- `llm-skill-review`: skill and prompt review.
- `debate`: compare design alternatives.
- `brainstorming`: create alternatives before review.
- `think-twice`: break circular remediation.
- `plan-and-execute`: replan a defective execution design.
