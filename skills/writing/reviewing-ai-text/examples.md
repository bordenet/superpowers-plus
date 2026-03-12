# Reviewing AI Text - Examples

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Stylometric analysis and review output examples.

---

## Stylometric Detection Techniques

### 1. Sentence Length Variance Test

Count words in 5-10 consecutive sentences. Calculate the range (max - min).

| Pattern | Range | Verdict |
|---------|-------|---------|
| AI-typical | 3-5 words | Flag: uniform cadence |
| Human-typical | 10-20 words | Pass: natural variation |

**AI pattern (flag):**
> The new system provides significant improvements. (7) Users can expect faster response times. (6) This update addresses several key issues. (7) The team worked hard on optimization. (7)

Range: 7-5 = 2. Flag as uniform.

**Human pattern (pass):**
> It works. (2) The new caching layer reduced p99 latency from 340ms to 89ms, which finally got the SRE team off our backs. (21) Still breaks on edge cases. (5)

Range: 21-2 = 19. Natural variation.

### 2. Type-Token Ratio (Vocabulary Diversity)

In a 100-word sample, count unique words. Divide by 100.

| TTR | Interpretation |
|-----|----------------|
| < 0.50 | Low diversity, repetitive (AI pattern) |
| 0.50-0.65 | Normal range |
| > 0.65 | High diversity (human or edited) |

**AI pattern:** "The system is robust. The architecture is robust. This provides a robust foundation."

**Human pattern:** Uses synonyms, or specific descriptions instead of repeated adjectives.

### 3. Hapax Legomena Check

Words that appear exactly once. In 500 words, 40-60% should be hapax.

| Hapax % | Interpretation |
|---------|----------------|
| < 35% | Low: repetitive vocabulary (AI pattern) |
| 35-60% | Normal range |
| > 60% | High: varied vocabulary |

**Quick check:** Scan for repeated filler words: "various", "specific", "significant". If 3+ times, flag.

### 4. Predictability Test

Read a sentence and try to predict the next word. If you can consistently predict 3+ words in a row, the text has low entropy.

**AI pattern (predictable):**
> "In today's fast-paced [world], it's important to [stay] ahead of the [curve]."

**Human pattern (less predictable):**
> "The deploy broke at 3am. Jenkins was down. I SSHed in from my phone."

### 5. N-gram Repetition Check

Look for repeated 3-4 word phrases within the same document.

**AI pattern:**
- "it's important to note" (appears 3x)
- "in order to" (appears 4x)

**Human pattern:** Rarely repeats exact multi-word phrases unless intentional.

---

## Tone Drift Detection

Watch for unexplained shifts:
- Casual → formal within paragraphs (confused persona)
- Technical → marketing speak (selling, not explaining)
- Empathy boilerplate: "I understand how challenging..." repeated
- Excessive cheerfulness: "I'm happy to help!" in grim contexts

---

## Argument Structure Problems

- **Enumerations that don't interact:** Bullets could be reordered freely—no cumulative case
- **Circular sections:** Rephrases thesis without new evidence
- **Balanced to a fault:** Every pro has matching con of equal weight
- **Absent negative knowledge:** Never says "I don't know" or "this is speculative"

---

## Chat-Specific Red Flags

- Direct prompt restatement: "You're asking how to X, so let's break it down"
- Meta-commentary: "Here's a breakdown:" / "Let's explore pros and cons"
- Educational scaffolding for experts: Beginner definitions when audience is advanced
- Consistently neutral persona: No stakes, preferences, or history

---

## Structured Review Output Format

```json
{
  "slop_signals": {
    "lexical": {
      "generic_boosters": ["incredibly", "robust"],
      "buzzword_density": "high",
      "sycophantic_phrases": ["Great question!"]
    },
    "rhythm": {
      "sentence_length_variance": "low (range: 3)",
      "staccato_paragraphs": true
    },
    "structure": {
      "formulaic_intro": true,
      "template_sections": true
    },
    "stylometric": {
      "type_token_ratio": 0.42,
      "repeated_adjectives": ["robust", "significant"],
      "proper_nouns_present": false
    }
  },
  "severity": "high",
  "priority_fixes": [
    "Kill all generic boosters",
    "Add specific tool names and versions",
    "Commit to recommendations",
    "Vary sentence length (target: 10+ range)"
  ]
}
```

---

## Self-Check Before Publishing

- [ ] No words from pattern categories remain (or justified)
- [ ] At least one specific tool/artifact/number mentioned
- [ ] Asymmetric recommendations (not "both have pros and cons")
- [ ] Varied sentence length (range > 10 words)
- [ ] No meta-commentary ("let me explain", "in this section")
- [ ] Constraints and tradeoffs acknowledged
- [ ] No repeated adjectives (same word 3+ times)
- [ ] Proper nouns present (names, products, versions)
- [ ] Would a subject-matter expert cringe? If unsure, more specific.
