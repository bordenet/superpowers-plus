---
name: using-git-worktrees
source: superpowers-plus
augment_menu: true
triggers: ["/sp-worktree", "create a worktree", "isolated workspace", "start feature work in isolation", "new worktree", "git worktree add"]
anti_triggers: ["switch branches", "checkout branch", "merge branch", "already in a worktree"]
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification
summary: "Use when: starting feature work that needs isolation. Creates isolated git worktrees."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: ["writing-plans", "executing-plans"]
  escalates_to: []
  internal: false
composition:
  consumes: [feature-description]
  produces: [isolated-workspace]
  capabilities: [worktree-management, workspace-isolation]
  priority: 6
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## When to Use

- Starting feature work that needs isolation from current changes in the working tree
- Executing an implementation plan that spans multiple tasks and branches
- Working on multiple branches of the same repo simultaneously without stash churn

**NOT when:** the feature is small enough to complete in one session on the current branch.

## Step 0: Detect Existing Isolation

Before creating anything:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
git rev-parse --show-superproject-working-tree 2>/dev/null  # prints a path → submodule, treat as normal repo
```

- `GIT_DIR != GIT_COMMON` and not a submodule → already in a linked worktree.
  Do NOT create another; skip to **Run Project Setup**. Report the path and
  branch, or "detached HEAD, externally managed — branch needed at finish".
- Otherwise (normal checkout): honor any declared worktree preference; if
  none, ask consent first ("Set up an isolated worktree? It protects your
  current branch."). Declined → work in place, skip to **Run Project Setup**.

## Step 1: Prefer the Harness's Native Tool

If you have a native worktree tool (e.g. `EnterWorktree`, `WorktreeCreate`,
a `/worktree` command, a `--worktree` flag), use it and skip to **Run Project
Setup**. `git worktree add` beside a native tool creates state the harness
cannot see or clean up. Only with no native tool, continue below.

## Directory Selection Process

Follow this priority order:

### 1. Check Existing Directories

```bash
# Check in priority order
ls -d .worktrees 2>/dev/null     # Preferred (hidden)
ls -d worktrees 2>/dev/null      # Alternative
```

**If found:** Use that directory. If both exist, `.worktrees` wins.

### 2. Check CLAUDE.md

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**If preference specified:** Use it without asking.

### 3. Ask User

If no directory exists and no CLAUDE.md preference:

```
No worktree directory found. Where should I create worktrees?

1. .worktrees/ (project-local, hidden)
2. ~/.config/superpowers/worktrees/<project-name>/ (global location)

Which would you prefer?
```

## Safety Verification

### For Project-Local Directories (.worktrees or worktrees)

**MUST verify directory is ignored before creating worktree:**

```bash
# Check if directory is ignored (respects local, global, and system gitignore)
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored:**

Per Jesse's rule "Fix broken things immediately":
1. Add appropriate line to .gitignore
2. Commit the change
3. Proceed with worktree creation

**Why critical:** Prevents accidentally committing worktree contents to repository.

### For Global Directory (~/.config/superpowers/worktrees)

No .gitignore verification needed - outside project entirely.

## Creation Steps

### 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. Create Worktree

```bash
# Determine full path
global_root="$HOME/.config/superpowers/worktrees"
case "$LOCATION" in
  .worktrees|worktrees)
    path="$PWD/$LOCATION/$BRANCH_NAME"
    ;;
  "$global_root"|"$global_root"/*|"~/.config/superpowers/worktrees"|"~/.config/superpowers/worktrees/"*)
    path="$global_root/$project/$BRANCH_NAME"
    ;;
  *)
    printf 'Unsupported worktree location: %s\n' "$LOCATION" >&2
    exit 1
    ;;
esac

# Stop before setup if creation or directory entry fails.
git worktree add "$path" -b "$BRANCH_NAME" || exit
cd "$path" || exit
```

### 3. Run Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 4. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
cargo test
pytest
go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### 5. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check CLAUDE.md → Ask user |
| Directory not ignored | Add to .gitignore + commit |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Skipping ignore verification (contents get tracked) | `git check-ignore` before a project-local worktree |
| Assuming directory location | Priority: existing > CLAUDE.md > ask |
| Proceeding with failing baseline tests | Report failures, get explicit permission |
| Hardcoding setup commands | Auto-detect from project files |

## Red Flags

**Never:**
- Create a worktree while already inside one, or beside a native worktree tool
- Create worktree without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip CLAUDE.md check

**Always:**
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline

## Integration

**Called by:**
- **brainstorming** (Phase 4) - REQUIRED when design is approved and implementation follows
- **subagent-driven-development** - REQUIRED before executing any tasks
- **executing-plans** - REQUIRED before executing any tasks
- Any skill needing isolated workspace

**Pairs with:**
- **finishing-a-development-branch** - REQUIRED for cleanup after work complete
