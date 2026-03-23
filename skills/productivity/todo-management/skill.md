---
name: todo-management
source: superpowers-plus
triggers: ["add task", "add TODO", "what should I work on", "show my tasks", "list tasks", "what are my tasks", "what's next", "what's pending", "complete [task]", "mark done", "what did I do", "triage", "my P1s", "today's priorities", "backlog", "implement this plan", "execute these steps", "track this work", "todo", "remaining work"]
description: Use when capturing tasks, tracking work, triaging priorities, querying task history, or executing multi-step plans.
summary: "Use when: managing multi-step tasks. Hard gate for 3+ step tasks."
---

# TODO Management

> **File location:** Resolved from `TODO_FILE_PATH` in `~/.codex/.env` (falls back to `$HOME/.codex/TODO.md`)
> **PRD:** See `PRD.md` in this skill folder for full requirements
> **MCP Tools:** `add_tasks`, `update_tasks`, `view_tasklist` (for in-conversation tracking)

## When to Use

- Capturing, tracking, or triaging tasks during any work session
- Executing a multi-step plan (3+ steps) that needs persistent tracking
- Querying "what are my TODOs?" or "what's next?"
- Closing out a session and ensuring no work is lost

---

## Multi-Step Plan Tracking

For 3+ step plans, use **TODO.md** (PRIMARY, survives crashes/compaction) + **MCP tools** (supplementary, session-only UI). Write TODO.md first, then mirror to MCP.

### Workflow

1. **Name the effort** — kebab-case from plan title (e.g., `config-refactor`). Ask if ambiguous.
2. **Persist** — Write steps as P1 tasks with `#plan-<identifier>` tag in TODO.md
3. **Mirror** — Create parent task + children in MCP via `add_tasks` with `parent_task_id`
4. **Track** — Update both systems as you complete steps
5. **Verify** — Filter by `#plan-<identifier>` to check completion

---

## Primary Interface: `todo-crud.sh`

**Use `todo-crud.sh` for ALL TODO.md write operations.** It handles preflight, locking, backup, and ID allocation automatically in a single call.

```bash
# Add a task
~/.codex/superpowers-plus/tools/todo-crud.sh add --priority P3 --description "Task description" --tags "#tag1 #tag2" --note "Additional context"

# Complete a task
~/.codex/superpowers-plus/tools/todo-crud.sh complete --id 20260322-01 --note "Resolution notes"

# Move task to different priority
~/.codex/superpowers-plus/tools/todo-crud.sh move --id 20260322-01 --to P1

# List/filter tasks
~/.codex/superpowers-plus/tools/todo-crud.sh list --priority P1
~/.codex/superpowers-plus/tools/todo-crud.sh list --tag "#plan-foo"

# Get next available task ID
~/.codex/superpowers-plus/tools/todo-crud.sh next-id

# Defer a task
~/.codex/superpowers-plus/tools/todo-crud.sh defer --id 20260322-01 --reason "Blocked on X"

# JSON output (for machine parsing)
~/.codex/superpowers-plus/tools/todo-crud.sh --json list --all
```

**What it does automatically:** path resolution, advisory locking, backup before write, task ID allocation, section targeting, whitespace normalization. Cross-platform (macOS + Linux).

**If TODO.md doesn't exist:** Run `todo-preflight.sh --create-if-missing` first to create from template.

## Maintenance Interface: `todo-maintenance.sh`

**Use `todo-maintenance.sh` for routine housekeeping.** It resolves/creates `TODO.md`, reports stale `#plan-*` tasks, and runs archive automatically when housekeeping thresholds are hit.

```bash
# One-command maintenance (recommended after multi-step sessions)
~/.codex/superpowers-plus/tools/todo-maintenance.sh

# Preview housekeeping actions without modifying TODO.md
~/.codex/superpowers-plus/tools/todo-maintenance.sh --dry-run

# Machine-readable summary for agents/scripts
~/.codex/superpowers-plus/tools/todo-maintenance.sh --json
```

### Legacy Tools (still available, rarely needed)

| Tool | When to use |
|------|-------------|
| `todo-preflight.sh` | Create initial TODO.md, or debug path resolution |
| `todo-lock.sh` | Debug lock issues (`status`, `steal` commands) |

**Anti-pattern:** Do NOT improvise shell/sed/python to write TODO.md. Use `todo-crud.sh`.

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

## Context-Aware TODO Standard (Plan-Level Tasks)

When creating tasks that represent meaningful work units (not mechanical sub-steps), enforce these fields:

| Field | Required Content | Max Length | Skip For |
|-------|-----------------|-----------|----------|
| **Purpose** | WHY this task exists — what problem does completing it solve? | 1 line | Sub-steps that share parent context |
| **Trinity** | **WHY** (rationale), **WHAT** (deliverable), **HOW** (approach + file paths) | 1 bullet each (3 total) | Trivial tasks (< 5 min) |
| **Success Criteria** | Binary done/not-done — verifiable by command or state check | 1 bullet | Sub-steps with obvious completion |
| **Handoff State** | Branch, last commit, partial work, gotchas — enough for a fresh agent | 3 bullets max | Tasks that won't span sessions |

**When to enforce:** Any TODO tagged with `#plan-*` that could be picked up by a different agent. If a sub-step shares context with its parent, the parent carries the context fields.

---

## Guardrails

| Condition | Action |
|-----------|--------|
| P1 count > 5 | Warn and offer to demote |
| P3 task > 14 days old | Friday sweep: "Kill or Keep?" |
| Multi-day task | Ask "What did you accomplish? What remains?" |
| Plan-level task missing Context-Aware fields | Warn: "This task needs Purpose/Trinity/Success Criteria/Handoff State for handoff" |

---

## ♻️ Housekeeping (MANDATORY — Every Session)

**On task completion:** Move `[x]` items from ACTIVE to `# HISTORY → ## YYYY-MM-DD` immediately. Only `[ ]` tasks belong in ACTIVE sections.

**Post-session maintenance** — run `~/.codex/superpowers-plus/tools/todo-maintenance.sh` after any multi-step session. It will report stale `#plan-*` tasks and run archive automatically when any of these are true:
- HISTORY has ≥5 completed tasks
- TODO.md exceeds 200 lines
- HISTORY entries are >7 days old

**Backup:** Before EVERY write: `cp "$TODO_PATH" "$TODO_PATH.$(date +%Y%m%d-%H%M%S).bak"`

---

## Reference Files

- [`references/taxonomy.md`](references/taxonomy.md) — Full tagging taxonomy, customization guidance
- [`references/file-format-and-operations.md`](references/file-format-and-operations.md) — File format, task ID format, core operations, implementation workflow
