# Round 20: product-requirements-assistant | Condition C (Direct-External) - FINAL ROUND

## Summary

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 5 |
| **HR (Hallucinations)** | 1 |

## Gemini Findings Verification

### Finding 1: Banned Tech Detection Missing
- **Category**: Missing Check
- **Severity**: CRITICAL
- **Claim**: No regex to detect forbidden implementation details (PostgreSQL, React, AWS, etc.)
- **Verification**:
  ```bash
  grep -n -i "postgresql\|react\|aws\|lambda\|microservice" validator/js/validator.js
  # No matches!
  ```
- **Verdict**: ✅ **TRUE** - Zero detection for banned "How" terms

### Finding 2: Calendar Date Detection Missing
- **Category**: Missing Check
- **Severity**: HIGH
- **Claim**: No check for absolute dates despite phase1.md banning them
- **Verification**:
  ```bash
  grep -n -i "calendar\|2025\|2026\|january\|february" validator/js/validator.js
  # No matches for date detection!
  ```
- **Verdict**: ✅ **TRUE** - Only checks for relative terms, never penalizes absolute dates

### Finding 3: Failure Case Gaming
- **Category**: Gaming Vulnerability
- **Severity**: HIGH
- **Claim**: Global keyword search for "error" triggers failure case credit even if not in AC
- **Verification**:
  ```javascript
  // Test: "error" in NFR section, not in AC
  // Result: strengths: ['3 acceptance criteria with success AND failure cases']
  // Gaming confirmed!
  ```
- **Verdict**: ✅ **TRUE** - Document-wide search, not AC-specific

### Finding 4: Formula Detection Missing
- **Category**: Missing Check
- **Severity**: MEDIUM
- **Claim**: No detection for explicit formulas despite Specificity Checklist requirement
- **Verification**:
  ```bash
  grep -n "formula\|equation\|math\|calculation" validator/js/validator.js
  # No matches for formula detection!
  ```
- **Verdict**: ✅ **TRUE** - Formulas mentioned in phase1.md but never checked

### Finding 5: Aha Quote Attribution Gaming
- **Category**: Gaming Vulnerability
- **Severity**: MEDIUM
- **Claim**: Quote regex doesn't verify Role/Context as required by phase1.md
- **Verification**:
  ```javascript
  // Test: "Fake quote long enough." — Some Person
  // hasAhaQuote: true
  // strengths: ['Customer "Aha!" moment quote included']
  // Gaming confirmed!
  ```
- **Verdict**: ✅ **TRUE** - Only checks for quote + em-dash, not attribution format

### Finding 6: Alternatives Per Feature
- **Category**: Semantic Gap
- **Severity**: MEDIUM
- **Claim**: Only checks for section presence, not per-feature alternatives
- **Verification**:
  ```javascript
  // alternativesConsidered: section header regex
  // alternativesContent: keyword search
  // No counting of features vs alternatives
  ```
- **Verdict**: ❌ **FALSE** - This is directionally correct but overstated. The validator never claimed to check per-feature alternatives; it's a section-level check by design. The "gap" is real but calling it a "bug" is inaccurate.

## Score Breakdown

| Finding | Category | Verified? |
|---------|----------|-----------|
| 1. Banned tech detection | Missing Check | ✅ TRUE |
| 2. Calendar date detection | Missing Check | ✅ TRUE |
| 3. Failure case gaming | Gaming Vulnerability | ✅ TRUE |
| 4. Formula detection | Missing Check | ✅ TRUE |
| 5. Aha quote attribution | Gaming Vulnerability | ✅ TRUE |
| 6. Alternatives per feature | Semantic Gap | ❌ FALSE (overstated) |

**Final: VH=5, HR=1**

## Notes

This is the **FINAL ROUND** of the experiment. Condition C (Direct-External) produced solid results with 5 verified hits and only 1 hallucination.

Key patterns from Gemini in this round:
- Correctly identified multiple missing checks (banned tech, dates, formulas)
- Correctly identified gaming vulnerabilities (failure cases, quote attribution)
- Overstated one finding (alternatives per feature) - called it a "bug" when it's a design choice

**Experiment Complete!** All 20 rounds finished.

