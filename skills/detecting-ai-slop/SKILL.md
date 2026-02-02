---
name: detecting-ai-slop
description: Use when analyzing text to calculate a slop score score (0-100) that measures AI slop density - invoke for CVs, cover letters, marketing copy, drafts, or any text where you need to quantify machine-generated patterns before deciding whether to edit
---

# Detecting AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-25

## Overview

This skill analyzes text and produces a **slop score score** (0-100) with detailed breakdown by detection dimension. Use it to quantify AI slop before deciding whether to rewrite.

**Core principle:** Detection is read-only. This skill flags patterns but does not rewrite. Use `eliminating-ai-slop` for active rewriting.

## When to Use

- Score a CV or resume for AI-generated content
- Analyze cover letters for generic patterns
- Audit marketing copy for slop density
- Review your own AI-assisted drafts before editing
- Compare before/after versions of edited text
- Triage documents: which need the most cleanup?
- Assess candidate materials for AI-generated red flags

---

## Content Type Detection

The skill auto-detects content type from context and applies type-specific patterns:

| Content Type | Detection Signals | Type-Specific Patterns |
|--------------|-------------------|------------------------|
| Document | Default fallback | Universal patterns only |
| Email | "email", "to:", "subject:" | Corporate filler, buried leads |
| LinkedIn | "linkedin", "post", "connections" | Engagement bait, humble brags |
| SMS | "text", "sms", short length | Formality mismatch |
| Teams/Slack | "teams", "slack", "channel" | Email-in-chat patterns |
| CLAUDE.md | Filename contains "CLAUDE" | Vague instructions |
| README | Filename is "README" | Marketing language, missing quickstart |
| PRD | "requirements", "PRD", "product" | Vague requirements |
| Design Doc | "design", "architecture" | Decision avoidance |
| Test Plan | "test plan", "test cases" | Vague test cases |
| CV/Resume | "resume", "cv", "experience" | Responsibilities vs achievements |
| Cover Letter | "cover letter", "dear hiring" | Generic openings |

**Override:** "Analyze this as a [type]: [text]"

---

## Output Format

When analyzing text, produce this structured output:

```
Slop Score: 73/100

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
├── Sentence length σ: 7.3 words (target: >15.0) ⚠️
├── Paragraph length SD: 18 words (target: >25) ⚠️
├── Type-token ratio: 0.48 (target: 0.50-0.70) ⚠️
└── Hapax rate: 31% (target: >40% or user baseline) ⚠️

Content Type: CV/Resume
Type-Specific Flags:
├── "Responsible for" appears 5 times [Duties, not achievements]
├── No quantified metrics in experience section
└── Generic skills list without context
```

---

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

## Stylometric Thresholds

Based on StyloAI (Opara, 2024) and Desaire et al. (2023) research.

| Metric | Formula | Flag If | Target |
|--------|---------|---------|--------|
| Sentence length σ | Standard deviation of words/sentence | σ < 15.0 | σ > 15.0 |
| Paragraph length SD | Standard deviation of words/paragraph | SD < 25 | SD > 25 |
| Type-Token Ratio (TTR) | Unique words / Total words (per 100-word window) | TTR < 0.50 or TTR > 0.70 | 0.50 ≤ TTR ≤ 0.70 |
| Hapax legomena rate | Words appearing once / Total unique words | Below user baseline | At or above baseline |

### Stylometric Calculation Methods

**Sentence length σ:**
1. Split text into sentences (period, question mark, exclamation)
2. Count words in each sentence
3. Calculate standard deviation: `σ = sqrt(Σ(x - μ)² / n)`

**Paragraph length SD:**
1. Split text into paragraphs (double newline)
2. Count words in each paragraph
3. Calculate standard deviation

**Type-Token Ratio (TTR):**
1. Normalize text (lowercase, remove punctuation)
2. For each 100-word window:
   - Count unique tokens
   - Divide by 100
3. Average across windows

**Hapax legomena rate:**
1. Build word frequency map
2. Count words appearing exactly once
3. Divide by total unique words

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
| delve | generic-booster |
| tapestry | generic-booster |
| multifaceted | generic-booster |
| myriad | generic-booster |
| plethora | generic-booster |

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
| actionable | buzzword |

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

## Content-Type-Specific Patterns

