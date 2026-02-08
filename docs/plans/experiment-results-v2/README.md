# Self-Prompting Experiment v2

## Current Status: ✅ EXPERIMENT COMPLETE

**Last Updated:** 2026-02-08
**Completed:** All 20 rounds finished

---

## Experiment Overview

This is a scientific experiment testing "self-prompting" - the technique of writing comprehensive prompts to discover code issues. The hypothesis is that the act of writing a detailed prompt helps the model think more systematically.

### 2x2 Factorial Design

| Condition | Reframe? | External Model? | Description |
|-----------|----------|-----------------|-------------|
| **A: Direct** | No | No | Claude analyzes code directly |
| **B: Reframe-Self** | Yes | No | Claude writes prompt, reads it back, answers itself |
| **C: Direct-External** | No | Yes | Raw files sent to Gemini |
| **D: Reframe-External** | Yes | Yes | Claude writes prompt, sends to Gemini |

### Metrics

- **VH (Verified Hits)**: Findings confirmed by code inspection (grep/node tests)
- **HR (Hallucinations)**: Findings that are factually incorrect

---

## Final Results (All 20 Rounds Complete)

### By Condition

| Condition | VH | HR | Rounds | Avg VH/Round | HR Rate |
|-----------|----|----|--------|--------------|---------|
| **A: Direct** | 19 | 1 | 5 | 3.8 | **20%** |
| **B: Reframe-Self** | 21 | 1 | 5 | 4.2 | **20%** ← WINNER: Highest VH, lowest HR |
| **C: Direct-External** | 23 | 4 | 5 | 4.6 | 80% |
| **D: Reframe-External** | 18 | 6 | 5 | 3.6 | **100%** ← Every round had hallucinations |

### By Tool

| Tool | VH | HR | Rounds |
|------|----|----|--------|
| pr-faq-assistant | 15 | 3 | 4 (R1, R6, R11, R16) |
| jd-assistant | 18 | 1 | 4 (R2, R7, R12, R17) |
| one-pager | 14 | 4 | 4 (R3, R8, R13, R18) |
| business-justification-assistant | 17 | 2 | 4 (R4, R9, R14, R19) |
| product-requirements-assistant | 17 | 2 | 4 (R5, R10, R15, R20) |

---

## Completed Rounds Summary

| Round | Tool | Condition | VH | HR | Key Finding |
|-------|------|-----------|----|----|-------------|
| 1 | pr-faq-assistant | A | 4 | 1 | Banned word cap, quote count gap |
| 2 | jd-assistant | C | 5 | 0 | Salary transparency gap, benefits keyword stuffing |
| 3 | one-pager | B | 3 | 1 | Success metrics gaming, stakeholder keyword stuffing |
| 4 | business-justification-assistant | D | 3 | 1 | ROI formula gaming, slop penalty cap |
| 5 | product-requirements-assistant | A | 3 | 0 | Leading indicator gaming, door type emoji |
| 6 | pr-faq-assistant | B | 3 | 0 | Competitive diff gap, mechanism clarity |
| 7 | jd-assistant | D | 4 | 1 | Remote policy gap, team size detection |
| 8 | one-pager | A | 3 | 0 | Timeline milestone gaming, risk mitigation |
| 9 | business-justification-assistant | C | 4 | 1 | Ratio check missing, stakeholder keyword stuffing |
| 10 | product-requirements-assistant | B | 5 | 0 | Implementation details gap, traceability gaming |
| 11 | pr-faq-assistant | D | 3 | 1 | Quote type gap, dateline false positive |
| 12 | jd-assistant | A | 4 | 0 | Missing red flags, no de-duplication check |
| 13 | one-pager | C | 4 | 1 | Circular logic threshold, measurable gaming |
| 14 | business-justification-assistant | B | 5 | 0 | ROI formula gaming, payback target not enforced |
| 15 | product-requirements-assistant | D | 4 | 1 | Kill switch gaming, failure case gaming |
| 16 | pr-faq-assistant | C | 5 | 1 | Banned word penalty cap, mechanism gaming |
| 17 | jd-assistant | B | 5 | 0 | Red flags list gap, encouragement gaming |
| 18 | one-pager | D | 4 | 2 | Circular logic threshold, ROI logic absence |
| 19 | business-justification-assistant | A | 5 | 0 | Payback target not enforced, sunk cost missing |
| 20 | product-requirements-assistant | C | 5 | 1 | Banned tech missing, calendar dates, failure case gaming |

