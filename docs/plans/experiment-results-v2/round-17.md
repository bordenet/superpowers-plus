# Round 17: jd-assistant | Condition B (Reframe-Self)

## Metrics

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 5 |
| **HR (Hallucinations)** | 0 |

## Self-Analysis Findings (After Writing Comprehensive Prompt)

### Finding 1: Red Flags List Misalignment
- **Category**: Enforcement Gap
- **Severity**: HIGH
- **Claim**: phase1.md lists 21 red flag phrases, validator.js only has 15
- **Verification**: TRUE
  - phase1.md includes: young dynamic team, work family, family first, 10x engineer, bro culture, party hard
  - validator.js RED_FLAGS array: only 15 phrases, missing the 6 above
  - grep for "young dynamic" in validator.js: No results
- **Impact**: JDs with "young dynamic team" or "10x engineer" won't be penalized

### Finding 2: Encouragement Statement Gaming
- **Category**: Gaming Vulnerability
- **Severity**: MEDIUM
- **Claim**: "we encourage you to apply" alone passes the check without 60-70% context
- **Verification**: TRUE
  - validator.js line 105: `/we\s+encourage.*apply/i` matches any "we encourage...apply"
  - Test: "We encourage you to apply for our credit card" → TRUE (passes)
  - The intent is to encourage underqualified candidates, but any encouragement passes

### Finding 3: Internal Posting Bypass
- **Category**: Gaming Vulnerability
- **Severity**: MEDIUM
- **Claim**: Including "internal posting" text in external JD bypasses compensation check
- **Verification**: TRUE
  - validator.js line 25-27: `/internal posting/i.test(text)` triggers internal mode
  - Test: "We are not an internal posting company" → TRUE (triggers bypass)
  - External JDs can avoid -10 compensation penalty by mentioning "internal posting"

### Finding 4: Absurd Compensation Range Accepted
- **Category**: Semantic Gap
- **Severity**: LOW
- **Claim**: "$0 - $999,999" passes compensation check
- **Verification**: TRUE
  - validator.js line 84: `/\$[\d,]+\s*[-–—]\s*\$[\d,]+/i` matches any range
  - Test: "$0 - $999,999" → TRUE (passes)
  - No validation for reasonable spread (phase1.md says 30-50% spread)

### Finding 5: prompts.js vs validator.js List Mismatch
- **Category**: Enforcement Gap
- **Severity**: MEDIUM
- **Claim**: LLM scoring rubric (prompts.js) has different word lists than validator.js
- **Verification**: TRUE
  - prompts.js masculine-coded: 17 words (original list only)
  - validator.js MASCULINE_CODED: 26 words (includes 9 additions)
  - Missing from prompts.js: leader, go-getter, hard-charging, strong, tough, warrior, superhero, superstar, boss
  - LLM may not penalize words that validator.js catches, causing score discrepancy

### Finding 6: De-Duplication Not Enforced (Investigated but FALSE)
- **Category**: Missing Check
- **Severity**: N/A
- **Claim**: phase1.md requires unique content per section, validator doesn't check
- **Verification**: FALSE (not a bug)
  - This is LLM generation guidance, not a scoring requirement
  - The validator scores the output, not the generation process
  - De-duplication is for the LLM to follow, not for scoring

### Finding 7: Specificity Not Validated (Investigated but FALSE)
- **Category**: Missing Check
- **Severity**: N/A
- **Claim**: phase1.md requires "concrete responsibilities" but validator doesn't check
- **Verification**: FALSE (not a bug)
  - Specificity is subjective and hard to validate with regex
  - Slop detection partially addresses this by penalizing vague language
  - This is LLM guidance, not a scoring requirement

## Verification Commands

```bash
# Finding 1: Red flags list gap
grep "young dynamic\|bro culture\|10x engineer" validator/js/validator.js  # No results

# Finding 2: Encouragement gaming
node -e "console.log(/we\s+encourage.*apply/i.test('We encourage you to apply for our credit card'))"

# Finding 3: Internal posting bypass
node -e "console.log(/internal posting/i.test('We are not an internal posting company'))"

# Finding 4: Absurd compensation
node -e "console.log(/\$[\d,]+\s*[-–—]\s*\$[\d,]+/i.test('\$0 - \$999,999'))"

# Finding 5: List mismatch
grep -c "'" validator/js/validator.js | head -1  # Count words in MASCULINE_CODED
```

## Summary

Condition B (Reframe-Self) produced 5 verified hits and 0 hallucinations.

The act of writing a comprehensive adversarial prompt helped identify:
1. A significant red flags list gap (6 phrases missing from validator)
2. Two gaming vulnerabilities (encouragement and internal posting)
3. A semantic gap (absurd compensation ranges accepted)
4. A list mismatch between prompts.js and validator.js

The prompt also helped distinguish between actual bugs and design decisions (Findings 6-7).

