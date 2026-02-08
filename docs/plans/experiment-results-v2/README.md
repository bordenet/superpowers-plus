# Self-Prompting Experiment v2

## Current Status: Round 19 of 20

**Last Updated:** 2026-02-08
**Next Action:** Execute Round 19 (business-justification-assistant | Condition A: Direct)

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

## Running Totals (After Round 18)

### By Condition

| Condition | VH | HR | Rounds | Avg VH/Round | HR Rate |
|-----------|----|----|--------|--------------|---------|
| **A: Direct** | 14 | 1 | 4 | 3.5 | 25% |
| **B: Reframe-Self** | 21 | 1 | 5 | 4.2 | **20%** ← leads in VH, lowest HR rate |
| **C: Direct-External** | 18 | 3 | 4 | 4.5 | 75% |
| **D: Reframe-External** | 18 | 6 | 5 | 3.6 | **100%** ← still 100% HR rate |

### By Tool

| Tool | VH | HR | Rounds |
|------|----|----|--------|
| pr-faq-assistant | 15 | 3 | 4 (R1, R6, R11, R16) |
| jd-assistant | 18 | 1 | 4 (R2, R7, R12, R17) |
| one-pager | 14 | 4 | 4 (R3, R8, R13, R18) |
| business-justification-assistant | 12 | 2 | 3 (R4, R9, R14) |
| product-requirements-assistant | 12 | 1 | 3 (R5, R10, R15) |

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

---

## Remaining Rounds

| Round | Tool | Condition | Procedure |
|-------|------|-----------|-----------|
| **19** | business-justification-assistant | A: Direct | Claude analyzes directly |
| 20 | product-requirements-assistant | C: Direct-External | Send raw files to Gemini |

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

## Key Observations So Far

1. **Condition D has 100% hallucination rate** - Every round with Gemini + reframing has at least 1 HR (4 rounds, 4 HR)
2. **Condition B (Reframe-Self) shows best balance** - High VH (16) with low HR (1)
3. **Condition A and B tied for lowest HR rate** - Both at 25% (1 HR in 4 rounds each)
4. **Gemini confidently asserts false claims** - e.g., calendar date prohibition is LLM guidance, not scoring requirement

---

## Files in This Directory

- `experiment-state-v2.json` - Machine-readable state (currentRound, metrics, randomizedOrder)
- `round-XX.md` - Detailed findings for each completed round
- `round-XX-prompt.md` - Adversarial prompts (Conditions B and D only)
- `README.md` - This file (human-readable state for crash recovery)

