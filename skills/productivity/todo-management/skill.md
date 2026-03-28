---
name: todo-management
source: superpowers-plus
triggers: ["add task", "add TODO", "what should I work on", "show my tasks", "list tasks", "what are my tasks", "what's next", "what's pending", "complete [task]", "mark done", "what did I do", "triage", "my P1s", "today's priorities", "backlog", "implement this plan", "execute these steps", "track this work", "todo", "remaining work"]
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
~/.codex/superpowers-plus/tools/todo-crud.sh unclaim --id 20260322-01
~/.codex/superpowers-plus/tools/todo-crud.sh reap

# Utility
~/.codex/superpowers-plus/tools/todo-crud.sh next-id
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

| Layer | Mechanism | What it catches |
|-------|-----------|----------------|
| 1. Rules | This ban + AGENTS.md + core.always.md | Cooperating agents |
| 2. Structural validation | `validate_structure()` in `write_file()` | Malformed content through engine |
| 3. OS immutability | `chflags uchg` (macOS) / `chattr +i` (Linux) | ALL direct writes — `Operation not permitted` |
| 4. chmod 444 | Secondary protection if immutability unavailable | `save-file`, `str-replace-editor`, shell redirects |
| 5. Shadow + annihilation | Pre-write comparison vs shadow | Catastrophic data loss (>60% size drop, all tasks wiped, >5 tasks lost) |
| 6. Stray path detection | `_validate_canonical_path()` in `write_file()` | Writes to wrong TODO.md path |
| 7. Path obscuring | Path in private `.todo-registry`, NOT in `.env` | Agent path discovery; honeypot at `~/.codex/TODO.md` |

**If annihilation detection blocks a legitimate write:** delete `~/.codex/todo-shadow/TODO.md` and retry.

**Incidents:**
- **2026-03-23:** Agent used `save-file` to overwrite TODO.md, destroying dozens of open tasks. Unrecoverable.
- **2026-03-26a:** Agent hit chmod 444, fell back to `~/.codex/TODO.md` — stray file. Fix: `_validate_canonical_path()`.
- **2026-03-26b:** GPT-5.4 agent wrote directly despite all rules. Fix: `chflags uchg` + path obscuring + honeypot.

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

## How It Works

Conversational TODO management through AI dialog. Captures tasks in ≤15 seconds, P1/P2/P3 priority, auto-tagged. **Announce at start:** "I'm using the todo-management skill."

## Command Reference

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

## ♻️ Housekeeping (MANDATORY)

Move `[x]` items to `# HISTORY → ## YYYY-MM-DD` immediately. Run `todo-maintenance.sh` after multi-step sessions (auto-archives when ≥5 completed or >200 lines or >7 days old).

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

## References

- [`references/taxonomy.md`](references/taxonomy.md) · [`references/file-format-and-operations.md`](references/file-format-and-operations.md)
