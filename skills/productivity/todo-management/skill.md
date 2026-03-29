---
name: todo-management
source: superpowers-plus
triggers: ["add task", "add TODO", "what should I work on", "show my tasks", "list tasks", "what are my tasks", "what's next", "what's pending", "complete [task]", "mark done", "what did I do", "triage", "my P1s", "today's priorities", "backlog", "implement this plan", "execute these steps", "track this work", "todo", "remaining work"]
anti_triggers: ["archive old tasks", "search old tasks", "find archived"]
description: Use when capturing tasks, tracking work, triaging priorities, querying task history, or executing multi-step plans.
summary: "Use when: managing multi-step tasks. Hard gate for 3+ step tasks."
coordination:
  group: productivity
  order: 0
  requires: []
  enables: ["todo-archive", "fallback-planning"]
  escalates_to: []
  internal: false
---

# TODO Management

> **Wrong skill?** Archiving completed tasks → `todo-archive`. Plan execution → `plan-and-execute`.
>
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

**Use `todo-crud.sh` for ALL TODO.md access** — both reading and writing. It resolves the correct path from `~/.codex/.env` automatically. NEVER `cat` or `view` TODO.md directly.

```bash
# READ — show TODO.md contents (resolved path)
~/.codex/superpowers-plus/tools/todo-crud.sh cat
~/.codex/superpowers-plus/tools/todo-crud.sh path      # just the path
~/.codex/superpowers-plus/tools/todo-crud.sh list       # filtered task list

# WRITE — add, complete, move, defer
~/.codex/superpowers-plus/tools/todo-crud.sh add --priority P3 --description "Task description" --tags "#tag1 #tag2" --note "Additional context"
~/.codex/superpowers-plus/tools/todo-crud.sh complete --id 20260322-01 --note "Resolution notes"
~/.codex/superpowers-plus/tools/todo-crud.sh move --id 20260322-01 --to P1
~/.codex/superpowers-plus/tools/todo-crud.sh defer --id 20260322-01 --reason "Blocked on X"

# Multi-agent: claim a task (marks [/], adds TTL metadata)
~/.codex/superpowers-plus/tools/todo-crud.sh claim --id 20260322-01 --ttl 30

# Multi-agent: release a claim
~/.codex/superpowers-plus/tools/todo-crud.sh unclaim --id 20260322-01

# Multi-agent: reap all expired claims (reverts to [ ])
~/.codex/superpowers-plus/tools/todo-crud.sh reap

# JSON output (for machine parsing)
~/.codex/superpowers-plus/tools/todo-crud.sh --json list --all
```

**What it does automatically:** path resolution, advisory locking, backup before write, task ID allocation, section targeting, whitespace normalization, expired claim reaping. Cross-platform (macOS + Linux).

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

### 🔴 DESTRUCTIVE WRITE BAN (NON-NEGOTIABLE — DATA LOSS PREVENTION)

**NEVER write to TODO.md except through the approved TODO tools** (`todo-crud.sh`, `todo-preflight.sh --create-if-missing`, `todo-maintenance.sh`). This ban includes:

- ❌ `save-file` / `str-replace-editor` / `echo >` / `cat >` / `sed -i` / inline python
- ❌ ANY method that bypasses preflight, locking, backup, or structure validation

**Incident 2026-03-23:** An agent used `save-file` to overwrite TODO.md with a raw task list. Dozens of unstarted tasks were permanently destroyed. No backup was created. Recovery was impossible.

`todo-crud.sh` prevents this by: (1) resolving the correct `TODO_FILE_PATH`, (2) acquiring an advisory lock, (3) creating a timestamped backup, (4) validating section structure (required headers in order, priority subsections, and at least one task or history artifact). Bypassing it bypasses ALL of these protections.

### Defense Layers (enforced by `todo-engine.py`)

7 layers: rules → structural validation → OS immutability (`chflags uchg`) → chmod 444 → shadow+annihilation detection → stray path detection → path obscuring (`.todo-registry`). If annihilation blocks a write: delete `~/.codex/todo-shadow/TODO.md` and retry.

