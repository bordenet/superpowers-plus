# Eliminating AI Slop - Examples

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

This file contains extended examples and usage patterns.

---

## Example: Full Interactive Workflow

**User provides:**
> "Our incredibly powerful platform leverages cutting-edge AI to deliver comprehensive solutions. It's important to note that we prioritize user experience above all else."

**Skill response:**
```
Found 5 slop patterns:

1. "incredibly powerful" [Generic booster]
   → Suggest: specify capability, e.g., "processes 1M requests/day"

2. "leverages" [Buzzword]
   → Suggest: use "uses"

3. "cutting-edge AI" [Buzzword cluster]
   → Suggest: name the technology, e.g., "GPT-4o with RAG"

4. "comprehensive solutions" [Buzzword]
   → Suggest: list what's covered

5. "It's important to note that" [Filler phrase]
   → Suggest: delete, start with "We prioritize..."

Options:
- "Rephrase all" → I'll rewrite all 5
- "Keep all" → Leave unchanged
- "List them" → One by one
- "Rephrase 1,3,5" → Specific patterns only
```

**User:** "Rephrase all"

**Skill rewrites:**
> "Our platform processes 1M requests/day using GPT-4o with retrieval-augmented generation. It covers intake, routing, and resolution. We prioritize user experience above all else."

---

## Example: GVR Loop in Action

**User:** "Write a blog post introduction about database indexing"

**GVR Iteration 1 (Generate):**
> "In today's data-driven world, database performance is incredibly important. Let's explore how indexing can significantly improve your query speeds and deliver robust solutions for your applications."

**GVR Iteration 1 (Verify):**
- Patterns found: 5 (In today's, incredibly, Let's explore, significantly, robust)
- Sentence σ: 4.2 (target: >15) ⚠️
- TTR: 0.48 (target: 0.50-0.70) ⚠️

**GVR Iteration 2 (Refine → Verify):**
> "Database indexing cut our query time from 340ms to 12ms. Here's what we learned after indexing 50M rows across three production systems."

- Patterns found: 0 ✓
- Sentence σ: 18.4 ✓
- TTR: 0.62 ✓

**GVR Return:**
> "Database indexing cut our query time from 340ms to 12ms. Here's what we learned after indexing 50M rows across three production systems."
>
> [GVR: 2 iterations | removed 5 patterns | σ: 4.2→18.4 | TTR: 0.48→0.62]

---

## Dictionary Management Examples

### Adding Patterns

```
User: "Add 'synergize' to the slop dictionary"
Skill: Added 'synergize' to Buzzwords category.
       Weight: 1.0 | Count: 1 | Source: user-added
       Rescanning current document... No instances found.

User: "Flag 'game-changing' as slop"
Skill: Added 'game-changing' to Generic Boosters.
       Rescanning... Found 1 instance at line 34.
       Rephrase? [Yes/No]
```

### Adding Exceptions

```
User: "Never flag 'leverage' - I use it intentionally"
Skill: Added 'leverage' to permanent exceptions. Won't flag in future.

User: "Keep 'comprehensive' - it's accurate here"
Skill: Added 'comprehensive' to exceptions (this document only).
```

### Querying Dictionary

```
User: "Show my top slop patterns"
Skill: [displays patterns sorted by count]

User: "Show dictionary stats"
Skill:
  Dictionary Statistics:
  ├── Total patterns: 312
  ├── Built-in: 265
  ├── User-added: 47
  ├── Exceptions: 8 (6 permanent, 2 document)
  └── Last modified: 2026-01-25T10:30:00Z
```

---

## Calibration Mode

Calibrate thresholds using your own human-written samples.

### Invoke Calibration

```
User: "Calibrate slop detection with my writing"
[Paste 3-5 samples of your authentic writing, 300+ words each]
```

### Calibration Output

```
Calibration Complete

Your Writing Profile:
├── Sentence length σ: 12.3 words (default threshold: <15)
├── TTR range: 0.55-0.62 (default threshold: <0.50)
├── Hapax rate: 45% (default threshold: <40%)
└── Paragraph variance: High (characteristic of your style)

Adjusted GVR Thresholds:
├── Sentence σ target: >10 (personalized from your 12.3 baseline)
├── TTR target: >0.52 (personalized from your 0.55 low)
└── Hapax target: >42% (personalized from your 45% baseline)

Calibration saved. GVR loop now uses your personalized thresholds.
```

---

## Cross-Machine Sync

Dictionary can be synchronized across machines using `slop-sync`:

```bash
slop-sync push    # Upload dictionary to GitHub
slop-sync pull    # Download latest dictionary
slop-sync status  # Show sync state
```

See `slop-sync` script in repository root for setup instructions.
