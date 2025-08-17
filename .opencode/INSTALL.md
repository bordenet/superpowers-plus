# Installing Superpowers Plus for OpenCode

Extended domain skills for wiki editing, issue tracking, security audits, and more.

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- Git
- **obra/superpowers** (core workflow skills) - will be installed if missing

## Installation

### Step 1: Install obra/superpowers (Prerequisite)

Check if superpowers is already installed:

```bash
ls ~/.config/opencode/superpowers/skills 2>/dev/null && echo "✓ superpowers installed" || echo "✗ superpowers not found"
```

**If not installed**, follow the [superpowers OpenCode installation](https://github.com/obra/superpowers/blob/main/.opencode/INSTALL.md):

```bash
# Clone superpowers
git clone https://github.com/obra/superpowers.git ~/.config/opencode/superpowers

# Register the plugin
mkdir -p ~/.config/opencode/plugins
rm -f ~/.config/opencode/plugins/superpowers.js
ln -s ~/.config/opencode/superpowers/.opencode/plugins/superpowers.js ~/.config/opencode/plugins/superpowers.js

# Symlink skills
mkdir -p ~/.config/opencode/skills
rm -rf ~/.config/opencode/skills/superpowers
ln -s ~/.config/opencode/superpowers/skills ~/.config/opencode/skills/superpowers
```

### Step 2: Install superpowers-plus

```bash
# Clone superpowers-plus
git clone https://github.com/bordenet/superpowers-plus.git ~/.config/opencode/superpowers-plus

# Symlink skills
ln -sf ~/.config/opencode/superpowers-plus/skills ~/.config/opencode/skills/superpowers-plus
```

### Step 3: Restart OpenCode

Restart OpenCode. Verify by asking: "do you have superpowers?"

## Verify Installation

```bash
ls -la ~/.config/opencode/skills/superpowers ~/.config/opencode/skills/superpowers-plus
```

Both should be symlinks pointing to their respective skill directories.

## Usage

### Finding Skills

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
```

### Loading a Skill

```
use skill tool to load superpowers-plus/wiki-authoring
```

## Updating

```bash
cd ~/.config/opencode/superpowers && git pull
cd ~/.config/opencode/superpowers-plus && git pull
```

## Uninstalling

```bash
# Remove superpowers-plus only
rm -rf ~/.config/opencode/skills/superpowers-plus
rm -rf ~/.config/opencode/superpowers-plus

# Remove superpowers (optional)
rm ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers
rm -rf ~/.config/opencode/superpowers
```

## What You Get

**From obra/superpowers (prerequisite):**
- Core workflow: brainstorming, writing-plans, executing-plans
- Testing: test-driven-development
- Debugging: systematic-debugging, verification-before-completion
- Collaboration: subagent-driven-development, using-git-worktrees

**From superpowers-plus:**
- Wiki: wiki-authoring, wiki-verify, link-verification
- Issue Tracking: issue-authoring, issue-link-verification
- Security: secret-detection, public-repo-ip-audit
- Writing: AI slop detection, professional language audit
- Engineering: pre-commit gates, blast radius checks

## Getting Help

- superpowers-plus: https://github.com/bordenet/superpowers-plus/issues
- obra/superpowers: https://github.com/obra/superpowers/issues
