# Round 15: product-requirements-assistant | Condition D (Reframe-External)

## Metrics

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 4 |
| **HR (Hallucinations)** | 1 |

## Gemini's Findings

### Finding 1: Kill Switch Keyword Loophole
- **Category**: Gaming Vulnerability
- **Severity**: HIGH
- **Claim**: "We haven't decided on a kill switch yet" scores same as full structure
- **Verification**: TRUE
  - Line 141: `killSwitch: /\b(kill\s+(switch|criteria)|pivot\s+or\s+persevere|...)\b/gi`
  - Test: "We have not decided on a kill switch yet" matches `['kill switch']`
  - No validation of Kill Criteria, Decision Point, or Rollback Plan structure

### Finding 2: Failure-Case AC Gaming
- **Category**: Semantic Gap / Gaming Vulnerability
- **Severity**: HIGH
- **Claim**: Mentioning "error" anywhere grants failure case bonus
- **Verification**: TRUE
  - Line 1001: `hasFailureCases = /\b(fail|error|invalid|edge\s+case|...)\b/i.test(text)`
  - Test: "We must handle error conditions" → PASS (not in AC context)
  - Test: "Empty state handling is important" → PASS (not in AC context)
  - No validation that failure keywords appear within Given/When/Then blocks

### Finding 3: Traceability "Documentation Theater"
- **Category**: Point Misalignment / Semantic Gap
- **Severity**: MEDIUM
- **Claim**: Mentioning FR1, P1, NFR1 separately passes traceability check
- **Verification**: TRUE
  - Lines 1179-1180: `if (traceabilityMatches.length >= 3) { traceabilityScore += 2 }`
  - Test: "FR1 is important. P1 is the main problem. NFR1 covers performance." → 3 matches, passes
  - No validation of actual Problem→Requirement→Metric mapping table

### Finding 4: Formula/Calculation Specificity Gap
- **Category**: Missing Check
- **Severity**: MEDIUM
- **Claim**: No check for explicit formulas despite phase1.md requirement
- **Verification**: TRUE
  - phase1.md line 343: "All scoring mechanisms include explicit formulas"
  - grep for "formula\|calculation\|weighted" in validator.js: No pattern detection
  - User can describe "Engagement Score" qualitatively without formula

### Finding 5: Calendar Date Prohibition
- **Category**: Point Misalignment
- **Severity**: LOW
- **Claim**: Calendar dates not penalized despite phase1.md prohibition
- **Verification**: PARTIAL (counts as hallucination)
  - phase1.md lines 260-267: "Use relative timeframes, NOT specific calendar dates"
  - However, this is guidance for the LLM generating the PRD, not a scoring requirement
  - The validator scores what's IN the PRD, not how it was generated
  - prompts.js doesn't mention penalizing calendar dates
  - This is a spec interpretation issue, not a validator bug

## Verification Commands

```bash
# Finding 1: Kill switch keyword gaming
grep -n "killSwitch" validator/js/validator.js
node -e "const p=/\b(kill\s+(switch|criteria)|pivot\s+or\s+persevere)\b/gi; console.log('We have not decided on a kill switch yet'.match(p))"

# Finding 2: Failure case gaming
grep -n "hasFailureCases" validator/js/validator.js
node -e "const p=/\b(fail|error|invalid|edge\s+case)\b/i; console.log(p.test('We must handle error conditions'))"

# Finding 3: Traceability gaming
grep -n "traceabilityMatches.length >= 3" validator/js/validator.js

# Finding 4: Formula check missing
grep -n "formula" validator/js/validator.js  # No results
grep -n "formula" shared/prompts/phase1.md   # Line 343

# Finding 5: Calendar date check
grep -n "calendar\|2025\|2026" validator/js/validator.js  # No results
```

## Summary

Condition D (Reframe-External) produced 4 verified hits and 1 hallucination:
- Finding 5 misinterprets phase1.md guidance as a scoring requirement
- The calendar date prohibition is for LLM generation, not validator scoring
- Findings 1-4 are legitimate gaming vulnerabilities

This continues the pattern of external model (Gemini) having higher hallucination rates.

