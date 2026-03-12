---
name: reviewing-ai-text
source: superpowers-plus
triggers: ["review AI text", "edit AI output", "check AI writing", "fix AI prose", "improve AI draft"]
description: Use when reviewing or editing AI-generated text to detect and eliminate slop - the telltale patterns of machine-like writing including overused boosters, formulaic structure, excessive hedging, and hollow specificity.
---

# Reviewing AI Text

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-03-12
> **See also:** [reference.md](./reference.md) (pattern tables), [examples.md](./examples.md) (stylometric tests)

## Overview

AI slop is the signature of lazy machine generation: formulaic structure, hollow abstraction, and sycophantic tone that a careful human expert would never write.

**Core principle:** Real expertise is specific, opinionated, and unafraid of asymmetry.

## When to Use

- Before publishing AI-assisted documentation
- When editing AI-generated content for human consumption
- When reviewing text that "feels" robotic but you can't pinpoint why
- To self-audit your own responses for slop patterns

---

## Quick Reference: Pattern Categories

For complete pattern tables, see [reference.md](./reference.md).

| Category | Examples | Action |
|----------|----------|--------|
| 1. Generic Boosters | incredibly, extremely, highly | Delete or quantify |
| 2. Vague Quality | robust, seamless, powerful | Describe specifically |
| 3. Hype Words | game-changing, revolutionary | Delete or describe |
| 4. Glue Phrases | "It's important to note" | Delete |
| 5. Hedge Patterns | might, potentially, arguably | Commit or delete |
| 6. Sycophancy | "Great question!" | Delete |
| 7. Transitional Filler | Furthermore, Moreover | Simplify |

---

## Structural Slop

- **Formulaic intro:** Rephrases question → asserts importance → promises overview
- **Template sections:** Overview → Key Points → Best Practices → Conclusion
- **Over-signposting:** "In this section, we will..." / "As mentioned earlier..."
- **Staccato paragraphs:** Many 1-2 sentence paragraphs for false clarity
- **Symmetric coverage:** Equal weight to every axis without prioritization

---

## Semantic Detection

### 1. Specificity Test

Does the text name specific tools, versions, or quantified tradeoffs?

**Slop:** "Use appropriate caching strategies"
**Real:** "Use Redis with 5-minute TTL for session data"

### 2. Asymmetry Test

Does the text commit to rankings, preferences, or opinionated tradeoffs?

**Slop:** "Both options have merits and considerations"
**Real:** "Use Postgres unless you need >10M writes/day, then consider DynamoDB"

### 3. Constraint Test

Does the text acknowledge cost, politics, legacy systems, or messy reality?

**Slop:** "Implement microservices for scalability"
**Real:** "Microservices add 3x operational overhead. Stay monolith unless you have dedicated platform team."

### 4. First-Person Test

Can you insert "in my experience" or "on my last project" naturally?

**Slop:** Generic enough to apply anywhere
**Real:** Grounded in specific context

---

## Stylometric Quick Tests

For detailed techniques, see [examples.md](./examples.md).

| Test | Pass | Fail |
|------|------|------|
| Sentence length range | >10 words | <5 words |
| Type-Token Ratio | 0.50-0.65 | <0.50 |
| Repeated adjectives | <3 same word | 3+ same word |
| Predictable next-word | Can't predict | Can predict 3+ words |
| Proper nouns present | Yes | No |

---

## Typographic Slop

- **Em-dash abuse:** "punchy—but—annoying" for false energy
- **Excessive exclamation points** for enthusiasm
- **Emoji as crutch** for personality
- **Parenthetical asides overused** (hedging everything)

---

## Domain-Specific Checks

### Technical Documentation

| Pattern | Problem | Fix |
|---------|---------|-----|
| "This function is used to..." | Passive | "Parses JSON from stdin" |
| "Simply call the API..." | Condescending | Delete "simply" |
| "Various bug fixes" | Lazy | List the actual fixes |
| "Works with recent versions" | Vague | "Requires Node 18+" |

---

## Transformation Examples

### Before (Slop)
> "Our cutting-edge platform leverages advanced AI to deliver seamless, enterprise-ready solutions that drive meaningful outcomes."

### After (Specific)
> "The platform uses GPT-4o for intent classification (200ms p95) and returns JSON responses. Tested with 50K daily requests at Company X."

---

## Self-Check Before Publishing

- [ ] No words from pattern categories remain (or justified)
- [ ] At least one specific tool/artifact/number mentioned
- [ ] Asymmetric recommendations (not "both have pros and cons")
- [ ] Varied sentence length (range > 10 words)
- [ ] No meta-commentary ("let me explain")
- [ ] Constraints and tradeoffs acknowledged
- [ ] No repeated adjectives (same word 3+ times)
- [ ] Proper nouns present (names, products, versions)
- [ ] Would a subject-matter expert cringe? If unsure, more specific.

---

## Related Skills

- **detecting-ai-slop**: Quantitative scoring (0-100)
- **eliminating-ai-slop**: Active rewriting with GVR loop
