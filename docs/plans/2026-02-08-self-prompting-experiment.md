# Self-Prompting Experiment: Scientific Bake-Off (v2)

> **For Claude:** This is a CRASH-RESILIENT experiment plan. If session is lost, read this file + `experiment-state-v2.json` + any `experiment-results-v2/round-NN.md` files to resume.

**Goal:** Scientifically test whether self-reframing and/or external models improve analysis quality.

**Created:** 2026-02-08
**Completed:** 2026-02-08
**Status:** ✅ COMPLETE (all 20 rounds finished)

---

## 🏆 Final Results Summary

### Winner: Condition B (Reframe-Self)

| Condition | VH | HR | Rounds | Avg VH/Round | HR Rate |
|-----------|----|----|--------|--------------|---------|
| **A: Direct** | 19 | 1 | 5 | 3.8 | 20% |
| **B: Reframe-Self** | 21 | 1 | 5 | **4.2** | **20%** ← WINNER |
| **C: Direct-External** | 23 | 4 | 5 | 4.6 | 80% |
| **D: Reframe-External** | 18 | 6 | 5 | 3.6 | **100%** |

### Key Conclusions

1. **Self-prompting works** - Writing a comprehensive adversarial prompt before analyzing code produces the best results
2. **Reframing helps Claude, hurts Gemini** - B (Claude+reframe): 21 VH, 1 HR vs D (Gemini+reframe): 18 VH, 6 HR
3. **External model increases hallucination rate** - With Gemini (C,D): 10 HR total; Without (A,B): 2 HR total
4. **Condition D is worst approach** - 100% hallucination rate across all 5 rounds

### Skill Created

The winning methodology (Condition B) has been codified as the **`self-prompting`** skill at `~/.codex/skills/self-prompting/SKILL.md`.

See `experiment-results-v2/README.md` for detailed round-by-round results.

---

## V1 Experiment Post-Mortem

The original experiment (v1) had critical methodology errors:

1. **Truncated input to Gemini**: The adversarial review prompts sent to Gemini contained incomplete data (e.g., 17 masculine-coded words instead of 26 in phase1.md)
2. **False attribution**: Claimed "Gemini made factual errors" when Gemini correctly analyzed the truncated input I provided
3. **Inflated metrics**: "17 novel insights" and "69% accuracy" were artifacts of comparing apples to oranges
4. **Invalid conclusions**: "Sub-agents find things external models miss" was not supported by evidence

**V1 results are INVALID and should not be cited.**

---

## V2 Hypothesis

**Core Question:** Can I (Claude) achieve better outcomes by stepping back and reframing problems, or do I need an external model?

**Hypothesis C (selected by user):** Both help independently
- Self-reframing helps (the act of writing a comprehensive prompt improves analysis)
- External models add value on top of that (different model finds different things)

**Sub-hypotheses to test:**
- H1: Writing a comprehensive prompt and reading it back improves MY analysis vs. direct analysis
- H2: An external model (Gemini) finds things I miss, given IDENTICAL input
- H3: The combination (reframe + external) is better than either alone

---

## V2 Experimental Design: 2x2 Factorial

### Independent Variables

| Variable | Levels |
|----------|--------|
| **Reframing** | No (direct) / Yes (write comprehensive prompt first) |
| **External Model** | No (Claude only) / Yes (send to Gemini) |

### Four Conditions

| Condition | Reframe? | External? | Description |
|-----------|----------|-----------|-------------|
| **A: Direct** | ❌ No | ❌ No | I analyze the code directly, no prompt writing |
| **B: Reframe-Self** | ✅ Yes | ❌ No | I write comprehensive prompt, then answer it myself |
| **C: Direct-External** | ❌ No | ✅ Yes | Send raw files to Gemini without reframing |
| **D: Reframe-External** | ✅ Yes | ✅ Yes | I write comprehensive prompt, send to Gemini |

### What Each Condition Tests

