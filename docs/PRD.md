# Product Requirements Document: reviewing-ai-text Skill Enhancement

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-24
> **Status:** Draft
> **Author:** Matt J Bordenet

## Purpose

Define requirements for enhancing the `reviewing-ai-text` skill to detect and eliminate AI-generated text patterns ("slop") across multiple dimensions.

---

## Problem Statement

AI-generated text exhibits identifiable patterns that undermine credibility:

1. **Lexical patterns** - Overused boosters, buzzwords, and filler phrases
2. **Structural patterns** - Formulaic intros, template sections, uniform rhythm
3. **Semantic patterns** - Hollow specificity, symmetric coverage, absent constraints
4. **Stylometric patterns** - Abnormal word frequency distributions, low entropy

Current detection relies on manual review. This skill automates pattern detection and provides actionable rewrite guidance.

---

## Goals

| Goal | Metric | Target |
|------|--------|--------|
| Detect lexical slop | Phrases flagged per 1000 words | ≥15 for typical AI text |
| Detect structural slop | Patterns identified | ≥5 per document |
| Provide rewrite guidance | Actionable suggestions | 1 per flagged pattern |
| Reduce false positives | Human-written text flagged | <5% |

---

## Requirements

### P0 - Must Have

#### REQ-001: Expanded Lexical Detection

**Description:** Detect 100+ specific slop phrases across categories.

**Categories:**
- Generic boosters (incredibly, extremely, highly, etc.)
- Buzzwords (leverage, utilize, synergy, etc.)
- Glue phrases (it's important to note, let's dive in, etc.)
- Hedge patterns (of course, naturally, in many ways, etc.)
- Sycophantic phrases (great question, happy to help, etc.)

**Acceptance Criteria:**
- [ ] Skill lists ≥100 specific phrases with replacements
- [ ] Phrases organized by category with severity levels
- [ ] Each phrase has concrete replacement guidance

#### REQ-002: Domain-Specific Patterns

**Description:** Detect slop patterns specific to content domains.

**Domains:**
- Technical documentation (API docs, READMEs, code comments)
- Marketing/business (press releases, product descriptions)
- Academic/research (literature reviews, methodology sections)

**Acceptance Criteria:**
- [ ] ≥10 patterns per domain
- [ ] Domain-specific examples provided
- [ ] Rewrite guidance tailored to domain

#### REQ-003: Structural Detection

**Description:** Detect formulaic document structures.

**Patterns:**
- Formulaic introductions (rephrases question → asserts importance → promises overview)
- Template sections (Overview → Key Points → Best Practices → Conclusion)
- Over-signposting ("In this section, we will...")
- Staccato paragraphs (many 1-2 sentence paragraphs)

**Acceptance Criteria:**
- [ ] ≥5 structural patterns documented
- [ ] Detection heuristics provided
- [ ] Rewrite examples for each pattern

### P1 - Should Have

#### REQ-004: Stylometric Detection

**Description:** Detect statistical anomalies in text.

**Metrics:**
- Sentence length variance (AI text has uniform 15-22 word sentences)
- Type-token ratio (vocabulary diversity)
- Hapax legomena frequency (words appearing once)

**Acceptance Criteria:**
- [ ] Heuristics for each metric documented
- [ ] Thresholds for flagging provided
- [ ] Manual calculation instructions included

#### REQ-005: Entropy Analysis

**Description:** Detect low-entropy patterns.

**Patterns:**
- Predictable n-gram sequences
- Zipf distribution deviation
- Repetitive phrase structures

**Acceptance Criteria:**
- [ ] Conceptual explanation provided
- [ ] Manual detection heuristics included
- [ ] No external tooling required

### P2 - Nice to Have

#### REQ-006: JSON Output Schema

**Description:** Structured output format for systematic reviews.

**Acceptance Criteria:**
- [ ] JSON schema documented
- [ ] Example output provided
- [ ] Severity scoring included

---

## Out of Scope

- Automated scanning tools (skill is for human-guided review)
- Machine learning models (skill uses heuristics only)
- Real-time detection (skill is for post-hoc review)
- Watermark detection (requires specialized tooling)

---

## Success Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Patterns detected | 20 | 100+ | Count in SKILL.md |
| Domains covered | 0 | 3 | Technical, Marketing, Academic |
| Detection heuristics | 5 | 10+ | Count in SKILL.md |
| User satisfaction | N/A | Positive feedback | Manual review |

---

## Timeline

| Phase | Deliverable | Target Date |
|-------|-------------|-------------|
| Phase 1 | Documentation (PRD, Design, Test Plan) | 2026-01-24 |
| Phase 2 | Expanded word lists | 2026-01-25 |
| Phase 3 | Domain-specific patterns | 2026-01-25 |
| Phase 4 | Stylometric detection | 2026-01-26 |
| Phase 5 | Testing and validation | 2026-01-26 |

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [DESIGN.md](./DESIGN.md) - Technical design
- [TEST_PLAN.md](./TEST_PLAN.md) - Test plan
- [skills/reviewing-ai-text/SKILL.md](../skills/reviewing-ai-text/SKILL.md) - Current skill

