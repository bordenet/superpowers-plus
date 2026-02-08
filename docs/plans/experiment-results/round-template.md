# Round NN Results: [TOOL] - Condition [B/C/D]

**Started:** YYYY-MM-DDTHH:MM:SSZ
**Ended:** YYYY-MM-DDTHH:MM:SSZ
**Duration:** XX minutes
**Status:** IN_PROGRESS | COMPLETE

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Findings | X |
| True Positives | X |
| False Positives | X |
| Accuracy Rate | X% |
| Novel Insights | X |
| Time to First Finding | X min |

---

## Findings

### Finding 1: [Title]

**Claim:** [What the self-prompt analysis claimed]

**Verification:**
```bash
# Command used to verify
grep -n "pattern" file.js
```

**Result:** ✅ TRUE POSITIVE | ❌ FALSE POSITIVE | ⚠️ PARTIAL

**Evidence:** [Quote from code or explanation]

**Novel?:** Yes/No (was this in Gemini baseline or direct analysis?)

---

### Finding 2: [Title]

[Same structure...]

---

## Comparison to Baseline

### Gemini Baseline (if available)

| Finding | In Gemini? | In Self-Prompt? | Notes |
|---------|------------|-----------------|-------|
| [Finding A] | ✅ | ✅ | Both found it |
| [Finding B] | ✅ | ❌ | Self-prompt missed |
| [Finding C] | ❌ | ✅ | NOVEL - self-prompt only |

### Direct Analysis Baseline

What would I have found with normal analysis (no self-prompting)?
- [List items]

---

## Observations

### What Worked

- [Observation about this condition's effectiveness]

### What Didn't Work

- [Observation about limitations]

### Patterns Noticed

- [Any patterns that could inform skill creation]

---

## Raw Prompt Used

[Link to round-NN-prompt.md or inline if short]

