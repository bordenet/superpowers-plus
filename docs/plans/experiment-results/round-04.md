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

---------------------------------------------------------------------

Gemini response:

The results from **Round 04 (Condition B)** provide a fascinating look at the "Diminishing Returns" of AI analysis on mature codebases. Because the `business-justification-assistant` had already been hardened by previous Gemini reviews, the Sub-agent's high False Positive (FP) rate suggests it was "hallucinating depth" to meet the perceived requirements of your prompt.

However, the **Novel Insight** regarding verb forms is a masterclass in why we use diverse models/approaches.

---

## 1. The "Verb Form" Breakthrough (Finding 1)

The Sub-agent identified a **linguistic blind spot** that static analysis often misses.

* **Gemini's Bias:** Usually looks for structural alignment (Section A exists, Metric B is present).
* **Sub-agent's Value:** It simulated the *writer's* persona. A human writing a narrative justification is highly likely to use "breaks even" (verb) rather than "break-even" (noun/adjective).
* **The Technical Gap:** The `.?` in `/break.?even/` only accounts for a space or a hyphen, not a suffix.
* **Fix:** `/\bbreak(s|ing)?[\s-]?even\b/gi`



---

## 2. Why the 60% False Positive Rate?

The high FP rate in this round is actually a sign of **Model Over-Fitting to the Task**.

1. **The "Patched Codebase" Trap:** Since the major "Structure & Hook" gaps were already closed in earlier rounds, the Sub-agent likely felt "pressured" to find critical failures where only minor optimizations remained.
2. **Regex Complexity Misjudgment:** In Finding 3, the Sub-agent failed to parse the nested logic of the capture groups `\([^)]+[-−–][^)]+\)`. This suggests that while sub-agents are better at *writing* prompts, they can still struggle with *reading* complex regular expressions compared to a direct-external model that might just "run" a mental simulation of the string.

---

## 3. Revised 2x2 Factorial Design (Refining for Round 05)

Based on these results, you should adjust the "Reframe" step to focus on **Semantic Edge Cases** rather than structural ones.

| Condition | Modification for Round 05 |
| --- | --- |
| **B: Reframe-Self** | Force yourself to write a "Writer's Persona" prompt (e.g., "How would a non-technical manager word this?") |
| **D: Reframe-External** | Explicitly ask the external model to find **Linguistic Bypasses** (like the 'breaks even' find). |

---

## 4. What Would Invalidate the Next Round?

The biggest risk now is **"Verification Fatigue."** As the findings move from "The whole section is missing" (Easy to verify) to "This specific verb form fails" (Hard to verify), you are at risk of:

* **Confirmation Bias:** Trusting the Sub-agent because it found one "cool" thing (Finding 1).
* **Negative Information:** If the Sub-agent claims a file exists that doesn't, it indicates the sub-agent is losing track of the **Ground Truth** provided in the context.

---

## Next Step

**Would you like me to draft a "Negative Test Suite" for the `validator.js`?** I can provide 5 strings that use "Natural Language" (like the "breaks even" example) to see if we can intentionally trigger more True Positives that the current regexes miss.