---
name: detecting-ai-slop
source: superpowers-plus
triggers: ["calculate slop score", "check for AI slop", "detect AI writing", "slop density", "is this AI generated", "writing definitions", "tooltip text", "prose for documentation", "writing prose", "documentation text"]
description: Use when analyzing text to calculate a slop score (0-100) that measures AI slop density - invoke for CVs, cover letters, marketing copy, drafts, tooltip definitions, documentation prose, or any text where you need to quantify machine-generated patterns before deciding whether to edit.
---

# Detecting AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-03-12
> **See also:** [reference.md](./reference.md) (pattern dictionary), [examples.md](./examples.md) (usage examples)

## Overview

This skill analyzes text and produces a **slop score** (0-100) with detailed breakdown by detection dimension. Use it to quantify AI slop before deciding whether to rewrite.

**Core principle:** Detection is read-only. This skill flags patterns but does not rewrite. Use `eliminating-ai-slop` for active rewriting.

## When to Use

- Score a CV or resume for AI-generated content
- Analyze cover letters for generic patterns
- Audit marketing copy for slop density
- Review your own AI-assisted drafts before editing
- Compare before/after versions of edited text
- Triage documents: which need the most cleanup?

---

## Content Type Detection

The skill auto-detects content type from context:

| Content Type | Detection Signals |
|--------------|-------------------|
| Document | Default fallback |
| Email | "email", "to:", "subject:" |
| LinkedIn | "linkedin", "post", "connections" |
| CV/Resume | "resume", "cv", "experience" |
| Cover Letter | "cover letter", "dear hiring" |
| README | Filename is "README" |
| PRD | "requirements", "PRD", "product" |

**Override:** "Analyze this as a [type]: [text]"

---

## Output Format

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
 ...

Stylometric Measurements:
├── Sentence length σ: 7.3 words (target: >15.0) ⚠️
├── Type-token ratio: 0.48 (target: 0.50-0.70) ⚠️
└── Hapax rate: 31% (target: >40%) ⚠️

Verdict: Heavy slop. Substantial rewrite needed.
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

| Metric | Flag If | Target |
|--------|---------|--------|
| Sentence length σ | σ < 15.0 | σ > 15.0 |
| Paragraph length SD | SD < 25 | SD > 25 |
| Type-Token Ratio | TTR < 0.50 or TTR > 0.70 | 0.50 ≤ TTR ≤ 0.70 |
| Hapax legomena rate | Below user baseline | At or above baseline |

---

## Structural Patterns (25 points max)

| Pattern | Description | Points |
|---------|-------------|--------|
| Formulaic Introduction | Rephrasing topic → importance → overview | +5 |
| Template Sections | Overview → Key Points → Best Practices → Conclusion | +5 |
| Over-Signposting | "In this section...", "As mentioned earlier..." | +5 |
| Staccato Paragraphs | >50% are 1-2 sentences | +5 |
| Symmetric Coverage | Equal weight to all options without prioritization | +5 |

---

## Semantic Patterns (20 points max)

| Pattern | Description | Points |
|---------|-------------|--------|
| Hollow Specificity | "Many companies have seen improvements" (which?) | +5 |
| Absent Constraints | Absolute claims without limitations | +5 |
| Balanced to a Fault | Every pro has matching con of equal weight | +5 |
| Circular Reasoning | Rephrases thesis without new evidence | +5 |

---

## Lexical Pattern Categories

For the complete pattern dictionary, see [reference.md](./reference.md).

| Category | Examples | Action |
|----------|----------|--------|
| Generic Boosters | incredibly, extremely, very | Delete or replace with metrics |
| Buzzwords | robust, seamless, leverage | Replace with plain language |
| Filler Phrases | "It's important to note that" | Delete entirely |
| Hedge Patterns | of course, arguably, seems to | Commit or remove |
| Sycophancy | "Great question!", "Happy to help!" | Delete |
| Typographic Tells | em-dash (—), smart quotes | Replace with standard punctuation |

---

## Dictionary Integration

This skill reads from `.slop-dictionary.json` if present in workspace root.

- Custom patterns are included in detection
- Exceptions are skipped during detection
- Weight affects scoring: `score = base_score * weight`

**Note:** This skill reads from the dictionary but does not write. Use `eliminating-ai-slop` to add patterns or exceptions.

---

## Related Skills

- **eliminating-ai-slop**: Active rewriting to remove detected patterns
- **professional-language-audit**: Profanity and inappropriate language detection
