# Upgrading Superpowers

> **For AI Coding Assistants**: This document provides self-serve upgrade instructions.
> When a user says "keep my superpowers current" or "upgrade superpowers", follow this guide.

---

## Quick Reference

| Scenario | Command |
|----------|---------|
| Standard upgrade | `./install.sh --upgrade --verbose` |
| Force upgrade (discard local changes) | `./install.sh --upgrade --force --verbose` |
| Complete reinstall | `./install.sh --force --verbose` |

---

## Pre-Upgrade Checklist

Before upgrading, check the current state:

```bash
# Check current version
cd ~/.codex/superpowers && git log -1 --oneline

# Check for local modifications
cd ~/.codex/superpowers && git status
```

If `git status` shows modifications, decide whether to:
- Preserve them: Use standard `--upgrade` (may fail if conflicts exist)
- Discard them: Use `--upgrade --force`

---

## When to Use Each Command

### Standard Upgrade (`--upgrade`)

```bash
cd /path/to/superpowers-plus
./install.sh --upgrade --verbose
```

**Use when:**
- Routine updates (weekly/monthly)
- No local changes to superpowers
- Want to see before/after SHA comparison

**What it does:**
1. Requires superpowers already installed
2. Runs `git fetch origin` + `git pull --ff-only origin main`
3. Shows version comparison (e.g., `abc1234 → def5678`)
4. Reinstalls all personal skills

### Force Upgrade (`--upgrade --force`)

```bash
cd /path/to/superpowers-plus
./install.sh --upgrade --force --verbose
```

**Use when:**
- Standard upgrade fails due to local changes
- Want to reset to upstream state
- Git pull fails with merge conflicts

**What it does:**
1. Runs `git reset --hard HEAD` (discards uncommitted changes)
2. Runs `git clean -fd` (removes untracked files)
3. Then performs standard upgrade

### Complete Reinstall (`--force` without `--upgrade`)

```bash
cd /path/to/superpowers-plus
./install.sh --force --verbose
```

**Use when:**
- Installation is corrupted
- Want a fresh clone from scratch
- Troubleshooting strange behavior

**What it does:**
1. Removes `~/.codex/superpowers` entirely
2. Fresh clone from `https://github.com/obra/superpowers.git`
3. Reinstalls all personal skills

---

## Post-Upgrade Verification

After upgrading, verify the installation:

```bash
# Verify skills load correctly
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap

# Check skill count
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep -c "^superpowers:"
```

**Expected results:**
- Bootstrap should complete without errors
- Skill count should be 30+ (varies as skills are added)

---

## Example User Prompts

Users may request upgrades with phrases like:

- "Keep my superpowers current"
- "Upgrade superpowers"
- "Update superpowers to latest"
- "Pull latest superpowers"

**AI Assistant Response:**
1. Navigate to superpowers-plus directory
2. Run `./install.sh --upgrade --verbose`
3. If it fails, retry with `--upgrade --force`
4. Verify with bootstrap command

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "superpowers not installed" | Run `./install.sh` (without --upgrade) first |
| "not a git repository" | Run `./install.sh --force` to reinstall |
| "Fast-forward pull failed" | Run `./install.sh --upgrade --force` |
| Skills not loading | Check `~/.codex/superpowers/skills/` exists |
| Wrong skill count | Run `./install.sh` to reinstall personal skills |
