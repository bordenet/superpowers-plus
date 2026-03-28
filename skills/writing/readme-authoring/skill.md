---
name: readme-authoring
source: superpowers-plus
triggers: ["create README", "update README", "write README", "improve README", "README best practices"]
anti_triggers: ["write skill file", "create skill", "skill.md format"]
description: Use when creating or updating README.md files - enforces best practices, applies AI slop detection, quickstart-first structure.
summary: "Use when: creating or updating README.md files."
coordination:
  group: writing
  order: 3
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# README Authoring

> **Wrong skill?** Skill file authoring → `skill-authoring` / `writing-skills`. Wiki pages → `wiki-orchestrator`. Plan/roadmap → `plan-quality-gates`.

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-06

## Approach

Author and maintain README.md files that onboard contributors in <5 minutes. Treat the README as your project's **API documentation for humans**.

**Core principles:**

- Quickstart first. Delete adjectives. Show, don't tell.
- Markdown only (no HTML/JS gimmicks unless critical).
- <2000 lines; link to docs/ for depth.
- Mobile-friendly (short lines, no wide tables).


## When to Use

Invoke when:

- Creating a new repository README
- Updating an existing README
- Before major releases (README audit)
- User says: "Write/update/review the README"


## Scope Exclusions

- Wiki page writing → `wiki-orchestrator`
- Skill file writing → `skill-authoring`
- AI slop removal → `eliminating-ai-slop`

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

### 6-12. Remaining Sections

| # | Section | Notes |
|---|---------|-------|
| 6 | Why This Project? | Optional. Comparison table vs alternatives |
| 7 | Configuration/API | Brief table of flags; link to full docs |
| 8 | Features | Bullet list, no adjectives, link to docs |
| 9 | Directory Structure | Optional. ASCII tree for >10 files |
| 10 | Contributing | Link to CONTRIBUTING.md + dev commands |
| 11 | Support/Community | Bug reports, discussions, docs links |
| 12 | License | Single line: "MIT" with link to LICENSE |


## Anti-Patterns

No emoji spam/ASCII art · no dead badges · no inline API docs (link to docs/) · quickstart in first 20 lines · always LICENSE + TOC for long docs · tables <80 chars.

**Slop:** Target score <20. Use `references/anti-slop-rules.md` + GVR loop from `eliminating-ai-slop`.

**Lint:** `npx markdownlint-cli2 "README.md"` before every commit. See `references/linting-rules.md`.

## Audit Checklist

Lint passes · description concrete · quickstart works · examples runnable · no dead links · badges current · versions match.
- [ ] Screenshots/GIFs are current
- [ ] No marketing language (slop score <20)


## Maintenance Mode

For existing READMEs, check:

1. **Links:** `grep -E '\[.*\]\(http' README.md` - verify each
2. **Version refs:** Search for version numbers, update if stale
3. **Examples:** Run each code example
4. **Screenshots:** Compare to current UI


## GVR Transparency

After generating README content, report:

```text
[GVR: 1 iteration | removed 3 patterns | σ: 14.2 | TTR: 0.58]
README slop score: 18/100 ✓
Markdown lint: PASS (0 errors)
```

**If lint fails, fix before reporting completion.**


## Companion Skills

- **detecting-ai-slop**: Analyze README for slop score
- **eliminating-ai-slop**: GVR loop for clean generation
- **brainstorming**: Before creating README, brainstorm structure
- **markdown-table-discipline**: Table formatting in READMEs
- **golden-agents**: AGENTS.md generation
## Related Tools

For executive summaries or go/no-go decisions, use [docforge-ai one-pager](https://bordenet.github.io/docforge-ai/assistant/?type=one-pager) — adversarial review scores urgency, alternatives, and measurable outcomes.

## Example

```bash
# Validate README structure
head -1 README.md | grep -q "^# " || echo "Missing title"
grep -c "## " README.md  # count sections
```

## Failure Modes

- **AI slop in README:** Phrases like "robust solution" or "This README provides" — run eliminating-ai-slop after drafting
- **Missing prerequisites section:** Users can't get started without knowing what to install first
- **Stale examples:** Code examples that no longer compile or reference deprecated APIs

## References

- [`references/anti-slop-rules.md`](references/anti-slop-rules.md) — Word/phrase blocklist, vague→concrete replacements, rewriting examples
- [`references/linting-rules.md`](references/linting-rules.md) — Common lint errors (MD058, MD009, etc.), table formatting, pre-commit checks
- [`references/automation-resources.md`](references/automation-resources.md) — GitHub Actions workflow, link checker setup, exemplar READMEs
