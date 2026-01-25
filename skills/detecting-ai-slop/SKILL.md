---
name: detecting-ai-slop
description: Use when analyzing text to calculate a bullshit factor score (0-100) that measures AI slop density - invoke for CVs, marketing copy, drafts, or any text where you need to quantify machine-generated patterns before deciding whether to edit
---

# Detecting AI Slop

## Overview

This skill analyzes text and produces a **bullshit factor score** (0-100) with detailed breakdown by detection dimension. Use it to quantify AI slop before deciding whether to rewrite.

**Core principle:** Detection is read-only. This skill flags patterns but does not rewrite. Use `eliminating-ai-slop` for active rewriting.

## When to Use

- Score a CV or resume for AI-generated content
- Analyze marketing copy for slop density
- Audit your own AI-assisted drafts before editing
- Compare before/after versions of edited text
- Triage documents: which need the most cleanup?

## Output Format

When analyzing text, produce this structured output:

```
Bullshit Factor: 73/100

Breakdown:
├── Lexical:      28/40  (14 patterns in 500 words)
├── Structural:   18/25  (formulaic intro, template sections)
├── Semantic:     12/20  (3 hollow examples, 1 absolute claim)
└── Stylometric:  15/15  (low sentence variance, flat TTR)

Top Offenders (showing 10 of 23):
 1. Line 12: "incredibly powerful" [Generic booster]
 2. Line 34: "leverage synergies" [Buzzword cluster]
 3. Line 56: "it's important to note" [Filler phrase]
 4. Line 78: "In this document, we will explore" [Signposting]
 5. Line 92: "comprehensive solution" [Vague quality]
 ...

Stylometric Measurements:
├── Sentence length SD: 2.3 words (flag: <5 indicates AI)
├── Type-token ratio: 0.38 (flag: <0.4 indicates AI)
└── Hapax rate: 31% (flag: <40% indicates AI)
```

## Scoring Algorithm

| Dimension | Max Points | Calculation |
|-----------|------------|-------------|
| Lexical | 40 | `min(40, pattern_count * 2)` |
| Structural | 25 | `5 * structural_patterns_found` |
| Semantic | 20 | `5 * semantic_patterns_found` |
| Stylometric | 15 | `5 * stylometric_flags` |

**Total:** Sum of dimensions, capped at 100.

### Score Interpretation

| Score | Interpretation |
|-------|----------------|
| 0-20 | Clean: minimal AI patterns detected |
| 21-40 | Light: some patterns, minor editing needed |
| 41-60 | Moderate: noticeable AI fingerprint, edit recommended |
| 61-80 | Heavy: significant slop, substantial rewrite needed |
| 81-100 | Severe: text reads as unedited AI output |

---

## Lexical Patterns (40 points max)

Each pattern found adds 2 points to lexical score.

### Category 1: Generic Boosters

Delete or replace with specific metrics.

| Phrase | Category |
|--------|----------|
| incredibly | generic-booster |
| extremely | generic-booster |
| highly | generic-booster |
| very | generic-booster |
| truly | generic-booster |
| absolutely | generic-booster |
| definitely | generic-booster |
| really | generic-booster |
| quite | generic-booster |
| remarkably | generic-booster |
| exceptionally | generic-booster |
| particularly | generic-booster |
| especially | generic-booster |
| significantly | generic-booster |
| substantially | generic-booster |
| considerably | generic-booster |
| dramatically | generic-booster |
| tremendously | generic-booster |
| immensely | generic-booster |
| profoundly | generic-booster |

### Category 2: Buzzwords

Replace with plain language or specific descriptions.

| Phrase | Category |
|--------|----------|
| robust | buzzword |
| seamless | buzzword |
| comprehensive | buzzword |
| elegant | buzzword |
| powerful | buzzword |
| flexible | buzzword |
| intuitive | buzzword |
| user-friendly | buzzword |
| streamlined | buzzword |
| optimized | buzzword |
| efficient | buzzword |
| scalable | buzzword |
| reliable | buzzword |
| secure | buzzword |
| modern | buzzword |
| innovative | buzzword |
| sophisticated | buzzword |
| advanced | buzzword |
| state-of-the-art | buzzword |
| best-in-class | buzzword |
| world-class | buzzword |
| enterprise-ready | buzzword |
| production-grade | buzzword |
| battle-tested | buzzword |
| industry-leading | buzzword |
| game-changing | buzzword |
| revolutionary | buzzword |
| transformative | buzzword |
| disruptive | buzzword |
| cutting-edge | buzzword |
| next-generation | buzzword |
| bleeding-edge | buzzword |
| groundbreaking | buzzword |
| paradigm-shifting | buzzword |
| synergy | buzzword |
| holistic | buzzword |
| ecosystem | buzzword |
| leverage | buzzword |
| utilize | buzzword |
| facilitate | buzzword |
| enable | buzzword |
| empower | buzzword |
| optimize | buzzword |
| accelerate | buzzword |
| amplify | buzzword |
| unlock | buzzword |
| drive | buzzword |
| spearhead | buzzword |
| champion | buzzword |
| pivot | buzzword |

