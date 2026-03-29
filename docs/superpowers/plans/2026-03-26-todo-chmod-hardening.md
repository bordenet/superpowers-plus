# TODO chmod Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate the failure mode where agents bypass `todo-crud.sh`, hit chmod 444, and write to stray TODO files.

**Architecture:** Three defense layers: (1) fix the `core.always.md` rule to mandate the tool, (2) add `todo-engine.py` validation that detects and refuses stray-path writes, (3) add a preflight diagnostic command.

**Repo:** `superpowers-plus` — GitHub workflow (branch → PR → merge)

---

## Root Cause

Sibling agent read `core.always.md` which says "write tasks to `$TODO_FILE_PATH` (default `~/.codex/TODO.md`)" — no mention of `todo-crud.sh`. Agent tried direct write, hit chmod 444, concluded path was "unwritable", fell back to `~/.codex/TODO.md` (the documented "default"), creating a disconnected stray file.

## Fix Summary

| # | Layer | Fix | File |
|---|-------|-----|------|
| 1 | Rule | Rewrite `core.always.md` TODO section to mandate `todo-crud.sh` and ban fallback | `~/.augment/rules/core.always.md` |
| 2 | Engine | Add `_validate_no_stray()` check — refuse writes if path != resolved `$TODO_FILE_PATH` | `tools/todo-engine.py` |
| 3 | Engine | Improve `_unprotect_file()` error message — tell agent to use `todo-crud.sh` | `tools/todo-engine.py` |
| 4 | Preflight | Add `todo-preflight.sh --diagnose` mode — reports path, permissions, chmod state | `tools/todo-preflight.sh` |
| 5 | Skill | Add incident record to `todo-management/skill.md` | `skills/todo-management/skill.md` |
| 6 | Test | Add test for chmod 444 write cycle | `test/test_todo_engine.bats` or Python unittest |

---

### Task 1: Fix `core.always.md` TODO section

**Files:** `~/.augment/rules/core.always.md` (line 64-65)

- [ ] **Step 1:** Replace the current TODO section with:

```markdown
## TODO.md
For multi-step tasks (3+ steps): write tasks to `$TODO_FILE_PATH` using `~/.codex/superpowers-plus/tools/todo-crud.sh`. Mirror to MCP `add_tasks` as supplementary.

🔴 **NEVER write TODO.md directly** — the file is deliberately chmod 444 (read-only). Only `todo-crud.sh` can safely write to it (it handles chmod 644 → write → chmod 444 automatically).

🔴 **NEVER fall back to `~/.codex/TODO.md`** or any other path if `$TODO_FILE_PATH` is "unwritable." The read-only permission is intentional protection, not a broken path. If `todo-crud.sh` fails, STOP and tell the user — do NOT write elsewhere.
```

- [ ] **Step 2:** Verify line count is still ≤150 per AGENTS.md self-manage rule.

---

### Task 2: Add stray-path detection to `todo-engine.py`

**Files:** `tools/todo-engine.py`

- [ ] **Step 1:** Add a `_validate_canonical_path()` function after `_protect_file()`:

```python
def _validate_canonical_path(path: str) -> None:
    """Refuse writes if path doesn't match resolved TODO_FILE_PATH.
    
    Prevents agents from writing to ~/.codex/TODO.md or other stray
    locations when the real path is elsewhere (e.g., external synced folder).
    """
    canonical = resolve_todo_path()
    real_canonical = os.path.realpath(canonical)
    real_path = os.path.realpath(path)
    if real_path != real_canonical:
        _error(
            f"REFUSED: Write target '{path}' does not match "
            f"TODO_FILE_PATH '{canonical}'. This looks like a stray write. "
            f"Use todo-crud.sh which resolves the correct path automatically."
        )
```

- [ ] **Step 2:** Call `_validate_canonical_path(path)` at the top of `write_file()`, before `validate_structure()`.

- [ ] **Step 3:** Improve `_unprotect_file()` error message to reference `todo-crud.sh`:

Change the RuntimeError text from:

```text
"CRITICAL: Cannot unprotect TODO.md for writing: {exc}. File protection may be broken on this filesystem."
```

to:

```bash
"CRITICAL: Cannot chmod TODO.md for writing: {exc}. "
"The file is deliberately read-only (chmod 444). "
"Use todo-crud.sh which handles chmod automatically. "
"NEVER write TODO.md directly or fall back to a different path."
```

---

### Task 3: Add `--diagnose` mode to `todo-preflight.sh`

**Files:** `tools/todo-preflight.sh`

- [ ] **Step 1:** Add a `--diagnose` flag handler that prints:
  - Resolved `$TODO_FILE_PATH` (from env, .env, or default)
  - File exists? (yes/no)
  - File permissions (octal)
  - File writable by current user? (chmod test)
  - Shadow file exists? (`~/.codex/todo-shadow/TODO.md`)
  - Stray TODO files detected? (check `~/.codex/TODO.md` if it's not the canonical path)

- [ ] **Step 2:** If stray `~/.codex/TODO.md` exists AND canonical path is elsewhere, print a WARNING with instructions to merge and delete the stray.

---

### Task 4: Add incident record to skill.md

**Files:** `skills/todo-management/skill.md`

- [ ] **Step 1:** Add to the Defense Layers table (after line 108):

```markdown
| 5. Stray path detection | `_validate_canonical_path()` in `write_file()` | Writes to wrong TODO.md path (e.g., ~/.codex/TODO.md when real path is external synced folder) |
```

- [ ] **Step 2:** Add incident to the destructive write ban section:

```markdown
**Incident 2026-03-26:** A sibling agent tried to write directly to `$TODO_FILE_PATH`, hit chmod 444 ("unwritable"), and fell back to `~/.codex/TODO.md` — creating a stray disconnected TODO file. Root cause: `core.always.md` didn't mandate `todo-crud.sh` and advertised `~/.codex/TODO.md` as a "default" fallback.
```

---

### Task 5: Test the chmod write cycle

**Files:** `test/test_todo_engine.bats` or `test/test_todo_engine_chmod.py`

- [ ] **Step 1:** Write a test that:
  1. Creates a temp TODO.md with valid structure
  2. Sets it to chmod 444
  3. Calls `todo-crud.sh add` — verify it succeeds
  4. Verify file is back to chmod 444 after the write
  5. Verify the task was actually added

- [ ] **Step 2:** Write a test that:
  1. Creates a TODO.md at a non-canonical path
  2. Calls `todo-engine.py add` with that path
  3. Verify it REFUSES with stray-path error

---

### Task 6: Commit, PR, merge (GitHub-first)

- [ ] **Step 1:** Branch from `upstream/main`
- [ ] **Step 2:** Commit with message: `fix: harden TODO writes against chmod 444 fallback to stray paths`
- [ ] **Step 3:** Push to `upstream`, create PR on GitHub
- [ ] **Step 4:** After merge, verify changes on `main`.
