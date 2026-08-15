# ADR-003: llm-skill-review Gate Pass Condition (Score as Metadata)

**Status:** Proposed (human checkpoint required before enforcement change)  
**Date:** 2026-08-15  
**Decision Makers:** pending  
**Related:** [#1187](https://github.com/bordenet/superpowers-plus/issues/1187), workstream WS6 in `TODO.md`

## Context

Gate 6 (`tools/pre-push-llm-skill-review-gate.sh`) requires `.llm-skill-review-cleared`, written only by `tools/run-llm-skill-review.sh --verdict PASS --min-score <N>` with `N >= 9.0`. The number compared to the floor is the Prose/Design cross-persona mean (see `skills/engineering/llm-skill-review/skill.md` after #1188).

During calibration on 2026-08-15, the same review process was run against three already-merged, actively used skills:

| Skill | Verdict | Prose/Design mean |
|-------|---------|-------------------|
| `repo-security-scan` | REJECT | 5.35 |
| `systematic-debugging` | REJECT | 5.80 |
| `llm-skill-review` (self) | REJECT | 5.43 |
| `explain-like-im-five` (new) | PASS WITH RISKS | 7.18-7.40 |

Concrete, independently verified defects were found (history-scan gap, contradictory fix thresholds, broken Evidence Schema example). A self-typed numeric floor that nothing cross-checks against unresolved S0/S1 findings is exactly how those defects stayed mergeable while a cleaner new skill could not clear the gate.

## Decision (proposed)

Change the **pass condition** for writing `.llm-skill-review-cleared` to:

1. **Verdict** is `PASS` or `PASS WITH RISKS` (reject still blocks).
2. **Zero unresolved S0/S1** findings remain in the evidence envelope (every S0/S1 either fixed or explicitly waived with rationale in the envelope).
3. **Evidence replay succeeds** via `tools/verify-cr-battery-evidence.js` (existing path; keep `--no-envelope` as loud escape hatch only).

Record the Prose/Design mean in the sentinel / envelope / PR body as **metadata**, not as the value compared to `LLM_SKILL_REVIEW_MIN`.

Optional follow-on (not required for the first enforcement change): keep publishing the mean under the PR heading convention already documented in `reference.md`, and add a warn-only advisory if mean < 9.0.

## Consequences

### Positive

- Gate failure tracks real unresolved severity, not an uncalibrated self-score.
- New skills can land with honest `PASS WITH RISKS` when S0/S1 are clear.
- Calibration defects become enforceable blockers.

### Negative / risks

- Agents may aim for `PASS WITH RISKS` instead of `PASS` if waivers are too easy — mitigate by requiring waiver rationale in the envelope and keeping S0 non-waivable without human text in the PR.
- Existing docs and help text that say ">= 9.0" must be updated in the same change set as the scripts.
- Does not by itself add behavioral tests of prompt-only skill guidance (see ADR follow-up / WS7).

## Non-goals

- Lowering or raising `9.0` as a soft quality target for humans.
- Replacing `progressive-harsh-review` persona ensemble.
- Auto-merging without human review of skill PRs.

## Implementation sketch (do not apply until Status = Accepted)

1. `tools/run-llm-skill-review.sh` — accept `--verdict PASS|PASS WITH RISKS`; require envelope with `unresolved_s0_s1: 0` (or equivalent derived count); write sentinel with recorded mean as metadata field.
2. `tools/pre-push-llm-skill-review-gate.sh` — stop comparing mean to `LLM_SKILL_REVIEW_MIN`; verify sentinel schema + evidence replay stamp.
3. Update `skills/engineering/llm-skill-review/{skill,reference}.md` Enforcement sections to match.
4. Add bats covering: PASS WITH RISKS + clean S0/S1 writes sentinel; PASS WITH RISKS + open S0 refuses; REJECT refuses regardless of score.

## Checkpoint

**Do not merge enforcement changes until a human sets Status to Accepted** (or rejects this ADR). Skill-content fixes from #1187 can land independently under current Gate 6 rules.
