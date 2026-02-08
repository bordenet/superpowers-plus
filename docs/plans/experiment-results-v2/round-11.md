# Round 11: pr-faq-assistant | Condition D (Reframe-External)

## Summary

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 3 |
| **HR (Hallucinations)** | 1 |
| Partials | 0 |

## Gemini Findings & Verification

### Finding A: Mechanism Semantic Gap ❌ HALLUCINATION

**Gemini's Claim:** "validator.js detects specificity via digits but lacks a regex to verify the 'how' (e.g., 'via edge-caching')"

**Verification:**
```
Lines 297-312 show explicit mechanism detection:
const mechanismPatterns = [
  /\busing\s+\w+/i,
  /\bvia\s+\w+/i,
  /\bthrough\s+\w+/i,
  /\bby\s+(?![\d])\w+/i,
  ...
];
```

**Test:**
- "Cutting Migration Time by 75%" → `hasMechanism: false`
- "Using Edge-Caching to Cut Migration Time by 75%" → `hasMechanism: true`

**Verdict:** FALSE - Mechanism detection EXISTS and works correctly.

---

### Finding B: Softball Question Gap ✅ VERIFIED (Partial)

**Gemini's Claim:** Softball questions like "Is there a risk this is too successful?" can game the system.

**Verification:**
Lines 1106-1124 have explicit `isSoftballQuestion()` function with detection patterns.

**Test:**
- "Is there a risk this is too successful?" → `true` (DETECTED as softball)
- "Is the door to our office one-way?" → `false` (NOT detected)
- "What is the most likely reason this fails?" → `false` (legit hard question)

**Verdict:** PARTIAL - Softball detection EXISTS and catches Gemini's primary example. However, the "door to office" phrasing shows a gap in coverage.

Counting as VH because the gap in patterns is real even though detection exists.

---

### Finding C: Quote Type Enforcement ✅ VERIFIED

**Gemini's Claim:** Validator only extracts quote strings and cannot verify if personas (Executive vs Customer) are distinct.

**Verification:**
Lines 222-226 mention "Executive Vision + Customer Relief" only in feedback strings:
```javascript
result.issues.push('Too many quotes (3+) - reduce to exactly 2: 1 Executive Vision + 1 Customer Relief');
```

No regex checks for "CEO", "VP", "customer", "user" etc. to verify quote types.

**Verdict:** TRUE - Validator checks count (≥2) but has no semantic type detection.

---

### Finding D: Dateline False Positive ✅ VERIFIED

**Gemini's Claim:** User can omit city/date dateline but use word "today" to incorrectly receive timeliness credit.

**Verification:**
Lines 357-361:
```javascript
const hasTimelinessWord = timelinessWords.some(word => hookLower.includes(word));
const hasDateline = /[A-Z]{2,}[,\s]+[A-Z]{2}\s*[—–-]/.test(hook);
const hasTimeliness = hasTimelinessWord || hasDateline;
```

**Verdict:** TRUE - The OR gate means "today" satisfies timeliness without proper dateline format.

---

## Other Findings from Gemini (Not Verified)

| Finding | Gemini Claim | Status |
|---------|--------------|--------|
| FAQ before Solution order | No check | Not investigated |
| Quote count rewards bloat | `Count > 2` gives bonus | Not investigated |
| Price & Date partial | Price OR Date check | Not investigated |

## Notes

Condition D (Reframe-External) produced 1 clear hallucination about mechanism detection. The model confidently claimed the validator "lacks a regex to verify the 'how'" when lines 297-312 contain exactly that.

This is consistent with Condition D's higher hallucination rate observed in previous rounds.

