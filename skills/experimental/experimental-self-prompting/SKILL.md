---
name: experimental-self-prompting
description: "⚠️ EXPERIMENTAL - Write comprehensive context-free prompts before analyzing code. Validated in 20-round experiment but NOT production-ready. Always verify outputs manually."
---

# ⚠️ EXPERIMENTAL: Self-Prompting ⚠️

> **WARNING**: This skill is EXPERIMENTAL. It has been validated in a controlled
> experiment but is NOT production-ready. Expect ~20% false positive rate.
> ALWAYS verify outputs manually before acting on findings.

---

## Experiment Results Summary

**Winner: Condition B (Reframe-Self)** - Write prompt, answer yourself (no external model)

| Condition | VH | HR | Avg VH/Round | HR Rate |
|-----------|----|----|--------------|---------|
| A: Direct | 19 | 1 | 3.8 | 20% |
| **B: Reframe-Self** | 21 | 1 | **4.2** | **20%** ← WINNER |
| C: Direct-External | 23 | 4 | 4.6 | 80% |
| D: Reframe-External | 18 | 6 | 3.6 | **100%** ← WORST |

**Key Insight**: Reframing helps Claude (+10% VH), but HURTS external models (+400% HR).

---

## ⚠️ CRITICAL WARNINGS ⚠️

### 1. DO NOT Use with External Models

**Condition D (reframe + Gemini) had 100% hallucination rate.**

Every single round had at least one false positive. The detailed prompts give
external models more rope to hallucinate confidently.

### 2. Expect ~20% False Positive Rate

Even with Claude answering its own prompts, expect 1 in 5 findings to be wrong.
NEVER trust findings without verification.

### 3. Only Tested on Genesis-Tools

This skill was validated on 5 genesis-tools projects:
- pr-faq-assistant
- jd-assistant
- one-pager
- business-justification-assistant
- product-requirements-assistant

It may not generalize to other codebases.

---

## When to Invoke

| Trigger | Description |
|---------|-------------|
| **Complex system review** | Multi-component systems with alignment concerns |
| **Adversarial analysis** | Looking for gaming vulnerabilities or edge cases |
| **Independent verification** | Verify claims from external sources (Gemini, GPT) |
| **Pre-commit review** | Final check before major commits |

**Explicit invocation required:**
```
Use the experimental-self-prompting skill to analyze [system]
```

---

## The Protocol (Condition B)

### Step 1: Write Comprehensive Prompt

Create a context-free prompt that any engineer could pick up cold:

```markdown
You are an expert [ROLE] performing [TASK TYPE] on [SYSTEM].

## CONTEXT
[Explain the system, its components, and their relationships]

## THE PROBLEM
[What misalignment/issue pattern you're looking for]

## YOUR TASK
[Specific things to check]

## VERIFICATION REQUIREMENTS
For EACH finding:
1. State the claim
2. Cite exact file and line number
3. Show evidence (grep/code)
4. Categorize: VERIFIED | FALSE POSITIVE | NEEDS INVESTIGATION

## FILES TO EXAMINE
[List specific files with full paths]

Focus on ACTIONABLE findings with EVIDENCE. No speculation.
```

### Step 2: Read It Back Cold

Treat the prompt as if you've never seen the code before. Answer systematically.

### Step 3: Verify EVERY Finding

**CRITICAL**: Never trust findings without verification.

For each finding:
1. Run grep/view command to confirm existence
2. Run node test to confirm behavior (if applicable)
3. Mark as VERIFIED (VH) or FALSE POSITIVE (HR)

### Step 4: Document Results

Create summary with:
- VH count (verified hits)
- HR count (hallucinations)
- Key findings with evidence

---

## Known Issues

1. **False positive rate ~20%** - Not yet reduced to target <15%
2. **Limited codebase testing** - Only 5 genesis-tools projects
3. **No automated verification** - Manual grep/test required
4. **Prompt templates not optimized** - May miss issues or over-flag

---

## Graduation Criteria

This skill will be promoted to production when:

- [ ] Tested on 10+ diverse codebases
- [ ] False positive rate consistently <15%
- [ ] Automated verification pipeline integrated
- [ ] User feedback loop established
- [ ] Prompt templates optimized and documented

---

## Reference

- Full experiment: `superpowers-plus/docs/plans/experiment-results-v2/`
- Statistical analysis: `superpowers-plus/docs/plans/experiment-results-v2/STATISTICAL_ANALYSIS.md`
- Skill comparison: `superpowers-plus/docs/SKILL_COMPARISON_self-prompting_vs_think-twice.md`

