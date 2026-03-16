---
name: skill-authoring
source: superpowers-plus
triggers: ["create a skill", "make a skill", "I need a skill", "new skill for", "skill that", "what skills should", "skill gap analysis", "turn this pattern into a skill", "synthesize skill", "generate skill"]
description: The genesis capability — create new skills from natural language descriptions, observed patterns, or codebase analysis. Makes superpowers-plus self-extending.
---

# Skill Authoring

> **Purpose:** Generate skill.md files from descriptions, patterns, or analysis
> **Last Updated:** 2026-03-16
> **See also:** [skill-effectiveness](../../observability/skill-effectiveness/skill.md) for pattern recording

**Announce at start:** "I'm using the **skill-authoring** skill to help create a new skill."

---

## Overview

This skill enables superpowers-plus to extend itself. Three modes:

| Mode | Input | Output |
|------|-------|--------|
| **From Description** | Natural language | Draft skill.md |
| **From Patterns** | learning-state.json observations | Skill candidates |
| **From Codebase** | Repository analysis | Skill recommendations |

---

## Mode 1: From Natural Language

**Triggers:** "create a skill for...", "I need a skill that...", "make a skill to..."

### Process

1. **Capture intent** — What should this skill do?
2. **Identify domain** — engineering, wiki, writing, productivity, etc.
3. **Generate triggers** — What phrases should invoke this skill?
4. **Define workflow** — What steps does the skill guide?
5. **Draft skill.md** — Using the template structure
6. **Review with user** — Iterate until approved

### Example

**User:** "I need a skill that checks for TypeScript strict mode violations before commit"

**Response:**

```
I'll help create a TypeScript strict mode skill.

**Proposed skill:**
- Name: `typescript-strict-check`
- Domain: `engineering`
- Triggers: ["strict mode violations", "typescript strict", "check strict mode", "ts strict"]

**What it would do:**
1. Check tsconfig.json for strict mode settings
2. Run tsc --noEmit to find violations
3. Categorize violations by severity
4. Suggest fixes or auto-fix where possible

**Integration:**
- Could run as part of pre-commit-gate
- Composition: consumes code-changes, produces strict-validated

Want me to generate the full skill.md?
```

### Detailed Guide

See [modules/from-description.md](./modules/from-description.md)

---

## Mode 2: From Recorded Patterns

**Triggers:** "turn this pattern into a skill", "synthesize skill from patterns"

### Process

1. **Check candidates** — Run `check-synthesis-candidates` command
2. **Review patterns** — Patterns with frequency ≥ 3 shown in table
3. **Select pattern** — Choose one to synthesize
4. **Generate draft** — Create skill.md from pattern description

### Find Synthesis Candidates

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js check-synthesis-candidates
```

This shows patterns observed 3+ times that haven't been synthesized yet.

**Example output:**
| # | Pattern | Freq | Suggested Name | Last Seen |
|---|---------|------|----------------|-----------|
| 1 | Always run lint before commit | 5x | pre-commit-lint | 2026-03-15 |

### Synthesize a Pattern

When you see a candidate worth codifying, tell the AI:
> "Turn this pattern into a skill: [pattern description]"

### Detailed Guide

See [modules/from-patterns.md](./modules/from-patterns.md)

---

## Mode 3: From Codebase Analysis

**Triggers:** "what skills should this repo have", "skill gap analysis"

### Process

1. **Scan repository** — Analyze structure, scripts, patterns
2. **Identify workflows** — Recurring tasks, manual processes
3. **Propose skills** — Ranked by potential value
4. **Generate drafts** — User selects which to create

### Analysis Targets

| Target | What to Look For |
|--------|------------------|
| `.github/workflows/` | CI patterns that could be skills |
| `scripts/` | Manual scripts to codify |
| `package.json` scripts | Build/test patterns |
| Commit history | Recurring commit types |
| TODOs/FIXMEs | Pain points to address |

### Detailed Guide

See [modules/from-codebase.md](./modules/from-codebase.md)

---

## Skill Template

All generated skills follow this structure:

```yaml
---
name: <skill-name>
source: superpowers-plus  # or custom source
triggers: ["trigger 1", "trigger 2"]
description: <one-line description>
# Optional composition for pipeline skills:
composition:
  consumes: [<artifact>]
  produces: [<artifact>]
  capabilities: [<capability>]
  priority: 50
---

# <Skill Title>

> **Purpose:** <why this skill exists>
> **Last Updated:** <date>

## When to Use

<Triggers and context>

## Process

<Step-by-step guidance>

## Examples

<Concrete usage examples>
```

See [modules/skill-template.md](./modules/skill-template.md) for full template.

---

## Integration with Existing Skills

| Skill | How skill-authoring Uses It |
|-------|----------------------------|
| skill-effectiveness | Reads pattern_observations for synthesis |
| golden-agents | Similar scaffolding UX pattern |
| brainstorming | Could be invoked for skill design |
| readme-authoring | Generates README alongside skill.md |

---

## Output Location

Generated skills are saved to:

```
skills/<domain>/<skill-name>/
├── skill.md       # Main skill definition
├── README.md      # Optional: if skill needs extended docs
└── modules/       # Optional: for complex skills
```

**Domain selection:**
- `engineering` — Code quality, testing, CI/CD
- `wiki` — Documentation platforms
- `writing` — Prose quality, formatting
- `productivity` — Workflow optimization
- `issue-tracking` — Tickets, bugs, features
- `security` — Audits, vulnerabilities
- `observability` — Metrics, tracking
- `research` — Information gathering

---

## Quality Gates

Before finalizing any generated skill:

1. **Validate YAML frontmatter** — Name, triggers, description required
2. **Check trigger uniqueness** — No overlap with existing skills
3. **Verify domain fit** — Skill belongs in chosen domain
4. **Run harsh-review.sh** — Must pass before commit

---

## After Generation

1. **Review the draft** — User approves or requests changes
2. **Save to skills/** — In appropriate domain directory
3. **Run harsh-review.sh** — Verify formatting
4. **Update README.md** — Add to skills table if needed
5. **Commit and deploy** — `./install.sh` to activate
