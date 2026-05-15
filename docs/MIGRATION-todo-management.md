# Migration Guide: todo-management Skill Cleanup

> **For:** Adopters of superpowers-plus who have a local `todo-management` override
> **Date:** 2026-03-16
> **Affects:** superpowers-plus v2.5.1+

## Problem

The `todo-management` skill had a broken deployment state:

1. **Stale override wins:** Adopter repos copied a stale
   `todo-management` override into `~/.codex/skills/` and `~/.codex/superpowers/skills/`,
   overwriting the superpowers-plus version that has critical fixes (deterministic
   default path, dual-persistence, hard gate).

2. **Orphaned TODO.md files:** Before the deterministic default (`$HOME/.codex/TODO.md`),
   agents guessed paths from skill examples (`~/Documents/TODO.md`) or workspace roots
   (`$WORKSPACE_ROOT/TODO.md`), leaving real task data in unreachable locations.

3. **Hallucinated task state:** Without a valid file path, agents fell back to MCP-only
   tracking, which loses state on context compaction, causing fabricated TODO items.

## What superpowers-plus Now Does Automatically

The `superpowers-plus/install.sh` installer runs post-install migrations:

- **`migrate_todo_skill_overrides()`** — Detects stale overrides in both
  `~/.codex/superpowers/skills/todo-management/` and `~/.codex/skills/todo-management/`
  by checking the `source:` field. If it came from an adopter
  (not obra/superpowers/superpowers-plus), removes it.

- **`detect_orphaned_todo_files()`** — Scans common locations for TODO.md files
  outside the default path, reports them with consolidation instructions.

## What Adopters Need to Do

### Step 1: Delete the todo-management override

If your repo has a file like:

```text
skills/productivity/todo-management/skill.md
```

**Delete it.** The superpowers-plus version now includes:

- All engineering tags (frontend, backend, infra, testing, docs)
- All recruiting tags (sourcer, scheduler, admin, interviewer, hr)
- Customizable general tags (`#team` → `#your-team`, `#product` → `#your-product`)
- Deterministic default path (`$HOME/.codex/TODO.md`)
- Dual-persistence (TODO.md + MCP tools)
- Hard gate (no file = no task operations)
- **Preflight script** (`tools/todo-preflight.sh`) — single-command path resolution
- Extended trigger phrases ("add a TODO", "what are my TODOs", "process TODOs", etc.)

If you had custom tags not covered above, add them to the upstream skill via PR.

### Step 2: Update your install.sh

If your `skills/install.sh` deploys skills to `~/.codex/superpowers/skills/`:

**Stop doing that.** Only deploy to `~/.codex/skills/`. The `~/.codex/superpowers/`
directory is managed by obra/superpowers and should not be modified by adopters.

### Step 3: Set TODO_FILE_PATH (optional)

The default path (`$HOME/.codex/TODO.md`) works out of the box. If you want a
custom location, set in `~/.codex/.env`:

```bash
# In ~/.codex/.env (NOT your shell profile — the preflight script sources this file)
TODO_FILE_PATH="$HOME/your/preferred/path/TODO.md"
```

The `todo-preflight.sh` script sources `~/.codex/.env` automatically. You can
verify your path resolves correctly:

```bash
~/.codex/superpowers-plus/tools/todo-preflight.sh
```

### Step 4: Consolidate orphaned TODO.md files

After running `superpowers-plus/install.sh`, it will report any orphaned TODO.md
files it finds. For each one:

1. **Check if it has real task data** — `cat <path>`
2. **If yes:** Move it to the default location or set `TODO_FILE_PATH`
3. **If no:** Delete it (it was likely created by an agent guessing paths)

## Verification

After applying these changes, run:

```bash
# Reinstall superpowers-plus (deploys clean todo-management skill)
cd ~/.codex/superpowers-plus && git pull origin main && ./install.sh --force

# Reinstall your adopter repo (should NOT overwrite todo-management)
cd ~/your-repo && ./install.sh

# Verify only one copy exists with correct source
grep 'source:' ~/.codex/skills/todo-management/skill.md
# Expected: source: superpowers-plus

# As of v2.6.0, ~/.codex/superpowers/ is removed by the migration. Verify the
# bundled skill is deployed at the new canonical location:
grep 'source:' ~/.codex/skills/todo-management/skill.md 2>/dev/null
# Expected: source: superpowers-plus (bundled skill deployed correctly)
```
