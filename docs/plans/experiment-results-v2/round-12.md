# Round 12: jd-assistant | Condition A (Direct)

## Summary

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 4 |
| **HR (Hallucinations)** | 0 |

## Findings

### Finding 1: Missing Red Flag Phrases ✅ VERIFIED

**phase1.md line 74** lists these BANNED phrases:
- young dynamic team
- work family
- family first
- 10x engineer
- bro culture
- party hard

**validator.js lines 204-209** - RED_FLAGS array is MISSING all 6 of these phrases.

**Verification:** `grep -n "young dynamic\|work family\|family first\|10x\|bro culture\|party hard" validator/js/validator.js` returns nothing.

**Verdict:** TRUE - 6 banned phrases from phase1.md are not enforced by validator.

---

### Finding 2: Missing Extrovert-Bias Phrases ✅ VERIFIED

**phase1.md line 67** lists these BANNED phrases:
- social butterfly
- thrives in ambiguity
- flexible (without specifics)
- adaptable (without specifics)

**validator.js lines 195-198** - EXTROVERT_BIAS array is MISSING these phrases.

**Verification:** `grep -n "social butterfly\|thrives in ambiguity" validator/js/validator.js` returns nothing.

**Verdict:** TRUE - Multiple extrovert-bias phrases from phase1.md are not enforced.

---

### Finding 3: No De-Duplication Check ✅ VERIFIED

**phase1.md lines 107-116** - CRITICAL de-duplication rule:
- "Redundant job descriptions look unprofessional"
- "Review all sections for duplicate content"
- "Tech stack appears ONCE"
- "Benefits appear ONCE"

**validator.js** - NO duplicate content detection exists.

**Verification:** `grep -n "duplicate\|redundan\|dedup" validator/js/validator.js` returns nothing.

**Verdict:** TRUE - A JD with identical content in multiple sections scores the same as a clean one.

---

### Finding 4: No Section Structure Validation ✅ VERIFIED

**phase1.md lines 94-103** - Required sections:
- About the Role
- Key Responsibilities
- Required Qualifications
- Preferred Qualifications
- What We Offer
- To Apply

**validator.js** - NO section presence/order validation.

**Verification:** `grep -n "About the Role\|Key Responsibilities" validator/js/validator.js` returns nothing.

**Verdict:** TRUE - A JD missing required sections gets no penalty.

---

## Additional Observations (Not Counted as VH)

### Slop Penalty Cap
- **prompts.js line 44**: "-1 to -5 pts" for AI slop
- **validator.js line 121**: `Math.min(5, Math.floor(slopPenalty.penalty * 0.6))`
- This is ALIGNED - both cap at 5 points max

### Specificity Not Validated
- phase1.md requires "concrete responsibilities" and "measurable requirements"
- validator.js has no semantic check for specificity
- "Strong Python skills" scores same as "3+ years with Python"
- Not counting as VH since this is a known limitation of regex-based validation

---

## Notes

Condition A (Direct) produced 4 verified hits with 0 hallucinations. The findings are straightforward gaps where phase1.md lists banned phrases that validator.js doesn't include in its detection arrays.

This is the cleanest type of finding - explicit lists in phase1.md that are incomplete in validator.js.

