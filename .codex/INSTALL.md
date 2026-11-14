# Installing Superpowers Plus for Codex

125 skills for engineering workflows, code review, wiki editing, issue tracking, security audits, and more. Extends [obra/superpowers](https://github.com/obra/superpowers); all 14 of its core workflow skills are bundled.

## Prerequisites

- **bash 4+**: macOS ships bash 3.2; run `brew install bash` first
- **git**: macOS: `xcode-select --install`
- **Node.js 18+**: macOS: `brew install node`
- **Python 3**: macOS: `brew install python3`

The installer detects missing prerequisites and tells you exactly how to fix them.

## Installation

```bash
git clone https://github.com/bordenet/superpowers-plus.git ~/.codex/superpowers-plus
cd ~/.codex/superpowers-plus
bash install.sh
```

The installer automatically:

- Includes the 14 bundled obra/superpowers skills (no separate install)
- Deploys skills to `~/.codex/skills/` and `~/.claude/skills/`
- Sets up the bootstrap script and agent configuration
- Auto-fixes CRLF line endings on Windows/WSL

> **Windows (no WSL):** In PowerShell run `git clone https://github.com/bordenet/superpowers-plus.git $HOME\.codex\superpowers-plus`, `cd $HOME\.codex\superpowers-plus`, then `powershell -ExecutionPolicy Bypass -File .\install.ps1`. Run it from a normal (not elevated) PowerShell; it refuses to run elevated. It installs missing Python and jq with winget and runs `install.sh` under Git Bash. If Git for Windows or Node.js is missing, it stops and prints the `winget install` command to run from an elevated PowerShell first.

## Verify Installation

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
# Expected: the 125 superpowers-plus skills (14 bundled from obra/superpowers), plus any others installed
```

## Updating

```bash
cd ~/.codex/superpowers-plus
bash install.sh --upgrade
```

Windows (PowerShell): run `git pull` in `$HOME\.codex\superpowers-plus`, then `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

## Uninstalling

```bash
bash install.sh --uninstall
```

Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall`

## What You Get

**From obra/superpowers (bundled):**

- brainstorming, writing-plans, executing-plans
- test-driven-development, systematic-debugging
- subagent-driven-development, using-git-worktrees
- 14 core workflow skills

**Added by superpowers-plus:**

- Wiki editing and verification skills
- Issue tracking patterns (GitHub and Jira adapters, plus a template for others)
- Security audit skills (secret detection, IP audit)
- Engineering skills (pre-commit gates, blast radius)
- Observability and research skills
- AI slop detection for writing
- TODO management and archival

## Getting Help

- superpowers-plus issues: <https://github.com/bordenet/superpowers-plus/issues>
- obra/superpowers issues: <https://github.com/obra/superpowers/issues>
