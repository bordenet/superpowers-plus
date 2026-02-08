# Think Twice Response Scoring Rubric

## Overview

After the sub-agent returns its consultation response, score it on a 0-100
effectiveness scale using these four dimensions.

## Scoring Dimensions

| Dimension | Weight | Description |
|-----------|--------|-------------|
| **Relevance** | 30% | Does the response address the actual problem? |
| **Novelty** | 25% | Does it suggest approaches NOT already tried? |
| **Specificity** | 25% | Does it include concrete code, commands, or steps? |
| **Feasibility** | 20% | Can the suggestion be implemented within stated constraints? |

## Dimension Scoring (0-100 each)

### Relevance (30%)

| Score | Criteria |
|-------|----------|
| 90-100 | Directly addresses the core problem; shows deep understanding |
| 70-89 | Addresses the problem but may miss some nuance |
| 50-69 | Partially relevant; addresses related but not core issue |
| 25-49 | Tangentially related; mostly off-topic |
| 0-24 | Completely misses the problem |

### Novelty (25%)

| Score | Criteria |
|-------|----------|
| 90-100 | Suggests entirely new approach not mentioned in "What Has Been Tried" |
| 70-89 | Suggests meaningful variation on tried approaches |
| 50-69 | Suggests minor tweaks to tried approaches |
| 25-49 | Mostly repeats what was already tried |
| 0-24 | Only suggests things already tried |

### Specificity (25%)

| Score | Criteria |
|-------|----------|
| 90-100 | Includes working code, exact commands, step-by-step instructions |
| 70-89 | Includes code snippets or specific steps, minor gaps |
| 50-69 | General guidance with some specifics |
| 25-49 | Vague suggestions, no concrete steps |
| 0-24 | Completely abstract, no actionable content |

### Feasibility (20%)

| Score | Criteria |
|-------|----------|
| 90-100 | Fully respects all stated constraints; immediately implementable |
| 70-89 | Respects constraints with minor adjustments needed |
| 50-69 | Partially respects constraints; some conflicts |
| 25-49 | Ignores important constraints |
| 0-24 | Violates core constraints; not implementable |

## Calculating Final Score

```
Final Score = (Relevance × 0.30) + (Novelty × 0.25) + (Specificity × 0.25) + (Feasibility × 0.20)
```

## Score Interpretation

| Score Range | Interpretation | Action |
|-------------|----------------|--------|
| 75-100 | High confidence | Proceed with recommendation |
| 50-74 | Moderate confidence | Proceed with caution; may need iteration |
| 25-49 | Low confidence | Consider retry with refined prompt |
| 0-24 | Not useful | Retry or switch to manual dispatch |

## Retry Logic

- **Score ≥ 50:** Integrate the response and proceed
- **Score < 50:** Inform user and offer options:
  1. Retry with refined prompt (include what first consultation suggested and why insufficient)
  2. Proceed with best suggestion anyway
  3. Switch to manual dispatch (paste into Perplexity yourself)

- **Maximum retries:** 1 (total of 2 consultations per Think Twice invocation)

## User-Facing Results Format

```markdown
## Think Twice Results

**Effectiveness Score:** [X]/100

**Summary:** [1-2 sentence synthesis of the key insight]

**Key Recommendations:**
- [Recommendation 1]
- [Recommendation 2]

**Suggested Next Step:** [The single most promising action]

**Dimension Breakdown:**
- Relevance: [X]/100
- Novelty: [X]/100
- Specificity: [X]/100
- Feasibility: [X]/100
```

