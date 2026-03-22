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

## When to Use

- Capturing, tracking, or triaging tasks during any work session
- Executing a multi-step plan (3+ steps) that needs persistent tracking
- Querying "what are my TODOs?" or "what's next?"
- Closing out a session and ensuring no work is lost

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

### Querying by Effort

| Query | Action |
|-------|--------|
| "What's left in config-refactor?" | Filter `#plan-config-refactor`, show incomplete tasks |
| "Show my active plans" | List unique `#plan-*` tags with task counts |
| "Complete the auth-fix plan" | Mark all `#plan-auth-fix` tasks as done |

### MCP Tools (Supplementary)

MCP tools (`add_tasks`, `update_tasks`, `view_tasklist`) provide real-time UI visibility
but are session-scoped. **Always write to TODO.md first**, then mirror to MCP if available.

---

## ⛔ HARD GATE: File Path Resolution (MANDATORY — No Exceptions)

**Before ANY task operation**, run preflight → use returned `TODO_PATH` for all file ops:

```bash
~/.codex/superpowers-plus/tools/todo-preflight.sh              # resolve path
~/.codex/superpowers-plus/tools/todo-preflight.sh --create-if-missing  # create if needed
```

**If `FILE_EXISTS=false`: STOP. Do NOT proceed. Do NOT fall back to MCP-only tracking.**

See **[AGENTS.md § Planning and Task Management](../../../AGENTS.md#planning-and-task-management)** for the full hard gate, locking protocol, anti-patterns, and configuration.

**Quick reference — correct write sequence:**
1. Run preflight → get `TODO_PATH`
2. `todo-lock.sh acquire` → backup → write → `todo-lock.sh release`
3. Optionally mirror to MCP tools for UI visibility

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

**Post-session archive check** — run archive (`todo-archive` skill or `~/.codex/skills/todo-archive/todo-archive.sh --force`) when any of these are true:
- HISTORY has ≥5 completed tasks
- TODO.md exceeds 200 lines
- HISTORY entries are >7 days old

**Backup:** Before EVERY write: `cp "$TODO_PATH" "$TODO_PATH.$(date +%Y%m%d-%H%M%S).bak"`

---

## Reference Files

- [`references/taxonomy.md`](references/taxonomy.md) — Full tagging taxonomy, customization guidance
- [`references/file-format-and-operations.md`](references/file-format-and-operations.md) — File format, task ID format, core operations, implementation workflow