### CV/Resume Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "Responsible for" | duties-not-achievements | High |
| "Assisted with" | passive-contribution | Medium |
| "Helped to" | passive-contribution | Medium |
| "Worked on" | vague-contribution | Medium |
| "Involved in" | vague-contribution | Medium |
| "Participated in" | vague-contribution | Medium |
| "Passionate about" | empty-enthusiasm | High |
| "Team player" | generic-trait | Medium |
| "Detail-oriented" | generic-trait | Medium |
| "Self-motivated" | generic-trait | Medium |
| "Strong communication skills" | generic-trait | Medium |
| "Problem solver" | generic-trait | Medium |
| "Results-driven" | generic-trait | Medium |
| "Dynamic" | buzzword | Medium |
| "Synergized" | buzzword | High |
| "Spearheaded" (without metrics) | inflated-verb | Medium |
| "Orchestrated" (without metrics) | inflated-verb | Medium |
| "Architected" (without metrics) | inflated-verb | Medium |
| Skills list >15 items | skills-inflation | High |
| No metrics in experience | missing-quantification | High |

**CV/Resume Red Flags:**
- Skills list exactly matches job description keywords → GPT optimization
- Every bullet uses "power verbs" with no specifics → Resume generator
- Claims expertise in 20+ technologies → Aspirational, not evidenced
- Generic bullets that apply anywhere → Template-driven

### Cover Letter Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "I am writing to express my interest" | generic-opener | High |
| "I am excited to apply" | generic-opener | Medium |
| "I believe I would be a great fit" | unsupported-claim | Medium |
| "I am confident that" | unsupported-claim | Medium |
| "As you can see from my resume" | redundant-reference | Low |
| "Thank you for your consideration" | generic-closer | Low |
| "I look forward to hearing from you" | generic-closer | Low |
| No company-specific details | missing-research | High |
| Repeats resume bullet points | cv-duplication | Medium |
| "Intersection of X and Y" | chatgpt-cliche | High |
| "Needle in a haystack" | chatgpt-cliche | High |
| "Aligns with my values" | vague-alignment | Medium |
| "Make a meaningful impact" | vague-impact | Medium |
| "Thrilled by the opportunity" | performative-enthusiasm | High |

### Email Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "Hope this email finds you well" | corporate-opener | Medium |
| "Per my last email" | passive-aggressive | Medium |
| "Just wanted to follow up" | hedge-opener | Low |
| "Please don't hesitate to reach out" | filler-closer | Low |
| "Let me know if you have any questions" | filler-closer | Low |
| "Best regards" after short email | formality-mismatch | Low |
| Ask buried in paragraph 3+ | buried-lead | High |
| 5+ paragraphs for simple ask | overcommunication | Medium |

### LinkedIn Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "I'm humbled to announce" | humble-brag | High |
| "Excited to share" | engagement-bait | Medium |
| "Thrilled to announce" | engagement-bait | Medium |
| "Grateful for this opportunity" | performative-gratitude | Medium |
| "Who else agrees?" | engagement-bait | High |
| "Drop a 🙋 if you..." | engagement-bait | High |
| "Comment below" | engagement-bait | Medium |
| Line breaks after every sentence | listicle-abuse | Medium |
| "Agree?" | engagement-bait | High |
| "Thoughts?" at end | engagement-bait | Medium |

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

## Dictionary Integration

This skill reads from the shared pattern dictionary if available.

### Dictionary Location

**Primary:** `{workspace_root}/.slop-dictionary.json`
**Fallback:** Built-in patterns only

### Dictionary Schema (v2)

```json
{
  "version": "2.0",
  "last_modified": "2026-01-25T10:30:00Z",
  "patterns": {
    "leverage": {
      "pattern": "leverage",
      "category": "buzzword",
      "weight": 1.0,
      "count": 47,
      "timestamp": "2026-01-25T10:30:00Z",
      "source": "built-in",
      "exception": false
    },
    "synergize": {
      "pattern": "synergize",
      "category": "buzzword",
      "weight": 1.5,
      "count": 12,
      "timestamp": "2026-01-24T14:22:00Z",
      "source": "user-added",
      "exception": false
    }
  },
  "exceptions": {
    "robust": {
      "pattern": "robust",
      "scope": "permanent",
      "added": "2026-01-23T09:15:00Z",
      "reason": "Technical term in my domain"
    }
  },
  "calibration": {
    "samples_provided": 3,
    "baseline_ttr": 0.58,
    "baseline_hapax": 0.45,
    "baseline_sentence_sd": 12.3,
    "calibrated_at": "2026-01-20T16:00:00Z"
  }
}
```

### Dictionary Fields

| Field | Type | Description |
|-------|------|-------------|
| pattern | string | The slop phrase or pattern |
| category | string | lexical, structural, semantic, stylometric |
| weight | float | Detection priority (default 1.0, range 0.1-2.0) |
| count | integer | Times detected and flagged |
| timestamp | ISO 8601 | Last time pattern was detected |
| source | string | "built-in" or "user-added" |
| exception | boolean | If true, skip during detection |