- **A vs B**: Does reframing help ME? (H1)
- **A vs C**: Does external model help with raw input? (H2 partial)
- **B vs D**: Does external model add value AFTER reframing? (H2)
- **B vs C**: Is my reframing better than external model with raw input?
- **A vs D**: Is the full combination better than nothing? (H3)
- **B+C vs D**: Is combination better than either alone? (H3)

### Tools (5 total, all 4 conditions each = 20 rounds)

| Tool | Has Existing Gemini? | Notes |
|------|---------------------|-------|
| pr-faq-assistant | ✅ Yes (but truncated input) | Need to re-run with complete input |
| business-justification-assistant | ✅ Yes (but truncated input) | Need to re-run with complete input |
| product-requirements-assistant | ✅ Yes (git history) | Need to verify input completeness |
| jd-assistant | ✅ Yes (but truncated input) | Known issue: 17 vs 26 words |
| one-pager | ❌ No | Fresh - no prior Gemini review |

### Experimental Matrix (20 Rounds)

| Round | Tool | Condition | Reframe? | External? |
|-------|------|-----------|----------|-----------|
| 1 | pr-faq-assistant | A: Direct | ❌ | ❌ |
| 2 | pr-faq-assistant | B: Reframe-Self | ✅ | ❌ |
| 3 | pr-faq-assistant | C: Direct-External | ❌ | ✅ |
| 4 | pr-faq-assistant | D: Reframe-External | ✅ | ✅ |
| 5 | business-justification-assistant | A: Direct | ❌ | ❌ |
| 6 | business-justification-assistant | B: Reframe-Self | ✅ | ❌ |
| 7 | business-justification-assistant | C: Direct-External | ❌ | ✅ |
| 8 | business-justification-assistant | D: Reframe-External | ✅ | ✅ |
| 9 | product-requirements-assistant | A: Direct | ❌ | ❌ |
| 10 | product-requirements-assistant | B: Reframe-Self | ✅ | ❌ |
| 11 | product-requirements-assistant | C: Direct-External | ❌ | ✅ |
| 12 | product-requirements-assistant | D: Reframe-External | ✅ | ✅ |
| 13 | jd-assistant | A: Direct | ❌ | ❌ |
| 14 | jd-assistant | B: Reframe-Self | ✅ | ❌ |
| 15 | jd-assistant | C: Direct-External | ❌ | ✅ |
| 16 | jd-assistant | D: Reframe-External | ✅ | ✅ |
| 17 | one-pager | A: Direct | ❌ | ❌ |
| 18 | one-pager | B: Reframe-Self | ✅ | ❌ |
| 19 | one-pager | C: Direct-External | ❌ | ✅ |
| 20 | one-pager | D: Reframe-External | ✅ | ✅ |

**Total time estimate:** 10 hours (20 rounds × 30 min)

---

## V2 Methodology (from Gemini Review)

### Ground Truth: Blind Jury Approach

Every finding must be:
1. **Functional Bug** - Reproducible with a test case, OR
2. **Format/Style Violation** - Linter-verifiable

**Oracle Judge:** Use a 3rd model (GPT-4o or fresh Gemini session) as blind judge. Give the finding + code, ask "Is this claim true?" without revealing which condition generated it.

### Information Boundary (Fixing v1 Error)

| Condition | Source Files | Instruction |
|-----------|--------------|-------------|
| A: Direct | Full files (byte-for-byte) | None - I analyze directly |
| B: Reframe-Self | Full files (byte-for-byte) | Custom reframed prompt (I answer) |
| C: Direct-External | Full files (byte-for-byte) | Generic: "Analyze for logic errors" |
| D: Reframe-External | Full files (byte-for-byte) | Custom reframed prompt (Gemini answers) |

**Critical:** Raw source files must be IDENTICAL across all conditions. Only the instruction changes.

### Metrics

| Metric | Definition | Measures |
|--------|------------|----------|
| **Verified Hit (VH)** | Finding confirmed by Oracle judge | True Positives |
| **Hallucination Rate (HR)** | Finding that is factually incorrect | Noise/False Positives |
| **Unique Delta (UD)** | VH in D but NOT in B | External model's unique value |
| **Reframing Lift (RL)** | VH(B) minus VH(A) | Power of self-reframing |

