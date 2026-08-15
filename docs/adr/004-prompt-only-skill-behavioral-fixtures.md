# Design Note: Behavioral Fixtures for Prompt-Only Skills

**Status:** Draft (brainstorm / scoped design only — no runner implementation)  
**Date:** 2026-08-15  
**Related:** [#1187](https://github.com/bordenet/superpowers-plus/issues/1187), workstream WS7 in `TODO.md`

## Problem

Existing tests for skills mostly check **structure and compression** (frontmatter parse, token budgets, DAG nodes, operative baselines). They do not check whether an agent following a skill's guidance would actually do the right thing.

Calibration reviews found real guidance defects (e.g. secrets scan missing history while Verification claimed "zero remaining issues"). Structure tests would not have caught those.

## Goal

Define a minimal fixture format and runner contract so selected **prompt-only** skills can regress on guidance-correctness without requiring a live multi-persona LLM review on every commit.

## Non-goals (this design note)

- Implementing the runner in this PR.
- Replacing `llm-skill-review` Gate 6.
- Full agent simulation / multi-turn trajectory scoring.

## Proposed fixture shape

Per skill under `test/fixtures/skill-behavior/<skill-name>/`:

```text
case-001/
  input.md          # scenario the agent is given
  expected.json     # machine-checkable obligations
  notes.md          # why this case exists (human)
```

`expected.json` (v0 sketch):

```json
{
  "must_invoke_commands_matching": ["gitleaks|git log -p"],
  "must_not_claim": ["zero remaining issues.*HEAD-only"],
  "required_phases": ["Phase 1 history"],
  "forbidden_rationalizations": ["skip history because tool missing without fallback"]
}
```

Checks are **static against the skill text** and/or against a recorded agent plan transcript — not against live model output in CI v0.

## Runner contract (future)

1. Load skill.md (+ referenced local .md files the skill says to load).
2. For each case, assert skill text contains / omits patterns from `expected.json`.
3. Optionally, if a `plan.md` transcript is checked in, assert the plan cites required phases.
4. Exit non-zero on mismatch; integrate as an optional job behind `./tools/test-all.sh` flag before making it default.

## Pilot candidates

1. `repo-security-scan` — history required; Verification wording.
2. `systematic-debugging` — single 2+ failed-fix threshold; no duplicate companions.
3. `llm-skill-review` — Evidence Schema example includes `reviewer`/`dimension`.

## Open questions (human)

- Own job vs fold into `harsh-review.sh`?
- Are transcript fixtures allowed, or text-only assertions forever?
- Who owns updating fixtures when intentional skill behavior changes?

## Checkpoint

No implementation until a human accepts this note (or a successor ADR) and picks the pilot set.
