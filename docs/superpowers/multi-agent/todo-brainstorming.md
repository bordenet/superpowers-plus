# TODO: brainstorming Multi-Perspective Ensemble

> **Epic:** Role-based ideation ensemble for brainstorming skill
> **Priority:** P3 — Third priority but recommended to ship FIRST (lowest risk, fastest to validate)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29 · **Status:** ✅ ALL ITEMS COMPLETE

## P1 — Critical Path

- [x] **BS-01: Activation criteria** ✅ → `references/ensemble-mode.md` (shared rubric ≥5 + brainstorming boosters/dampeners)
- [x] **BS-02: Lens taxonomy** ✅ → `references/lens-mandates.md` (6 lenses with scoped mandate prompts + output schema)
- [x] **BS-03: Anti-duplication** ✅ → `references/synthesis-protocol.md` §2-3 (cluster → dedup within clusters)
- [x] **BS-04: Idea synthesis** ✅ → `references/synthesis-protocol.md` (cluster, dedup, rank, preserve contrarian, aggregate risks)
- [x] **BS-05: Handoff contract** ✅ → `references/synthesis-protocol.md` §8 output format (planning-ready markdown)

## P2 — Important

- [x] **BS-06: Novelty scoring** ✅ → `skills/_shared/multi-agent-quality-standards.md` §4 (0–3 scale with bias guard)
- [x] **BS-07: Risk surfacing** ✅ → `references/lens-mandates.md` (each lens MUST surface ≥1 risk) + `references/synthesis-protocol.md` §6 (aggregate all risks)
- [x] **BS-08: Constraints** ✅ → `references/ensemble-mode.md` (1.5× cost cap, max 4 lenses) + `skills/_shared/multi-agent-quality-standards.md` §2
- [x] **BS-09: Readability** ✅ → `skills/_shared/multi-agent-quality-standards.md` §2 (≤3 sentences per idea, ≤2× single-agent length)
- [x] **BS-10: Evaluation harness** ✅ → `exercises/multi-agent-skills/fixtures/BS-1.json, BS-2.json, BS-3.json`

## P3 — Completed (formerly deferred)

- [x] **BS-11: Adaptive lens selection** ✅ → `references/ensemble-mode.md` §"Adaptive Lens Selection" (signal-based auto-selection with prune rules)
- [x] **BS-12: Iterative brainstorming** ✅ → `references/ensemble-mode.md` §"Iterative Brainstorming" (second-round triggers, cost guard, max 2 rounds)
- [x] **BS-13: Cross-lens contradiction clarification** ✅ → `references/ensemble-mode.md` §"Cross-Lens Contradiction Clarification" (contradiction-triggered, 1 round max, surfaces assumptions, preserves tradeoffs)
- [x] **BS-14: Instrumentation** ✅ → `skills/_shared/multi-agent-quality-standards.md` §5 (full JSON logging spec)
- [x] **BS-15: Historical idea dedup** ✅ → `references/ensemble-mode.md` §"Historical Idea Dedup" (session-scoped hash dedup, Jaccard >0.7, annotation not removal)
- [x] **BS-16: NOT to use criteria** ✅ → `skills/_shared/multi-agent-quality-standards.md` §9 + `skills/_shared/multi-agent-activation-rubric.md` anti-signals

## Open Questions

- **OQ-BS-01:** Should the Contrarian lens see other lenses' output, or brainstorm independently then critique? Independent → more diverse; sees others → more targeted critique.
- **OQ-BS-02:** How many ideas should each lens produce? Too few → not enough diversity. Too many → synthesis overload. Hypothesis: 3–5 per lens, 15–20 raw ideas → synthesized to 5–8.
- **OQ-BS-03:** Should the synthesizer be a separate agent or a post-processing step? Agent can reason about idea quality; post-processing is cheaper.

## Experiments

| ID | Scenario | Expected | Measures |
|----|----------|----------|----------|
| BS-1 | Vague feature request | Ensemble wins on diversity | Idea count, novelty, risk coverage |
| BS-2 | Architecture redesign | Ensemble wins on coverage | Perspectives represented, blind spots |
| BS-3 | Simple UI change | Single-agent wins on efficiency | Time, cost, quality parity |
