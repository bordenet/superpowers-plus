# Round 1: pr-faq-assistant | Condition A (Direct)

**Date:** 2026-02-08
**Tool:** pr-faq-assistant
**Condition:** A (Direct - no reframe, no external)
**Time:** ~15 minutes

---

## Findings

### Finding 1: Banned Words List Mismatch
**Type:** Pattern not scored / List mismatch

**Evidence:**
- phase1.md lines 83-87: Bans `passionate, comprehensive, seamless, robust, innovative, transformative`
- validator.js lines 861-867: Does NOT check for these words
- validator.js checks words NOT in phase1.md: `industry-leading, breakthrough, disruptive, unprecedented, ultimate, premier, superior, exceptional, outstanding`

**Severity:** High

**Verification needed:** grep for these words in validator.js

---

### Finding 2: Phrase patterns not checked
**Type:** Pattern not scored

**Evidence:**
- phase1.md line 87: Bans `"we believe", "we're proud", "we're excited"` (full phrases)
- validator.js: Only checks individual words like `excited`, `proud`

**Severity:** Medium

**Verification needed:** Check if phrase matching exists

---

### Finding 3: Penalty amounts differ
**Type:** Logic gap

**Evidence:**
- phase1.md line 82: "2-5 points EACH"
- prompts.js lines 101-103: "3 pts" / "2 pts" for specific categories
- validator.js: Uses aggregate scoring (starts at 10, deducts by count)

**Severity:** Low (different approach, may be intentional)

---

### Finding 4: Quote type detection missing
**Type:** Pattern not scored

**Evidence:**
- phase1.md lines 99-109: Requires 1 Executive Vision + 1 Customer Relief quote
- validator.js `scoreCustomerEvidence()`: Only counts quotes and checks for metrics, doesn't distinguish quote types

**Severity:** Medium

---

### Finding 5: Quote count scoring mismatch
**Type:** Logic gap

**Evidence:**
- phase1.md lines 92-97: "Exactly 2 quotes (1 Executive Vision, 1 Customer Relief): 3 pts"
- validator.js lines 203-210: 2 quotes = +1 bonus, 3+ = -2 penalty

**Severity:** Low

---

## Verification (grep against actual code)

### Finding 1 - Verified PARTIAL
- `passionate` - NOT in validator.js ✅ TRUE POSITIVE
- `transformative` - NOT in validator.js ✅ TRUE POSITIVE
- `comprehensive` - IS in `weakLanguage` array (line 316) - FALSE POSITIVE
- `seamless` - IS in `vagueTerms` as phrase (line 920) - PARTIAL
- `robust` - IS in `weakLanguage` (line 316) - FALSE POSITIVE
- `innovative` - IS in `weakLanguage` (line 316) - FALSE POSITIVE

**Verdict:** 2 TRUE POSITIVES (passionate, transformative), 3 FALSE POSITIVES

### Finding 2 - Verified TRUE
- grep confirms phrase patterns NOT FOUND ✅ TRUE POSITIVE

### Finding 3 - Not verifiable (design choice)
- Different scoring approaches - not a bug, just different implementation

### Finding 4 - TRUE (by code inspection)
- validator.js has no logic to distinguish Executive vs Customer quotes ✅ TRUE POSITIVE

### Finding 5 - TRUE (by code inspection)
- Point values differ between phase1.md and validator.js ✅ TRUE POSITIVE

---

## Summary

| Finding | Verified? | True Positive? |
|---------|-----------|----------------|
| 1. Banned words mismatch | ✅ Yes | PARTIAL (2/6 words missing) |
| 2. Phrase patterns | ✅ Yes | ✅ TRUE |
| 3. Penalty amounts | N/A | Design choice |
| 4. Quote type detection | ✅ Yes | ✅ TRUE |
| 5. Quote count scoring | ✅ Yes | ✅ TRUE |

**Verified Hits (VH):** 4 (Finding 1 partial + 2 + 4 + 5)
**Hallucinations (HR):** 1 (Finding 3 was not a bug)
**False claims within findings:** 3 (comprehensive, robust, innovative were actually checked)

---

## Notes

This was direct analysis without reframing. I found real issues but also made false claims about words that ARE actually checked in different arrays. The verification step caught my errors.

