# TODO: writing-plans Multi-Agent Planning Council

> **Epic:** Multi-agent planning council for writing-plans skill
> **Priority:** P1 — Highest among the three targets (gates downstream execution quality)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29 · **Status:** ✅ ALL ITEMS COMPLETE

## P1 — Critical Path

- [x] **WP-01: Activation heuristic** ✅ → `references/planning-council-mode.md` §"When Planning Council Activates" (rubric ≥5 + task-specific criteria)
- [x] **WP-02: Role definitions and prompts** ✅ → `references/role-mandates.md` (5 roles with copy-pasteable mandate prompts)
- [x] **WP-03: Common plan packet schema** ✅ → `references/role-mandates.md` common preamble + `multi-agent-skill-strategy.md` §3.2
- [x] **WP-04: Merged-plan synthesis strategy** ✅ → `references/synthesis-protocol.md` (cross-reference validation, section merge, conflict resolution)
- [x] **WP-05: Conflict-resolution rules** ✅ → `references/synthesis-protocol.md` §3 (factual, priority, scope, unresolvable conflict types)

## P2 — Important

- [x] **WP-06: Plan quality rubric** ✅ → `skills/_shared/multi-agent-quality-standards.md` §1 (5-dimension 0–2 scoring, min 7/10)
- [x] **WP-07: Readability requirements** ✅ → `skills/_shared/multi-agent-quality-standards.md` §2 (≤2× length, per-section caps, no lens voice)
- [x] **WP-08: Token/cost limits** ✅ → `references/planning-council-mode.md` (2.0× cost cap) + `skills/_shared/multi-agent-activation-rubric.md` (25% per-branch, 0.3 kill)
- [x] **WP-09: Fallback behavior** ✅ → `skills/_shared/multi-agent-quality-standards.md` §3 (6 failure triggers with recovery paths)
- [x] **WP-10: Evaluation harness** ✅ → `exercises/multi-agent-skills/fixtures/WP-1.json, WP-2.json, WP-3.json`

## P3 — Completed (formerly deferred)

- [x] **WP-11: Dynamic role selection** ✅ → `references/planning-council-mode.md` §"Dynamic Role Selection" (signal-based auto-selection with prune rules)
- [x] **WP-12: Iterative refinement** ✅ → `references/planning-council-mode.md` §"Iterative Refinement" (tradeoff-triggered, quality threshold, 1 round max)
- [x] **WP-13: Plan versioning** ✅ → `references/planning-council-mode.md` §"Plan Versioning" (JSON version entries, delta tracking, rollback support)
- [x] **WP-14: Instrumentation** ✅ → `skills/_shared/multi-agent-quality-standards.md` §5 (full JSON logging spec)
- [x] **WP-15: Operator visibility** ✅ → `references/planning-council-mode.md` §"Operator Visibility" (7 progress events, quiet mode option)

## Open Questions

- **OQ-WP-01:** Should the Synthesis Planner be a separate agent or a post-processing step in the conductor? Tradeoff: agent can reason about conflicts; post-processing is cheaper.
- **OQ-WP-02:** How do we prevent the Requirements Clarifier from producing a full plan instead of just requirements? Role boundary enforcement is critical.
- **OQ-WP-03:** Should council members see each other's output during synthesis, or only the synthesizer? Tradeoff: cross-pollination vs. independence.

## Experiments

| ID | Scenario | Expected | Measures |
|----|----------|----------|----------|
| WP-1 | Simple utility function | Single-agent wins | Overhead, quality |
| WP-2 | Medium feature (3 components) | Close call | Risk coverage, coherence |
| WP-3 | Large cross-service with migration | Council wins | Completeness, missed risks |