### Order Effects: Zero-Context Reset

**Problem:** If I analyze Tool X in Condition A, I'm "primed" for Condition B.

**Solution:**
1. Shuffle tools - don't do all 4 conditions for one tool consecutively
2. Randomize sequence: e.g., Tool1(A), Tool2(C), Tool3(B), Tool1(D)
3. Each condition starts fresh - act as if never seen the code before

### V1 Traps to Avoid

| Trap | How to Avoid |
|------|--------------|
| **Prompt Leakage** | Reframe must be a QUERY, not contain the answer |
| **Temperature Variance** | Set all models to same temperature (0.0 for reproducibility) |
| **Labeling Bias** | Don't tell Gemini "I'm doing an experiment" |
| **Information Asymmetry** | Gemini gets ONLY the prompt, not my thought process |

---

## Experimental Design

### Three Conditions (Independent Variable)

| Condition | Code | Mechanism |
|-----------|------|-----------|
| Sub-agent dispatch | B | Use `sub-agent-explore` to spawn fresh agent with the prompt |
| Document-based | C | Write prompt to file, read it back cold as if receiving from external source |
| Hybrid | D | Manual context-clearing simulation, then formalize patterns |

### Five Case Study Tools

| Tool | Has Gemini Baseline? | Review History |
|------|---------------------|----------------|
| pr-faq-assistant | ✅ Yes (`Gemini_Response.md`) | Complete |
| business-justification-assistant | ✅ Yes (`Gemini_Response.md`) | Complete |
| product-requirements-assistant | ✅ Yes (git history: `47526f3`, `e7ca905`) | Complete |
| jd-assistant | ❌ No | Has `ADVERSARIAL_REVIEW_PROMPT.md` ready |
| one-pager | ❌ No | Needs prompt creation |

### Experimental Matrix (15 Rounds)

| Round | Tool | Condition | Baseline | Time Box |
|-------|------|-----------|----------|----------|
| 1 | pr-faq-assistant | B (Sub-agent) | ✅ Gemini | 30 min |
| 2 | pr-faq-assistant | C (Document) | ✅ Gemini | 30 min |
| 3 | pr-faq-assistant | D (Hybrid) | ✅ Gemini | 30 min |
| 4 | business-justification-assistant | B (Sub-agent) | ✅ Gemini | 30 min |
| 5 | business-justification-assistant | C (Document) | ✅ Gemini | 30 min |
| 6 | business-justification-assistant | D (Hybrid) | ✅ Gemini | 30 min |
| 7 | product-requirements-assistant | B (Sub-agent) | ✅ Git history | 30 min |
| 8 | product-requirements-assistant | C (Document) | ✅ Git history | 30 min |
| 9 | product-requirements-assistant | D (Hybrid) | ✅ Git history | 30 min |
| 10 | jd-assistant | B (Sub-agent) | ❌ Fresh | 30 min |
| 11 | jd-assistant | C (Document) | ❌ Fresh | 30 min |
| 12 | jd-assistant | D (Hybrid) | ❌ Fresh | 30 min |
| 13 | one-pager | B (Sub-agent) | ❌ Fresh | 30 min |
| 14 | one-pager | C (Document) | ❌ Fresh | 30 min |
| 15 | one-pager | D (Hybrid) | ❌ Fresh | 30 min |

**Total time estimate:** 7.5 hours (15 rounds × 30 min)

---

## Metrics (Dependent Variables)

### Per-Round Metrics

| Metric | Definition | How Measured |
|--------|------------|--------------|
| **Novel Insights** | Findings NOT in Gemini response or my direct analysis | Count after verification |
| **True Positives** | Findings verified against actual code | Grep/code inspection |
| **False Positives** | Claims that don't hold up to code verification | Grep/code inspection |
| **Accuracy Rate** | True Positives / (True Positives + False Positives) | Calculated |
| **Time to First Finding** | Minutes from start to first actionable insight | Timestamp |
| **Total Findings** | All findings (TP + FP) in 30 min | Count |

