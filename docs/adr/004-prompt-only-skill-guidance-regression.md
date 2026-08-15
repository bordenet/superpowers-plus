# ADR-004: Guidance-Regression Fixtures for Prompt-Only Skills

**Status:** Proposed (human checkpoint required before implementation)  
**Date:** 2026-08-15  
**Decision Makers:** pending  
**Related:** [#1187](https://github.com/bordenet/superpowers-plus/issues/1187), workstream WS7 in `TODO.md`

## Context

Existing tests for skills mostly check **structure and compression** (frontmatter parse, token budgets, DAG nodes, operative baselines). They do not check whether skill guidance text still encodes the obligations that reviews keep rediscovering (e.g. secrets history required; Verification must not claim clean after HEAD-only greps).

Calibration reviews found real guidance defects. Structure tests would not have caught those.

## Goal

Define a minimal fixture format and runner contract so selected **prompt-only** skills can regress on **guidance obligations** (static skill-text assertions, optionally checked-in plan transcripts) without requiring a live multi-persona LLM review on every commit.

This is **guidance-regression**, not live agent behavioral simulation.

## Non-goals (this ADR)

- Implementing the runner in the same change set as Status=Proposed.
- Replacing `llm-skill-review` Gate 6.
- Full agent simulation / multi-turn trajectory scoring in CI v0.

## Proposed fixture shape

Per skill under `test/fixtures/skill-guidance/<skill-name>/`:

```text
case-001/
  input.md          # scenario the agent is given (documentation for humans)
  expected.json     # machine-checkable obligations against skill.md text
  notes.md          # why this case exists
```

`expected.json` (v0 sketch):

```json
{
  "skill_path": "skills/security/repo-security-scan/skill.md",
  "must_match": ["gitleaks|git log -p", "INCOMPLETE"],
  "must_not_match": ["head -n 500"],
  "required_phrases": ["Phase 1 history", "do not claim"]
}
```

v0 checks are **static against the skill text** (and optionally against a checked-in `plan.md` transcript). They are not assertions against live model output in CI.

## Runner contract (future; after Status = Accepted)

1. Load `skill.md` (+ local `.md` files the skill says to load).
2. For each case, assert skill text contains / omits patterns from `expected.json`.
3. Optionally, if a `plan.md` transcript is checked in, assert the plan cites required phases.
4. Exit non-zero on mismatch; integrate behind `./tools/test-all.sh` flag before making it default.

## Pilot candidates

1. `repo-security-scan` — history required; no silent truncation; Verification wording.
2. `systematic-debugging` — single 2+ failed-fix threshold; no duplicate companions.
3. `llm-skill-review` — Evidence Schema example includes `reviewer`/`dimension`.

## Open questions (human)

- Own job vs fold into `harsh-review.sh`?
- Are transcript fixtures allowed, or text-only assertions forever?
- Who owns updating fixtures when intentional skill behavior changes?

## Checkpoint

No runner implementation until a human sets Status to **Accepted** (or rejects this ADR) and picks the pilot set.