### Category 3: Filler Phrases

Delete entirely - these add no meaning.

| Phrase | Category |
|--------|----------|
| It's important to note that | filler |
| It's worth mentioning that | filler |
| It should be noted that | filler |
| It goes without saying that | filler |
| Needless to say | filler |
| As you may know | filler |
| As we all know | filler |
| In today's world | filler |
| In today's digital age | filler |
| In today's fast-paced environment | filler |
| In the modern era | filler |
| At the end of the day | filler |
| When all is said and done | filler |
| Having said that | filler |
| That said | filler |
| That being said | filler |
| With that in mind | filler |
| With that being said | filler |
| Let me explain | filler |
| Let me walk you through | filler |
| Let's dive in | filler |
| Let's explore | filler |
| Let's take a look at | filler |
| Let's break this down | filler |
| Here's the thing | filler |
| The thing is | filler |
| The fact of the matter is | filler |
| At this point in time | filler |
| In order to | filler |
| Due to the fact that | filler |
| For the purpose of | filler |
| In the event that | filler |
| In light of | filler |
| With regard to | filler |
| In terms of | filler |
| On a daily basis | filler |
| First and foremost | filler |
| Last but not least | filler |
| Each and every | filler |
| One and only | filler |
| Plain and simple | filler |
| Pure and simple | filler |

### Category 4: Hedge Patterns

Weasel words that avoid commitment.

| Phrase | Category |
|--------|----------|
| of course | hedge |
| naturally | hedge |
| obviously | hedge |
| clearly | hedge |
| certainly | hedge |
| undoubtedly | hedge |
| in many ways | hedge |
| to some extent | hedge |
| in some cases | hedge |
| it depends | hedge |
| it varies | hedge |
| generally speaking | hedge |
| for the most part | hedge |
| more or less | hedge |
| kind of | hedge |
| sort of | hedge |
| somewhat | hedge |
| relatively | hedge |
| arguably | hedge |
| potentially | hedge |
| possibly | hedge |
| might | hedge |
| may or may not | hedge |
| could potentially | hedge |
| tends to | hedge |
| seems to | hedge |
| appears to | hedge |

### Category 5: Sycophantic Phrases

Never compliment the user or express enthusiasm about helping.

| Phrase | Category |
|--------|----------|
| Great question! | sycophancy |
| Excellent question! | sycophancy |
| That's a great point! | sycophancy |
| Good thinking! | sycophancy |
| I love that idea! | sycophancy |
| What a fascinating topic! | sycophancy |
| Happy to help! | sycophancy |
| I'd be happy to help | sycophancy |
| I'm glad you asked | sycophancy |
| Thanks for asking | sycophancy |
| Absolutely! | sycophancy |
| Definitely! | sycophancy |
| Of course! | sycophancy |
| Sure thing! | sycophancy |
| No problem! | sycophancy |
| You're welcome! | sycophancy |
| My pleasure! | sycophancy |
| I appreciate you sharing | sycophancy |
| That's an interesting perspective | sycophancy |
| I understand your concern | sycophancy |

### Category 6: Transitional Filler

Overused transitions that pad word count.

| Phrase | Category |
|--------|----------|
| Furthermore | transition-filler |
| Moreover | transition-filler |
| Additionally | transition-filler |
| In addition | transition-filler |
| Nevertheless | transition-filler |
| Nonetheless | transition-filler |
| On the other hand | transition-filler |
| Conversely | transition-filler |
| In contrast | transition-filler |
| Similarly | transition-filler |
| Likewise | transition-filler |
| Consequently | transition-filler |
| Therefore | transition-filler |
| Thus | transition-filler |
| Hence | transition-filler |
| Accordingly | transition-filler |
| As a result | transition-filler |
| For this reason | transition-filler |
| To that end | transition-filler |
| With this in mind | transition-filler |
| Given the above | transition-filler |
| Based on the above | transition-filler |
| As mentioned earlier | transition-filler |
| As previously stated | transition-filler |
| As noted above | transition-filler |
| Moving forward | transition-filler |
| Going forward | transition-filler |

