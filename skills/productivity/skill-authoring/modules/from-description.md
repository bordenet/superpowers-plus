# Mode 1: From Natural Language Description

Generate a skill.md from a natural language description.

---

## Input Format

User provides intent in natural language:

```
"I need a skill that [does X] when [condition Y]"
"Create a skill for [workflow Z]"
"Make a skill to [achieve outcome]"
```

---

## Extraction Process

### Step 1: Identify Core Purpose

Ask yourself:
- What problem does this skill solve?
- When should it fire?
- What outcome does it produce?

### Step 2: Determine Domain

| If the skill involves... | Domain |
|--------------------------|--------|
| Code quality, testing, CI | engineering |
| Documentation platforms | wiki |
| Prose, formatting, messages | writing |
| Workflows, habits, planning | productivity |
| Tickets, bugs, tracking | issue-tracking |
| Credentials, vulnerabilities | security |
| Metrics, logging, analysis | observability |
| Information gathering | research |

### Step 3: Generate Triggers

Create 3-8 trigger phrases that would invoke this skill:

**Good triggers:**
- Specific action phrases: "check strict mode", "verify typescript config"
- Problem statements: "strict mode violations", "ts strict errors"
- Command-like: "run strict check", "validate strict"

**Bad triggers:**
- Too generic: "check code", "typescript" (overlaps with other skills)
- Too long: "make sure all typescript files follow strict mode" (no one types this)

### Step 4: Define Workflow

Structure the skill's guidance:

```markdown
## Process

### Step 1: [Action]
[What to do]

### Step 2: [Action]
[What to do]

### Step 3: [Action]
[What to do]
```

### Step 5: Add Examples

Include at least one concrete example showing the skill in action.

---

## Template for Generation

```markdown
---
name: <kebab-case-name>
source: superpowers-plus
triggers: [<list of 3-8 trigger phrases>]
description: <one-line description starting with "Use when...">
---

# <Title Case Name>

> **Purpose:** <why this skill exists>
> **Last Updated:** <today's date>

## When to Use

Invoke this skill when:
- <condition 1>
- <condition 2>
- User says: <trigger examples>

---

## Process

### Step 1: <Action>

<guidance>

### Step 2: <Action>

<guidance>

### Step 3: <Action>

<guidance>

---

## Examples

### Example: <Scenario>

<walkthrough of skill in action>

---

## Integration

| Related Skill | Relationship |
|---------------|--------------|
| <skill> | <how they interact> |
```

---

## Validation Checklist

Before presenting the draft:

- [ ] Name is kebab-case, unique, descriptive
- [ ] Triggers don't overlap with existing skills
- [ ] Description starts with "Use when..."
- [ ] Process has clear, actionable steps
- [ ] At least one concrete example
- [ ] Domain is appropriate

---

## Example Generation

**Input:** "I need a skill that validates API response schemas match our TypeScript types"

**Generated:**

```yaml
name: api-schema-validation
source: superpowers-plus
triggers: ["validate API schema", "check response types", "API type mismatch", "schema drift"]
description: Use when API responses don't match TypeScript types, after API changes, or during integration testing.
```