---

## Multi-Agent Coordination

When multiple agents (Augment, Claude Code, amp, etc.) share a TODO.md, use **claim/unclaim/reap** to prevent duplicate work:

1. **Before starting work:** `claim --id <ID>` — marks `[/]` with TTL metadata
2. **On completion:** `complete --id <ID>` — moves to HISTORY (claim auto-removed)
3. **On abandonment:** `unclaim --id <ID>` — reverts to `[ ]` for another agent
4. **Periodic cleanup:** `reap` — finds expired claims and reverts them

**TTL (default 30 min):** If an agent claims a task and dies/disconnects, the claim expires after TTL minutes. Another agent running `claim` or `reap` will auto-reap it.

**Agent identity:** Set `AGENT_ID` env var for readable names. Falls back to `hostname:ppid`.

**Claim metadata** (single line in task block):
```
  - Claimed: 2026-03-25T14:30:00 by augment-session-1 ttl=30
```

---

## Overview

Use `claim --id <ID>` → `complete --id <ID>` (or `unclaim` to abandon). Claims auto-expire after TTL (default 30 min). Run `reap` to clean expired claims. Set `AGENT_ID` env var for readable names.

---

## How It Works

Conversational TODO management. Captures tasks in ≤15 seconds, P1/P2/P3 priority, auto-tagged. Commands: "Add task: X", "Show my tasks", "Complete [ID]", "What did I do?", "What should I work on?", "Triage".

## Priority Framework

| Priority | Label | Max | Definition |
|----------|-------|-----|------------|
| **P1** | Today | 5 | Must complete today; blocking others or time-sensitive |
| **P2** | This Week | 15 | Should complete this week; important but flexible |
| **P3** | Backlog | ∞ | Complete when capacity allows |

**P1 Overload:** If P1 count > 5, warn: "You have [N] P1s. That's unsustainable—want to demote any?"

---

## References

- **Tags**: Auto-inferred. Use `#plan-<id>` for parallel work. Full taxonomy: `references/taxonomy.md`
- **File format**: `references/file-format-and-operations.md` (sections, IDs, operations, lock workflow)
- **Context-Aware**: `references/context-aware-standard.md` — enforce on `#plan-*` tasks

## Guardrails

P1 >5 → warn/demote. P3 >14 days → Friday sweep. Multi-day → ask progress. Plan tasks without Context-Aware fields → warn.

**Housekeeping:** Move `[x]` to HISTORY immediately. Run `todo-maintenance.sh` after multi-step sessions.

---

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Direct file write attempted | OS immutability blocks it | No action needed |
| Honeypot tampered/missing flag | `sp-doctor` Check 23 detects | Run `sp-doctor --fix` |
| TODO path missing | Check 24 reports ERROR | Run `todo-preflight.sh --create-if-missing` |
| `.todo-registry` missing/empty | `self-test` warns; falls back to `.env` → default path | Create `.todo-registry` with real TODO path |
| Annihilation detected (>60% drop) | Engine blocks write | Delete `~/.codex/todo-shadow/TODO.md` and retry |
| Lock stuck (agent died mid-write) | TTL expires after 120s | Wait 2 min, or `rm -rf` the `.TODO.md.lock` dir |
| Agent writes directly despite rules | Shadow comparison catches post-write | Restore from `~/.codex/todo-shadow/TODO.*.bak` |

> **Honeypot is optional.** Only for external TODO paths. Default-path users: no honeypot, Check 23 auto-skips.

Diagnostics: `todo-crud.sh self-test` (health) · `doctor-checks.sh` (checks 23-25)

## Companion Skills

- **todo-archive**: Archiving completed tasks · **plan-and-execute**: Planning complex task sequences

**References:** [`references/taxonomy.md`](references/taxonomy.md) · [`references/file-format-and-operations.md`](references/file-format-and-operations.md)

- **todo-guardian**: TODO enforcement layer
