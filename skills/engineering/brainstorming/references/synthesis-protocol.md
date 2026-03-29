# Brainstorming Ensemble — Synthesis Protocol

> **Purpose:** Concrete instructions for merging lens outputs into a single coherent brainstorm result.
> **Executor:** The conductor agent after all lens sub-agents return.

## Input

You receive N lens outputs (JSON objects), each containing:
- `ideas[]` — 3–5 ideas with summary, rationale, feasibility, impact
- `risks[]` — 1+ risks from that lens perspective
- `rejections[]` — 1+ rejected ideas with reasons
- `confidence` — how relevant this lens was (0.0–1.0)
- `keyAssumption` — what this lens assumed

## Synthesis Steps

### 1. Filter Low-Confidence Lenses

If any lens has confidence < 0.3:
- Note it was irrelevant to this task
- Exclude its ideas from ranking (but keep its risks — even irrelevant lenses catch risks)

### 2. Cluster Ideas by Theme

Group all ideas across lenses by similarity:
- Ideas proposing the same approach from different angles → one cluster
- Use summary text comparison: if two ideas could be merged into one sentence, they're the same cluster
- Label each cluster with a short theme name

### 3. Deduplicate Within Clusters

Within each cluster:
- Keep the version with the strongest rationale
- Merge unique feasibility/impact data from other versions
- Record which lenses contributed (source diversity = higher confidence)

### 4. Rank Clusters

Score each cluster: `rank = feasibility × impact × source_count`

Where:
- feasibility: H=3, M=2, L=1
- impact: H=3, M=2, L=1
- source_count: number of lenses that independently proposed this idea

Sort descending. Top 5–8 ideas make the final list.

### 5. Handle Contrarian Ideas

Contrarian/Skeptic lens ideas get special treatment:
- Do NOT merge them into clusters (they're intentionally different)
- Present them in a separate "High-Upside / High-Risk" section
- If the contrarian rejected the #1 ranked idea, include that rejection prominently

### 6. Aggregate Risks

- Merge identical risks (same failure mode described differently)
- Count how many lenses flagged each risk
- Risks flagged by ≥2 lenses → "Recurring Concern" (higher priority)
- Unique risks from one lens → preserve but flag as single-source

### 7. Aggregate Rejections

- Include rejected ideas only if they're genuinely tempting (would fool a single-agent brainstorm)
- Group by reason pattern (e.g., "adds complexity" rejections together)

### 8. Produce Output

```markdown
## Brainstorm Results: [Topic]

### Ensemble Summary
[1–2 sentences: what lenses were used, overall finding, top-level recommendation]

### Top Recommendations (ranked)
1. **[Idea]** — [merged rationale]
   - Feasibility: [H/M/L] · Impact: [H/M/L] · Source lenses: [list]
   - Key risks: [aggregated from relevant lenses]

2. [... up to 5–8 ideas ...]

### High-Upside / High-Risk Ideas
- **[Contrarian idea]** — [why it's interesting but risky]
  - Source: [Contrarian lens]

### Recurring Concerns (flagged by ≥2 lenses)
- **[Risk]** — flagged by [Lens A, Lens C]
  - Mitigation: [if available]

### Rejected Ideas (worth noting)
- **[Idea]** — rejected by [Lens] because [reason]

### Open Questions for Planning
- [Questions that emerged during brainstorming]
- [Assumptions that should be validated before proceeding]

### Ensemble Metadata
- Lenses activated: [list with confidence scores]
- Raw ideas: N → synthesized to M
- Token cost: [total] ([ratio]× single-agent estimate)
- Lenses filtered (low confidence): [list or "none"]
```

## Quality Checks Before Returning

1. **Length check:** Output ≤ 2× what a single-agent brainstorm would produce
2. **No lens voice:** Output reads as one author, not a patchwork of perspectives
3. **Contrarian preserved:** At least 1 idea challenges the mainstream recommendations
4. **Risks preserved:** Every lens risk appears somewhere in the output
5. **Actionable:** A reader can hand this to `plan-and-execute` without additional brainstorming

## Failure Recovery

| Problem | Action |
|---------|--------|
| All lenses produced identical ideas | Note "ensemble added no diversity"; recommend single-agent for this task type |
| Contrarian produced only negativity | Omit from synthesis; note in metadata |
| Token budget hit during synthesis | Truncate to top 3 ideas + recurring concerns only |
| Synthesis confidence < 0.5 | Fall back to single-agent brainstorm; note why ensemble failed |
