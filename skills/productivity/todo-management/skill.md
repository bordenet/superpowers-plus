---
name: todo-management
source: superpowers-plus
triggers: ["add task", "add a TODO", "add TODO", "what should I work on", "show my tasks", "show my TODOs", "what are my TODOs", "what are my tasks", "complete [task]", "what did I do", "triage", "process TODOs", "mark done", "my P1s", "backlog", "today's priorities", "TODOs today", "task list", "implement this plan", "execute these steps", "track this work", "let's do this", "begin implementation", "work through this checklist"]
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
2. Read/write `TODO_PATH` with `view` / `str-replace-editor` / `launch-process`
3. THEN optionally mirror to MCP tools for UI visibility

### Configuration

Set `TODO_FILE_PATH` in `~/.codex/.env`:

```bash
# Example entries in ~/.codex/.env:
TODO_FILE_PATH="$HOME/OneDrive/Documents/TODO.md"
TODO_FILE_PATH="/mnt/c/Users/YourName/Documents/TODO.md"  # WSL
```

**Default path:** `$HOME/.codex/TODO.md` (used only if `TODO_FILE_PATH` is not set)

---

## ⚠️ CRITICAL: Always Check Persistent TODO.md First

When user asks "show my TODOs", "what are my tasks", or any task query:

1. **ALWAYS read the resolved TODO.md path FIRST** — This is the source of truth
2. **MCP tools are supplementary** — `view_tasklist` shows session context only
3. **Never imply completeness** from MCP state alone

**Why this matters:**
- MCP tasks are session-only (lost on context compaction)
- TODO.md persists across sessions
- Showing only MCP tasks gives a false "all done" impression

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

Tags are auto-inferred from keywords in the task description. The taxonomy below
covers common domains. **Customize for your organization** by adding domain-specific
tags (e.g., replace `#team` with your team name like `#delta-team`).

### Engineering Tags

| Tag | Trigger Keywords |
|-----|------------------|
| `#engineering-frontend` | UI, component, CSS, React, layout, styling |
| `#engineering-backend` | API, database, server, endpoint, migration |
| `#engineering-infra` | deploy, CI, pipeline, Docker, Kubernetes, terraform |
| `#engineering-testing` | test, coverage, unit, integration, QA |
| `#engineering-docs` | documentation, README, wiki, spec, ADR |

### Recruiting Tags

| Tag | Trigger Keywords |
|-----|------------------|
| `#recruiting-sourcer` | source, outreach, LinkedIn, pipeline, candidate search |
| `#recruiting-scheduler` | schedule, calendar, Zoom, interview time, availability |
| `#recruiting-admin` | offer, letter, system, ATS, paperwork |
| `#recruiting-interviewer` | interview, prep, feedback, scorecard, debrief |
| `#recruiting-hr` | comp, compensation, policy, HR, benefits |

### General Tags (auto-inferred from context)

| Tag | Trigger Context |
|-----|-----------------|
| `#team` | Team member names, "team", "direct report" (customize: `#delta-team`, `#your-team`) |
| `#1on1` | "1:1", "one-on-one", "sync with [name]" |
| `#product` | "product", "feature", "roadmap" (customize: `#cari`, `#your-product`) |
| `#process` | "process", "workflow", "documentation" |

### Plan Tags (effort-scoped)

Use `#plan-<identifier>` to group tasks by effort for parallel work isolation.

| Pattern | Purpose | Example |
|---------|---------|---------|
| `#plan-<identifier>` | Group tasks by effort | `#plan-auth-fix`, `#plan-config-refactor` |
| `#plan` | ⚠️ **Deprecated** | Use `#plan-<identifier>` for effort isolation |

**Identifier derivation:**
- Derive from plan title: "Config Refactor" → `config-refactor`
- Use kebab-case: lowercase, hyphens instead of spaces
- Keep short but descriptive: 2-4 words max
- If ambiguous, ask: "What should I call this effort?"

**Example TODO.md with multiple efforts:**
```markdown
## P1 - Today
- [ ] [20250315-01] Update config schema #plan-config-refactor #engineering
- [ ] [20250315-02] Add validation layer #plan-config-refactor #engineering
- [ ] [20250315-03] Fix auth token refresh #plan-auth-fix #engineering-backend
- [ ] [20250315-04] Add auth retry tests #plan-auth-fix #engineering-testing
```

---

## File Format

