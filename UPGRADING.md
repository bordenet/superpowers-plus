# Upgrading Superpowers

> **For AI Coding Assistants**: This document provides self-serve upgrade instructions.
> When a user says "keep my superpowers current" or "upgrade superpowers", follow this guide.

---

## Quick Reference

| Scenario | Command |
|----------|---------|
| Standard upgrade | `bash install.sh --upgrade --verbose` |
| Force upgrade (discard local changes) | `bash install.sh --upgrade --force --verbose` |
| Complete reinstall | `bash install.sh --force --verbose` |

---

## Pre-Upgrade Checklist

Before upgrading, check the current state:

```bash
# Check current version
cd ~/path/to/superpowers-plus && git log -1 --oneline

# Check for local modifications in the repo
cd ~/path/to/superpowers-plus && git status
```

If `git status` shows modifications to the superpowers-plus repo, decide whether to:

- Preserve them: Use standard `--upgrade` (may fail if conflicts exist)
- Discard them: Use `--upgrade --force`

---

## When to Use Each Command

### Standard Upgrade (`--upgrade`)

```bash
cd /path/to/superpowers-plus
bash install.sh --upgrade --verbose
```

**Use when:**

- Routine updates (weekly/monthly)
- No local changes to superpowers
- Want to see before/after SHA comparison

**What it does:**

1. Runs `_migrate_remove_obra_clone` (removes legacy `~/.codex/superpowers/` if present — safe no-op otherwise)
2. Reinstalls all personal skills, rules, templates

### Force Upgrade (`--upgrade --force`)

```bash
cd /path/to/superpowers-plus
bash install.sh --upgrade --force --verbose
```

**Use when:**

- Standard upgrade fails due to local changes
- Want to reset to upstream state
- Git pull fails with merge conflicts

**What it does:**

1. Same as standard upgrade, but the `--force` flag is reserved for future use (no git reset behavior — edit the superpowers-plus repo directly if needed)

### Complete Reinstall (`--force` without `--upgrade`)

```bash
cd /path/to/superpowers-plus
bash install.sh --force --verbose
```

**Use when:**

- Installation is corrupted
- Want a fresh clone from scratch
- Troubleshooting strange behavior

**What it does:**

1. Removes `~/.codex/superpowers` if present (legacy clone — safe no-op if already gone)
2. Reinstalls all personal skills from the bundled skills/ tree

---

## Post-Upgrade Verification

After upgrading, verify the installation:

```bash
# Verify skills load correctly
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap

# List all installed skills
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

**Expected results:**

- Bootstrap should complete without errors
- Skills catalog prints without errors (superpowers-plus contributes 89 skills; installed overlays add more)

---

## Example User Prompts

Users may request upgrades with phrases like:

- "Keep my superpowers current"
- "Upgrade superpowers"
- "Update superpowers to latest"
- "Pull latest superpowers"

**AI Assistant Response:**

1. Navigate to superpowers-plus directory
2. Run `bash install.sh --upgrade --verbose`
3. If it fails, retry with `--upgrade --force`
4. Verify with bootstrap command

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "superpowers not installed" | Run `bash install.sh` (without --upgrade) first |
| "not a git repository" | Run `bash install.sh --force` to reinstall |
| "Fast-forward pull failed" | Run `bash install.sh --upgrade --force` |
| Skills not loading | Check `~/.codex/skills/` and `~/.claude/skills/` exist |
| Wrong skill count | Run `bash install.sh` to reinstall personal skills |
