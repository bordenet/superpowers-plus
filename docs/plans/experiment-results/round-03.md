# Round 03 Results: pr-faq-assistant - Condition D (Hybrid)

**Started:** 2026-02-08T10:40:00Z
**Ended:** 2026-02-08T10:55:00Z
**Duration:** ~15 minutes
**Status:** COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Findings | 5 |
| True Positives | 4 |
| False Positives | 0 |
| Gemini Corrections | 2 |
| Novel Insights | 2 |
| Accuracy Rate | 100% |

---

## Hybrid Approach

For Round 3, I:
1. Reviewed Gemini's findings that Rounds 1 & 2 missed
2. Verified them against actual code
3. Explored adjacent code areas for NEW vulnerabilities

---

## Gemini Finding Verification

### Gemini: "About Section Hack" - VERIFIED FALSE POSITIVE

**Gemini's Claim:** Users can score "WHO" points by having "About [Company]" boilerplate.

**Investigation:** `analyzeFiveWs()` at lines 506-522 only looks at "first 2-3 paragraphs":
```javascript
for (let i = 0; i < Math.min(3, paragraphs.length); i++) {
  leadContent += paragraphs[i] + ' ';
}
```

**Result:** ❌ GEMINI WAS WRONG - About section at END doesn't affect WHO scoring.

---

### Gemini: "Pseudo-Logic FAQs" - VERIFIED FIXED

**Gemini's Claim:** "one-way door to success" satisfies `/door/i` regex.

**Investigation:** At line 1120, softball detection catches this FIRST:
```javascript
/\b(one.?way|two.?way)\s+door\s+to\s+(success|growth|opportunity)/i
```

And at line 1150-1152, softballs are skipped:
```javascript
if (isSoftballQuestion(text)) {
  result.softballCount++;
  continue;  // Skip counting as legitimate hard question
}
```

**Result:** ❌ GEMINI WAS WRONG (or code was fixed since) - Pseudo-logic is caught.

---

## Novel Findings (Not in Rounds 1, 2, or Gemini)

### NOVEL Finding 1: External FAQ Content Validation Missing

**Claim:** phase1.md specifies External FAQ requirements but validator only checks count.

**Evidence - phase1.md lines 115-119:**
```markdown
**External FAQ (10 pts)**:
- 5-7 customer-facing questions present: 3 pts
- Addresses pricing and availability: 2 pts
- Addresses compatibility/migration: 2 pts
- Includes "How is this different from [Alternative]?": 3 pts
```

**Evidence - validator.js lines 1196-1208:**
```javascript
if (externalQuestions.length >= 5) {
  result.score += 10;  // Full points for COUNT only!
}
```

**Problem:** No validation that questions address pricing, availability, compatibility, or differentiation. User gets 10 pts for 5 garbage questions.

**Verification:** TRUE POSITIVE

**Impact:** 10 pts exploitable

---

### NOVEL Finding 2: Internal FAQ Question Count vs Content Mismatch

**Claim:** phase1.md specifies content requirements but validator only checks count + hard keywords.

**Evidence - phase1.md lines 121-125:**
```markdown
**Internal FAQ Presence (10 pts)**:
- 5-7 stakeholder questions present: 3 pts
- Addresses business model/unit economics: 3 pts
- Addresses technical dependencies: 2 pts
- Addresses regulatory/compliance: 2 pts
```

**Evidence - validator.js lines 1210-1225:**
Only checks count and Risk/Reversibility/OpportunityCost keywords. No validation for:
- Business model/unit economics
- Technical dependencies
- Regulatory/compliance

**Verification:** TRUE POSITIVE

**Impact:** 10 pts exploitable (minus hard question portion)

---

## Previously Found (Confirmed in Hybrid)

1. Quote asymmetry (+1/-2) - TRUE POSITIVE
2. Softball 30-char bypass - TRUE POSITIVE
3. Mechanism no specificity - TRUE POSITIVE (but less severe than claimed)

---

## Comparison to Rounds 1 & 2

| Finding | Round 1 | Round 2 | Round 3 |
|---------|---------|---------|---------|
| Quote asymmetry | ✅ | ✅ | ✅ |
| Softball bypass | ✅ | ✅ | ✅ |
| Mechanism vagueness | ✅ | ✅ | ✅ |
| Fake metrics | ✅ | ✅ | - |
| FAQ answer rigor | ✅ | ✅ | - |
| Dateline format | ✅ | ❌ | - |
| External FAQ content | ❌ | ❌ | ✅ **NOVEL** |
| Internal FAQ content | ❌ | ❌ | ✅ **NOVEL** |
| Gemini correction (About) | - | - | ✅ **NEW** |
| Gemini correction (Door) | - | - | ✅ **NEW** |

---

## Key Insight

**Hybrid approach's unique value:** Cross-referencing Gemini's claims against code found TWO false positives in Gemini's response that neither sub-agent nor document-based approach caught. This reduces noise in final recommendations.

---

## Observations

### What Worked

- Targeted exploration of Gemini's "missed" findings found errors in Gemini
- Code reading with phase1.md comparison found new structural gaps
- Hybrid allowed course-correction mid-review

### What Didn't Work

- Fewer total findings than Round 1 (focused depth over breadth)

### Unique Contribution

- **Gemini correction rate: 2 false positives identified**
- This is critical for avoiding wasted remediation effort

