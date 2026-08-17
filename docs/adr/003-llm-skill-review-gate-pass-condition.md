# ADR-003: llm-skill-review Gate Pass Condition (Score as Metadata)

**Status:** Accepted  
**Date:** 2026-08-15  
**Accepted:** 2026-08-15 (human: "Accept and proceed")  
**Decision Makers:** @bordenet  
**Related:** [#1187](https://github.com/bordenet/superpowers-plus/issues/1187), workstream WS6 in `TODO.md`

## Context

Gate 6 (`tools/pre-push-llm-skill-review-gate.sh`) previously required `.llm-skill-review-cleared`, written only by `tools/run-llm-skill-review.sh --verdict PASS --min-score <N>` with `N >= 9.0`. The number compared to the floor was the Prose/Design cross-persona mean (see `skills/engineering/llm-skill-review/skill.md` after #1188).

During calibration on 2026-08-15, the same review process was run against three already-merged, actively used skills:

| Skill | Verdict | Prose/Design mean |
|-------|---------|-------------------|
| `repo-security-scan` | REJECT | 5.35 |
| `systematic-debugging` | REJECT | 5.80 |
| `llm-skill-review` (self) | REJECT | 5.43 |
| `explain-like-im-five` (new) | PASS WITH RISKS | 7.18-7.40 |

Concrete, independently verified defects were found (history-scan gap, contradictory fix thresholds, broken Evidence Schema example). A self-typed numeric floor that nothing cross-checks against unresolved S0/S1 findings is exactly how those defects stayed mergeable while a cleaner new skill could not clear the gate.

## Decision

Change the **pass condition** for writing `.llm-skill-review-cleared` to all of the following:

1. **Verdict** is `PASS` or `PASS_WITH_RISKS` (CLI token uses underscore; reject still blocks).
2. **Envelope bound to the reviewed commit, and zero unresolved S0/S1.** The envelope MUST carry `"head_sha": "<sha>"` equal to the commit being cleared. The envelope filename also contains a SHA, but a filename is not an assertion: copying `<reviewed-sha>.json` onto `<unreviewed-sha>.json` replays a clean review onto code nobody read, and the sentinel that results names the *new* commit, so Gate 6's staleness check (`sentinel_sha != pushed_sha`) cannot detect it. Binding in the body makes forgery a false statement rather than a file copy.

   Each finding MUST carry:
   - `"severity": "S0"|"S1"|"S2"|"S3"`
   - optional `"waiver": {"by":"human","ref":"<PR-comment-URL>","rationale":"..."}`
   - Pass iff `count(findings where severity in {S0,S1} and waiver absent) == 0`.
   - **S0 is non-waivable via envelope alone** — requires human PR comment URL **and** explicit `--allow-s0-waiver` on the writer. S1 may use envelope waiver with rationale.
3. **Evidence replay succeeds** via `tools/verify-cr-battery-evidence.js` for every `evidence.command` (Decision §3 only). Decision §2 is enforced in `tools/run-llm-skill-review.sh` (severity/waiver check), **not** by verify-cr alone.
4. **Non-vacuous review proof** — refuse empty envelopes for `skills/**/*.md` changes:
   - **Required:** at least one `clean_dimensions` entry carrying replayable evidence (`{"evidence":{"command":"...","verifiable":true}}`) covering a scored axis. Array length alone is not the test — a bare string or an all-`verifiable:false` set is refused.
   - Attested metadata `{rounds, personas, artifact_paths, prose_design_mean}` is **additive** (recorded alongside), never a substitute for clean_dimensions.
   - `--no-envelope` is disallowed when writing `PASS_WITH_RISKS` (PASS-only escape hatch, still loud).

Record the Prose/Design mean in the sentinel as **metadata** (`mean=<n>`), not as the value compared to a numeric floor. Gate 6 stops floor-comparing the mean; it verifies sentinel schema + `evidence_replay=ok` (or `bypassed` only with `PASS`) + `unresolved_s0_s1=0`.

**Sentinel v2:** `v2|<HEAD_SHA>|<PASS|PASS_WITH_RISKS>|<UTC>|mean=<n>|unresolved_s0_s1=0|evidence_replay=<ok|bypassed>`

Missing or invalid `severity` on any finding **refuses the sentinel write** (do not silently exclude from the S0/S1 count).

Optional follow-on: warn-only advisory in CI if mean < 9.0 (soft quality target for humans, not a hard gate).

## Consequences

### Positive

- Gate failure tracks real unresolved severity, not an uncalibrated self-score.
- New skills can land with honest `PASS_WITH_RISKS` when S0/S1 are clear and review proof is non-vacuous.
- Calibration defects become enforceable blockers.

### Negative / risks

- Agents may aim for `PASS_WITH_RISKS` if S1 waivers are too easy — mitigate with required rationale + PR ref.
- `head_sha` binding stops envelope *reuse*, not dishonesty. An agent that writes the correct `head_sha` for a review it performed carelessly still clears the gate. The bar this sets is that clearing the gate on unreviewed code now requires stating something false, rather than copying a file. Binding to a diff hash instead of a commit SHA would narrow it further and is deliberately deferred — at the point the envelope is written, HEAD is the artifact under review.
- Requiring one replayable `clean_dimensions` entry raises the floor on cheap "looks fine" envelopes but does not force *breadth*: one replayable dimension plus nine judgment calls still passes. Per-axis coverage enforcement is left to the reviewer's scoring caps in `verify-cr-battery-evidence.js`.
- Existing docs and help text that said ">= 9.0" must be updated in the same change set as the scripts.
- Does not by itself add guidance-regression fixtures for prompt-only skills (see ADR-004).

## Non-goals

- Lowering or raising `9.0` as a soft quality target for humans.
- Replacing `progressive-harsh-review` persona ensemble.
- Auto-merging without human review of skill PRs.
- Treating an empty `{"findings":[],"clean_dimensions":[]}` envelope as proof of review.

## Implementation

1. Extend Evidence Schema in `skills/engineering/llm-skill-review/reference.md` with `severity` + optional `waiver`.
2. `tools/run-llm-skill-review.sh` — accept `--verdict PASS|PASS_WITH_RISKS`; enforce §2–§4; write v2 sentinel with `mean=` metadata; add `--allow-s0-waiver`.
3. `tools/pre-push-llm-skill-review-gate.sh` — stop comparing mean to a floor; verify v2 schema + unresolved_s0_s1=0 + evidence_replay.
4. Update Enforcement sections in `skill.md` / `reference.md` to match.
5. Bats covering: PASS_WITH_RISKS + clean S0/S1 + non-empty clean_dimensions writes sentinel; empty envelope refuses; open S0 refuses; REJECT refuses; `--no-envelope` with PASS_WITH_RISKS refuses.
