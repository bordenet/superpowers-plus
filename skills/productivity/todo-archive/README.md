# todo-archive

Archive completed tasks from `TODO.md` to monthly satellite files. Companion to `todo-management` (from superpowers-plus).

## Problem

`TODO.md` has a 500-line hard limit (LLM context window constraint). Completed tasks in the HISTORY section accumulate and eventually get purged, losing operational history.

## Solution

Move completed tasks to monthly archive files (`YYYY-MM.md`) in a `todo-archives/` directory alongside `TODO.md`. An `INDEX.md` manifest tracks archive contents.

## Files

| File | Purpose |
|------|---------|
| `skill.md` | Skill definition with triggers and full workflow spec |
| `todo-archive.sh` | Core archival logic (parse, partition, write, verify) |
| `todo-archive-search.sh` | Search across archived tasks |

## Usage

### Archive completed tasks

```bash
# Archive tasks meeting age criteria (7+ days if TODO.md > 400 lines, 30+ days always)
./todo-archive.sh

# Preview without modifying anything
./todo-archive.sh --dry-run

# Archive ALL history entries regardless of age
./todo-archive.sh --force
```

### Search archived tasks

```bash
# By keyword
./todo-archive-search.sh keyword "alarm tuning"

# By Linear issue
./todo-archive-search.sh linear DELTA-1239

# By month
./todo-archive-search.sh month 2026-03

# Statistics
./todo-archive-search.sh stats
```

## Archive Location

Archives live alongside `TODO.md`:
```
$(dirname $TODO_FILE_PATH)/todo-archives/
├── INDEX.md
├── 2026-02.md
├── 2026-03.md
└── ...
```

## Safety

- Backup created before every modification
- Duplicate task IDs skipped (idempotent)
- Post-archive integrity check (task count reconciliation)
- Uses existing `todo-lock.sh` for concurrency safety
