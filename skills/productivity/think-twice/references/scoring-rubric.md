# Think Twice Response Scoring Rubric

Score consultation responses on 0-100 using four dimensions:

| Dimension | Weight | 90+ | 50-69 | <25 |
|-----------|--------|-----|-------|-----|
| **Relevance** | 30% | Directly addresses core problem | Partially relevant | Completely off-topic |
| **Novelty** | 25% | New approach not already tried | Minor tweaks to tried approaches | Only repeats tried approaches |
| **Specificity** | 25% | Working code + exact steps | General guidance | Abstract, no actionable content |
| **Feasibility** | 20% | Respects all constraints | Partially respects constraints | Violates core constraints |

**Formula:** `(Relevance × 0.30) + (Novelty × 0.25) + (Specificity × 0.25) + (Feasibility × 0.20)`

## Score Interpretation

| Score | Action |
|-------|--------|
| ≥75 | Proceed with recommendation |
| 50-74 | Proceed with caution |
| <50 | Retry with refined prompt (max 1 retry) or switch to manual dispatch |

## Results Format

```markdown
## Think Twice Results

**Effectiveness Score:** [X]/100
**Summary:** [1-2 sentences]
**Key Recommendations:** [bulleted list]
**Suggested Next Step:** [single most promising action]
**Dimension Breakdown:** Relevance: X | Novelty: X | Specificity: X | Feasibility: X
```
