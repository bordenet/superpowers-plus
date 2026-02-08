# Round 04: business-justification-assistant | Condition D (Reframe-External)

**Tool:** business-justification-assistant
**Condition:** D (Reframe-External) - Comprehensive prompt written by Claude, sent to Gemini
**Started:** 2026-02-08

---

## Gemini's Findings (5 total)

### Finding A: ROI Formula Regex Trap
**Claim:** Regex fails on variable names like `(Benefit - Cost) / Cost` and the `×` symbol

**Verification:**
```bash
grep -n "roiFormula" validator/js/validator.js
# Line 43: Complex regex with multiple alternatives
```

```javascript
// Test results:
'(Benefit - Cost) / Cost'.match(regex) // ['(Benefit - Cost) /'] - MATCHES (partial)
'(Savings - Cost) / Cost'.match(regex) // ['(Savings - Cost) / Cost'] - MATCHES
'(100 - 50) / 50'.match(regex)         // ['(100 - 50) / 50'] - MATCHES
```

**Result:** ❌ **FALSE POSITIVE** - The regex DOES match variable names via `\([^)]+[-−–][^)]+\)\s*[\/÷]\s*\S+`
The `×` symbol claim is TRUE but edge case (users rarely use ×)

---

### Finding B: Missing Section Validation (11 vs 8)
**Claim:** phase1.md requires 11 sections but REQUIRED_SECTIONS only has 7-8

**Verification:**
```bash
grep -A 10 "REQUIRED_SECTIONS" validator/js/validator.js
# Shows 8 sections: Problem, Options, Financial, Solution, Scope, Stakeholders, Risks, Timeline
```

phase1.md requires: Executive Summary, Problem (2 sub), Options (4 sub), Financial (3 sub), 
Proposed Solution, Scope, Requirements, Stakeholders, Timeline, Risks, Open Questions

Missing from REQUIRED_SECTIONS: **Requirements**, **Open Questions**
(Executive Summary checked separately via EXECUTION_PATTERNS.executiveSummary)

**Result:** ✅ **TRUE** - Requirements and Open Questions sections not validated

---

### Finding C: Vague Language Contradiction (comprehensive rewarded)
**Claim:** Banned words like "comprehensive" are rewarded in validator.js

**Verification:**
```bash
grep -n "comprehensive" validator/js/validator.js
# Line 61: fullInvestment pattern INCLUDES "comprehensive"
```

BUT slop-detection.js line 37 penalizes: `'robust', 'seamless', 'comprehensive'...`

**Result:** ⚠️ **PARTIAL** - "comprehensive" is in fullInvestment pattern (positive) 
AND in slop-detection (negative). Net effect depends on which fires first.
This IS a logic conflict.

---

### Finding D: Stakeholder Keyword Stuffing
**Claim:** Regex only checks department names, not actual concerns

**Verification:**
```bash
grep -n "stakeholderConcerns" validator/js/validator.js
# Line 73: /\b(finance|fp&a|...|hr|...|legal|compliance|...)\b/gi
```

The regex matches keywords only. "We will check with Finance, HR, and Legal later" 
would score 7/7 despite no actual concerns documented.

**Result:** ✅ **TRUE** - Keyword presence ≠ concern addressed

---

### Finding E: Payback Period Verb Forms
**Claim:** Regex `/break.?even/` doesn't match "breaks even"

**Verification:**
```javascript
'breaks even'.match(/break.?even/gi) // null - DOES NOT MATCH
'break even'.match(/break.?even/gi)  // ['break even'] - matches
```

**Result:** ✅ **TRUE** - Verb form "breaks even" fails to match

---

## Metrics Summary

| Finding | Gemini Claim | Verified | Result |
|---------|--------------|----------|--------|
| A: ROI Formula | Regex fails on variables | Tested with node | ❌ FALSE (regex works) |
| B: Missing Sections | 11 vs 8 sections | grep REQUIRED_SECTIONS | ✅ TRUE |
| C: Vague Language | "comprehensive" rewarded | grep both files | ⚠️ PARTIAL (conflict exists) |
| D: Stakeholder Stuffing | Keywords only | grep regex | ✅ TRUE |
| E: Payback Verb | "breaks even" fails | JS test | ✅ TRUE |

**Verified Hits (VH):** 3 (B, D, E)
**Partial:** 1 (C)
**Hallucinations (HR):** 1 (A)

---

## Condition D Performance

| Metric | Value |
|--------|-------|
| Total Findings | 5 |
| Verified Hits | 3 |
| Partial | 1 |
| Hallucinations | 1 |
| **VH Rate** | 60% (3/5) |
| **HR Rate** | 20% (1/5) |

---

## Comparison: Condition D vs Earlier Rounds

| Round | Tool | Condition | VH | HR | Notes |
|-------|------|-----------|----|----|-------|
| 1 | pr-faq-assistant | A: Direct | 4 | 1 | Direct analysis |
| 2 | jd-assistant | C: Direct-External | 5 | 0 | Gemini raw files |
| 3 | one-pager | B: Reframe-Self | 3 | 1 | Self-reframing |
| **4** | **business-justification** | **D: Reframe-External** | **3** | **1** | **Full treatment** |

---

## Observations

1. **Condition D (Reframe-External) performed similarly to Condition A (Direct)** - 3 VH, 1 HR
2. **Condition C (Direct-External) still leads** with 5 VH, 0 HR
3. **The comprehensive prompt may have over-constrained Gemini** - it focused on the categories I specified rather than finding novel issues
4. **Finding E (verb forms) appeared in both sub-agent and Gemini reviews** - this is a real pattern

---

## Checkpoint

Round 4 complete. Proceeding to Round 5.

