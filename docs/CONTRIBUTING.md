# Contributing

How to add new skills to superpowers-plus.

## Adding a Skill

### 1. Create the Directory

```bash
mkdir -p skills/{domain}/{skill-name}
```

Use an existing domain or create a new one. Current domains:
- `writing/` — text quality
- `typescript/` — TypeScript development
- `issue-tracking/` — issue management
- `wiki/` — documentation
- `observability/` — auditing and tracking
- `productivity/` — workflow automation
- `research/` — external research
- `security/` — vulnerability scanning
- `experimental/` — unstable skills

### 2. Create skill.md

```bash
touch skills/{domain}/{skill-name}/skill.md
```

### 3. Write the Skill

Use this template:

```markdown
---
name: skill-name
source: superpowers-plus
triggers: ["trigger phrase 1", "trigger phrase 2", "another trigger"]
description: One sentence describing what it does.
---

# Skill Name

## When to Invoke

Invoke when:
- [Condition 1]
- [Condition 2]

Do NOT invoke when:
- [Exception 1]

## Procedure

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Output Format

[Describe expected outputs, tables, or artifacts]

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| [Failure type] | [How to detect] | [How to recover] |
```

### Frontmatter Requirements

| Field | Required | Example |
|-------|----------|---------|
| `name` | ✅ | `link-verification` |
| `source` | ✅ | `superpowers-plus` |
| `triggers` | ✅ | `["verify links", "check URL"]` |
| `description` | ✅ | One sentence, no "Triggers on" — triggers are in the array |

**Note:** The `triggers` array enables automated auditing via `./tools/skill-trigger-validator.sh`.

### 4. Validate Triggers

Before committing, run the trigger validator:

```bash
./tools/skill-trigger-validator.sh audit
```

This checks for:
- Missing `triggers` arrays
- Unexpected overlaps with other skills
- Registry completeness

### 5. Install and Verify

```bash
./install.sh
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep skill-name
```

## Skill Writing Guidelines

**Do:**
- Start with "When to Invoke" — AI needs to know when to use it
- Include concrete examples
- Define failure modes
- Keep procedures to 5-10 steps

**Don't:**
- Use vague language ("consider", "might want to")
- Include conditional logic without defaults
- Omit the "Do NOT invoke" section
- Write procedures longer than one screen

## Testing Your Skill

1. Start a new conversation with your AI assistant
2. Run bootstrap: `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap`
3. Create a scenario that should trigger your skill
4. Verify the skill fires and produces expected output
5. Test edge cases and failure modes

## Submitting Changes

### Before Committing

**Install the pre-commit hook** (recommended):
```bash
./tools/install-hooks.sh
```

This will automatically block commits that violate quality standards.

**Or manually run the harsh review:**
```bash
./tools/harsh-review.sh
```

### Quality Requirements (Enforced by CI)

All PRs must pass these checks:

| Check | Requirement |
|-------|-------------|
| File endings | Exactly one newline at EOF (`0a`) |
| Shell scripts | `#!/usr/bin/env bash` shebang |
| Shell scripts | Pass `bash -n` and `shellcheck` |
| JSON files | Valid syntax |
| Required files | README.md, AGENTS.md, etc. must exist |

**CI will block merge if any check fails.**

### Auto-Fix Available

```bash
./tools/harsh-review.sh --fix
```

This will automatically fix file endings.

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Add your skill
4. Run `./tools/harsh-review.sh` (must pass)
5. Submit a pull request with:
   - Skill name and purpose
   - Example trigger scenario
   - Example output
6. Complete the PR checklist (auto-populated from template)
