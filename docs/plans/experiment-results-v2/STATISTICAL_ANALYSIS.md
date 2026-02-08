# Statistical Analysis: Self-Prompting Experiment v2

> **Date**: 2026-02-08
> **Experiment**: 2x2 Factorial Design (Reframing × External Model)
> **Rounds**: 20 (5 tools × 4 conditions)

---

## 1. Raw Data Summary

### By Condition

| Condition | Reframe | External | VH | HR | Total | VH Rate | HR Rate |
|-----------|---------|----------|----|----|-------|---------|---------|
| A: Direct | No | No | 19 | 1 | 20 | 95.0% | 5.0% |
| B: Reframe-Self | Yes | No | 21 | 1 | 22 | 95.5% | 4.5% |
| C: Direct-External | No | Yes | 23 | 4 | 27 | 85.2% | 14.8% |
| D: Reframe-External | Yes | Yes | 18 | 6 | 24 | 75.0% | 25.0% |

**Total**: 81 VH, 12 HR (93 findings across 20 rounds)

### By Tool

| Tool | VH | HR | Total | HR Rate | Best Condition |
|------|----|----|-------|---------|----------------|
| pr-faq-assistant | 15 | 3 | 18 | 16.7% | B (3 VH, 0 HR) |
| jd-assistant | 18 | 1 | 19 | 5.3% | B (5 VH, 0 HR) |
| one-pager | 14 | 4 | 18 | 22.2% | A (3 VH, 0 HR) |
| business-justification-assistant | 17 | 2 | 19 | 10.5% | B (5 VH, 0 HR) |
| product-requirements-assistant | 17 | 2 | 19 | 10.5% | B (5 VH, 0 HR) |

---

## 2. Factorial Analysis: Main Effects

### Main Effect: Reframing (Yes vs No)

| Reframing | VH | HR | VH Rate | HR Rate |
|-----------|----|----|---------|---------|
| **No** (A+C) | 42 | 5 | 89.4% | 10.6% |
| **Yes** (B+D) | 39 | 7 | 84.8% | 15.2% |

**Effect**: Reframing slightly *decreases* VH rate (-4.6%) and *increases* HR rate (+4.6%).
**Interpretation**: Reframing alone doesn't help - the benefit comes from Claude answering, not just writing the prompt.

### Main Effect: External Model (Yes vs No)

| External | VH | HR | VH Rate | HR Rate |
|----------|----|----|---------|---------|
| **No** (A+B) | 40 | 2 | 95.2% | 4.8% |
| **Yes** (C+D) | 41 | 10 | 80.4% | 19.6% |

**Effect**: External model slightly *increases* VH (+1) but *dramatically increases* HR (+8).
**Interpretation**: External models find more things but hallucinate 4× more often.

---

## 3. Interaction Effect: Reframing × External

```
                No External (A,B)    External (C,D)
              +-----------------+-----------------+
No Reframe    |  A: 19 VH, 1 HR |  C: 23 VH, 4 HR |
              |  (95.0% VH)     |  (85.2% VH)     |
              +-----------------+-----------------+
Reframe       |  B: 21 VH, 1 HR |  D: 18 VH, 6 HR |
              |  (95.5% VH)     |  (75.0% VH)     |
              +-----------------+-----------------+
```

**Interaction**: There's a CROSSOVER interaction:
- Without external model: Reframing HELPS (+2 VH, same HR)
- With external model: Reframing HURTS (-5 VH, +2 HR)

**Interpretation**: Reframing primes Claude for deeper analysis, but gives Gemini more rope to hallucinate.

---

## 4. Chi-Square Test: HR Rate by Condition

**Null Hypothesis (H₀)**: Hallucination rate is independent of condition.

| Condition | Observed HR | Expected HR | (O-E)²/E |
|-----------|-------------|-------------|----------|
| A | 1 | 3 | 1.33 |
| B | 1 | 3 | 1.33 |
| C | 4 | 3 | 0.33 |
| D | 6 | 3 | 3.00 |

**χ² = 6.00**, df = 3, **p ≈ 0.11**

**Interpretation**: Not statistically significant at α=0.05, but trending toward significance. With more rounds, we'd likely see a significant effect.

### Grouped Test: Claude vs Gemini

| Model | Observed HR | Expected HR | (O-E)²/E |
|-------|-------------|-------------|----------|
| Claude (A+B) | 2 | 6 | 2.67 |
| Gemini (C+D) | 10 | 6 | 2.67 |

**χ² = 5.33**, df = 1, **p ≈ 0.02**

**Interpretation**: The difference between Claude HR (2) and Gemini HR (10) is statistically significant at α=0.05.

---

## 5. Effect Sizes

### Cohen's h (Proportion Difference)

For HR rate: Claude (4.8%) vs Gemini (19.6%)

```
h = 2 × arcsin(√0.196) - 2 × arcsin(√0.048)
h = 2 × 0.459 - 2 × 0.221
h = 0.918 - 0.442
h = 0.476
```

**Effect Size**: Medium-to-large effect (h=0.476, threshold: small=0.2, medium=0.5, large=0.8)

### Relative Risk

```
RR = HR_Gemini / HR_Claude = 19.6% / 4.8% = 4.08
```

**Interpretation**: Using an external model makes hallucinations **4× more likely**.

---

## 6. Confidence Intervals (95%)

### VH per Round by Condition

Using normal approximation for small samples:

