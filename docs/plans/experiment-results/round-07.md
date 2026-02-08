# Round 07 Results: product-requirements-assistant - Condition B (Sub-agent)

**Started:** 2026-02-08T12:00:00Z
**Ended:** 2026-02-08T12:20:00Z
**Duration:** ~20 minutes
**Status:** COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Findings | 5 |
| True Positives | 3 |
| False Positives | 2 |
| Accuracy Rate | 60% |
| Novel Insights | 3 |
| Time to First Finding | ~8 min |

---

## Context

This is a FRESH tool with NO prior Gemini review. Expected to find more issues.

---

## Verified Findings

### Finding 1: Leading Indicator Keyword Stuffing - VERIFIED TRUE POSITIVE ✅

**Claim:** Users can get 2 pts by just mentioning "leading indicator" without details.

**Evidence - phase1.md lines 121-130:** Requires comprehensive format:
```markdown
For EACH metric, provide:
- **Metric Name:** What we're measuring
- **Type:** Leading Indicator (predictive) or Lagging Indicator (outcome)
- **Baseline:** Current state (with evidence/source)
- **Target:** Goal state (specific number)
- **Timeline:** When we'll achieve it
- **Source of Truth:** Specific system (e.g., Mixpanel, Datadog, Salesforce)
- **Counter-Metric:** What we must NOT degrade
```

**Evidence - validator.js lines 1080-1082:**
```javascript
if (leadingMatches.length >= 1) {
  metricValidityScore += 2;  // Just keyword presence!
}
```

**Result:** ✅ TRUE POSITIVE - phase1.md requires 7 components, validator only checks keyword

**Impact:** 2 pts exploitable

---

### Finding 2: Counter-Metric Keyword Stuffing - VERIFIED TRUE POSITIVE ✅

**Claim:** Users can get 2 pts by just mentioning "counter-metric" keyword.

**Evidence - validator.js lines 1087-1089:**
```javascript
if (counterMatches.length >= 1) {
  metricValidityScore += 2;  // Just keyword presence!
}
```

**Result:** ✅ TRUE POSITIVE - No validation of what counter-metric protects

**Impact:** 2 pts exploitable

---

### Finding 3: Source of Truth Threshold Too Low - VERIFIED TRUE POSITIVE ✅

**Claim:** Requires 2 source mentions for only 2 pts, but no validation of association.

**Evidence - validator.js lines 1094-1096:**
```javascript
if (sourceMatches.length >= 2) {
  metricValidityScore += 2;
}
```

**Evidence - phase1.md line 129:** Requires source of truth FOR EACH METRIC.

**Result:** ✅ TRUE POSITIVE - Can mention "Mixpanel Datadog" anywhere for 2 pts

**Impact:** 2 pts exploitable

---

### Finding 4: FR vs User Stories Scoring - FALSE POSITIVE ❌

**Sub-agent Claim:** Mismatch in scoring

**Investigation:** Validator correctly scores FR format (with door types) higher than user stories.

**Result:** ❌ FALSE POSITIVE - Working as intended

---

### Finding 5: AC Table Detection - FALSE POSITIVE ❌

**Sub-agent Claim:** AC detection issues

**Investigation:** Validator handles both table and bullet formats correctly.

**Result:** ❌ FALSE POSITIVE - Working as intended

---

## Novel Insights Summary

All 3 TRUE POSITIVES are NOVEL (no prior Gemini review):

1. **Leading Indicator Keyword Stuffing** - 2 pts exploitable
2. **Counter-Metric Keyword Stuffing** - 2 pts exploitable  
3. **Source of Truth Threshold** - 2 pts exploitable

**Total Gaming Potential:** 6 pts (out of ~100) from Metric Validity section

---

## Comparison to Rounds 1-6

| Round | Tool | Condition | Novel Insights |
|-------|------|-----------|----------------|
| 1 | pr-faq | Sub-agent | 2 |
| 2 | pr-faq | Document | 0 |
| 3 | pr-faq | Hybrid | 2 |
| 4 | biz-just | Sub-agent | 1 |
| 5 | biz-just | Document | 0 |
| 6 | biz-just | Hybrid | 0 |
| **7** | **prd** | **Sub-agent** | **3** |

Fresh tools produce MORE novel insights than already-reviewed tools!

---

## Observations

### What Worked

- Sub-agent found 3 genuine novel findings on fresh tool
- 60% accuracy (better than Round 4's 40%)
- Correctly identified gaming vulnerabilities

### What Didn't Work

- Sub-agent claimed to create files that don't exist
- 2 false positives still indicate noise

### Pattern

Fresh tools (no prior review) yield more novel insights from sub-agent approach.

---

## Recommended Fixes

1. Add proximity check: leading indicators must appear with baselines/targets
2. Add proximity check: counter-metrics must specify what they protect
3. Increase source of truth threshold or require association with metrics

