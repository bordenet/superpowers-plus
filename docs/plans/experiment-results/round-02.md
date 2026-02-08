# Round 02 Results: pr-faq-assistant - Condition C (Document-based)

**Started:** 2026-02-08T10:20:00Z
**Ended:** 2026-02-08T10:35:00Z
**Duration:** ~15 minutes
**Status:** COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Findings | 5 |
| True Positives | 5 |
| False Positives | 0 |
| Accuracy Rate | 100% |
| Novel Insights | 1 |
| Time to First Finding | ~5 min |

---

## Findings (via Document-based Cold Read)

### Finding 1: Quote Count Asymmetric Penalty

**Claim:** Bonus for 2 quotes (+1) is less than penalty for 3+ quotes (-2), creating asymmetric incentives.

**Evidence:**
- File: `validator.js`
- Lines: 203-210
- Code: `quoteCountAdjustment = 1` for 2, `-2` for 3+

**Verification:** TRUE POSITIVE

**Impact:** 3 pts total swing (asymmetry discourages experimentation)

---

### Finding 2: Softball Detection 30-char Distance Constraint

**Claim:** Softball patterns use `.{0,30}` which users can bypass by adding buffer text between keywords.

**Evidence:**
- File: `validator.js`
- Lines: 1115-1122
- Code: `/\b(risk|fail|challenge|concern).{0,30}\b(success|easy|minimal|none|unlikely|low|small|minor|exciting|opportunity)/i`

**Verification:** TRUE POSITIVE

**Impact:** Could bypass 50-pt cap if all softballs evade detection

---

### Finding 3: Mechanism Detection Keyword-Only (No Specificity)

**Claim:** `/\busing\s+\w+/i` matches "using AI" identically to "using edge-caching with 200ms SLA"

**Evidence:**
- File: `validator.js`
- Lines: 297-305
- Code: All patterns are single-word after preposition

**Verification:** TRUE POSITIVE

**Impact:** 2 pts available for vague mechanisms

---

### Finding 4: No Metric Validation (Fake Metrics Score Full Points)

**Claim:** `detectMetricsInText()` finds any percentage/number without validating realism.

**Evidence:**
- File: `validator.js`
- Lines: 46-96
- Code: No upper/lower bound checking, no sanity validation

**Gaming example:** "500% improvement" and "10,000x faster" both score full points

**Verification:** TRUE POSITIVE

**Impact:** Up to 6 pts in quote scoring exploitable

---

### Finding 5: FAQ Answer Rigor Not Validated

**Claim:** `checkHardQuestions()` checks question+answer for keywords but doesn't validate answer length or substance.

**Evidence:**
- File: `validator.js`
- Lines: 1146-1165
- Code: `const text = q.question + ' ' + q.answer` then only keyword pattern matching

**Gaming example:**
- Q: "What risks exist?" A: "None." → Counts as risk question!
- The answer could be one word and still pass if question has keyword

**Verification:** TRUE POSITIVE

**Impact:** 15 pts for hard questions available without substantive answers

---

## Comparison to Round 1 (Sub-agent)

| Finding | Round 1 (Sub-agent) | Round 2 (Document) |
|---------|---------------------|-------------------|
| Quote asymmetry | ✅ Found | ✅ Found |
| Softball 30-char bypass | ✅ Found | ✅ Found |
| Mechanism no specificity | ✅ Found | ✅ Found |
| Fake metrics accepted | ✅ Found | ✅ Found |
| FAQ answer rigor | ✅ Found | ✅ Found |
| Dateline format ambiguity | ✅ Found (NOVEL) | ❌ Not found |

### What Document-Based Missed

1. **Dateline Format Ambiguity** - Round 1 found that validator accepts "SEATTLE WA —" but phase1.md specifies comma. I didn't catch this in Round 2.

### Novel Insight (Document-Based)

1. **None truly novel** - But the FAQ answer rigor finding was articulated more clearly: specifically noting that a one-word answer like "None." passes validation.

---

## Comparison to Gemini Baseline

| Finding | Gemini | Round 2 (Document) |
|---------|--------|-------------------|
| Mechanism Detection Gap | ✅ | ✅ |
| Quote Count Collision | ✅ | ✅ |
| Internal FAQ Softball Loophole | ✅ | ✅ |
| Metric Spam Gaming | ✅ | ✅ |
| About Section Hack | ✅ | ❌ Not found |
| Pseudo-Logic FAQs | ✅ | ❌ Not found |

Document-based missed 2 Gemini findings: About Section Hack, Pseudo-Logic FAQs.

---

## Observations

### What Worked

- Document prompt forced systematic investigation of each area
- Code citations were accurate
- 100% accuracy (no false positives)

### What Didn't Work

- Missed more findings than Round 1 (5 vs 6)
- Prompt was less comprehensive than sub-agent's internal exploration
- No novel insights beyond Round 1

### Patterns Noticed

- Document-based produced fewer findings than sub-agent dispatch
- The "cold read" didn't seem to provide fresh perspective advantage
- Sub-agent's autonomous exploration found more edge cases

---

## Time Breakdown

- Writing prompt: 3 min
- Reading code systematically: 8 min
- Generating findings: 4 min
- Total: ~15 min

---

## Prompt File

See: `round-02-prompt.md`

