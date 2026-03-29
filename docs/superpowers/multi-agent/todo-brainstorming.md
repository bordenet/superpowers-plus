# TODO: brainstorming Multi-Perspective Ensemble

> **Epic:** Role-based ideation ensemble for brainstorming skill
> **Priority:** P3 — Third priority but recommended to ship FIRST (lowest risk, fastest to validate)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29

## P1 — Critical Path

- [ ] **BS-01: Activation criteria** — Define when ensemble brainstorming activates. Use shared activation rubric (≥5) plus brainstorming-specific: broad/ambiguous prompt, design-heavy, multiple stakeholders affected, architectural impact. _Success:_ activates on BS-1 (vague request), stays single on BS-3 (simple UI). _Risk:_ over-brainstorming wastes time and tokens.
- [ ] **BS-02: Lens taxonomy** — Finalize lens definitions: Product/User, Architecture, Reliability/Ops, Security/Abuse, Simplicity/DX, Contrarian. Each lens gets a scoped mandate prompt with specific question focus. _Success:_ lenses produce genuinely different perspectives. _Risk:_ lenses overlap (Architecture and Simplicity often say the same thing).
- [ ] **BS-03: Anti-duplication strategy** — During synthesis, detect and merge ideas that appear in multiple lenses (same idea, different framing). Use structural comparison on idea summaries. _Success:_ final output has no redundant ideas. _Risk:_ overzealous dedup removes legitimately similar-but-distinct ideas.
- [ ] **BS-04: Idea synthesis approach** — Implement synthesizer that: clusters similar ideas, removes duplicates, ranks by feasibility × impact, identifies recurring concerns, separates high-risk/high-reward ideas. _Success:_ output is shorter than sum of lens outputs. _Risk:_ synthesis loses nuance from individual lenses.
- [ ] **BS-05: Handoff contract into writing-plans** — Define the structured output format that writing-plans can directly consume: ranked options, tradeoffs per option, risk surface, recommended direction, open questions. _Depends on:_ writing-plans input schema.

## P2 — Important

- [ ] **BS-06: Novelty scoring** — Score each idea on novelty (was this already discussed? is it obvious?). Prefer novel high-value ideas in ranking. _Risk:_ novelty bias toward exotic-but-impractical ideas.
- [ ] **BS-07: Risk surfacing requirements** — Each lens must surface at least 1 risk relevant to its perspective. Synthesizer must preserve ALL risks, even if ideas are merged. _Success:_ risk surface in ensemble output ≥ single-agent. _Risk:_ manufactured risks to fill quota.
- [ ] **BS-08: Constraints to prevent over-brainstorming** — Hard cap: max 6 ideas in final output. Max 3 lenses for simple prompts. Budget cap: 2× single-agent tokens. _Success:_ concise, actionable output. _Risk:_ too restrictive for genuinely complex prompts.
- [ ] **BS-09: Readability rules** — Final output must be scannable: each idea gets ≤3 sentences + tradeoff bullet. No wall-of-text. _Success:_ user reads entire output without scrolling fatigue.
- [ ] **BS-10: Evaluation harness** — Create fixtures for BS-1 (vague request), BS-2 (architecture redesign), BS-3 (simple change). Measure: diversity, usefulness, novelty, downstream plan quality. _Depends on:_ shared experiment infrastructure.

## P3 — Deferred

- [ ] **BS-11: Adaptive lens selection** — Instead of activating all lenses, select 3–4 most relevant based on task classification. _Not now:_ start with all lenses, optimize later.
- [ ] **BS-12: Iterative brainstorming** — After synthesis, ask lenses to react to the merged output and add ideas they missed. _Not now:_ expensive second pass; validate first round quality first.
- [ ] **BS-13: Cross-lens debate** — Allow one lens to challenge another's ideas (e.g., Security challenges Architecture). _Not now:_ risk of premature convergence (debates narrow, brainstorms should expand).
- [ ] **BS-14: Instrumentation** — Log: which lenses activated, per-lens timings, synthesis merges/dedup actions, final idea count vs raw idea count. _Priority rises when prototyping begins._
- [ ] **BS-15: Historical idea dedup** — Compare new brainstorm output against previous brainstorms for the same project to avoid re-generating known ideas. _Not now:_ requires persistent idea store.
- [ ] **BS-16: "NOT to use" criteria** — Explicitly define when multi-agent brainstorming should NOT fire: task is a bug fix, task has a known solution, user says "just do it", task is time-sensitive and speed matters more than breadth.

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