---

## Structural Patterns (25 points max)

Each structural pattern found adds 5 points.

### Formulaic Introduction

**Pattern:** Text opens by rephrasing the topic → asserting importance → promising overview.

**Example:**
> "In today's fast-paced world, efficiency matters more than ever. In this article, we will explore the key aspects of productivity and provide actionable insights."

**Flags:** +5 points

### Template Sections

**Pattern:** Predictable section progression: Overview → Key Points → Best Practices → Conclusion.

**Example:**
> "First, we'll examine the basics. Then, we'll dive into advanced techniques. Finally, we'll discuss best practices."

**Flags:** +5 points

### Over-Signposting

**Pattern:** Excessive meta-commentary about document structure.

**Examples:**
- "In this section, we will..."
- "As mentioned earlier..."
- "Let's now turn to..."
- "Before we proceed..."

**Flags:** +5 points per instance (max 2 counted)

### Staccato Paragraphs

**Pattern:** Many 1-2 sentence paragraphs creating false sense of clarity.

**Heuristic:** If >50% of paragraphs are 1-2 sentences, flag.

**Flags:** +5 points

### Symmetric Coverage

**Pattern:** Equal weight given to every option without prioritization.

**Example:**
> "Option A has pros and cons. Option B also has pros and cons. Both are valid choices depending on your needs."

**Flags:** +5 points

---

## Semantic Patterns (20 points max)

Each semantic pattern found adds 5 points.

### Hollow Specificity

**Pattern:** Claims specificity without actual details.

**Examples:**
- "Many companies have seen significant improvements" (which companies? what improvements?)
- "One organization reported substantial gains" (which organization? what gains?)
- "Users consistently report positive experiences" (which users? what experiences?)

**Flags:** +5 points per instance (max 2 counted)

### Absent Constraints

**Pattern:** Absolute claims without acknowledging limitations.

**Examples:**
- "This solution works perfectly for all use cases"
- "It never fails under any circumstances"
- "Every user will see immediate results"

**Flags:** +5 points per instance (max 2 counted)

### Balanced to a Fault

**Pattern:** Every pro has matching con of equal weight (reality is asymmetric).

**Example:**
> "While X has advantages, it also has disadvantages. Similarly, Y has both strengths and weaknesses."

**Flags:** +5 points

### Circular Reasoning

**Pattern:** Rephrases thesis without adding new evidence.

**Example:**
> "This approach is effective because it produces good results. The results are good because the approach is effective."

**Flags:** +5 points

---

## Stylometric Patterns (15 points max)

Each stylometric flag adds 5 points.

### Sentence Length Variance

**Heuristic:** Count words in 5-10 consecutive sentences. Calculate standard deviation.

| SD | Interpretation |
|----|----------------|
| < 5 words | Flag: uniform cadence (AI pattern) |
| 5-10 words | Normal variation |
| > 10 words | High variation (human pattern) |

**AI pattern (flag):**
> "The new system provides significant improvements. (7) Users can expect faster response times. (6) This update addresses several key issues. (7)"

**Human pattern (pass):**
> "It works. (2) The new caching layer reduced p99 latency from 340ms to 89ms. (14) Still breaks on edge cases. (5)"

**Flags:** +5 points if SD < 5

### Type-Token Ratio (TTR)

**Heuristic:** In a 100-word sample, count unique words. Divide by 100.

| TTR | Interpretation |
|-----|----------------|
| < 0.40 | Low diversity (AI pattern) |
| 0.40-0.60 | Normal range |
| > 0.60 | High diversity |

**Quick check:** Same adjective 3+ times in 200 words = flag.

**Flags:** +5 points if TTR < 0.40

### Hapax Legomena Rate

**Definition:** Words that appear exactly once in the text.

**Heuristic:** In 500 words, 40-60% of vocabulary should be hapax.

| Hapax % | Interpretation |
|---------|----------------|
| < 35% | Low: repetitive vocabulary (AI pattern) |
| 35-60% | Normal range |
| > 60% | High: varied vocabulary |

**Flags:** +5 points if hapax rate < 35%

---

## Domain-Specific Patterns

Flag these in addition to general patterns when domain is identified.

### Technical Documentation

