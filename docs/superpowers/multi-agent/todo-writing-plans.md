# TODO: writing-plans Multi-Agent Planning Council

> **Epic:** Multi-agent planning council for writing-plans skill
> **Priority:** P1 — Highest among the three targets (gates downstream execution quality)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29

## P1 — Critical Path

- [ ] **WP-01: Activation heuristic** — Define and implement the decision logic for single-agent vs planning council mode. Use shared multi-agent activation rubric (score ≥5) plus writing-plans-specific criteria (≥3 components, cross-domain, high rollback cost). _Success:_ heuristic fires on WP-3 scenario, stays single on WP-1. _Risk:_ false positives cause overhead on simple tasks.
- [ ] **WP-02: Role definitions and prompts** — Write scoped mandate prompts for each planning council role (Requirements Clarifier, Architecture Planner, Risk Planner, Test Planner, Rollout Planner). Each prompt must constrain the agent to ONE aspect. _Success:_ agents produce non-overlapping sections. _Risk:_ roles drift into each other's territory.
- [ ] **WP-03: Common plan packet schema** — Define the structured input packet that all council members receive (task description, context, constraints, success criteria). Must be identical across roles. _Depends on:_ shared task packet schema from multi-agent-skill-strategy.md.
- [ ] **WP-04: Merged-plan synthesis strategy** — Implement the Synthesis Planner that receives all role outputs and merges into one coherent plan. This is the hardest part. _Success:_ merged plan reads as if written by one author. _Risk:_ synthesis produces Frankenstein doc.
- [ ] **WP-05: Conflict-resolution rules** — Define how the synthesis layer handles contradictory recommendations (e.g., Architecture Planner says monolith, Rollout Planner says microservice for easier rollout). _Success:_ conflicts surfaced explicitly, not hidden. _Risk:_ always deferring to user defeats the purpose.

## P2 — Important

- [ ] **WP-06: Plan quality rubric** — Extend existing plan-quality-gates with multi-agent-specific checks: completeness (all sections present), coherence (no contradictions), coverage (risks match architecture), actionability (tasks are concrete). _Depends on:_ WP-04 synthesis output.
- [ ] **WP-07: Readability requirements** — Merged plan must be shorter or same length as single-agent plan. Multi-agent MUST NOT produce bloated output. Hard cap: 2× single-agent length. _Success:_ blind human evaluation rates multi-agent ≥ single-agent on readability.
- [ ] **WP-08: Token/cost limits** — Per-branch budget (25% of total), total budget cap (2.5× single-agent), kill branches below 0.3 confidence. _Risk:_ too aggressive kills good-but-slow branches.
- [ ] **WP-09: Fallback behavior** — If multi-agent activation triggers but subagents are unavailable or fail, gracefully fall back to single-agent mode. Must not leave user in broken state. _Success:_ transparent fallback with explanation.
- [ ] **WP-10: Evaluation harness** — Create fixtures for WP-1 (simple), WP-2 (medium), WP-3 (complex) scenarios. Measure: plan completeness, coherence, contradictions, downstream execution success. _Depends on:_ shared experiment harness.

## P3 — Deferred

- [ ] **WP-11: Dynamic role selection** — Not all roles needed every time. Implement lens selection based on task characteristics (e.g., skip Rollout Planner for internal tools). _Not now:_ start with full council, prune later.
- [ ] **WP-12: Iterative refinement** — After synthesis, run a second pass where council members review the merged plan and flag issues. _Not now:_ adds cost; validate first pass quality first.
- [ ] **WP-13: Plan versioning** — Track plan versions as council iterations produce refinements. _Not now:_ premature without proving first iteration adds value.
- [ ] **WP-14: Instrumentation** — Log activation decisions, branch timings, synthesis conflicts, kill events. _Priority rises to P2 when prototyping begins._
- [ ] **WP-15: Operator visibility** — Show user which roles were activated and why, what was merged, what conflicts existed. _Not now:_ build internal first, expose to user after validation.

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
