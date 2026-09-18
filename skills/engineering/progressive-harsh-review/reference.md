# Progressive Harsh Review reference

## Project-min override

A repository minimum raises only the PASS floor. It does not change the REJECT band or critical veto.

- A generic PASS below the project floor becomes PASS_WITH_FIXES.
- A score below 7 remains REJECT under every floor.
- A score meeting the higher floor may PASS if all other convergence conditions hold.

Example: 8.3 under a 9.2 floor is PASS_WITH_FIXES; 6.8 is REJECT; 9.5 may PASS.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Self-reviewed in same thinking pass | Use sub-agent (preferred) — in-process role switch with no context isolation is significantly less reliable; if used, explicitly discard the author's reasoning and start fresh from the artifact text |
| All personas gave same feedback | Each persona must name ≥1 plausible failure mode unique to their lens, or cite a specific property of the change explaining why none exists (generic dismissal = rubber-stamp) — identical findings means the lenses aren't distinct |
| Score inflated to avoid re-work | Findings with concrete issues MUST score ≤7 on that dimension |
| Remediation skipped after REJECT | REJECT means start over. No "fix one thing and call it done" |
| Only reviewed happy path | OpsRealist must consider failure, rollback, 3am scenarios, and OE telemetry for new behavior |
| Round N mean lower than Round N-1 | Remediation introduced new issues — flag REGRESSION, root-cause before Round N+1 |
| No output summary before presenting | Always emit PHR SUMMARY block (rounds, mean, verdict, project-min, vetoes) |
| Shipped at round 3 without convergence | 3 rounds = escalate to human with blocker list — never auto-ship |
| Unrecoverable finding scored only on Blind Spots | Must ALSO score Operational Risk to be veto-eligible — Blind Spots alone bypasses the veto gate |
| Skipped sentinel write after PASS | Pre-push Gate 5 refuses the push with "PHR sentinel missing." Run `tools/run-phr.sh --verdict PASS --min-score <N>` and retry. |

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