| Pattern | Example |
|---------|---------|
| Passive function opener | "This function is used to..." |
| Dismissive "simply" | "Simply call the API..." |
| Vague "easy" claims | "Easy to use and configure" |
| Capability laundry list | "Supports X, Y, Z, and more" |
| Empty "powerful" | "A powerful library for..." |
| Vague error handling | "Handle errors appropriately" |

### Marketing/Business

| Pattern | Example |
|---------|---------|
| Unsubstantiated leadership | "Industry-leading solution" |
| Transformation promises | "Transform your workflow" |
| Customer count padding | "Trusted by thousands" |
| Satisfaction claims | "Loved by customers" |
| ROI promises | "Maximize your ROI" |
| Future-proofing claims | "Future-proof your business" |

### Academic/Research

| Pattern | Example |
|---------|---------|
| Vague attribution | "The literature suggests..." |
| Appeal to consensus | "It is well known that..." |
| Scope hedging | "This is beyond the scope..." |
| Future work dumping | "Further research is needed" |
| Significance claims | "This research is significant because..." |
| Passive voice overuse | "It was found that..." |

---

## Detection Heuristics

Quick tests to apply during analysis.

### 1. Specificity Test

Does the text name specific tools, versions, tradeoffs, or constraints?

**Slop:** "Focus on clear communication and alignment with stakeholders."
**Real:** "Use Slack threads for async decisions; Zoom only for contentious items."

### 2. Asymmetry Test

Does the text commit to rankings, preferences, or opinionated tradeoffs?

**Slop:** "Both options have merits and considerations."
**Real:** "Use Postgres unless you're at >10M writes/day."

### 3. Constraint Test

Does the text acknowledge cost, politics, legacy systems, or messy reality?

**Slop:** "Adopt a microservices architecture for scalability."
**Real:** "Microservices add 3x operational overhead. Stay monolithic unless you have dedicated platform team."

### 4. First-Person Test

Can you insert "in my experience" or "on my last project" naturally?

**Slop:** Generic enough to apply anywhere.
**Real:** Grounded in specific context.

### 5. Predictability Test

Read a sentence and try to predict the next word. If you can consistently predict 3+ words in a row, the text has low entropy.

**AI pattern:** "In today's fast-paced [world], it's important to [stay] ahead of the [curve]."
**Human pattern:** "The deploy broke at 3am. Jenkins was down. I SSHed in from my phone."

---

## Example Analysis

**Input text:**
> "In today's rapidly evolving digital landscape, it's crucial for organizations to leverage cutting-edge technologies. By adopting a holistic approach to digital transformation, you can unlock significant value and drive meaningful outcomes. Let's explore the key considerations."

**Analysis:**

```
Bullshit Factor: 82/100

Breakdown:
├── Lexical:      32/40  (16 patterns)
├── Structural:   15/25  (formulaic intro, signposting, template)
├── Semantic:     15/20  (hollow specificity, absent constraints, balanced)
└── Stylometric:  20/15  (capped at 15)

Top Offenders:
 1. "In today's rapidly evolving digital landscape" [Filler phrase]
 2. "it's crucial" [Generic booster]
 3. "leverage" [Buzzword]
 4. "cutting-edge" [Buzzword]
 5. "holistic" [Buzzword]
 6. "digital transformation" [Buzzword cluster]
 7. "unlock" [Buzzword]
 8. "significant" [Generic booster]
 9. "drive" [Buzzword]
 10. "meaningful outcomes" [Vague quality]
 11. "Let's explore" [Filler phrase]

Stylometric Measurements:
├── Sentence length SD: 3.2 words (flag: <5)
├── Type-token ratio: 0.52 (pass)
└── Hapax rate: 48% (pass)

Verdict: Severe slop. Substantial rewrite needed.
```

---

## Dictionary Integration

This skill reads from the shared pattern dictionary if available:

**Location:** `{workspace_root}/.slop-dictionary.json`

**Behavior:**
- If dictionary exists, include custom patterns in detection
- If dictionary has exceptions, skip those patterns
- If dictionary missing, use built-in patterns only

**Note:** This skill does not write to the dictionary. Use `eliminating-ai-slop` to add patterns or exceptions.

---

## Metrics Contribution

After each analysis, this skill contributes to shared metrics:

**Location:** `{workspace_root}/.slop-metrics.json`

**Tracked:**
- Documents analyzed count
- Total patterns found
- Patterns by category
- Average bullshit factor

---

## Related Skills

- **eliminating-ai-slop**: Active rewriting to remove detected patterns
- **reviewing-ai-text**: (Deprecated) Original combined skill

