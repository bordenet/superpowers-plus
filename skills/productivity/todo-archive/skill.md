---
name: todo-archive
triggers: ["archive todos", "archive completed tasks", "search archived todos", "show archived todos", "todo archive", "archive history", "clean up todos", "archived tasks", "old todos", "todo history search"]
description: Archive completed tasks from TODO.md to monthly satellite files. Preserves operational history while keeping TODO.md under 500 lines. Companion to todo-management (upstream).
---

# TODO Archive System

> **Companion to:** `todo-management` (from superpowers-plus)
> **Archive location:** `$(dirname $TODO_FILE_PATH)/todo-archives/`
> **Index:** `todo-archives/INDEX.md`

---

## When to Use

| Trigger | Action |
|---------|--------|
| User says "archive todos" | Run full archive of all HISTORY entries |
| TODO.md exceeds 400 lines | Auto-archive HISTORY entries ≥7 days old |
| HISTORY has entries >30 days old | Archive regardless of line count (staleness rule) |
| User says "search archived todos for X" | Search across archive files |
| User says "show archived todos from Month Year" | Display specific monthly archive |

---

## Archive Workflow

### Step 1: Resolve paths

```bash
EXPLICIT_TODO_FILE_PATH="${TODO_FILE_PATH:-}"
source ~/.codex/.env 2>/dev/null
TODO_FILE_PATH="${EXPLICIT_TODO_FILE_PATH:-${TODO_FILE_PATH:-$HOME/.codex/TODO.md}}"
TODO_PATH="${TODO_FILE_PATH:-$HOME/.codex/TODO.md}"
ARCHIVE_DIR="$(dirname "$TODO_PATH")/todo-archives"
```

### Step 2: Determine what to archive

Parse the `# HISTORY` section of TODO.md. Identify completed (`[x]`) and cancelled (`[-]`) tasks.

**Archival criteria (any match triggers archival):**
- Manual trigger (`archive todos`) → archive ALL HISTORY entries
- TODO.md > 400 lines AND entry is ≥7 days old → archive
- Entry is >30 days old → archive (staleness rule)

### Step 3: Partition by completion month

For each task, extract the `Done:` or `Cancelled:` date. Compute target file: `YYYY-MM.md`.

### Step 4: Write to archive files

For each target month file:

1. If file doesn't exist → create with header:
   ```markdown
   # TODO Archive — {Month Name} {Year}

   > Tasks archived from TODO.md

   ---
   ```

2. Check for duplicate task IDs (idempotency guard) and skip re-appending blocks already present in the month file
3. Append tasks under `## YYYY-MM-DD` date headers (reverse-chronological)
4. Compute and add metadata: `Duration:`, `Issue:` (extract ticket IDs from tags/description)

### Step 5: Update INDEX.md

Rebuild INDEX.md from all archive files:

```markdown
# TODO Archive Index

> Total archived: {count} tasks across {n} months

| Month | Tasks | Top Tags | Related Issues |
|-------|-------|----------|---------------|
| 2026-03 | 42 | #engineering (18) | PROJ-$1, PROJ-$1 |
| 2026-02 | 38 | #recruiting (12) | PROJ-$1 |
```

### Step 6: Remove archived tasks from TODO.md

Remove only the archived entries from the HISTORY section. Keep any entries that didn't meet archival criteria.

### Step 7: Integrity verification

```
pre_history_count = {N}
removed_from_history = {M}
post_history_count = {N - M}
```

If mismatch → ABORT, restore from backup, report error.

---

## Archive File Format

```markdown
# TODO Archive — March 2026

> Tasks archived from TODO.md

---

## 2026-03-18
- [x] [20260315-01] Fix alarm tuning across repos #engineering-backend
  - Added: 2026-03-15
  - Done: 2026-03-18T14:30:00
  - Duration: 3 days
  - Progress: Tuned P1/P2 alarms, added runbook URLs
  - Issue: PROJ-$1

## 2026-03-15
- [x] [20260314-02] Review config PR #engineering-backend
  - Added: 2026-03-14
  - Done: 2026-03-15T10:30:00
  - Duration: 1 day
  - Progress: Approved with minor suggestions
```

---

## Search Interface

### By keyword
```
search archived todos for "alarm tuning"
→ grep -rn "alarm tuning" "$ARCHIVE_DIR"/*.md
```

### By issue ID
```
search archived todos for PROJ-$1
→ grep -rn "PROJ-$1" "$ARCHIVE_DIR"/*.md
```

### By month
```
show archived todos from March 2026
→ cat "$ARCHIVE_DIR/2026-03.md"
```

### By date range
```
show archived todos from 2026-02-01 to 2026-03-15
→ cat 2026-02.md 2026-03.md (then filter by date headers)
```

---

## Integrity & Safety

- **Locking:** Uses existing `todo-lock.sh` (from todo-management)
- **Backup:** TODO.md backed up before any modification (existing mechanism)
- **Idempotency:** Task IDs checked before appending — duplicates skipped
- **Dry-run:** Report what would be archived without modifying files
- **Recovery:** If counts mismatch post-archive → restore from backup

---

## Edge Cases

| Scenario | Resolution |
|----------|-----------|
| Task completed then re-opened | Archive entry stays (immutable). New ACTIVE entry with `Reopened from [ID]` |
| Concurrent archive attempts | `todo-lock.sh` serializes access |
| Archive file already has entries for that day | Append under existing date header (no duplicate header) |
| HISTORY section is empty | No-op, report "No completed tasks to archive" |
| No HISTORY section exists | No-op, report "No HISTORY section found" |
