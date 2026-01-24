# Test Plan: reviewing-ai-text Skill

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-24
> **Status:** Draft
> **Author:** Matt J Bordenet

## Purpose

Validate that the enhanced `reviewing-ai-text` skill detects AI-generated text patterns per [PRD.md](./PRD.md) requirements.

---

## Test Strategy

### Approach

Use TDD methodology from superpowers framework:

1. **RED:** Generate AI text without skill, document slop patterns present
2. **GREEN:** Apply skill, verify patterns are detected
3. **REFACTOR:** Identify missed patterns, update skill, retest

### Test Categories

| Category | Tests | Priority |
|----------|-------|----------|
| Lexical detection | 5 | P0 |
| Domain patterns | 3 | P0 |
| Structural detection | 3 | P0 |
| Stylometric detection | 3 | P1 |
| False positive control | 2 | P1 |

---

## Test Cases

### TC-001: Lexical Detection - Boosters

**Objective:** Verify skill detects booster phrases.

**Input:**
> "The incredibly powerful framework provides an extremely robust solution that is highly scalable and truly transformative for enterprise workflows."

**Expected detections:**
- "incredibly" → flag as booster
- "extremely" → flag as booster
- "highly" → flag as booster
- "truly" → flag as booster
- "powerful" → flag as vague quality
- "robust" → flag as vague quality
- "transformative" → flag as hype word

**Pass criteria:** ≥6 of 7 patterns flagged.

### TC-002: Lexical Detection - Buzzwords

**Objective:** Verify skill detects AI buzzwords.

**Input:**
> "We leverage cutting-edge technology to facilitate seamless integration and enable teams to utilize best-in-class solutions that empower stakeholders."

**Expected detections:**
- "leverage" → use "use"
- "cutting-edge" → hype word
- "facilitate" → use "help" or "allow"
- "seamless" → vague quality
- "enable" → use "let"
- "utilize" → use "use"
- "best-in-class" → self-promotion
- "empower" → vague

**Pass criteria:** ≥7 of 8 patterns flagged.

### TC-003: Lexical Detection - Glue Phrases

**Objective:** Verify skill detects filler glue phrases.

**Input:**
> "It's important to note that this approach is fundamentally different. Let's dive into the key aspects. At the end of the day, what really matters is that we're seeing significant improvements."

**Expected detections:**
- "It's important to note" → delete
- "Let's dive into" → start directly
- "At the end of the day" → delete
- "what really matters" → delete

**Pass criteria:** ≥3 of 4 patterns flagged.

### TC-004: Domain - Technical Documentation

**Objective:** Verify skill detects tech doc slop.

**Input:**
> "This function provides a simple and easy-to-use interface. Simply call the API with your parameters. The library is designed to be lightweight yet powerful, offering comprehensive functionality for all your needs."

**Expected detections:**
- "simple and easy-to-use" → domain pattern
- "Simply call" → dismissive
- "lightweight yet powerful" → contradiction cliché
- "comprehensive functionality" → vague
- "for all your needs" → boilerplate

**Pass criteria:** ≥4 of 5 patterns flagged.

### TC-005: Domain - Marketing

**Objective:** Verify skill detects marketing slop.

**Input:**
> "Our industry-leading platform delivers game-changing results. Transform your workflow with our next-generation solution. Join thousands of satisfied customers who have revolutionized their processes."

**Expected detections:**
- "industry-leading" → self-promotion
- "game-changing" → hype
- "Transform your" → hype
- "next-generation" → hype
- "satisfied customers" → testimonial cliché
- "revolutionized" → hype

**Pass criteria:** ≥5 of 6 patterns flagged.

### TC-006: Structural Detection

**Objective:** Verify skill detects formulaic structure.

**Input:**
> "Introduction: In today's fast-paced world, efficiency matters. In this article, we will explore the key aspects of productivity. First, we'll examine the basics. Then, we'll dive into advanced techniques. Finally, we'll discuss best practices."

**Expected detections:**
- Formulaic intro pattern
- Over-signposting ("In this article, we will")
- Template structure (First/Then/Finally)
- "In today's fast-paced world" → cliché opener

**Pass criteria:** ≥3 of 4 patterns flagged.

### TC-007: Stylometric - Sentence Variance

**Objective:** Verify skill detects uniform sentence length.

**Input (5 sentences, all 18-22 words):**
> "The new system provides significant improvements in overall performance metrics. Users can expect faster response times across all major functions. This update addresses several key issues reported by customers. The development team worked hard to optimize core algorithms. Documentation has been updated to reflect all recent changes."

**Expected detection:** Flag uniform sentence length (~20 words each).

**Pass criteria:** Skill flags sentence uniformity.

### TC-008: False Positive - Human Text

**Objective:** Verify skill does not over-flag human-written text.

**Input (from Paul Graham essay):**
> "The way to get startup ideas is not to try to think of startup ideas. It's to look for problems, preferably problems you have yourself. The very best startup ideas tend to have three things in common: they're something the founders themselves want, that they themselves can build, and that few others realize are worth doing."

**Expected:** <2 false positive flags.

**Pass criteria:** Skill flags ≤2 patterns.

---

## Execution Procedure

1. Install skill: `./install.sh`
2. Load skill: `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill reviewing-ai-text`
3. Present test input to Claude with skill active
4. Request: "Review this text for AI slop patterns"
5. Compare output to expected detections
6. Record pass/fail per test case

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [PRD.md](./PRD.md) - Requirements
- [DESIGN.md](./DESIGN.md) - Technical design
- [skills/reviewing-ai-text/SKILL.md](../skills/reviewing-ai-text/SKILL.md) - Skill file

