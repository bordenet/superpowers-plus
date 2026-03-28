---
name: writing-skills
source: superpowers-plus
overrides: superpowers/writing-skills
# Override rationale: Condensed from 655→87 lines. Focuses on YAML frontmatter
# format, prose quality rules, and creation checklist. Base version covers
# obra/superpowers internals; this version targets superpowers-plus conventions.
triggers: ["skill writing style", "skill prose quality", "skill markdown format", "SKILL.md format", "skill file conventions", "review skill file", "skill quality check"]
anti_triggers: ["use skill", "find skill", "load skill"]
description: "Use when: creating or reviewing skill files. Covers SKILL.md structure, prose quality, markdown formatting, creation checklist, and quality gates. For the full creation workflow, see skill-authoring (upstream)."
coordination:
  group: writing
  order: 0
  requires: []
  enables: ['skill-authoring']
  escalates_to: []
  internal: false
---

# Writing Skills

> **Wrong skill?** Full skill creation workflow → `skill-authoring`. Skill runtime issues → `superpowers-doctor`. Skill structural lint → `skill-health-check`.

## When to Use

- Creating new skill files (structure, frontmatter, prose style, quality gates)
- Reviewing existing skill files for compliance with conventions
- NOT for: using/loading/finding skills at runtime (`superpowers-help`)

A **skill** is a reusable reference guide for techniques, patterns, or tools. NOT a narrative about solving a problem once.

## SKILL.md Structure

```yaml
---
name: skill-name
source: superpowers-plus  # or superpowers, or private overlay
triggers: ["phrase1", "phrase2"]
anti_triggers: ["not-this"]
description: "One-line summary starting with 'Use when:'"
---
```

Then markdown body: core procedure, checklists, rules. Scale section depth to complexity.

## Skill Types

| Type | Purpose | Example |
|------|---------|---------|
| **Technique** | How-to guide | brainstorming, systematic-debugging |
| **Pattern** | Mental model / guard | eliminating-ai-slop, engineering-rigor |
| **Reference** | API/tool docs | perplexity-research, todo-management |

## Directory Structure

```
skills/{domain}/{skill-name}/
├── skill.md          # Core skill (≤250 lines)
├── examples.md       # Extended examples (optional)
└── references/       # Reference material (optional)
```

Domains: `engineering`, `writing`, `productivity`, `security`, `research`, `wiki`, issue-tracking domain, `observability`, `experimental`.

## Creation Checklist

1. **Test first** — run pressure scenario WITHOUT the skill (baseline)
2. **Watch it fail** — document exact agent violations/rationalizations
3. **Write minimal skill** — address those specific failures
4. **Watch it pass** — verify agent now complies
5. **Close loopholes** — find new rationalizations → plug → re-verify
6. **Size check** — `wc -l skill.md` must be ≤250 lines

## Quality Gates

- Every rule has a concrete "what to do" (not just "don't do X")
- Triggers are specific enough to avoid false positives
- Anti-triggers prevent firing when not needed
- Description starts with "Use when:" for search optimization
- No narrative examples — use checklists and tables
- No philosophical arguments ("why this matters")
- Token budget: aim for <1000 compressed tokens

## Where Skills Go

| Repo | Content | Access |
|------|---------|--------|
| `superpowers` (obra) | Upstream skills | Read-only |
| `superpowers-plus` | Open-source enhancements | Public GitLab + GitHub |
| private overlay | Internal/proprietary | Private repo |

Override an obra skill: set `overrides: superpowers/{skill-name}` in frontmatter. Place in spp or spc with same `name`.

## After Creation

1. `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills {name}` — verify discoverable
2. `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill {name}` — verify loads correctly
3. Check compressed token count — target <1000

## Failure Modes

| Failure | Fix |
|---------|-----|
| Skill passes structural checks but has empty/placeholder procedure | Every skill needs at least one concrete "do X, then Y" instruction |
| Trigger phrases too broad — causes false positive routing | Test triggers: `find-skills "{trigger}"` should return <3 skills per trigger |
| Description doesn't start with "Use when:" — breaks search optimization | Format: `"Use when: {specific context}. Skip when: {anti-context}."` |
| Skill exceeds 250-line limit after edits | Check `wc -l skill.md` before committing — refactor to examples.md if needed |
