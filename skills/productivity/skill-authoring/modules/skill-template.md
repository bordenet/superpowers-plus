# Skill Template

The canonical structure for generated skill.md files.

---

## Minimal Skill (Required Fields Only)

```markdown
---
name: <kebab-case-name>
source: superpowers-plus
triggers: ["trigger 1", "trigger 2", "trigger 3"]
description: Use when <condition>. <What it does>.
---

# <Title Case Name>

> **Purpose:** <One-line purpose statement>

## When to Use

Invoke this skill when:
- <Condition 1>
- <Condition 2>

## Process

### Step 1: <Action>

<Guidance>

### Step 2: <Action>

<Guidance>
```

---

## Full Skill (All Optional Sections)

```markdown
---
name: <kebab-case-name>
source: superpowers-plus
triggers: ["trigger 1", "trigger 2", "trigger 3", "trigger 4"]
description: Use when <condition>. <What it does>. <Integration note>.
# For pipeline skills:
composition:
  consumes: [<artifact>]
  produces: [<artifact>]
  capabilities: [<capability>]
  priority: 50
  optional: false
# For coordinated skills (legacy):
coordination:
  group: <group-name>
  order: <number>
  requires: [<skill>]
  enables: [<skill>]
---

# <Title Case Name>

> **Purpose:** <One-line purpose statement>
> **Last Updated:** <YYYY-MM-DD>
> **See also:** [related-skill](../related-skill/skill.md)

**Announce at start:** "I'm using the **<skill-name>** skill to <action>."

---

## Overview

<2-3 sentence overview of what this skill does and why it exists.>

---

## When to Use

Invoke this skill when:
- <Condition 1>
- <Condition 2>
- User says: "<trigger example 1>", "<trigger example 2>"

**Do NOT use when:**
- <Anti-condition 1>
- <Anti-condition 2>

---

## Process

### Step 1: <Action>

<Detailed guidance for this step>

### Step 2: <Action>

<Detailed guidance for this step>

### Step 3: <Action>

<Detailed guidance for this step>

---

## Examples

### Example 1: <Scenario Name>

**Situation:** <Context>

**Action:**
<What the skill does>

**Outcome:**
<Result>

---

## Integration

| Related Skill | Relationship |
|---------------|--------------|
| <skill-name> | <How they work together> |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| <Issue> | <Fix> |
```

---

## Field Reference

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Kebab-case identifier | `api-schema-validation` |
| `source` | Origin of skill | `superpowers-plus` |
| `triggers` | Array of trigger phrases | `["check schema", "validate API"]` |
| `description` | One-line description | `Use when API types drift...` |

### Optional Fields

| Field | Description | When to Use |
|-------|-------------|-------------|
| `composition` | Pipeline metadata | Skill participates in auto-composition |
| `coordination` | Group ordering | Skill is part of coordinated group |

### Composition Fields

| Field | Type | Description |
|-------|------|-------------|
| `consumes` | Array | Input artifacts required |
| `produces` | Array | Output artifacts generated |
| `capabilities` | Array | What transformations it performs |
| `priority` | Number | Execution order (lower = earlier) |
| `optional` | Boolean | Can be skipped if inputs unavailable |

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Skill name | kebab-case | `api-schema-validation` |
| Directory | Same as name | `skills/engineering/api-schema-validation/` |
| Triggers | Lowercase phrases | `"check api schema"` |
| Description | Starts with "Use when" | `Use when API responses...` |

---

## Validation Checklist

Before saving a generated skill:

- [ ] Name is unique (no existing skill with same name)
- [ ] Triggers don't overlap significantly with other skills
- [ ] Description starts with "Use when..."
- [ ] Process has actionable steps
- [ ] YAML frontmatter is valid
- [ ] File ends with single newline
