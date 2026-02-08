# Round 16: pr-faq-assistant | Condition C (Direct-External)

## Metrics

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 5 |
| **HR (Hallucinations)** | 1 |

## Gemini's Findings

### Finding 1: Banned Word Penalty Disconnect
- **Category**: Enforcement Gap / Point Misalignment
- **Severity**: CRITICAL
- **Claim**: phase1.md says "2-5 points EACH" but validator caps at -3 total
- **Verification**: TRUE
  - phase1.md line 82: "BANNED WORDS — Using these costs you 2-5 points EACH"
  - validator.js lines 881-886: `if (hypeCount > 3) { result.score -= 3 }` (capped)
  - Test: 5 banned words → expected -10 to -25, actual -3

### Finding 2: Mechanism "Preposition" Gaming
- **Category**: Gaming Vulnerability / Semantic Gap
- **Severity**: HIGH
- **Claim**: "using magic" passes mechanism check same as "using AI-powered automation"
- **Verification**: TRUE
  - validator.js line 298: `/\busing\s+\w+/i`
  - Test: "using magic" → PASS, "using AI-powered automation" → PASS
  - No substance validation for the mechanism word

### Finding 3: Quote Attribution Ignored
- **Category**: Missing Requirement Enforcement
- **Severity**: MEDIUM
- **Claim**: phase1.md requires "named individuals with titles" but validator doesn't check
- **Verification**: TRUE
  - phase1.md line 94: "Quotes attributed to named individuals with titles: 2 pts"
  - grep for "attribution" in validator.js: No results
  - extractQuotes() and scoreQuote() only check for metrics, not attribution

### Finding 4: Price & Availability Depth Gap
- **Category**: Semantic Gap
- **Severity**: MEDIUM
- **Claim**: Can omit price ($) and availability and still get full points
- **Verification**: TRUE
  - phase1.md line 46-48: "Price & Availability (4 pts)" with pricing info requirement
  - validator.js analyzeReleaseDate only checks for date pattern and location
  - No explicit check for $ or pricing information

### Finding 5: Quantitative Metric Gaming in Quotes
- **Category**: Gaming Vulnerability
- **Severity**: HIGH
- **Claim**: "3 customers" counts as metric same as "10,000 customers"
- **Verification**: TRUE
  - validator.js line 84: `/\d+(?:,\d{3})*(?:\.\d+)?\s*(?:customers?|users?|transactions?)/gi`
  - Test: "3 customers" → matches, "10,000 customers" → matches
  - No minimum threshold for absolute counts

### Finding 6: Internal FAQ "Softball" Bypass
- **Category**: Semantic Gap
- **Severity**: LOW
- **Claim**: Padding text between "risk" and "success" bypasses softball detection
- **Verification**: PARTIAL (counts as hallucination)
  - validator.js line 1116: `.{0,30}` limits distance check
  - Test: "The risk is that success comes too fast" → TRUE (detected as softball)
  - Test: Long padded version → FALSE (not detected)
  - However, this is working as designed - the pattern is meant to catch obvious softballs
  - The 30-char limit is a reasonable heuristic, not a bug

## Verification Commands

```bash
# Finding 1: Banned word penalty cap
grep -n "hypeCount > 3" validator/js/validator.js
grep -n "costs you" shared/prompts/phase1.md

# Finding 2: Mechanism gaming
grep -n "using\\\s+\\\w+" validator/js/validator.js

# Finding 3: Quote attribution
grep -n "attribution" validator/js/validator.js  # No results
grep -n "named individuals" shared/prompts/phase1.md

# Finding 4: Price/availability
grep -n "price\|availability" validator/js/validator.js

# Finding 5: Metric gaming
node -e "console.log('3 customers'.match(/\d+\s*customers?/i))"

# Finding 6: Softball bypass
node -e "const p=/risk.{0,30}success/i; console.log(p.test('The risk is that success comes too fast'))"
```

## Summary

Condition C (Direct-External) produced 5 verified hits and 1 hallucination:
- Finding 6 describes intended behavior (30-char heuristic) as a bug
- Findings 1-5 are legitimate enforcement gaps and gaming vulnerabilities
- The banned word penalty disconnect (Finding 1) is particularly significant

This round shows Gemini can find real issues but sometimes misinterprets design decisions as bugs.

