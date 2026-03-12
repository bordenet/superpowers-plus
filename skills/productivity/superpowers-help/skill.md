---
name: superpowers-help
source: superpowers-plus
triggers: ["what skills do I have", "list available skills", "superpowers help", "how do I use skills", "what can you do", "show me your capabilities"]
description: Lists all superpowers-plus skills by category with invocation examples. Use when discovering available capabilities or explaining how skills work.
---

# Superpowers Help

> **Repository:** https://github.com/bordenet/superpowers-plus
> **Version:** 2.1.0
> **Built on:** [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent

superpowers-plus extends the [obra/superpowers](https://github.com/obra/superpowers) framework with additional skills for wiki editing, issue tracking, security audits, and AI text quality. The core superpowers framework (brainstorming, systematic-debugging, TDD, etc.) is installed as a prerequisite.

## Available Skills (40 total)

### Engineering (5 skills)

| Skill | Triggers On |
|-------|-------------|
| **blast-radius-check** | Modifying existing code, refactoring, changing APIs |
| **engineering-rigor** | Code quality gate requests |
| **pre-commit-gate** | Pre-commit checks, lint/typecheck/test requests |
| **providing-code-review** | Reviewing PRs, code review requests |
| **receiving-code-review** | Implementing review feedback |

### Issue Tracking (5 skills)

| Skill | Triggers On |
|-------|-------------|
| **issue-authoring** | Creating issues, tickets, bugs |
| **issue-comment-debunker** | Before posting issue comments |
| **issue-editing** | Updating existing issues |
| **issue-link-verification** | Adding URLs to issues |
| **issue-verify** | Referencing issues in commits/PRs |

### Observability (4 skills)

| Skill | Triggers On |
|-------|-------------|
| **completeness-check** | Detecting incomplete work |
| **exhaustive-audit-validation** | Before claiming audits complete |
| **holistic-repo-verification** | Full repository health checks |
| **skill-firing-tracker** | Logging skill invocations |

### Productivity (5 skills)

| Skill | Triggers On |
|-------|-------------|
| **enforce-style-guide** | Code style enforcement |
| **golden-agents** | Initializing repos with AI guidance |
| **superpowers-help** | "what skills do I have", "superpowers help" |
| **think-twice** | Stuck on problems, need fresh approach |
| **todo-management** | Task capture, tracking, triage |

### Research (2 skills)

| Skill | Triggers On |
|-------|-------------|
| **incorporating-research** | Merging external research |
| **perplexity-research** | Stuck after 2+ failed attempts |

### Security (2 skills)

| Skill | Triggers On |
|-------|-------------|
| **public-repo-ip-audit** | Auditing public repos for IP |
| **security-upgrade** | Scanning for CVEs, upgrading deps |

### TypeScript (5 skills)

| Skill | Triggers On |
|-------|-------------|
| **cognitive-complexity-refactoring** | High complexity warnings |
| **field-rename-verification** | Renaming fields, API changes |
| **typescript-project-conventions** | Import ordering, file size |
| **typescript-strict-mode** | Type errors, strict checks |
| **vitest-testing-patterns** | Mock issues, test failures |

### Wiki (7 skills)

| Skill | Triggers On |
|-------|-------------|
| **link-verification** | Adding repo/wiki/external links |
| **wiki-authoring** | Formatting wiki content |
| **wiki-debunker** | Verifying factual claims |
| **wiki-editing** | Editing wiki pages |
| **wiki-orchestrator** | Creating/updating wiki (default entry) |
| **wiki-secret-audit** | Scanning for exposed secrets |
| **wiki-verify** | Verifying codebase references |

### Writing (5 skills)

| Skill | Triggers On |
|-------|-------------|
| **detecting-ai-slop** | "calculate slop score", analyzing AI text |
| **eliminating-ai-slop** | "remove slop", rewriting AI text |
| **professional-language-audit** | Profanity/language checks |
| **readme-authoring** | Creating/updating READMEs |
| **reviewing-ai-text** | Editing AI-generated content |

---

## Invocation by Platform

### Claude Code

Skills auto-load. Use slash commands:
```
/skill-name
```

Or ask naturally — triggers fire automatically.

### Augment

Bootstrap at session start:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

Load specific skill:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:skill-name
```

List all skills:
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

### Cursor

Bootstrap at session start:
```bash
superpowers-cursor bootstrap
```

### Codex (OpenAI)

Bootstrap at session start:
```bash
superpowers-codex bootstrap
```

---

## Installation

### Method 1: Direct Clone (Power Users)

```bash
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus
./install.sh
```

### Method 2: Upgrade Existing

```bash
cd ~/path/to/superpowers-plus
./install.sh --upgrade
```

### Check Version

```bash
./install.sh --version
# install.sh version 2.1.0
```

---

## Documentation

- **Full README:** https://github.com/bordenet/superpowers-plus#readme
- **Architecture:** https://github.com/bordenet/superpowers-plus/blob/main/docs/ARCHITECTURE.md
- **Contributing:** https://github.com/bordenet/superpowers-plus/blob/main/docs/CONTRIBUTING.md
