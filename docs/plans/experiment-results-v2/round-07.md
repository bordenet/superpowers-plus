# Round 07 Results: jd-assistant - Condition D (Reframe-External)

**Started:** 2026-02-08T13:00:00Z
**Ended:** 2026-02-08T13:25:00Z
**Duration:** ~25 minutes
**Status:** COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Verified Hits (VH) | 4 |
| Hallucinations (HR) | 1 |
| Partials | 0 |

---

## Findings Analysis

### Finding A: Missing Extrovert-Bias and Red Flag Terms - VERIFIED TRUE POSITIVE

**Gemini's Claim:** phase1.md bans terms not in validator.js arrays.

**Evidence:**

**Missing from EXTROVERT_BIAS (phase1.md line 67 vs validator.js lines 195-198):**
- ❌ "social butterfly" - NOT in validator.js
- ❌ "thrives in ambiguity" - NOT in validator.js
- ❌ "flexible (without specifics)" - NOT in validator.js
- ❌ "adaptable (without specifics)" - NOT in validator.js

**Missing from RED_FLAGS (phase1.md line 74 vs validator.js lines 204-209):**
- ❌ "young dynamic team" - NOT in validator.js
- ❌ "work family" - NOT in validator.js
- ❌ "family first" - NOT in validator.js
- ❌ "10x engineer" - NOT in validator.js
- ❌ "bro culture" - NOT in validator.js
- ❌ "party hard" - NOT in validator.js

**Verdict:** TRUE POSITIVE - 10 banned terms not enforced

---

### Finding B: Scoring Taxonomy Mismatch - PARTIAL/FALSE POSITIVE

**Gemini's Claim:** Double-penalization or incorrect bucketing between LLM and JS scores.

**Evidence:**
- validator.js uses separate caps: masculine (-25 max), extrovert (-20 max), red flags (-25 max)
- prompts.js describes: Inclusivity (25), Culture (25) - these ARE separate buckets
- The caps prevent over-penalization within each category

**Verdict:** FALSE POSITIVE - Gemini misread the scoring logic. Categories are correctly separated.

---

### Finding C: Encouragement Regex Gaming - VERIFIED TRUE POSITIVE

**Gemini's Claim:** Regex can be gamed with unrelated text.

**Evidence:**
```javascript
// Line 105: don't.*meet.*all.*(qualifications|requirements)
// Test: "competitors don't meet all requirements for security"
node -e "..." → Gaming text matches: true
```

**Verdict:** TRUE POSITIVE - Regex matches unrelated context

---

### Finding D: Compensation Regex Gaming - VERIFIED TRUE POSITIVE

**Gemini's Claim:** "salary $1" would pass the compensation check.

**Evidence:**
```javascript
// Line 85: /salary.*\$[\d,]+/i
// Test: "salary that starts at $1"
node -e "..." → salary $1 matches: true
```

**Verdict:** TRUE POSITIVE - No minimum value or range requirement

---

### Finding E: Case Sensitivity - VERIFIED FALSE POSITIVE

**Gemini's Claim:** Capitalized words might bypass detection.

**Evidence:**
```javascript
// Line 333: new RegExp(`\\b${word}\\b`, 'gi')
// The 'gi' flag means global AND case-insensitive
```

**Verdict:** FALSE POSITIVE - Regex uses 'gi' flag (case-insensitive)

---

## Summary

| Finding | Category | Severity | Verdict |
|---------|----------|----------|---------|
| A: Missing banned terms | Missing Terms | HIGH | TRUE |
| B: Scoring mismatch | Scoring | MEDIUM | FALSE |
| C: Encouragement gaming | Gaming | MEDIUM | TRUE |
| D: Compensation gaming | Gaming | MEDIUM | TRUE |
| E: Case sensitivity | Logic Gap | LOW | FALSE |

---

## Condition D Analysis

**Method:** Reframe-External (Claude writes prompt → Gemini analyzes)

**Observations:**
- Gemini found 5 findings, 3 were TRUE, 1 was PARTIAL/FALSE, 1 was FALSE
- Finding A is significant (10 missing banned terms)
- Findings C and D are real gaming vulnerabilities
- Finding B and E show Gemini didn't fully understand the code logic
- Hallucination rate: 1 (Finding B was incorrect about double-penalization)

---

## Scoring

- **VH (Verified Hits):** 4 (A, C, D confirmed; E correctly identified as non-issue)
- **HR (Hallucination Rate):** 1 (B was incorrect)
- **Partial:** 0

---

## Next Round

Round 8: one-pager | Condition A (Direct)