```markdown
# ACTIVE TASKS

## P1 - Today
- [ ] [20250204-01] Task description #tag1 #tag2
  - Added: 2025-02-04
  - Due: 2025-02-04
  - Note: Context or blocker info

## P2 - This Week
- [ ] [20250204-02] Review PR for auth refactor #engineering-backend
  - Added: 2025-02-04

## P3 - Backlog
- [ ] [20250204-03] Document onboarding process #process
  - Added: 2025-02-04

---

# HISTORY

## 2025-02-04
- [x] [20250203-05] Fixed flaky test in CI pipeline #engineering-testing
  - Done: 2025-02-04T10:30:00
  - Progress: Root cause was race condition in async mock

---

# DEFERRED
- [ ] [20250201-03] Research competitor #product
  - Deferred: 2025-02-04
  - Reason: Blocked on access

---

# METRICS
- Week of 2025-02-03:
  - Tasks created: 12
  - Tasks completed: 9
  - Task failure rate: 8%
  - P1 overload warnings: 1
  - Tagging accuracy: 92%
```

---

## Task ID Format

**Pattern:** `YYYYMMDD-NN` (e.g., `20250204-01`)

- Date = creation date
- NN = sequential counter for that day (01, 02, 03...)
- Guarantees uniqueness; human-readable

---

## Core Operations

### 1. Add Task

**Input:** "Add task: [description]" or natural language variant

**Process:**
1. Parse task description
2. Infer priority (default P2 unless urgency signals)
3. Infer tags from keywords
4. Generate task ID
5. Write to TODO.md under appropriate section
6. Confirm in ≤20 words

**Response:** "Added: [title] as P[N] #tags. [ID]"

### 2. Complete Task

**Input:** "Complete [ID or title fragment]"

**Process:**
1. Match task (disambiguate if multiple matches)
2. Move to HISTORY under today's date
3. Add completion timestamp
4. Prompt for optional progress notes

**Response:** "Completed: [title]. Notes?"

### 3. Query History

**Input:** "What did I do [yesterday/last week/on Monday/for engineering]?"

**Process:**
1. Parse timeframe
2. Filter HISTORY section
3. Apply tag filter if specified
4. Return results in ≤30 seconds

---

## Guardrails

| Condition | Action |
|-----------|--------|
| P1 count > 5 | Warn and offer to demote |
| P3 task > 14 days old | Friday sweep: "Kill or Keep?" |
| Multi-day task | Ask "What did you accomplish? What remains?" |

---

## Proactive Prompts (Weekdays Only)

| Time (PST) | Prompt |
|------------|--------|
| 07:00 | Morning triage |
| 10:00 | Mid-morning check |
| 13:00 | Post-lunch reset |
| 15:00 | Afternoon focus |
| 16:45 | End-of-day wrap |
| 17:00 Fri | Weekly feedback + stale P3 review |

**Skippable:** "later", "skip", "busy" → 2-hour delay

---

## Backup Policy

Before EVERY write to TODO.md:
1. Copy current file to `TODO.md.YYYYMMDD-HHMMSS.bak`
2. Write new content
3. Validate Markdown structure

---

## Implementation Workflow

### On First Use (HARD GATE)

Run the preflight script to resolve the path and verify the file:
```bash
~/.codex/superpowers-plus/tools/todo-preflight.sh --create-if-missing
```

This resolves `TODO_FILE_PATH` from `~/.codex/.env`, verifies the file exists,
and creates it from the template if missing. The output includes:
- `TODO_PATH=<resolved-path>` — use this for all subsequent operations
- `FILE_EXISTS=true/false` — confirms file is accessible
- `SOURCE=env/default` — shows where the path came from

### On Task Add

```bash
# 1. Read current TODO.md (use resolved path from HARD GATE)
cat "$TODO_PATH"

# 2. Backup
cp "$TODO_PATH" "$TODO_PATH.$(date +%Y%m%d-%H%M%S).bak"

# 3. Parse task, infer priority/tags
# 4. Generate ID: YYYYMMDD-NN
# 5. Insert into appropriate section
# 6. Write back to TODO.md
```

### On Task Complete

```bash
# 1. Find task by ID or title fragment
# 2. Remove from ACTIVE section
# 3. Add to HISTORY under today's date header
# 4. Add completion timestamp
# 5. Write back to TODO.md
```

---

## Self-Improvement Pipeline

When user provides feedback:
1. Propose skill modification
2. Wait for user approval
3. Edit skill.md with changes
4. Provide git commands:
   ```bash
   # From your TODO file directory
   git add -A && git commit -m "[description]"
   git push origin main
   cd skills && ./install.sh
   ```
5. Remind user to pull on other machines

---

## Weekly Feedback (Friday 17:00 PST)

Prompt:
> "Weekly TODO check-in: What's working? What's frustrating? Any feature requests?"

Collect:
- Effectiveness rating (1-5)
- Friction points
- Feature requests
- Tagging corrections made this week

Store in METRICS section.
