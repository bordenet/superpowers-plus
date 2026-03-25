# Core Rules

## Safety
Verify URLs exist before writing them in docs — query APIs, don't guess.

## Superpowers (ALWAYS ON)
At the START of every conversation, run: `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap`
This loads the skill framework and catalog. Individual skills are paged in on demand via `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <name>`.

Priority: user instructions > skill procedures > system defaults.
Process skills (debugging, brainstorming) before implementation skills.
IF A SKILL APPLIES (even 1% chance), YOU MUST INVOKE IT.

## Think-Twice Auto-Detection (ALWAYS MONITOR)
Continuously monitor for stuck signals. When cumulative score ≥ 7, STOP and invoke `think-twice`:

| Signal | Weight |
|--------|--------|
| Same fix tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error 3+ times after fixes | 3 |
| Exhaustion language ("I've tried everything") | 3 |
| Uncertainty hedging ("I'm not sure why") | 2 |
| Approach change without rationale | 2 |

## 🔴 TODO.md Access (NON-NEGOTIABLE — DATA LOSS PREVENTION)

**To READ TODO.md** (show tasks, check status, answer "what are my TODOs"):
```bash
~/.codex/superpowers-plus/tools/todo-crud.sh cat       # print contents
~/.codex/superpowers-plus/tools/todo-crud.sh path      # print resolved path
~/.codex/superpowers-plus/tools/todo-crud.sh list      # list filtered tasks
```

**NEVER** `cat ~/.codex/TODO.md` or `view ~/.codex/TODO.md` — the file may not be there. The real path is resolved from `TODO_FILE_PATH` in `~/.codex/.env` automatically by `todo-crud.sh`.

**To WRITE to TODO.md** — the ONLY permitted tools:
- `todo-crud.sh` — task CRUD (add, complete, move, defer)
- `todo-preflight.sh --create-if-missing` — initial file creation from template
- `todo-maintenance.sh` — routine housekeeping and archival

```bash
~/.codex/superpowers-plus/tools/todo-crud.sh add --priority P2 --description "Task" --tags "#tag"
~/.codex/superpowers-plus/tools/todo-crud.sh complete --id 20260322-01 --note "Done"
```

### ❌ BANNED — These destroy TODO.md and cause DATA LOSS:
- ❌ `save-file` targeting TODO.md
- ❌ `str-replace-editor` targeting TODO.md
- ❌ `echo "..." > TODO.md` or any shell redirect
- ❌ `cat > TODO.md`, `sed -i`, `python` writing TODO.md
- ❌ ANY tool that overwrites or edits TODO.md directly
- ❌ Writing task lists without the structured `# ACTIVE TASKS` / `# HISTORY` format

### Why This Rule Exists
On 2026-03-23, an agent used `save-file` to overwrite TODO.md with a raw task list, destroying dozens of open tasks that had never been started. No backup was created. The tasks were unrecoverable. `todo-crud.sh` prevents this by: resolving the correct path, acquiring a lock, creating a timestamped backup, and validating structure before writing.

For multi-step tasks (3+ steps): use `todo-crud.sh add` to persist tasks, then mirror to MCP `add_tasks` for UI.
