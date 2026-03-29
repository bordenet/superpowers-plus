---
name: innovation
source: superpowers-plus
triggers: ["innovate", "innovation mode", "what's the boldest move", "radical improvement", "radical ideas", "radical brainstorm", "breakthrough idea", "game-changing", "most impactful change", "10x improvement", "transform this project", "moonshot", "blue sky thinking", "disruptive idea", "reimagine", "step-change", "new business model", "greenfield idea", "what if we started from scratch", "rethink architecture", "paradigm shift", "new product idea", "strategic pivot", "what would a world-class team do"]
anti_triggers: ["fix this bug", "small refactor", "add this field", "update the docs", "incremental improvement", "quick win", "minor change", "cleanup"]
description: INVOKE when user explicitly seeks transformative, 10x-level ideas — product innovations, architectural paradigm shifts, or new business models. NOT for incremental improvements, bug fixes, or feature requests. Outputs ranked ideas with effort/impact scores and concrete next-week prototypes.
summary: "Use when: user seeks transformative 10x ideas. Skip when: incremental improvements or bug fixes."
version: 2.0
coordination:
  group: thinking
  order: 5
  requires: []
  enables: ["brainstorming", "design-triad"]
  escalates_to: []
  internal: false
---

# Innovation

> **Core question:** What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?

> **Wrong skill?** Incremental feature ideas → `brainstorming`. Structured design evaluation → `design-triad`. Implementation planning → `plan-and-execute`.

**NOT for:** bug fixes (`systematic-debugging`), incremental features (`brainstorming`), cleanup (`engineering-rigor`).
**IS for:** product step-changes, architectural paradigm shifts, new business models, internal tool innovation.

## The Process

1. **Gather context:** Ask for PRD/RFC snippet or top 1-2 pain points. Read README, issues, tech debt.
2. **Generate 3-5 radical ideas** across: Technical Innovation, UX Breakthrough, Architectural Shift, Novel Integration, Paradigm Shift.
3. **Score each:** `(Impact×3) + (Feasibility×2) + Alignment + Uniqueness` (each 1-5).
4. **Present** with risks and a concrete next-week experiment per idea. See `references/output-template.md`.
5. **If stuck:** invoke `perplexity-research` for adjacent domain exploration or `think-twice` for fresh perspective.

## Key Principles

- **Bold over safe** — 10x, not 10%
- **Feasible over fantasy** — radical ≠ impossible
- **Accretive** — build on existing strengths
- **Concrete** — every idea needs a next-week experiment

## Scoring Example

| Idea | Impact (×3) | Feasibility (×2) | Alignment | Uniqueness | **Total** |
|------|:-----------:|:-----------------:|:---------:|:----------:|:---------:|
| AI-powered call scoring | 5 (15) | 3 (6) | 5 | 4 | **30** |
| Real-time coaching overlay | 5 (15) | 2 (4) | 4 | 5 | **28** |
| Self-healing config pipeline | 3 (9) | 4 (8) | 4 | 3 | **24** |

**Gate:** If no idea scores ≥25, the problem space may need reframing — invoke `think-twice`.

## Follow-Up

After presenting: offer to draft RFC, create experiment plan, or deep-dive on specific aspect.

**Flow:** `innovation → user selects → brainstorming → plan-and-execute → implementation`

## References

- [`references/output-template.md`](references/output-template.md) — Per-idea scoring template and output format.


## Companion Skills

- **brainstorming**: Incremental idea generation (this skill is 10x ideas)
- **design-triad**: Evaluating innovation options
- **plan-and-execute**: Executing on selected innovations
- **quantitative-decision-gate**: Option scoring
## When to Use

- Before building new features — generate radical alternatives to the obvious approach
- When brainstorming is yielding incremental ideas — force 10x thinking
- When evaluating whether to build vs buy vs integrate


## Example

```bash
# Run the innovation scoring framework
echo "Score each idea 1-5 on: Impact (×3), Feasibility (×2), Alignment, Uniqueness"
echo "Gate: ideas scoring <25 need reframing via think-twice"
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Ideas too abstract to act on | Require concrete "next-week experiment" for each idea |
| Scoring bias toward familiar approaches | Weight novelty explicitly in impact/feasibility matrix |
| Innovation theater — big ideas with no follow-through | Gate: each idea must have a testable hypothesis |
| Generated incremental improvements disguised as innovation | Apply the 10x test: would this change the product category? If no, it is not innovation |
| Confused technical cleverness with user impact | Score Impact (user-facing value) separately from Feasibility (technical) |
