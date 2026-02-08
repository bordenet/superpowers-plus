# Skill Comparison: self-prompting vs think-twice

> **TL;DR**: Use **self-prompting** for code analysis and adversarial review. Use **think-twice** for getting unstuck on problems.

## Overview

Both skills use the technique of writing comprehensive prompts before analysis, but they target different use cases and have different methodologies.

| Aspect | self-prompting | think-twice |
|--------|----------------|-------------|
| **Primary Use Case** | Code analysis, adversarial review | Getting unstuck on problems |
| **Trigger** | Complex system review needed | Stuck signals detected |
| **Output Format** | Verified findings (VH/HR counts) | Scored recommendations (0-100) |
| **Sub-agent Use** | Optional (can answer yourself) | Required (consultation dispatch) |
| **External Model** | AVOID (100% HR rate in experiment) | Supported (fallback to Perplexity/Gemini) |
| **Validation** | 20-round factorial experiment | Not yet scientifically validated |

---

## When to Use Each

### Use self-prompting when:

1. **Reviewing multi-component systems** for alignment or consistency
2. **Looking for gaming vulnerabilities** in validation logic
3. **Verifying external model claims** (Gemini said X, is it true?)
4. **Pre-commit review** of complex changes
5. **Adversarial analysis** of prompt/validator chains

**Expected outcome**: List of verified findings with evidence

### Use think-twice when:

1. **Same fix pattern tried 3+ times** without success
2. **Circular reasoning** detected (referencing own failed output)
3. **User says "I'm stuck"** or similar trigger phrase
4. **Uncertainty hedging** appears ("I'm not sure why...")
5. **80%+ context window consumed** without resolution

**Expected outcome**: Scored recommendation with next step

---

## Methodology Differences

### self-prompting Protocol

```
1. Write comprehensive adversarial prompt (context-free)
2. Read it back cold, answer yourself
3. Verify EVERY finding with grep/node tests
4. Count: VH (verified hits) + HR (hallucinations)
5. Document results with evidence
```

**Key insight**: Do NOT send reframed prompts to external models (100% HR rate).

### think-twice Protocol

```
1. Detect stuck signals (auto or manual trigger)
2. Generate consultation prompt (<2000 tokens)
3. Dispatch to sub-agent (or paste to Perplexity)
4. Score response on 4 dimensions (relevance, novelty, specificity, feasibility)
5. If score <50, retry with refined prompt (max 1 retry)
6. Synthesize recommendation and next step
```

**Key insight**: Pre-dispatch review gate prevents bad prompts.

---

## Prompt Templates

### self-prompting: Adversarial Review

```markdown
You are an expert [ROLE] performing [TASK TYPE] on [SYSTEM].

## CONTEXT
[System description with component relationships]

## THE PROBLEM
[Specific misalignment/issue pattern to find]

## YOUR TASK
[Checklist of things to verify]

## VERIFICATION REQUIREMENTS
For EACH finding:
1. State the claim
2. Cite file:line
3. Show grep/test evidence
4. Mark: VERIFIED | FALSE POSITIVE

## FILES TO EXAMINE
[Full paths to source files]
```

### think-twice: Consultation Brief

```markdown
## Problem Statement
[2-4 sentences, plain English]

## Technical Context
[Language, framework, versions, environment]

## What Has Been Tried
1. [Approach 1] → [Outcome]
2. [Approach 2] → [Outcome]

## Current Error/Blocker
[Exact error messages, not paraphrased]

## Relevant Code
[Minimal reproducible snippet, NOT entire files]

## Constraints
[Non-obvious limitations]

## What I Need
[Specific ask]
```

---

## Scoring and Metrics

### self-prompting Metrics

| Metric | Definition |
|--------|------------|
| **VH (Verified Hits)** | Findings confirmed by grep/test |
| **HR (Hallucinations)** | Findings that are factually incorrect |
| **HR Rate** | HR / (VH + HR) - target <25% |

### think-twice Scoring

| Dimension | Weight | What It Measures |
|-----------|--------|------------------|
| Relevance | 30% | Does it address the actual problem? |
| Novelty | 25% | Does it suggest something we haven't tried? |
| Specificity | 25% | Is it actionable (file, line, command)? |
| Feasibility | 20% | Can we implement it given constraints? |

---

## Experiment Data (self-prompting only)

20-round factorial experiment with 5 tools × 4 conditions:

| Condition | VH | HR | HR Rate | Verdict |
|-----------|----|----|---------|---------|
| A: Direct | 19 | 1 | 20% | Good baseline |
| **B: Reframe-Self** | 21 | 1 | **20%** | **WINNER** |
| C: Direct-External | 23 | 4 | 80% | External model helps VH, hurts HR |
| D: Reframe-External | 18 | 6 | **100%** | **WORST** - avoid |

**Conclusion**: Reframing helps Claude (+10% VH), but hurts external models (+400% HR).

---

## Integration Paths

### Can I use both together?

Yes, but sequentially:

1. **Start with think-twice** if you're stuck on HOW to approach the problem
2. **Switch to self-prompting** once you know WHAT to analyze

### When to switch skills

| Signal | Switch To |
|--------|-----------|
| "I don't know where to start" | think-twice |
| "I know the system, need to find bugs" | self-prompting |
| "My analysis found nothing" | think-twice |
| "External model claims X" | self-prompting (verify) |

---

## Future Work

- [ ] Validate think-twice with similar factorial experiment
- [ ] Compare effectiveness across different problem types
- [ ] Measure time-to-resolution for each skill
- [ ] Document failure modes and recovery strategies

