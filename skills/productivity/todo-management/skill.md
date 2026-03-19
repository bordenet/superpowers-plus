---
name: todo-management
source: superpowers-plus
triggers: ["add task", "add a TODO", "add TODO", "what should I work on", "show my tasks", "show my TODOs", "what are my TODOs", "what are my tasks", "complete [task]", "what did I do", "triage", "process TODOs", "mark done", "my P1s", "backlog", "today's priorities", "TODOs today", "task list", "implement this plan", "execute these steps", "track this work", "let's do this", "begin implementation", "work through this checklist", "todo", "todos", "what are our todos", "what's pending", "what's next", "what needs to be done", "open tasks", "outstanding tasks", "what's left", "remaining work", "show todos", "list tasks", "active tasks"]
description: Use when capturing tasks, tracking work, triaging priorities, querying task history, or executing multi-step plans.
---

# TODO Management

> **File location:** Resolved from `TODO_FILE_PATH` in `~/.codex/.env` (falls back to `$HOME/.codex/TODO.md`)
> **PRD:** See `PRD.md` in this skill folder for full requirements
> **MCP Tools:** `add_tasks`, `update_tasks`, `view_tasklist` (for in-conversation tracking)

---

## Multi-Step Plan Tracking

When executing a multi-step plan (3+ steps), use **BOTH** persistence mechanisms:

1. **TODO.md file** (PRIMARY) — Persist all plan steps to disk for resilience
2. **MCP tools** (SUPPLEMENTARY) — Real-time visibility in conversation UI

### Why Both?

| Mechanism | Purpose | Survives |
|-----------|---------|----------|
| **TODO.md** | Persistence, recovery, cross-session continuity | Context compaction, crashes, session switches |
| **MCP tools** | Real-time UI visibility for user | Current session only |

**Default behavior:** Write to TODO.md first, then mirror to MCP tools if available.

### Workflow: Executing a Multi-Step Plan

When user says "implement this plan", "execute these steps", etc.:

1. **Name the effort** — Derive identifier from plan title (kebab-case) or ask user if ambiguous
   - "Implement the config refactor" → `config-refactor`
   - "Fix the auth bug" → `auth-fix`
   - If unclear: "What should I call this effort?"
2. **Persist to TODO.md** — Write all steps as P1 tasks with `#plan-<identifier>` tag
3. **Mirror to MCP** — Create parent task for the plan, add steps as children using `parent_task_id`
4. **Track progress** — Update both systems as you complete steps
5. **Verify** — Filter by `#plan-<identifier>` to check completion

### Example: Executing a 4-Step Plan

```
User: "Implement the config refactor: 1) Update config, 2) Add validation, 3) Write tests, 4) Update docs"

Agent:
1. Derive effort identifier: "config refactor" → config-refactor
2. Write 4 tasks to TODO.md as P1 #plan-config-refactor #engineering
3. Call add_tasks: create parent "Plan: Config Refactor", add steps as children
4. For each step:
   - Mark IN_PROGRESS in both systems
   - Do the work
   - Mark COMPLETE in both systems
5. Verify: Filter #plan-config-refactor in TODO.md, call view_tasklist
6. Report "Config refactor complete"
```

### Querying by Effort

| Query | Action |
|-------|--------|
| "What's left in config-refactor?" | Filter `#plan-config-refactor`, show incomplete tasks |
| "Show my active plans" | List unique `#plan-*` tags with task counts |
| "Complete the auth-fix plan" | Mark all `#plan-auth-fix` tasks as done |
| "Switch to auth-fix" | Set current context for subsequent completion commands |

### MCP Tool Reference (Supplementary)

| Tool | Purpose | When to Call |
|------|---------|--------------|
| `add_tasks` | Create parent task + children | After writing to TODO.md |
| `update_tasks` | Sync state changes | After updating TODO.md |
| `view_tasklist` | Quick status check | In addition to reading TODO.md |

### When MCP Tools Are Unavailable

If MCP tools are not available, **TODO.md is sufficient**. The file provides:
- Full persistence
- Recovery from interruptions
- Cross-session continuity
- Queryable history ("what did I do?")
- Effort isolation via `#plan-<identifier>` tags

MCP tools are a convenience layer, not a requirement.

---

## ⛔ HARD GATE: File Path Resolution (MANDATORY — No Exceptions)

**Before ANY task operation** (add, complete, query, triage), run the preflight script:

```bash
~/.codex/superpowers-plus/tools/todo-preflight.sh
```

This single command does everything:
1. Sources `~/.codex/.env` to load `TODO_FILE_PATH`
2. Resolves the path (falls back to `$HOME/.codex/TODO.md` if unset)
3. Verifies the file exists
4. Outputs `TODO_PATH=<resolved-path>` — use this path for ALL subsequent file operations

