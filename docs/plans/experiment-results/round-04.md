# Round 04 Results: business-justification-assistant - Condition B (Sub-agent)

**Started:** 2026-02-08T11:00:00Z
**Ended:** 2026-02-08T11:15:00Z
**Duration:** ~15 minutes
**Status:** COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Findings | 5 |
| True Positives | 2 |
| False Positives | 3 |
| Accuracy Rate | 40% |
| Novel Insights | 1 |
| Time to First Finding | ~5 min |

---

## Findings Analysis

### Finding 1: Payback Period Verb Form - VERIFIED TRUE POSITIVE ✅

**Claim:** Regex `/break.?even/` doesn't match "breaks even" (verb form)

**Evidence:**
- File: `validator.js` line 44
- Code: `paybackPeriod: /\b(payback|break.?even|recoup|recover.+investment|months?.to.recover)\b/gi`

**Verification Test:**
```javascript
const regex = /break.?even/gi;
'breaks even'.match(regex) // null - DOES NOT MATCH
'break even'.match(regex)  // matches
'break-even'.match(regex)  // matches
```

**Result:** ✅ TRUE POSITIVE - "breaks even" (verb form) doesn't match

**Impact:** 8 pts at risk for natural English phrasing

---

### Finding 2: Stakeholder Keyword Stuffing - VERIFIED TRUE POSITIVE ✅

**Claim:** Scoring only checks keyword presence, not contextual analysis

**Evidence:**
- File: `validator.js` lines 73, 656
- No semantic validation that stakeholder concerns appear in context

**Result:** ✅ TRUE POSITIVE - Users can list keywords without substantive analysis

**Impact:** 7 pts exploitable

---

### Finding 3: ROI Formula Variables - FALSE POSITIVE ❌

**Sub-agent Claim:** Regex doesn't support variable names

**Investigation:** Line 43 shows:
```javascript
roiFormula: /... |\([^)]+[-−–][^)]+\)\s*[\/÷]\s*\S+/gi
```

This pattern `\([^)]+[-−–][^)]+\)` DOES match variable names like `(Total Savings - Implementation) / Implementation`

**Result:** ❌ FALSE POSITIVE - Regex is already permissive

---

### Finding 4: Stakeholder Vocabulary - FALSE POSITIVE ❌

**Sub-agent Claim:** Regex is missing terms

**Investigation:** Line 69-73 shows comprehensive vocabulary already present.

**Result:** ❌ FALSE POSITIVE - Already addressed

---

### Finding 5: Minimal Investment Keyword - FALSE POSITIVE ❌

**Sub-agent Claim:** Regex misses variants

**Investigation:** Pattern already includes `minimal|minimum|low.?cost|basic|mvp|phase.?1|incremental`

**Result:** ❌ FALSE POSITIVE - Already comprehensive

---

## Comparison to Gemini Baseline

| Finding | Gemini | Sub-agent |
|---------|--------|-----------|
| Full Investment Ghost Option | ⚠️ PARTIAL | Not found |
| ROI Formula Trap | ⚠️ PARTIAL (now fixed) | ❌ FALSE POSITIVE |
| Stakeholder/Equity | ❌ FALSE POSITIVE | ❌ FALSE POSITIVE |
| Payback Verb Form | Not found | ✅ **NOVEL** |
| Stakeholder Stuffing | Not found | ✅ Found |

---

## Novel Insights (Sub-agent)

1. **Payback Verb Form** - "breaks even" doesn't match regex. This is a NOVEL finding not in Gemini's review. Users writing natural English like "The project breaks even in 8 months" would lose points.

---

## Observations

### What Worked

- Sub-agent found a genuinely novel finding (payback verb form)
- Sub-agent verified claims against code

### What Didn't Work

- **60% false positive rate** - Sub-agent reported 5 findings but only 2 were true
- Sub-agent claimed to create files that don't exist in the repo
- Sub-agent over-confidently marked issues as "verified" without actual verification

### Patterns Noticed

- business-justification-assistant is MORE mature than pr-faq-assistant
- Gemini already caught most major issues and they were FIXED
- Sub-agent's value was finding edge cases Gemini missed (verb forms)

---

## Key Learning: Context Matters

This tool has ALREADY been reviewed by Gemini and fixes were applied. The sub-agent was reviewing a PATCHED codebase but didn't know that. This affected:
1. Many findings were already addressed
2. Novel findings were rarer
3. False positive rate was higher

---

## Time Breakdown

- Sub-agent execution: 10 min
- Verification of findings: 5 min
- Total: ~15 min

