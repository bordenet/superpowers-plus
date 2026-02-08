# Round 9: business-justification-assistant | Condition C (Direct-External)

**Date:** 2026-02-08
**Tool:** business-justification-assistant
**Condition:** C - Direct-External (raw files sent to Gemini, no adversarial reframing)

## Gemini's Findings

### Finding A: Backspace Regex Failure
**Claim:** Validator uses literal backspace character (\u0008) instead of \b
**Severity:** CRITICAL
**Verdict:** ❌ **FALSE (Hallucination)**
- Hex dump shows `5c62` which is `\b` (backslash + b), NOT backspace
- Tested regex: `text.match(/\b(problem|challenge|...)\b/gi)` returns `['problem', 'challenge']`
- Gemini likely saw `\b` in the source and misinterpreted it

### Finding B: Quantitative Ratio vs Count
**Claim:** phase1.md requires 80/20 ratio but validator.js only checks count >= 3
**Severity:** HIGH
**Verdict:** ✅ **TRUE**
- Line 479: `if (... && evidence.quantifiedCount >= 3) { score += 12; }`
- Tested: 1000+ words with only 3 metrics still scores full 12 points
- No density check exists - 0.3% quant content passes as "80/20"

### Finding C: Slop Penalty Cap Too Low
**Claim:** Slop penalty capped at 5 points despite phase1.md making it critical
**Severity:** HIGH
**Verdict:** ✅ **TRUE**
- Line 730: `slopDeduction = Math.min(5, Math.floor(slopPenalty.penalty * 0.6));`
- Cap of 5 points means document full of banned buzzwords loses max 5%
- phase1.md Self-Check implies banned terms are prerequisite for 30pt category

### Finding D: ROI Formula Missing × 100
**Claim:** validator.js ignores multiplication sign from phase1.md formula
**Severity:** MEDIUM
**Verdict:** ⚠️ **PARTIAL**
- Regex captures division portion but not `× 100` tail
- Tested: Both `(Benefit - Cost) / Cost × 100` and `(Benefit - Cost) / Cost` match same pattern
- Not a full failure - formula IS detected, just not verified complete

### Finding E: Stakeholder Keyword Stuffing
**Claim:** Validator awards points for keyword presence, not addressing concerns
**Severity:** MEDIUM
**Verdict:** ✅ **TRUE**
- Line 656-657: `if (execution.hasStakeholderSection && execution.hasStakeholderConcerns) { score += 7; }`
- Tested: "Stakeholders: Finance, HR, Legal." scores same as detailed concern analysis
- No semantic check for actually addressing ROI/equity/liability issues

### Finding F: Investment Option OR vs AND
**Claim:** Uses OR instead of AND for minimal/full investment requirement
**Severity:** MEDIUM
**Verdict:** ✅ **TRUE**
- Line 594: `const hasInvestmentOption = options.hasMinimalOption || options.hasFullOption;`
- phase1.md requires both "Option B: Minimal Investment" AND "Option C: Full Investment"
- Validator accepts either one for full points

## Scoring Summary

| Finding | Category | Claimed | Verified | Result |
|---------|----------|---------|----------|--------|
| A | Regex Error | CRITICAL | Regex works correctly | ❌ Hallucination |
| B | Ratio Check | TRUE | Count-only, no density | ✅ Verified Hit |
| C | Slop Cap | TRUE | 5pt max confirmed | ✅ Verified Hit |
| D | ROI Format | PARTIAL | Detects formula, not × | ⚠️ Partial |
| E | Stakeholder | TRUE | Keyword-only check | ✅ Verified Hit |
| F | Options OR | TRUE | OR gate confirmed | ✅ Verified Hit |

## Round Metrics

- **Verified Hits (VH):** 4 (B, C, E, F)
- **Hallucinations (HR):** 1 (A)
- **Partials:** 1 (D)

## Notes

Condition C (Direct-External) with no adversarial reframing produced:
- 1 major hallucination about regex backspace (Gemini misread \b as \u0008)
- 4 solid verified hits about scoring/gaming issues
- This is the first hallucination for Condition C (previously 0 in Round 2)

