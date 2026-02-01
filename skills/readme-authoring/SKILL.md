---
name: readme-authoring
description: Use when creating or updating README.md files - enforces best practices from awesome-readme, integrates AI slop detection, and ensures quickstart-first structure with concrete examples
---

# README Authoring

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-01

## Overview

Author and maintain README.md files that get people using your project in under 60 seconds. Eliminate marketing language. Lead with runnable examples.

**Core principle:** Quickstart first. Delete adjectives. Show, don't tell.

---

## When to Use

Invoke when:
- Creating a new repository README
- Updating an existing README
- Before major releases (README audit)
- User says: "Write/update/review the README"

---

## README Structure (Priority Order)

### 1. Project Name + One-Line Description (REQUIRED)

```markdown
# project-name

One sentence: what it does + why you'd use it.
```

**Bad:** "A comprehensive, cutting-edge solution for modern development workflows."
**Good:** "Detects AI-generated text in resumes and cover letters."

### 2. Badges (Optional - only if meaningful)

Include only badges that provide value:
- Build status (if CI exists)
- Version/release
- Coverage (if tracked)
- License

Skip vanity badges (stars, downloads) unless >1000.

### 3. Quick Start (REQUIRED - first code block)

User should be running your code in <60 seconds.

```markdown
## Quick Start

\`\`\`bash
npm install your-package
npx your-package --help
\`\`\`
```

Max 5 steps. If longer, you have an installation problem.

### 4. Usage Examples (REQUIRED)

Show 2-3 concrete examples. Code must be runnable.

```markdown
## Usage

\`\`\`bash
# Basic usage
your-tool input.txt

# With options
your-tool input.txt --format=json --verbose
\`\`\`
```

### 5. Installation (if different from Quick Start)

Only if quick start didn't cover full installation:
- Prerequisites
- System requirements
- Configuration

### 6. Features/What It Does

Bullet list. No adjectives. Each feature links to docs or example.

**Bad:** "Incredibly powerful detection engine"
**Good:** "Detects 300+ AI slop patterns across 13 content types"

### 7. API/Commands Reference (if applicable)

Table or list format. Keep brief - link to full docs.

### 8. Directory Structure (optional - if complex)

ASCII tree for projects with >10 files.

### 9. Contributing

Link to CONTRIBUTING.md or brief inline guidelines.

### 10. License

Single line: "MIT" or "Apache 2.0" with link.

---

## Anti-Slop Rules for READMEs

### Delete These Words

| Word/Phrase | Replacement |
|-------------|-------------|
| comprehensive | list what's covered |
| cutting-edge | name the technology |
| world-class | delete entirely |
| seamless/seamlessly | describe the mechanism |
| robust | specify failure handling |
| powerful | quantify capability |
| innovative | describe what's new |
| state-of-the-art | cite the paper/version |
| elegant | delete entirely |
| intuitive | show a 3-second example |

### Delete These Phrases

- "In today's fast-paced world"
- "It's important to note that"
- "Let's dive into"
- "This project aims to"
- "We believe that"

### Replace Vague Claims

| Vague | Concrete |
|-------|----------|
| "Fast" | "Responds in <50ms" |
| "Scalable" | "Tested to 10K concurrent users" |
| "Easy to use" | Show a 3-line example |
| "Flexible" | List the configuration options |
| "Secure" | Name the security measures |

---

## Markdown Linting (REQUIRED)

**Before committing ANY markdown changes, run the linter.**

### Common Lint Errors

| Rule | Error | Fix |
|------|-------|-----|
| MD058 | Tables need blank lines | Add blank line before AND after every table |
| MD009 | Trailing spaces | Remove trailing whitespace |
| MD012 | Multiple blank lines | Use single blank lines only |
| MD022 | Headers need blank lines | Add blank line before AND after headers |
| MD031 | Fenced code needs blank lines | Add blank line before AND after code blocks |
| MD032 | Lists need blank lines | Add blank line before AND after lists |
| MD047 | File should end with newline | Add trailing newline |

### Pre-Commit Check

```bash
# If markdownlint-cli2 is available
npx markdownlint-cli2 "README.md"

# Or with markdownlint
npx markdownlint README.md --fix
```

### Table Formatting (MD058)

**Wrong:**
```markdown
Some text
| Column | Column |
|--------|--------|
| data   | data   |
More text
```

**Correct:**
```markdown
Some text

| Column | Column |
|--------|--------|
| data   | data   |

More text
```

### Self-Check Before Commit

1. Run linter: `npx markdownlint-cli2 "README.md"`
2. Fix all errors (no exceptions)
3. Verify CI will pass

**If you skip linting, you WILL break CI.**

---

## Integration with AI Slop Detection

Before finalizing any README:

1. Run `detecting-ai-slop` on the content
2. Target bullshit factor: **<20** for READMEs
3. Fix all flagged patterns
4. Verify sentence variance (σ >12)

**Auto-invoke:** When generating README content, use GVR loop from `eliminating-ai-slop`.

---

## README Audit Checklist

Run before releases or quarterly:

- [ ] **Markdown lint passes** (`npx markdownlint-cli2 "README.md"`)
- [ ] One-line description is concrete, not vague
- [ ] Quick Start works (test it!)
- [ ] Examples are runnable (copy-paste test)
- [ ] No dead links
- [ ] Badges are current
- [ ] Version numbers match release
- [ ] Screenshots/GIFs are current
- [ ] No marketing language (bullshit factor <20)

---

## Maintenance Mode

For existing READMEs, check:

1. **Links:** `grep -E '\[.*\]\(http' README.md` - verify each
2. **Version refs:** Search for version numbers, update if stale
3. **Examples:** Run each code example
4. **Screenshots:** Compare to current UI

---

## GVR Transparency

After generating README content, report:

```
[GVR: 1 iteration | removed 3 patterns | σ: 14.2 | TTR: 0.58]
README bullshit factor: 18/100 ✓
Markdown lint: PASS (0 errors)
```

**If lint fails, fix before reporting completion.**

---

## Example: Rewriting a Bad Opening

**Before (bullshit factor: 67):**
> "SuperTool is a comprehensive, cutting-edge solution that seamlessly integrates into your workflow to provide powerful capabilities for modern development teams."

**After (bullshit factor: 12):**
> "SuperTool runs your tests in parallel across 8 cores. Install in 10 seconds: `npm i -g supertool`"

---

## Resources

Based on patterns from:
- [matiassingers/awesome-readme](https://github.com/matiassingers/awesome-readme)
- [Art of README](https://github.com/hackergrrl/art-of-readme)
- [Make a README](https://www.makeareadme.com/)

---

## Related Skills

- **detecting-ai-slop**: Analyze README for bullshit factor
- **eliminating-ai-slop**: GVR loop for clean generation
- **brainstorming**: Before creating README, brainstorm structure

