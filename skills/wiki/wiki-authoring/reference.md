# Wiki Authoring - Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Detailed formatting rules and tooling setup.

---

## Content Patterns for Common Topics

### Workflow Documentation

When documenting workflows, use this structure:

```markdown
## Workflow Name

Brief description of what this workflow accomplishes.

**Best Practices:**
- Bullet points for quick scanning
- Include cadence (daily, weekly)
- Note who owns the workflow

### Steps

1. First step with clear action
2. Second step with expected outcome
3. Third step with verification

### Related Documents

- [Related Wiki Page](/doc/xyz)
```

### Service Architecture Docs

```markdown
## Service Name

| Field | Value |
|-------|-------|
| Team | Team Name |
| Language | Go/TypeScript/etc |
| Repo | [repo-name]([your-repo-url]) |

### Overview

One paragraph explaining what this service does and why it exists.

### Key Components

#### component-name — Purpose

Detailed description...
```

---

## Table Formatting

### ✅ Always Include Blank Lines

```markdown
Some text before the table.

| Column 1 | Column 2 |
|----------|----------|
| Data | Data |

Some text after the table.
```

### ❌ Never Omit Spacing

```markdown
Some text before the table.
| Column 1 | Column 2 |
|----------|----------|
This may break rendering.
```

---

## Linting Tools

### VS Code Setup (Recommended)

Install the **markdownlint** extension from David Anson — lints with 100+ rules for consistency.

**Setup Steps:**
1. Open VS Code → Extensions (`Ctrl/Cmd+Shift+X`) → Search "markdownlint" → Install
2. Export wiki page to Markdown → Open `.md` file → Linting activates
3. Fix issues: Hover wavy underlines for details; `Ctrl/Cmd + .` quick-fixes many rules

### CLI Usage

```bash
# Install CLI
npm install -g markdownlint-cli2

# Lint a file
npx markdownlint-cli2 "wiki-page.md"

# Auto-fix
npx markdownlint "wiki-page.md" --fix
```

### Other Tools

| Tool | Language | Best For |
|------|----------|----------|
| **remark-lint** | JS | CI/CD pipelines, custom rules |
| **mdformat** | Python | Pre-commit hooks, auto-formatting |
| **textlint** | JS | Grammar + style (typos, passive voice) |
| **Mega-Linter** | GitHub Action | All-in-one CI |

### Wiki-Specific Configuration

Create `.markdownlint.json` in project root:

```json
{
  "default": true,
  "MD013": { "code_blocks": false, "line_length": 120 },
  "MD033": { "allowed_elements": ["ins", "del"] },
  "MD041": false,
  "MD024": { "siblings_only": true },
  "MD040": true
}
```

| Rule | Setting | Reason |
|------|---------|--------|
| MD013 (line length) | `code_blocks: false` | Allow long code lines |
| MD033 (inline HTML) | `allowed_elements` | Permit `<ins>`/`<del>` |
| MD041 (first line H1) | `false` | Wiki shows title in UI |
| MD024 (duplicate headings) | `siblings_only` | Allow same H3 under different H2s |
| MD040 (fenced code language) | `true` | Enforce syntax highlighting |

### Pre-Commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.41.0
    hooks:
      - id: markdownlint
        args: ["--fix"]
```

---

## Code Block Language Tags

Always specify language for syntax highlighting:

| Language | Tag |
|----------|-----|
| Bash/Shell | `bash` or `sh` |
| JavaScript | `javascript` or `js` |
| TypeScript | `typescript` or `ts` |
| Python | `python` |
| JSON | `json` |
| YAML | `yaml` |
| SQL | `sql` |
| Plain text | `text` or `plaintext` |

---

## Callout Formatting

### Info/Warning Callouts

Use blockquotes with bold prefix:

```markdown
> **Note:** This is important information.

> **Warning:** Be careful with this operation.

> **Tip:** Try this for better results.
```

### ❌ Avoid Special Syntax

Some platforms don't support:
- `> [!info]` → Escaped as `\[!info\]`
- `> [!warning]` → Use `> **Warning:**` instead
- `:::info` containers → Not portable
