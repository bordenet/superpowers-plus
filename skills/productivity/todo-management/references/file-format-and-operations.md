# TODO Management — File Format & Operations

> Reference material for the `todo-management` skill.
> See `skill.md` for core guidance.

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

## Task ID Format

**Pattern:** `YYYYMMDD-NN` (e.g., `20250204-01`)
- Date = creation date
- NN = sequential counter for that day (01, 02, 03...)

## Core Operations

### 1. Add Task

**Input:** "Add task: [description]" or natural language variant

**Process:**
1. Parse task description
2. Infer priority (default P2 unless urgency signals)
3. Infer tags from keywords (see `references/taxonomy.md`)
4. Generate task ID
5. Write to TODO.md under appropriate section
6. Confirm in ≤20 words

**Response:** "Added: [title] as P[N] #tags. [ID]"

### 2. Complete Task

**Input:** "Complete [ID or title fragment]"

**Process:**
1. Match task (disambiguate if multiple matches)
2. **REMOVE from ACTIVE section** — do NOT just flip `[ ]` to `[x]` in place
3. **ADD to HISTORY** under `## YYYY-MM-DD` (today's date) with `[x]` prefix
4. Add `  - Done: YYYY-MM-DD` timestamp
5. Prompt for optional progress notes

⚠️ **Common agent failure:** Marking `[x]` in the ACTIVE section without moving.
This causes unbounded file growth. Only `[ ]` tasks belong in ACTIVE.

**Response:** "Completed: [title]. Notes?"

### 3. Query History

**Input:** "What did I do [yesterday/last week/on Monday/for engineering]?"

**Process:**
1. Parse timeframe
2. Filter HISTORY section
3. Apply tag filter if specified
4. Return results in ≤30 seconds

## Implementation Workflow

All write operations follow: preflight → lock acquire → backup → write → lock release.
See `skill.md` § Hard Gate and [AGENTS.md](../../../AGENTS.md#planning-and-task-management) for the complete protocol and scripts.
