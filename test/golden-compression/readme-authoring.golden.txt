# Skill: readme-authoring

# README Authoring

> Guidelines: See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> Last Updated: 2026-02-06
## Approach
Author and maintain README.md files that onboard contributors in <5 minutes. Treat the README as your project's **API documentation for humans**.

**Core principles:**

- Quickstart first. Delete adjectives. Show, don't tell.
- Markdown only (no HTML/JS gimmicks unless critical).
- <2000 lines; link to docs/ for depth.
- Mobile-friendly (short lines, no wide tables).
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
## Contents (auto-generate via TOC extension, skip for short READMEs)
```
### 4. Quick Start (REQUIRED)
User runs your code in <60 seconds. Max 5 steps. If longer, you have an installation problem.
### 5. Usage Examples (REQUIRED)
2-3 concrete, runnable examples. Screenshot/GIF if applicable.
### 6-12. Remaining Sections
| # | Section | Notes |
|---|---------|-------|
| 6 | Why This Project? | Optional. Comparison table vs alternatives |
| 7 | Configuration/API | Brief flags table; link to full docs |
| 8 | Features | Bullet list, no adjectives |
| 9 | Directory Structure | Optional. ASCII tree for >10 files |
| 10 | Contributing | Link to CONTRIBUTING.md |
| 11 | Support/Community | Bug reports, discussions links |
| 12 | License | Single line: "MIT" with link |
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
## Failure Modes
- **AI slop in README:** Phrases like "robust solution" or "This README provides" — run eliminating-ai-slop after drafting
- **Missing prerequisites section:** Users can't get started without knowing what to install first
- **Stale examples:** Code examples that no longer compile or reference deprecated APIs
## References
- [`references/anti-slop-rules.md`](references/anti-slop-rules.md) — Word/phrase blocklist, vague→concrete replacements, rewriting examples
- [`references/linting-rules.md`](references/linting-rules.md) — Common lint errors (MD058, MD009, etc.), table formatting, pre-commit checks
- [`references/automation-resources.md`](references/automation-resources.md) — GitHub Actions workflow, link checker setup, exemplar READMEs
