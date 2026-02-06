---
name: readme-authoring
description: Use when creating or updating README.md files - enforces enterprise-grade best practices, integrates AI slop detection, and ensures quickstart-first structure with concrete examples
---

# README Authoring

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-06

## Overview

Author and maintain README.md files that onboard contributors in <5 minutes. Treat the README as your project's **API documentation for humans**.

**Core principles:**

- Quickstart first. Delete adjectives. Show, don't tell.
- Markdown only (no HTML/JS gimmicks unless critical).
- <2000 lines; link to docs/ for depth.
- Mobile-friendly (short lines, no wide tables).

---

## When to Use

Invoke when:

- Creating a new repository README
- Updating an existing README
- Before major releases (README audit)
- User says: "Write/update/review the README"

---

## README Structure (Priority Order)

### 1. Header (First Screen) - REQUIRED

```markdown
# project-name

[![Build](https://img.shields.io/...)](link) [![License](https://img.shields.io/...)](link)

> One sentence: what it does + why you'd use it.

[Try in 2min →](quickstart-link)
```

**Bad:** "A comprehensive, cutting-edge solution for modern development workflows."
**Good:** "Detects AI-generated text in resumes and cover letters."

### 2. Badges (3-5 max)

Include only badges that provide value:

- Build status (if CI exists)
- Version/release
- Coverage (if tracked)
- License
- Downloads/stars (only if >1000)

Skip vanity badges. Order: version → license → CI → coverage.

### 3. Table of Contents (if >500 lines)

```markdown
## Contents

- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [API](#api)
- [Contributing](#contributing)
- [License](#license)
```

Auto-generate via Markdown TOC extension. Skip for short READMEs.

### 4. Quick Start (REQUIRED - first code block)

User should be running your code in <60 seconds.

```markdown
## Quick Start

\`\`\`bash
# Clone & install (one command ideal)
git clone https://github.com/org/project
cd project && npm install
npm start
\`\`\`
```

Max 5 steps. If longer, you have an installation problem.

### 5. Usage Examples (REQUIRED)

Show 2-3 concrete examples. Code must be runnable.

```markdown
## Usage

\`\`\`bash
# Basic usage
your-tool input.txt

# With options
your-tool input.txt --format=json --verbose
\`\`\`

[Screenshot/GIF of output if applicable]
```

### 6. Why This Project? (optional but recommended)

```markdown
## Why project-name?

| vs Alternative | Advantage |
|----------------|-----------|
| Tool A         | 3x faster |
| Tool B         | No config required |
```

No fluff; link whitepaper/demo if available.

### 7. Configuration / API

```markdown
## Configuration

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--port` | int | 8080 | Server port |

Full schema: [config.md](./docs/config.md)
```

Keep brief - link to full docs.

### 8. Features/What It Does

Bullet list. No adjectives. Each feature links to docs or example.

**Bad:** "Incredibly powerful detection engine"
**Good:** "Detects 300+ AI slop patterns across 13 content types"

### 9. Directory Structure (optional - if complex)

ASCII tree for projects with >10 files.

### 10. Contributing / Development

```markdown
## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

### Development

\`\`\`bash
npm run dev
npm test
\`\`\`
```

### 11. Support / Community

```markdown
## Support

- 🚨 Bug reports: [Issues](https://github.com/org/project/issues)
- 💬 Discussions: [Discussions](https://github.com/org/project/discussions)
- 📖 Docs: [docs.project.io](https://docs.project.io)
```

### 12. License

Single line: "MIT" or "Apache 2.0" with link to LICENSE file.

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Personal/hobby vibe | Emojis everywhere, ASCII art, Spotify playlists | Professional tone, minimal decoration |
| Broken/outdated | Dead badges, untested quickstart | Automated link checks, test examples |
| Bloat | Full API docs, changelogs inline | Link to CHANGELOG.md, docs/ |
| No quickstart | Walls of text before "go" button | Code block in first 20 lines |
| Missing basics | No license, no TOC for long docs | Always include LICENSE, TOC if >500 lines |
| Wide tables | Break on mobile | Keep tables <80 chars or use lists |

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
2. Target slop score: **<20** for READMEs
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
- [ ] No marketing language (slop score <20)

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

```text
[GVR: 1 iteration | removed 3 patterns | σ: 14.2 | TTR: 0.58]
README slop score: 18/100 ✓
Markdown lint: PASS (0 errors)
```

**If lint fails, fix before reporting completion.**

---

## Example: Rewriting a Bad Opening

**Before (slop score: 67):**
> "SuperTool is a comprehensive, cutting-edge solution that seamlessly integrates into your workflow to provide powerful capabilities for modern development teams."

**After (slop score: 12):**
> "SuperTool runs your tests in parallel across 8 cores. Install in 10 seconds: `npm i -g supertool`"

---

## Automation (Recommended)

Set up GitHub Actions for:

1. **Markdown lint** - markdownlint on PRs
2. **Link checker** - Detect dead links automatically
3. **Badge updates** - Auto-update coverage/version badges

Example workflow:

```yaml
# .github/workflows/docs.yml
name: Docs
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npx markdownlint-cli2 "**/*.md"
```

---

## Resources

Based on patterns from:

- [matiassingers/awesome-readme](https://github.com/matiassingers/awesome-readme)
- [Art of README](https://github.com/hackergrrl/art-of-readme)
- [Make a README](https://www.makeareadme.com/)
- [jehna/readme-best-practices](https://github.com/jehna/readme-best-practices)
- [othneildrew/Best-README-Template](https://github.com/othneildrew/Best-README-Template)

Exemplars: Kubernetes (actionable), Google Style Guides (minimalist).

---

## Related Skills

- **detecting-ai-slop**: Analyze README for slop score
- **eliminating-ai-slop**: GVR loop for clean generation
- **brainstorming**: Before creating README, brainstorm structure
