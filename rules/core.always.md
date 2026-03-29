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

### ❌ BANNED — These destroy TODO.md and cause DATA LOSS

- ❌ `save-file` targeting TODO.md
- ❌ `str-replace-editor` targeting TODO.md
- ❌ `echo "..." > TODO.md` or any shell redirect
- ❌ `cat > TODO.md`, `sed -i`, `python` writing TODO.md
- ❌ ANY tool that overwrites or edits TODO.md directly
- ❌ Writing task lists without the structured `# ACTIVE TASKS` / `# HISTORY` format

### Why This Rule Exists

On 2026-03-23, an agent used `save-file` to overwrite TODO.md with a raw task list, destroying dozens of open tasks that had never been started. No backup was created. The tasks were unrecoverable.

### 🔴 NEVER fall back to a different path

`~/.codex/TODO.md` is a **honeypot** — writing there does nothing useful. The real file is OS-immutable (`chflags uchg`) and its path is private. Do NOT search for it. Use `todo-crud.sh` exclusively.

Run `todo-preflight.sh --diagnose` to check path, permissions, and detect stray TODO files.

### 🔴 Do NOT look for the file path

The TODO.md path is NOT in `.env`, NOT in environment variables. It is stored in a private registry that only `todo-crud.sh` and the engine can read. Do NOT try to discover or write to it directly.

### Enforcement (7 layers — you CANNOT bypass all of them)

1. **Rules** — this ban (you're reading it now)
2. **Structural validation** — `write_file()` rejects content missing required headers/sections
3. **OS immutability** — TODO.md is `chflags uchg` (macOS) / `chattr +i` (Linux) — `Operation not permitted` for ALL writes, even chmod attempts
4. **chmod 444** — secondary protection layer if immutability unavailable
5. **Shadow + annihilation detection** — pre-write comparison blocks >60% size drops
6. **Stray path detection** — `_validate_canonical_path()` refuses writes to any non-canonical path
7. **Path obscuring** — path removed from `.env`, stored in private registry; honeypot at default location

**If annihilation detection blocks a legitimate write:** delete `~/.codex/todo-shadow/TODO.md` and retry.

### Incidents

| Date | What Happened |
|------|---------------|
| 2026-03-23 | Agent used `save-file` to overwrite TODO.md, destroying dozens of open tasks. Unrecoverable. |
| 2026-03-26a | Agent hit chmod 444, fell back to `~/.codex/TODO.md` — stray file. Fix: `_validate_canonical_path()`. |
| 2026-03-26b | GPT-5.4 agent wrote directly to TODO.md despite all rules. Fix: `chflags uchg` + path obscuring + honeypot. |

For multi-step tasks (3+ steps): use `todo-crud.sh add` to persist tasks, then mirror to MCP `add_tasks` for UI.