**If preflight fails** (file doesn't exist), run with `--create-if-missing`:
```bash
~/.codex/superpowers-plus/tools/todo-preflight.sh --create-if-missing
```

### The Gate

| ✅ PASS | ❌ FAIL |
|---------|---------|
| Preflight returns `FILE_EXISTS=true` | Preflight returns `FILE_EXISTS=false` |
| Use `TODO_PATH` for all file operations | **STOP. Do NOT proceed.** |
| MCP tools (`add_tasks`) are supplementary | **NEVER use MCP-only tracking** |

**If you skip this gate:** MCP task state is session-scoped. It is lost on context
compaction, crashes, or session switches. This causes hallucinated task state where
the agent fabricates TODO items from context fragments.

### ⚠️ Common Agent Failure Mode

Agents frequently skip the preflight and jump straight to `add_tasks` / `view_tasklist`
because MCP tools are easier. **This is the #1 cause of TODO system failures.**

The correct sequence is ALWAYS:
1. Run preflight → get `TODO_PATH`
2. **For WRITES:** Acquire lock → backup → write → release lock
3. Read `TODO_PATH` with `view` (no lock needed for reads)
4. THEN optionally mirror to MCP tools for UI visibility

### 🔒 Write Locking (Concurrent Access Protection)

TODO.md lives on OneDrive and may be accessed by multiple agent sessions across
multiple machines. **All WRITE operations must be wrapped in a lock:**

```bash
# Acquire lock (blocks up to 8s if another agent is writing)
~/.codex/superpowers-plus/tools/todo-lock.sh acquire

# ... perform backup + write operations ...

# Release lock immediately after write completes
~/.codex/superpowers-plus/tools/todo-lock.sh release
```

**Lock behavior:**
- Lock is a directory (`.TODO.md.lock/`) alongside TODO.md — visible across OneDrive
- Auto-expires after 120 seconds (TTL) if agent crashes without releasing
- Detects dead processes on the same machine via PID check
- If lock acquisition fails (timeout), warn the user and skip the write

**READ operations (`view`, `cat`) do NOT need locks.** Only `str-replace-editor`,
`cp` (backup), and any write to TODO.md require locking.

### Configuration

Set `TODO_FILE_PATH` in `~/.codex/.env`:

```bash
# Example entries in ~/.codex/.env:
TODO_FILE_PATH="$HOME/OneDrive/Documents/TODO.md"
TODO_FILE_PATH="/mnt/c/Users/YourName/Documents/TODO.md"  # WSL
```

**Default path:** `$HOME/.codex/TODO.md` (used only if `TODO_FILE_PATH` is not set)

---

## Overview

Conversational TODO list management through AI dialog. Captures tasks in ≤15 seconds, organizes by P1/P2/P3 priority, auto-tags based on context, and provides queryable history.

**Announce at start:** "I'm using the todo-management skill."

---

## Quick Reference

| Command | Action |
|---------|--------|
| "Add task: [description]" | Create task with AI-inferred priority + tags |
| "Show my tasks" | Display P1 → P2 → P3 |
| "Complete [ID or fragment]" | Mark done, prompt for notes |
| "What did I do [timeframe]?" | Query history |
| "What did I do for engineering?" | Filter by #engineering-* tags |
| "What should I work on?" | Brainstorm mode |
| "Triage" | Review active tasks |

---

## Priority Framework

| Priority | Label | Max | Definition |
|----------|-------|-----|------------|
| **P1** | Today | 5 | Must complete today; blocking others or time-sensitive |
| **P2** | This Week | 15 | Should complete this week; important but flexible |
| **P3** | Backlog | ∞ | Complete when capacity allows |

**P1 Overload:** If P1 count > 5, warn: "You have [N] P1s. That's unsustainable—want to demote any?"

---

## Tagging Taxonomy

Tags are auto-inferred from keywords. See `references/taxonomy.md` for the full taxonomy (engineering, recruiting, general, plan tags) and customization guidance.

**Key pattern:** Use `#plan-<identifier>` (kebab-case) to group tasks by effort for parallel work isolation.

---

## File Format & Operations

See `references/file-format-and-operations.md` for:
- Full TODO.md file format (ACTIVE TASKS, HISTORY, DEFERRED, METRICS sections)
- Task ID format (`YYYYMMDD-NN`)
- Core operations (Add, Complete, Query History)
- Implementation workflow (lock acquire → backup → write → lock release)
- Self-improvement pipeline and weekly feedback

---

## Guardrails

| Condition | Action |
|-----------|--------|
| P1 count > 5 | Warn and offer to demote |
| P3 task > 14 days old | Friday sweep: "Kill or Keep?" |
| Multi-day task | Ask "What did you accomplish? What remains?" |

---

## Backup Policy

Before EVERY write: `cp "$TODO_PATH" "$TODO_PATH.$(date +%Y%m%d-%H%M%S).bak"`

---

## Reference Files

- [`references/taxonomy.md`](references/taxonomy.md) — Full tagging taxonomy (engineering, recruiting, general, plan tags), customization guidance
- [`references/file-format-and-operations.md`](references/file-format-and-operations.md) — File format template, task ID format, core operations, implementation workflow, weekly feedback
