# Self-Prompting Experiment: Scientific Bake-Off

> **For Claude:** This is a CRASH-RESILIENT experiment plan. If session is lost, read this file + `experiment-state.json` + any `experiment-results/round-NN.md` files to resume.

**Goal:** Scientifically test whether self-prompting (creating comprehensive prompts and feeding them back to myself) produces better results than external LLM review (Gemini) or direct analysis.

**Hypothesis:** The act of creating a context-free prompt forces externalization of reasoning, complete problem structuring, and removal of ambiguity - which may produce insights even when fed back to the same model.

**Created:** 2026-02-08
**Status:** NOT_STARTED

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

