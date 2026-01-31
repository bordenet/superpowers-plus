# Agents.md - AI Agent Guidelines for superpowers-plus

> **Last Updated:** 2026-01-25

This document defines the writing standards and quality requirements that **MUST** be followed
without exception in this repository. These rules exist because AI-generated text has
identifiable patterns that undermine credibility.

**Read this entire document before making any changes.**

---

## Cross-References

| Document | Purpose | Update When |
|----------|---------|-------------|
| [TODO.md](./TODO.md) | Task tracking | Any task changes |
| [README.md](./README.md) | Repository overview | Adding/removing skills |
| [docs/Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements | Major scope changes |
| [docs/PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector skill requirements (13 content types) | Detection feature changes |
| [docs/PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator skill requirements (11 strategies) | Rewriting feature changes |
| [docs/DESIGN.md](./docs/DESIGN.md) | Technical design | Implementation changes |
| [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan (80+ test cases) | Test changes |

**Rule:** Every markdown file in this repo MUST link back to this Agents.md file.

---

## ⛔ CRITICAL: Anti-Slop Writing Rules ⛔

**These rules apply to ALL documentation, comments, commit messages, and generated content.**

### Banned Phrases - Kill on Sight

| Category | Banned Phrases | Why |
|----------|----------------|-----|
| **Self-Promotion** | production-grade, world-class, enterprise-ready, best-in-class, industry-leading | Unsubstantiated marketing claims |
| **Hype Words** | game-changing, revolutionary, cutting-edge, next-generation, transformative | Empty superlatives |
| **Filler Boosters** | incredibly, extremely, highly, truly, absolutely, definitely | Adds no information |
| **Vague Quality** | robust, seamless, comprehensive, holistic, elegant, powerful | Describe the actual capability instead |
| **AI Tells** | leverage, utilize, facilitate, enable, empower | Use simple verbs: use, help, let |
| **Sycophancy** | Great question!, Happy to help!, Excellent point!, Absolutely! | Never compliment the user |

### Evidence-Based Claims Only

**Every claim MUST have supporting evidence:**

| Claim Type | Required Evidence |
|------------|-------------------|
| Performance | Specific metrics (e.g., "processes 1000 docs/min") |
| Comparison | Specific baseline (e.g., "50% faster than v1.2") |
| Capability | Concrete example or test case |
| Best practice | Citation or link to source |

**WRONG:** "This skill provides comprehensive AI detection."
**RIGHT:** "This skill detects 300+ slop patterns across 13 content types."

### No Celebratory Language

**Never celebrate our own work:**

- ❌ "Successfully implemented..."
- ❌ "The elegant solution..."
- ❌ "This powerful feature..."
- ✅ "Implemented X. Tested with Y. Result: Z."

### Sentence Structure Rules

1. **Vary sentence length** - Mix short (5-10 words) with longer (15-25 words)
2. **No uniform cadence** - Read aloud; if it sounds robotic, rewrite
3. **Limit em-dashes** - Maximum 1 per paragraph; prefer commas or periods
4. **No staccato paragraphs** - Avoid many consecutive 1-2 sentence paragraphs

---

## Documentation Standards

### Markdown File Requirements

Every markdown file MUST include:

1. **Title** - H1 header with document name
2. **Cross-reference link** - Link to Agents.md
3. **Last updated date** - In header or metadata
4. **Purpose statement** - What this document is for

**Template:**
```markdown
# Document Title

> **Guidelines:** See [Agents.md](../Agents.md) for writing standards.
> **Last Updated:** YYYY-MM-DD

## Purpose

[One sentence describing what this document covers]

---

[Content]
```

### Orphan Document Prevention

Before committing:

1. Verify document is listed in [TODO.md](./TODO.md) cross-references
2. Verify document links to Agents.md
3. Remove any temporary or obsolete documents

---

## Skill Development Standards

### Skill File Format

```yaml
---
name: skill-name-with-hyphens
description: Use when [specific triggering conditions]
---

# Skill Name

## Overview
[Content]
```

**Rules:**
- `name`: Letters, numbers, hyphens only
- `description`: Start with "Use when...", max 500 chars, third person
- Description describes WHEN to use, NOT what the skill does

### Skill Testing (TDD Approach)

1. **RED:** Run scenario WITHOUT skill, document baseline failures
2. **GREEN:** Write minimal skill addressing those failures
3. **REFACTOR:** Close loopholes, add edge cases

### Pre-Commit Checklist

- [ ] SKILL.md has valid YAML frontmatter
- [ ] `name` uses only letters, numbers, hyphens
- [ ] `description` starts with "Use when..."
- [ ] Skill tested with `use-skill` command
- [ ] `./install.sh` runs without errors
- [ ] No banned phrases in skill content
- [ ] All claims have evidence

---

## Directory Structure

```
superpowers-plus/
├── Agents.md           # This file - AI agent guidelines
├── TODO.md             # Task tracking (keep updated!)
├── README.md           # Repository overview
├── LICENSE
├── install.sh          # Deploy superpowers and skills
├── .gitignore
├── docs/
│   ├── Vision_PRD.md               # High-level vision
│   ├── PRD_detecting-ai-slop.md    # Detector requirements (13 content types)
│   ├── PRD_eliminating-ai-slop.md  # Eliminator requirements (11 strategies)
│   ├── DESIGN.md                   # Technical design
│   └── TEST_PLAN.md                # Test plan (80+ test cases)
└── skills/
    ├── detecting-ai-slop/          # Analysis and scoring
    │   └── SKILL.md
    ├── eliminating-ai-slop/        # Rewriting and prevention
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── resume-screening/
    │   ├── SKILL.md
    │   └── README.md
    ├── phone-screen-prep/
    │   ├── SKILL.md
    │   └── README.md
    └── reviewing-ai-text/          # Deprecated
        └── SKILL.md
```

---

## Testing Skills

```bash
# Install superpowers (if needed) and skills
./install.sh

# Use a personal skill
~/.codex/superpowers/.codex/superpowers-codex use-skill detecting-ai-slop

# Use a superpowers skill
~/.codex/superpowers/.codex/superpowers-codex use-skill superpowers:brainstorming
```

---

## Supported Content Types

The AI slop skills support 13 content types with type-specific patterns:

| Type | Detection Patterns | Rewriting Strategy |
|------|-------------------|-------------------|
| Document | Universal patterns only | Standard rewriting |
| Email | Corporate filler, buried leads | Lead with the ask |
| LinkedIn | Engagement bait, humble brags | Remove performative elements |
| SMS | Formality mismatch | Match conversational register |
| Teams/Slack | Email-in-chat patterns | Direct and immediate |
| Agents.md | Vague instructions | Make rules actionable |
| README | Marketing language | Quickstart first |
| PRD | Vague requirements | Add acceptance criteria |
| Design Doc | Decision avoidance | Recommend with rationale |
| Test Plan | Vague test cases | Add expected results |
| CV/Resume | Responsibilities vs achievements | Quantify impact |
| Cover Letter | Generic openings | Company-specific hooks |

---

## Relationship to Other Repos

| Repo | Purpose |
|------|---------|
| `obra/superpowers` | Core superpowers framework (upstream) |
| `bordenet/superpowers-plus` | Personal skills (this repo) |
| `bordenet/scripts` | Shell scripts with enforce-style-guide integration |

---

## Superpowers Skills

At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads available skills. Key skills:
- `superpowers:brainstorming` - Before creative/feature work
- `superpowers:systematic-debugging` - Before fixing bugs
- `superpowers:test-driven-development` - Before writing implementation
- `superpowers:verification-before-completion` - Before claiming done
- `superpowers:writing-plans` - Before multi-step tasks

**To load a skill:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:<skill-name>
```

**To list all skills:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

**The Rule:** IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST INVOKE IT.

---

## Author

Matt J Bordenet (@bordenet)
