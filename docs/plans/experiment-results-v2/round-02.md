# Round 2: jd-assistant | Condition C (Direct-External)

**Date:** 2026-02-08
**Tool:** jd-assistant
**Condition:** C - Direct-External (raw files to Gemini, no reframing)

## Raw Findings from Gemini

### Finding 1: Masculine Words Mismatch (Critical)
- prompts.js lists only 17 words (ending at "superior")
- validator.js has 26 words (includes leader, go-getter, etc.)
- phase1.md has 26 words

### Finding 2: Extrovert-Bias List De-sync (High)
- phase1.md has 12 phrases including: social butterfly, thrives in ambiguity, flexible (without specifics), adaptable (without specifics)
- validator.js has only 8 phrases
- prompts.js has only 8 phrases

### Finding 3: Red Flag Expansion Failure (High)
- phase1.md bans 21 phrases including: young dynamic team, work family, family first, 10x engineer, bro culture, party hard
- validator.js has only 15 phrases
- prompts.js has only 15 phrases

### Finding 4: Compensation Check Logic Loophole (Medium)
- phase1.md demands specific range with 30-50% spread
- validator.js only checks for presence of dollar sign/number, not range validity

### Finding 5: De-Duplication Scoring Void (Low)
- phase1.md emphasizes de-duplication rule
- Neither validator.js nor prompts.js scores for redundancy

---

## Verification (grep against actual code)

### Finding 1 - ✅ TRUE POSITIVE
- prompts.js lists only 17 words (ends at "superior") - CONFIRMED
- validator.js has 26 words in MASCULINE_CODED array - CONFIRMED
- **Gemini correctly identified the mismatch**

### Finding 2 - ✅ TRUE POSITIVE
- phase1.md includes: "social butterfly, thrives in ambiguity, flexible (without specifics), adaptable (without specifics)" - CONFIRMED
- validator.js EXTROVERT_BIAS has only 8 phrases (ends at "team player") - CONFIRMED
- **4 phrases in phase1.md are NOT enforced by validator**

### Finding 3 - ✅ TRUE POSITIVE
- phase1.md includes: "young dynamic team, work family, family first, 10x engineer, bro culture, party hard" - CONFIRMED
- validator.js RED_FLAGS has only 15 phrases (ends at "passion required") - CONFIRMED
- **6 phrases in phase1.md are NOT enforced by validator**

### Finding 4 - ✅ TRUE POSITIVE
- validator.js line 85: `/salary.*\$[\d,]+/i` matches "Salary: $1" - CONFIRMED
- No validation of range spread (30-50%) as required by phase1.md - CONFIRMED
- **Logic loophole exists**

### Finding 5 - ✅ TRUE POSITIVE
- phase1.md has dedicated "De-Duplication Rule" section - CONFIRMED
- Neither prompts.js nor validator.js has redundancy scoring - CONFIRMED
- **Design gap, not a bug per se**

---

## Summary

| Finding | Verified? | True Positive? |
|---------|-----------|----------------|
| 1. Masculine words mismatch | ✅ Yes | ✅ TRUE |
| 2. Extrovert-bias de-sync | ✅ Yes | ✅ TRUE |
| 3. Red flags expansion | ✅ Yes | ✅ TRUE |
| 4. Compensation loophole | ✅ Yes | ✅ TRUE |
| 5. De-duplication void | ✅ Yes | ✅ TRUE (design gap) |

**Verified Hits (VH):** 5
**Hallucinations (HR):** 0
**False claims within findings:** 0

---

## Notes

Condition C (Direct-External) - Gemini received raw files with generic instruction "find misalignments."
All 5 findings verified as true. Gemini produced a clean, accurate analysis with zero hallucinations.
Notable: Gemini provided a helpful summary table and offered to generate fixes.

