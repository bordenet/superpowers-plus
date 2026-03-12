# Installing Superpowers Plus for Codex

Extended domain skills for wiki editing, issue tracking, security audits, and more.

## Prerequisites

- Git
- **obra/superpowers** (core workflow skills) - will be installed if missing

## Installation

### Step 1: Install obra/superpowers (Prerequisite)

Check if superpowers is already installed:

```bash
ls ~/.codex/superpowers/skills 2>/dev/null && echo "✓ superpowers installed" || echo "✗ superpowers not found"
```

**If not installed**, install it first:

```bash
git clone https://github.com/obra/superpowers.git ~/.codex/superpowers
mkdir -p ~/.agents/skills
ln -sf ~/.codex/superpowers/skills ~/.agents/skills/superpowers
```

### Step 2: Install superpowers-plus

```bash
git clone https://github.com/bordenet/superpowers-plus.git ~/.codex/superpowers-plus
ln -sf ~/.codex/superpowers-plus/skills ~/.agents/skills/superpowers-plus
```

**Windows (PowerShell):**

```powershell
# Step 1: Install superpowers if not present
if (-not (Test-Path "$env:USERPROFILE\.codex\superpowers")) {
    git clone https://github.com/obra/superpowers.git "$env:USERPROFILE\.codex\superpowers"
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
    cmd /c mklink /J "$env:USERPROFILE\.agents\skills\superpowers" "$env:USERPROFILE\.codex\superpowers\skills"
}

# Step 2: Install superpowers-plus
git clone https://github.com/bordenet/superpowers-plus.git "$env:USERPROFILE\.codex\superpowers-plus"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\superpowers-plus" "$env:USERPROFILE\.codex\superpowers-plus\skills"
```

### Step 3: Restart Codex

Quit and relaunch the CLI to discover the skills.

## Verify Installation

```bash
ls -la ~/.agents/skills/superpowers ~/.agents/skills/superpowers-plus
```

You should see symlinks pointing to both skill directories.

## Updating

```bash
cd ~/.codex/superpowers && git pull
cd ~/.codex/superpowers-plus && git pull
```

Skills update instantly through the symlinks.

## Uninstalling

```bash
# Remove superpowers-plus only
rm ~/.agents/skills/superpowers-plus
rm -rf ~/.codex/superpowers-plus

# Remove superpowers (optional)
rm ~/.agents/skills/superpowers
rm -rf ~/.codex/superpowers
```

## What You Get

**From obra/superpowers (prerequisite):**
- brainstorming, writing-plans, executing-plans
- test-driven-development, systematic-debugging
- subagent-driven-development, using-git-worktrees
- 20+ core workflow skills

**From superpowers-plus:**
- Wiki editing and verification skills
- Issue tracking patterns
- Security audit skills (secret detection, IP audit)
- TypeScript-specific patterns
- Observability and research skills
- AI slop detection for writing

## Getting Help

- superpowers-plus issues: https://github.com/bordenet/superpowers-plus/issues
- obra/superpowers issues: https://github.com/obra/superpowers/issues