### Aggregate Metrics

| Metric | Definition |
|--------|------------|
| **Condition Winner** | Which condition (B/C/D) has highest accuracy + novel insights |
| **Tool Variance** | Do some tools benefit more from self-prompting? |
| **Efficiency Ratio** | Findings per minute across conditions |

---

## Control Conditions

1. **Gemini Baseline** (for tools 1-9): Compare against existing `Gemini_Response.md` or git history
2. **Direct Analysis Baseline**: What I would find with normal analysis (no self-prompting)

---

## Crash Resilience Protocol

### State Tracking Files

| File | Purpose | Updated When |
|------|---------|--------------|
| `experiment-state.json` | Current round, completion status | After each round |
| `experiment-results/round-NN.md` | Full results for round NN | Immediately after round |
| This file | Master plan | Only if design changes |

### Recovery Procedure

If session crashes:
1. Read this file for context
2. Read `experiment-state.json` for current state
3. Read any completed `round-NN.md` files
4. Resume from `currentRound` in state file

---

## Round Execution Protocol

### Before Each Round

1. Update `experiment-state.json` with `status: "IN_PROGRESS"`
2. Record start timestamp
3. Load the tool's `ADVERSARIAL_REVIEW_PROMPT.md`

### During Round (30 min time-box)

**Condition B (Sub-agent):**
- Create comprehensive prompt from ADVERSARIAL_REVIEW_PROMPT.md + actual code
- Dispatch via `sub-agent-explore`
- Collect findings
- Verify each finding against code

**Condition C (Document-based):**
- Write prompt to `experiment-results/round-NN-prompt.md`
- Clear mental context (acknowledge this is simulated)
- Read prompt back as if cold
- Generate findings
- Verify each finding against code

**Condition D (Hybrid):**
- Manually simulate fresh perspective
- Write findings
- Verify against code
- Identify patterns that could be formalized

### After Each Round

1. Write results to `experiment-results/round-NN.md`
2. Update `experiment-state.json` with `status: "COMPLETE"`, metrics
3. Commit checkpoint (if appropriate)

---

## File Locations

| File | Path |
|------|------|
| Master plan | `superpowers-plus/docs/plans/2026-02-08-self-prompting-experiment.md` |
| State file | `superpowers-plus/docs/plans/experiment-state.json` |
| Results dir | `superpowers-plus/docs/plans/experiment-results/` |
| Round results | `superpowers-plus/docs/plans/experiment-results/round-NN.md` |
| Round prompts | `superpowers-plus/docs/plans/experiment-results/round-NN-prompt.md` |

---

## Post-Experiment Tasks

1. **Aggregate Analysis**: Compare metrics across conditions
2. **Skill Creation**: If successful, create `self-prompting` skill in superpowers-plus
3. **Queued Meta-Task**: Use One-Pager LLM prompts to help refine my own problem-framing prompts

---

## Appendix A: Tool File Locations

| Tool | ADVERSARIAL_REVIEW_PROMPT.md | Gemini_Response.md |
|------|------------------------------|-------------------|
| pr-faq-assistant | `genesis-tools/pr-faq-assistant/ADVERSARIAL_REVIEW_PROMPT.md` | `genesis-tools/pr-faq-assistant/Gemini_Response.md` |
| business-justification-assistant | `genesis-tools/business-justification-assistant/ADVERSARIAL_REVIEW_PROMPT.md` | `genesis-tools/business-justification-assistant/Gemini_Response.md` |
| product-requirements-assistant | `genesis-tools/product-requirements-assistant/ADVERSARIAL_REVIEW_PROMPT.md` | Git history (commits `47526f3`, `e7ca905`, `006c288`) |
| jd-assistant | `genesis-tools/jd-assistant/ADVERSARIAL_REVIEW_PROMPT.md` | None (fresh) |
| one-pager | Needs creation | None (fresh) |

