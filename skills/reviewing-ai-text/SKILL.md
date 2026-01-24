---
name: reviewing-ai-text
description: Use when reviewing or editing AI-generated text to detect and eliminate slop - the telltale patterns of machine-like writing including overused boosters, formulaic structure, excessive hedging, and hollow specificity
---

# Reviewing AI Text

## Overview

AI slop is the signature of lazy machine generation: formulaic structure, hollow abstraction, and sycophantic tone that a careful human expert would never write.

**Core principle:** Real expertise is specific, opinionated, and unafraid of asymmetry.

## When to Use

- Before publishing AI-assisted documentation
- When editing AI-generated content for human consumption
- When reviewing text that "feels" robotic but you can't pinpoint why
- To self-audit your own responses for slop patterns

## Quick Reference: Slop Signals

### Lexical Red Flags

| Kill on Sight | Replace With |
|---------------|--------------|
| incredibly, highly, extremely | Drop or use specific degree |
| crucial, vital, essential | Explain why it matters |
| robust, seamless, comprehensive | Describe the actual capability |
| leverage, utilize | Use |
| game-changing, revolutionize | State the concrete change |
| holistic, synergy, alignment | Remove or explain precisely |

### Glue Phrase Killers

| Axe Immediately | Instead |
|-----------------|---------|
| "It's important to note that" | Just say the thing |
| "In today's world/digital age" | Delete (always filler) |
| "Having said that / That said" | Delete or use "But" |
| "With that in mind" | Delete |
| "Let me walk you through" | Delete and just explain |
| "Great question!" | Delete (sycophancy) |
| "Let's dive in" | Delete |

### Hedge Patterns (Cowardice)

- "of course," "naturally" (claims obviousness without proof)
- "in many ways," "to some extent" (weasel words)
- "it depends" without ranking the conditions
- "both approaches have pros and cons" without choosing

### Structural Slop

- **Formulaic intro:** Rephrases question → asserts importance → promises overview
- **Template sections:** Overview → Key Points → Best Practices → Conclusion
- **Over-signposting:** "In this section, we will..." / "As mentioned earlier..."
- **Staccato paragraphs:** Many 1-2 sentence paragraphs for false clarity
- **Symmetric coverage:** Equal weight to every axis without prioritization

## Detection Heuristics

### 1. Sentence Rhythm Test

Read aloud. If every sentence is 15-22 words with identical cadence, it's slop.
**Fix:** Vary sentence length drastically. Short. Then a long, complex sentence with subordinate clauses. Then another short punch.

### 2. Specificity Test

Does the text name specific tools, versions, tradeoffs, or constraints?
**Slop:** "Focus on clear communication and alignment with stakeholders."
**Real:** "Use Slack threads for async decisions; Zoom only for contentious items. Don't invite more than 4 people."

### 3. Asymmetry Test

Does the text commit to rankings, preferences, or opinionated tradeoffs?
**Slop:** "Both options have merits and considerations."
**Real:** "Use Postgres unless you're at >10M writes/day and can afford DynamoDB's operational complexity."

### 4. Constraint Test

Does the text acknowledge cost, politics, legacy systems, or messy reality?
**Slop:** "Adopt a microservices architecture for scalability."
**Real:** "Microservices add 3x operational overhead. Unless you have dedicated platform team, stay monolithic."

### 5. First-Person Test

Can you insert "in my experience" or "on my last project" naturally?
**Slop:** Generic enough to apply anywhere; says nothing specific.
**Real:** Grounded in specific context that would change the recommendation.

## The Rewrite Process

1. **Identify category** - Which slop type(s) dominate?
2. **Kill the killers** - Axe every word/phrase from the quick reference tables
3. **Inject specificity** - Add tool names, numbers, version constraints, concrete artifacts
4. **Break symmetry** - Commit to rankings, skip uninteresting branches
5. **Vary rhythm** - Rewrite for sentence length diversity
6. **Add constraints** - Acknowledge what makes this hard in practice
7. **Delete meta-commentary** - Remove all "let me explain" framing

## Example Transformation

**Before (pure slop):**
> In today's rapidly evolving digital landscape, it's crucial for organizations to leverage cutting-edge technologies. By adopting a holistic approach to digital transformation, you can unlock significant value and drive meaningful outcomes. Let's explore the key considerations.

**After (real):**
> Most "digital transformation" projects fail because they buy tools before fixing process. Start with a value stream map of your worst bottleneck. If you can't name it, you don't need new tech—you need visibility.

## Advanced Detection: Tone Drift

Watch for unexplained shifts:
- Casual → formal within paragraphs (confused persona)
- Technical → marketing speak (selling, not explaining)
- Empathy boilerplate: "I understand how challenging..." repeated across contexts
- Excessive cheerfulness: "I'm happy to help!" in grim contexts

## Advanced Detection: Argument Structure

**Enumerations that don't interact:** Bullets could be reordered freely—no cumulative case.
**Circular sections:** Rephrases thesis without new evidence.
**Balanced to a fault:** Every pro has matching con of equal weight (reality is asymmetric).
**Absent negative knowledge:** Never says "I don't know" or "this is speculative."

## Typographic Slop

- Em-dash abuse: "punchy—but—annoying" patterns for false energy
- Excessive exclamation points for enthusiasm
- Emoji as crutch for personality
- Parenthetical asides overused (making every point hedged like this)

## Chat-Specific Red Flags

- Direct prompt restatement: "You're asking how to X, so let's break it down"
- Meta-commentary: "Here's a breakdown:" / "Let's explore pros and cons"
- Educational scaffolding for experts: Beginner definitions when audience is advanced
- Consistently neutral persona: No stakes, preferences, or history admitted

## Output Format for Structured Review

When reviewing systematically, report findings:

```json
{
  "slop_signals": {
    "lexical": {
      "generic_boosters": ["incredibly", "robust", "leverage"],
      "buzzword_density": "high",
      "repeated_glue": ["it's important to note"]
    },
    "rhythm": {
      "sentence_length_variance": "low",
      "staccato_paragraphs": true
    },
    "structure": {
      "formulaic_intro": true,
      "template_sections": true,
      "over_signposting": true
    },
    "semantic": {
      "specificity": "none",
      "tradeoff_commitment": "none",
      "constraints_acknowledged": false
    },
    "tone": {
      "neutral_persona": true,
      "cheerful_helper": true
    }
  },
  "severity": "high",
  "priority_fixes": [
    "Kill all generic boosters",
    "Add specific tool names and version numbers",
    "Commit to recommendations instead of 'it depends'"
  ]
}
```

## Self-Check Before Publishing

- [ ] No words from "Kill on Sight" table remain
- [ ] At least one specific tool/artifact/number mentioned
- [ ] Asymmetric recommendations (not "both have pros and cons")
- [ ] Varied sentence length (check by reading aloud)
- [ ] No meta-commentary ("let me explain", "in this section")
- [ ] Constraints and tradeoffs acknowledged
- [ ] Would a subject-matter expert cringe? If unsure, more specific.