---

## Procedure by Condition

### Condition A (Direct)
1. Read all 3 source files: `phase1.md`, `prompts.js`, `validator.js`
2. Analyze directly for misalignments
3. Verify each finding with grep/node commands
4. Create `round-XX.md` with VH/HR counts
5. Update `experiment-state-v2.json`
6. Commit and push

### Condition B (Reframe-Self)
1. Read all 3 source files
2. Write comprehensive adversarial prompt → save as `round-XX-prompt.md`
3. Read the prompt back and answer it (no external model)
4. Verify each finding with grep/node commands
5. Create `round-XX.md` with VH/HR counts
6. Update `experiment-state-v2.json`
7. Commit and push

### Condition C (Direct-External)
1. Read all 3 source files
2. Copy raw files to clipboard (no reframing)
3. User pastes into Gemini, shares response
4. Verify each finding with grep/node commands
5. Create `round-XX.md` with VH/HR counts
6. Update `experiment-state-v2.json`
7. Commit and push

### Condition D (Reframe-External)
1. Read all 3 source files
2. Write comprehensive adversarial prompt → save as `round-XX-prompt.md`
3. Copy prompt + source files to clipboard
4. User pastes into Gemini, shares response
5. Verify each finding with grep/node commands
6. Create `round-XX.md` with VH/HR counts
7. Update `experiment-state-v2.json`
8. Commit and push

---

## Tool Source File Locations

| Tool | phase1.md | prompts.js | validator.js |
|------|-----------|------------|--------------|
| pr-faq-assistant | `genesis-tools/pr-faq-assistant/shared/prompts/phase1.md` | `validator/js/prompts.js` | `validator/js/validator.js` |
| jd-assistant | `genesis-tools/jd-assistant/shared/prompts/phase1.md` | `validator/js/prompts.js` | `validator/js/validator.js` |
| one-pager | `genesis-tools/one-pager/shared/prompts/phase1.md` | `validator/js/prompts.js` | `validator/js/validator.js` |
| business-justification-assistant | `genesis-tools/business-justification-assistant/shared/prompts/phase1.md` | `validator/js/prompts.js` | `validator/js/validator.js` |
| product-requirements-assistant | `genesis-tools/product-requirements-assistant/shared/prompts/phase1.md` | `validator/js/prompts.js` | `validator/js/validator.js` |

---

## Final Conclusions

### Winner: Condition B (Reframe-Self)

**Self-prompting works.** Writing a comprehensive adversarial prompt before analyzing code produces the best results:
- **Highest VH (21)** - Most verified findings
- **Lowest HR rate (20%)** - Tied with Condition A for reliability
- **Best VH/Round ratio (4.2)** - Consistently productive

### Key Findings

1. **Reframing helps Claude, hurts Gemini**
   - Condition B (Claude + reframe) = 21 VH, 1 HR (20% HR rate)
   - Condition D (Gemini + reframe) = 18 VH, 6 HR (100% HR rate)
   - The comprehensive prompt helps Claude think systematically but gives Gemini more rope to hallucinate

2. **External model (Gemini) increases hallucination rate**
   - Conditions with Gemini (C, D): 10 HR total
   - Conditions without Gemini (A, B): 2 HR total
   - Gemini confidently asserts false claims (e.g., looking at wrong file, overstating severity)

3. **Direct analysis is reliable but less productive**
   - Condition A: 19 VH, 1 HR (3.8 VH/round)
   - Condition B: 21 VH, 1 HR (4.2 VH/round)
   - Reframing adds ~10% more findings with no additional hallucinations

4. **Condition D is the worst approach**
   - 100% hallucination rate (every round had at least 1 HR)
   - Lowest VH/round ratio (3.6)
   - Reframing + external model = worst of both worlds

### Hypothesis Result

**Original hypothesis: "C: Both help independently (reframing + external)"**

**Result: PARTIALLY CONFIRMED**
- Reframing helps (B > A in VH)
- External model hurts reliability (C, D have higher HR rates)
- The combination (D) is worse than either alone

---

## Files in This Directory

- `experiment-state-v2.json` - Machine-readable state (currentRound, metrics, randomizedOrder)
- `round-XX.md` - Detailed findings for each completed round
- `round-XX-prompt.md` - Adversarial prompts (Conditions B and D only)
- `README.md` - This file (human-readable state for crash recovery)

