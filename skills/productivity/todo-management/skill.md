---
name: todo-management
source: superpowers-plus
triggers: ["add task", "what should I work on", "show my tasks", "complete [task]", "what did I do", "triage", "mark done", "my P1s", "backlog", "today's priorities", "task list"]
description: Use when capturing tasks, tracking work, triaging priorities, or querying task history.
---

# TODO Management

> **File location:** `$TODO_FILE_PATH` (see Configuration below)
> **PRD:** See `PRD.md` in this skill folder for full requirements

---

## Configuration

**REQUIRED:** Set the `TODO_FILE_PATH` environment variable before using this skill.

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)

# macOS example:
export TODO_FILE_PATH="$HOME/Documents/TODO.md"

# Windows/WSL example:
export TODO_FILE_PATH="/mnt/c/Users/YourName/Documents/TODO.md"

# Linux example:
export TODO_FILE_PATH="$HOME/Documents/TODO.md"
```

The skill will check for this variable on first use and prompt you to configure it if missing.

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

### Engineering Tags (auto-inferred from keywords)

| Tag | Trigger Keywords |
|-----|------------------|
| `#engineering-frontend` | UI, component, CSS, React, layout, styling |
| `#engineering-backend` | API, database, server, endpoint, migration |
| `#engineering-infra` | deploy, CI, pipeline, Docker, Kubernetes, terraform |
| `#engineering-testing` | test, coverage, unit, integration, QA |
| `#engineering-docs` | documentation, README, wiki, spec, ADR |

### General Tags (auto-inferred from context)

| Tag | Trigger Context |
|-----|-----------------|
| `#team` | Team member names, "team", "direct report" |
| `#1on1` | "1:1", "one-on-one", "sync with [name]" |
| `#product` | "product", "feature", "roadmap" |
| `#process` | "process", "workflow", "documentation" |

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

### On First Use

1. Check that `$TODO_FILE_PATH` is set:
   ```bash
   if [ -z "$TODO_FILE_PATH" ]; then
     echo "ERROR: TODO_FILE_PATH not set. See skill Configuration section."
     exit 1
   fi
   ```

2. If TODO.md doesn't exist at `$TODO_FILE_PATH`, create it:
   ```bash
   mkdir -p "$(dirname "$TODO_FILE_PATH")"
   ```

3. Initialize with empty section structure:
   ```markdown
   # ACTIVE TASKS

   ## P1 - Today

   ## P2 - This Week

   ## P3 - Backlog

   ---

   # HISTORY

   ---

   # DEFERRED

   ---

   # METRICS
   ```

### On Task Add

```bash
# 1. Read current TODO.md
cat "$TODO_FILE_PATH"

# 2. Backup
cp "$TODO_FILE_PATH" "$TODO_FILE_PATH.$(date +%Y%m%d-%H%M%S).bak"

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