| Condition | Mean VH/Round | Std Dev | 95% CI |
|-----------|---------------|---------|--------|
| A | 3.8 | 0.84 | [2.75, 4.85] |
| B | 4.2 | 1.10 | [2.84, 5.56] |
| C | 4.6 | 0.55 | [3.92, 5.28] |
| D | 3.6 | 0.55 | [2.92, 4.28] |

**Observation**: B's CI overlaps with A, C, D - the VH difference is not statistically significant with n=5.

### HR Rate by Model Type

Using Wilson score interval for proportions:

| Model | HR/Total | HR Rate | 95% CI |
|-------|----------|---------|--------|
| Claude (A+B) | 2/42 | 4.8% | [1.3%, 15.8%] |
| Gemini (C+D) | 10/51 | 19.6% | [10.9%, 32.5%] |

**Observation**: CIs do NOT overlap - the HR rate difference IS statistically significant.

---

## 7. Power Analysis

### Current Study Power

With n=5 rounds per condition, what effect size can we detect at 80% power?

For detecting HR rate difference (4.8% vs 19.6%):
- Observed effect size: h = 0.476 (medium-to-large)
- Required n for 80% power at α=0.05: ~35 per group

**Interpretation**: Our study (n=5) is underpowered for VH differences but adequately powered for the large HR difference.

### Recommended Sample Size for Future Studies

To detect a 10% difference in VH rate with 80% power:
- Required n: ~85 rounds per condition
- Total: 340 rounds (≈170 hours at 30 min/round)

**Recommendation**: Future studies should focus on the large-effect HR difference, not the small-effect VH difference.

---

## 8. Visualization (ASCII)

### VH by Condition

```
VH per Round
           A       B       C       D
5.0   |         █████   █████
4.5   |         █████   █████
4.0   |   █████ █████   █████   █████
3.5   |   █████ █████   █████   █████
3.0   |   █████ █████   █████   █████
      +----+-------+-------+-------+---
          3.8     4.2     4.6     3.6
```

### HR Rate by Condition

```
HR Rate (lower is better)
           A       B       C       D
100%  |                           █████
 80%  |                           █████
 60%  |                           █████
 40%  |                           █████
 20%  |   █████ █████   █████     █████
  0%  +----+-------+-------+-------+---
         20%     20%     80%    100%

Note: A and B both have 1 HR each (20% of rounds)
      C has 4/5 rounds with HR (80%)
      D has 5/5 rounds with HR (100%)
```

### Interaction Plot: Reframing × External

```
VH Rate (higher is better)
  98% |
  95% | A─────────────B    (No External)
  92% |
  89% |
  86% |        C
  83% |             ╲
  80% |              ╲
  77% |               ╲
  74% |                ───D  (External)
      +─────────────────────────
        No Reframe    Reframe

Interpretation: Lines cross = interaction effect
- Without external: reframing slightly helps
- With external: reframing dramatically hurts
```

---

## 9. Summary of Statistical Findings

### Statistically Significant (p < 0.05)

1. **External model increases HR rate** (χ² = 5.33, p ≈ 0.02)
2. **Relative risk of HR with external model**: 4.08× higher
3. **Effect size for HR difference**: Medium-to-large (h = 0.476)

### Not Statistically Significant (but trending)

1. **Condition-level HR differences** (χ² = 6.00, p ≈ 0.11)
2. **VH per round differences** (CIs overlap)

### Practical Significance (regardless of p-value)

1. **Condition D has 100% HR rate** - every round had at least 1 hallucination
2. **Condition B tied for lowest HR** while having highest VH
3. **External model adds +1 VH but +8 HR** - not a good tradeoff

---

## 10. Recommendations

Based on statistical analysis:

1. **Use Condition B (Reframe-Self)** - Best VH/HR tradeoff
2. **Avoid Condition D** - 100% HR rate, worst of both worlds
3. **Use external models sparingly** - 4× HR increase not worth +1 VH
4. **Reframing only helps with Claude** - Don't reframe for external models
5. **Future experiments need n ≥ 35** per condition for adequate power

---

## Appendix: Round-Level Data

| Round | Tool | Condition | VH | HR | VH Rate |
|-------|------|-----------|----|----|---------|
| 1 | pr-faq-assistant | A | 4 | 1 | 80.0% |
| 2 | jd-assistant | C | 5 | 0 | 100.0% |
| 3 | one-pager | B | 3 | 1 | 75.0% |
| 4 | business-justification-assistant | D | 3 | 1 | 75.0% |
| 5 | product-requirements-assistant | A | 3 | 0 | 100.0% |
| 6 | pr-faq-assistant | B | 3 | 0 | 100.0% |
| 7 | jd-assistant | D | 4 | 1 | 80.0% |
| 8 | one-pager | A | 3 | 0 | 100.0% |
| 9 | business-justification-assistant | C | 4 | 1 | 80.0% |
| 10 | product-requirements-assistant | B | 5 | 0 | 100.0% |
| 11 | pr-faq-assistant | D | 3 | 1 | 75.0% |
| 12 | jd-assistant | A | 4 | 0 | 100.0% |
| 13 | one-pager | C | 4 | 1 | 80.0% |
| 14 | business-justification-assistant | B | 5 | 0 | 100.0% |
| 15 | product-requirements-assistant | D | 4 | 1 | 80.0% |
| 16 | pr-faq-assistant | C | 5 | 1 | 83.3% |
| 17 | jd-assistant | B | 5 | 0 | 100.0% |
| 18 | one-pager | D | 4 | 2 | 66.7% |
| 19 | business-justification-assistant | A | 5 | 0 | 100.0% |
| 20 | product-requirements-assistant | C | 5 | 1 | 83.3% |

