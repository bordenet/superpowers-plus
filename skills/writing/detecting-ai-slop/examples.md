# Detecting AI Slop - Examples

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

This file contains extended examples and usage patterns for slop detection.

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

---

## Cross-Machine Sync

Dictionary and metrics can be synchronized across machines using `slop-sync`:

```bash
slop-sync push    # Upload dictionary to GitHub
slop-sync pull    # Download latest dictionary
slop-sync status  # Show sync state
```

See `slop-sync` script in repository root for setup instructions.
