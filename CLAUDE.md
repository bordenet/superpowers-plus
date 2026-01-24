# CLAUDE.md - AI Agent Guidelines for superpowers-plus

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
| [docs/PRD.md](./docs/PRD.md) | Product requirements | Scope changes |
| [docs/DESIGN.md](./docs/DESIGN.md) | Technical design | Implementation changes |
| [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan | Test changes |

**Rule:** Every markdown file in this repo MUST link back to this CLAUDE.md file.

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
**RIGHT:** "This skill detects 47 specific slop patterns across 9 categories."

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
2. **Cross-reference link** - Link to CLAUDE.md
3. **Last updated date** - In header or metadata
4. **Purpose statement** - What this document is for

**Template:**
```markdown
# Document Title

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** YYYY-MM-DD

## Purpose

[One sentence describing what this document covers]

---

[Content]
```

### Orphan Document Prevention

Before committing:

1. Verify document is listed in [TODO.md](./TODO.md) cross-references
2. Verify document links to CLAUDE.md
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
├── CLAUDE.md           # This file - AI agent guidelines
├── TODO.md             # Task tracking (keep updated!)
├── README.md           # Repository overview
├── LICENSE
├── install.sh          # Deploy skills to ~/.codex/skills/
├── install-augment-superpowers.sh
├── docs/
│   ├── PRD.md          # Product requirements
│   ├── DESIGN.md       # Technical design
│   └── TEST_PLAN.md    # Test plan
└── skills/
    ├── reviewing-ai-text/
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── resume-screening/
    │   ├── SKILL.md
    │   └── README.md
    └── phone-screen-prep/
        ├── SKILL.md
        └── README.md
```

---

## Testing Skills

```bash
# Install skills
./install.sh

# List available skills
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills

# Load a specific skill
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill reviewing-ai-text
```

---

## Relationship to Other Repos

| Repo | Purpose |
|------|---------|
| `obra/superpowers` | Core superpowers framework (upstream) |
| `bordenet/superpowers-plus` | Personal skills (this repo) |
| `bordenet/scripts` | Shell scripts with enforce-style-guide integration |

---

## Author

Matt J Bordenet (@bordenet)

