# Claude Code Guidelines for superpowers-plus

This repository contains personal Claude/Augment skills extending [obra/superpowers](https://github.com/obra/superpowers).

## Quick Start

1. Skills live in `skills/<skill-name>/SKILL.md`
2. Run `./install.sh` to deploy skills to `~/.codex/skills/`
3. Test with `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <skill-name>`

## Skill File Format

Each skill must have:

```yaml
---
name: skill-name-with-hyphens
description: Use when [specific triggering conditions and symptoms]
---

# Skill Name

## Overview
...
```

**Critical rules:**
- `name`: Letters, numbers, hyphens only (no parentheses, special chars)
- `description`: Start with "Use when...", max 500 chars, third person
- Description describes WHEN to use, NOT what the skill does

## Creating Skills

Follow the TDD approach from `superpowers:writing-skills`:

1. **RED:** Run pressure scenario WITHOUT skill, document baseline behavior
2. **GREEN:** Write minimal skill addressing those specific failures
3. **REFACTOR:** Close loopholes, add rationalization tables

## Pre-Commit Checklist

Before committing skill changes:

- [ ] SKILL.md has valid YAML frontmatter
- [ ] `name` uses only letters, numbers, hyphens
- [ ] `description` starts with "Use when..."
- [ ] Skill tested with `use-skill` command
- [ ] `./install.sh` runs without errors

## Directory Structure

```
skills/
  skill-name/
    SKILL.md              # Main skill file (required)
    README.md             # Optional documentation
    supporting-file.*     # Optional supporting files
```

## Skill Categories

| Category | Examples |
|----------|----------|
| **Writing/Editing** | reviewing-ai-text |
| **Code Quality** | enforce-style-guide |
| **Recruiting** | resume-screening, phone-screen-prep |

## Testing Skills

```bash
# Install skills
./install.sh

# List available skills
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills

# Load a specific skill
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill reviewing-ai-text
```

## Relationship to Other Repos

| Repo | Purpose |
|------|---------|
| `obra/superpowers` | Core superpowers framework (upstream) |
| `bordenet/superpowers-plus` | Personal skills (this repo) |
| `bordenet/scripts` | Shell scripts with enforce-style-guide integration |

## Author

Matt J Bordenet (@bordenet)

