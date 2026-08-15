# ADR-004: Guidance-Regression Fixtures for Prompt-Only Skills

**Status:** Accepted  
**Date:** 2026-08-15  
**Accepted:** 2026-08-15 (human: "Accept and proceed")  
**Decision Makers:** @bordenet  
**Related:** [#1187](https://github.com/bordenet/superpowers-plus/issues/1187), workstream WS7 in `TODO.md`

## Context

Existing tests for skills mostly check **structure and compression** (frontmatter parse, token budgets, DAG nodes, operative baselines). They do not check whether skill guidance text still encodes the obligations that reviews keep rediscovering (e.g. secrets history required; Verification must not claim clean after HEAD-only greps).

Calibration reviews found real guidance defects. Structure tests would not have caught those.

## Goal

Define a minimal fixture format and runner contract so selected **prompt-only** skills can regress on **guidance obligations** (static skill-text assertions, optionally checked-in plan transcripts) without requiring a live multi-persona LLM review on every commit.

This is **guidance-regression**, not live agent behavioral simulation.

## Decision

Ship v0 as:

1. Fixture tree under `test/fixtures/skill-guidance/<skill-name>/case-*/`.
2. Runner `tools/skill-guidance-regress.sh` (invoked from bats / `test-all.sh --fast`).
3. Pilot set: `repo-security-scan`, `systematic-debugging`, `llm-skill-review`.
4. Text-only assertions in v0 (no live model output). Optional `plan.md` transcripts deferred.

## Fixture shape

```text
test/fixtures/skill-guidance/<skill-name>/
  case-001/
    input.md          # scenario (documentation for humans)
    expected.json     # machine-checkable obligations against skill.md text
    notes.md          # why this case exists
```

`expected.json` (v0):

```json
{
  "skill_path": "skills/security/repo-security-scan/skill.md",
  "must_match": ["gitleaks|git log -p", "INCOMPLETE"],
  "must_not_match": ["head -n 500"],
  "required_phrases": ["do not claim"]
}
```

## Runner contract

1. Load the skill file at `skill_path`.
2. For each case, assert skill text matches / omits patterns from `expected.json`.
3. Exit non-zero on mismatch.
4. Integrate via `test/skill-guidance-regress.bats` (picked up by `tools/test-all.sh`).

## Open questions (resolved for v0)

- Own job vs fold into `harsh-review.sh`? **Own bats suite** for v0.
- Transcript fixtures? **Deferred** past v0.
- Fixture ownership? **Same PR that changes the skill text** must update matching cases.
