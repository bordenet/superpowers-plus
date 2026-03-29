# Installing Superpowers Plus for Codex

58 domain skills for wiki editing, issue tracking, security audits, and more. Extends [obra/superpowers](https://github.com/obra/superpowers) (14 core workflow skills).

## Prerequisites

- **bash 4+** — macOS ships bash 3.2; run `brew install bash` first
- **git** — macOS: `xcode-select --install`
- **Node.js 18+** — macOS: `brew install node`

The installer detects missing prerequisites and tells you exactly how to fix them.

## Installation

```bash
git clone https://github.com/bordenet/superpowers-plus.git ~/.codex/superpowers-plus
cd ~/.codex/superpowers-plus
bash install.sh
```

The installer automatically:

- Installs obra/superpowers if missing
- Deploys skills to `~/.codex/skills/` and `~/.claude/skills/`
- Sets up the bootstrap script and agent configuration
- Auto-fixes CRLF line endings on Windows/WSL

> **Windows/WSL:** Run from within WSL-Ubuntu, not Windows cmd/PowerShell.

## Verify Installation

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
# Expected: ~72 skills (58 superpowers-plus + 14 obra/superpowers)
```

## Updating

```bash
cd ~/.codex/superpowers-plus
bash install.sh --upgrade
```

## Uninstalling

```bash
bash install.sh --uninstall
```

## What You Get

**From obra/superpowers (installed automatically):**

- brainstorming, writing-plans, executing-plans
- test-driven-development, systematic-debugging
- subagent-driven-development, using-git-worktrees
- 14 core workflow skills

**From superpowers-plus (58 skills):**

- Wiki editing and verification skills
- Issue tracking patterns (Linear, GitHub, Jira)
- Security audit skills (secret detection, IP audit)
- Engineering skills (pre-commit gates, blast radius)
- Observability and research skills
- AI slop detection for writing
- TODO management and archival

## Getting Help

- superpowers-plus issues: <https://github.com/bordenet/superpowers-plus/issues>
- obra/superpowers issues: <https://github.com/obra/superpowers/issues>
