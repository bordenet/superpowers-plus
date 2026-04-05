---
name: skill-authoring
source: superpowers-plus
triggers: ["create a skill", "make a skill", "I need a skill", "new skill for", "skill that", "what skills should", "skill gap analysis", "turn this pattern into a skill", "synthesize skill", "generate skill"]
anti_triggers: ["check skill health", "diagnose skill", "run doctor", "what skills are available", "list skills", "which skills", "help with skills"]
description: The genesis capability — create new skills from natural language descriptions, observed patterns, or codebase analysis. Makes superpowers-plus self-extending.
summary: "Use when: writing or editing superpowers skill files."
coordination:
  group: productivity
  order: 5
  requires: []
  enables: ["writing-skills"]
  escalates_to: []
  internal: false
composition:
  consumes: [goal, skill-gap]
  produces: [new-skill]
  capabilities: [generates-skills, validates-structure]
  priority: 10
---

# Skill Authoring

> **Wrong skill?** Skill structure/format → `writing-skills`. Checking skill health → `skill-health-check`. Diagnosing skill issues → `superpowers-doctor`.
>
> **Purpose:** Generate skill.md files from descriptions, patterns, or analysis
> **Last Updated:** 2026-03-16

**Announce at start:** "I'm using the **skill-authoring** skill to help create a new skill."

## When to Use

- User asks to create, generate, or scaffold a new skill
- A repeating pattern is identified that should become a reusable skill
- Skill gap analysis reveals missing capabilities in the skill catalog

## Authoring Modes

This skill enables superpowers-plus to extend itself. Three modes:

| Mode | Input | Output |
|------|-------|--------|
| **From Description** | Natural language | Draft skill.md |
| **From Patterns** | learning-state.json observations | Skill candidates |
| **From Codebase** | Repository analysis | Skill recommendations |

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

```bash
I'll help create a TypeScript strict mode skill.

**Proposed skill:**
- Name: `typescript-strict-mode` (overlay)
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

### Validation Checklist

Before presenting the draft:

- [ ] Name is kebab-case, unique, descriptive
- [ ] Triggers don't overlap with existing skills
- [ ] Description starts with "Use when..."
- [ ] Process has actionable steps
- [ ] At least one concrete example
- [ ] Domain is appropriate

## Mode 2: From Observed Patterns

**Triggers:** "turn this pattern into a skill", "synthesize skill from patterns"

### Process

1. **Identify pattern** — User describes a recurring workflow or behavior they want codified
2. **Review scope** — Determine if the pattern is distinct enough to warrant its own skill
3. **Generate draft** — Create skill.md from pattern description
4. **Validate** — Run through the quality checklist (see below)

### Example

When you notice a recurring pattern worth codifying, tell the AI:
> "Turn this pattern into a skill: [pattern description]"

The pattern description contains the "what" — extract trigger conditions, actions, and outcomes, then expand into the full skill structure.

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

### Output Format

For each recommended skill:

1. **Name** — Suggested skill name
2. **Evidence** — What in the codebase suggests this
3. **Value** — Why this skill would help
4. **Complexity** — Low/Medium/High
5. **Priority** — P1/P2/P3

## Skill Template

See [`references/output-location.md`](references/output-location.md) for directory structure and domain selection guide.

```yaml
name: <skill-name>
source: superpowers-plus
triggers: ["trigger 1", "trigger 2"]
description: <one-line description>
```

Required sections: `## When to Use`, `## Process`, `## Examples`, `## Companion Skills`, `## Failure Modes`.

## Quality Gates

1. Validate YAML frontmatter (name, triggers, description)
2. Check trigger uniqueness — no overlap with existing skills (`superpowers-doctor`)
3. Verify domain fit · run `harsh-review.sh` · user approval
4. Save to `skills/{domain}/` · update README · `./install.sh`

**Skip when:** domain design (`domain-design`) · structural lint (`skill-health-check`) · runtime issues (`superpowers-doctor`)

## Companion Skills

- **writing-skills**: Skill file format reference
- **skill-health-check**: Structural lint for skill files
- **superpowers-doctor**: Runtime diagnostics after publishing
- **domain-design**: Domain-level skill design
- **golden-agents**: Similar scaffolding UX pattern
- **evolution-loop**: Pattern-driven skill creation

## Failure Modes

| Failure | Fix |
|---------|-----|
| Oversized skill (>250L) | Extract reference material to `references/` |
| Missing frontmatter | Add `---` delimiters, `description:`, `triggers:` |
| Trigger collision | Run `superpowers-doctor` before committing |