### Behavior

- If dictionary exists, include custom patterns in detection
- If dictionary has exceptions, skip those patterns
- Weight affects scoring: `score = base_score * weight`
- Higher count patterns are reported first in "Top Offenders"

**Note:** This skill reads from the dictionary but does not write. Use `eliminating-ai-slop` to add patterns or exceptions.

---

## Calibration Mode

Calibrate detection thresholds using your own human-written samples.

### Invoke Calibration

```
User: "Calibrate slop detection with my writing"
[Paste 3-5 samples of your authentic writing, 300+ words each]
```

### Calibration Process

1. Analyze each sample for stylometric measurements
2. Calculate your personal baselines:
   - Sentence length σ (your natural variance)
   - TTR range (your vocabulary diversity)
   - Hapax rate (your unique word frequency)
3. Store baselines in dictionary calibration section
4. Adjust future thresholds to your personal baseline

### Calibration Output

```
Calibration Complete

Your Writing Profile:
├── Sentence length σ: 12.3 words (AI baseline: <15)
├── TTR range: 0.55-0.62 (AI baseline: <0.50)
├── Hapax rate: 45% (AI baseline: <40%)
└── Paragraph variance: High (characteristic of your style)

Adjusted Thresholds:
├── Sentence σ flag: <10 (personalized from your 12.3 baseline)
├── TTR flag: <0.52 (personalized from your 0.55 low)
└── Hapax flag: <42% (personalized from your 45% baseline)

Calibration saved to dictionary. Future analysis uses your thresholds.
```

---

## Metrics Commands

### Show Detection Stats

```
User: "Show slop detection stats"
```

**Output:**

```
Slop Detection Metrics

Session Stats:
├── Documents analyzed: 12
├── Total patterns found: 156
├── Average slop score: 43/100
└── Patterns by category:
    ├── Lexical: 89 (57%)
    ├── Structural: 34 (22%)
    ├── Semantic: 21 (13%)
    └── Stylometric: 12 (8%)

All-Time Stats (from .slop-metrics.json):
├── Documents analyzed: 347
├── Total patterns found: 4,231
├── Dictionary size: 312 patterns
├── User-added patterns: 47
└── Exceptions: 8

Top 5 Patterns (by frequency):
 1. "leverage" - 47 times
 2. "comprehensive" - 39 times
 3. "it's important to note" - 31 times
 4. "robust" - 28 times
 5. "incredibly" - 24 times
```

### Export Metrics

```
User: "Export slop metrics"
```

Exports `.slop-metrics.json` in machine-readable format for analysis.

---

## Metrics Location

**File:** `{workspace_root}/.slop-metrics.json`

**Schema:**

```json
{
  "version": "2.0",
  "last_updated": "2026-01-25T10:30:00Z",
  "totals": {
    "documents_analyzed": 347,
    "patterns_found": 4231,
    "patterns_fixed": 3892,
    "average_slop_score": 43
  },
  "by_category": {
    "lexical": 2412,
    "structural": 934,
    "semantic": 567,
    "stylometric": 318
  },
  "by_content_type": {
    "document": 120,
    "email": 89,
    "cv_resume": 45,
    "cover_letter": 23,
    "linkedin": 34,
    "readme": 18,
    "prd": 12,
    "design_doc": 6
  },
  "sessions": [
    {
      "date": "2026-01-25",
      "documents": 12,
      "patterns": 156,
      "avg_score": 43
    }
  ]
}
```

---

## Example Analysis

**Input text:**
> "In today's rapidly evolving digital landscape, it's crucial for organizations to leverage cutting-edge technologies. By adopting a holistic approach to digital transformation, you can unlock significant value and drive meaningful outcomes. Let's explore the key considerations."

**Analysis:**

```
Slop Score: 82/100

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
├── Sentence length σ: 3.2 words (target: >15.0) ⚠️
├── Paragraph length SD: N/A (single paragraph)
├── Type-token ratio: 0.52 (target: 0.50-0.70) ✓
└── Hapax rate: 48% (target: >40%) ✓

Verdict: Severe slop. Substantial rewrite needed.
```

---

## Related Skills

- **eliminating-ai-slop**: Active rewriting to remove detected patterns
- **reviewing-ai-text**: (Deprecated) Original combined skill

---

## Cross-Machine Sync

Dictionary and metrics can be synchronized across machines using `slop-sync`:

```bash
slop-sync push    # Upload dictionary to GitHub
slop-sync pull    # Download latest dictionary
slop-sync status  # Show sync state
```

See `slop-sync` script in repository root for setup instructions.
