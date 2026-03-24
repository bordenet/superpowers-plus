# Installing Superpowers Plus for OpenCode

58 domain skills for wiki editing, issue tracking, security audits, and more. Extends [obra/superpowers](https://github.com/obra/superpowers) (14 core workflow skills).

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- **bash 4+** — macOS ships bash 3.2; run `brew install bash` first
- **git** — macOS: `xcode-select --install`
- **Node.js 18+** — macOS: `brew install node`

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

### Restart OpenCode

Restart OpenCode after installation to discover the skills.

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
- Wiki: wiki-orchestrator, wiki-verify, link-verification
- Issue Tracking: issue-authoring, issue-link-verification (Linear, GitHub, Jira)
- Security: secret-detection, public-repo-ip-audit
- Writing: AI slop detection, professional language audit
- Engineering: pre-commit gates, blast radius checks
- TODO management, archival, and maintenance

## Getting Help

- superpowers-plus: https://github.com/bordenet/superpowers-plus/issues
- obra/superpowers: https://github.com/obra/superpowers/issues
