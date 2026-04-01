# TODO Path Obscuring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans

**Goal:** Make it physically impossible for agents to corrupt TODO.md by (1) hiding the path, (2) using OS-level immutability, and (3) deploying a honeypot.

**Repo:** `superpowers-plus` (GitHub-first)

---

## Task 1: Add `chflags uchg` / `chattr +i` to protect/unprotect

**Files:** `tools/todo-engine.py`

- [ ] **Step 1:** Update `_protect_file()` to try `chflags uchg` (macOS) first, then `chattr +i` (Linux), then fall back to `chmod 444`.
- [ ] **Step 2:** Update `_unprotect_file()` to try `chflags nouchg` first, then `chattr -i`, then fall back to `chmod 644`.
- [ ] **Step 3:** Update existing tests in `FileProtectionTests` to verify the stronger protection.

## Task 2: Add `.todo-registry` path resolution

**Files:** `tools/todo-engine.py`, `tools/todo-preflight.sh`

- [ ] **Step 1:** Update `resolve_todo_path()` priority:
  1. `TODO_FILE_PATH` env var (for testing — NOT in .env)
  2. `~/.codex/.todo-registry` (new private file)
  3. `~/.codex/.env` `TODO_FILE_PATH` (backward compat, but deprecated)
  4. Default `~/.codex/TODO.md`
- [ ] **Step 2:** Create `~/.codex/.todo-registry` containing the real path.
- [ ] **Step 3:** Remove `TODO_FILE_PATH` from `~/.codex/.env`.
- [ ] **Step 4:** Update `todo-preflight.sh --diagnose` to show which resolution source was used.

## Task 3: Deploy honeypot at `~/.codex/TODO.md`

- [ ] **Step 1:** Create `~/.codex/TODO.md` with warning content and `chflags uchg`.
- [ ] **Step 2:** Add honeypot creation to `install.sh` (if canonical path != default path).

## Task 4: Update rules and skill docs

**Files:** `rules/core.always.md`, `skills/productivity/todo-management/skill.md`

- [ ] **Step 1:** Remove ALL path mentions from `core.always.md` — only reference `todo-crud.sh`.
- [ ] **Step 2:** Add incident record and Layer 6 (path obscuring) to skill.md.
- [ ] **Step 3:** Update defense layers table.

## Task 5: Test, commit, PR, merge, sync

- [ ] **Step 1:** Run `python3 -m unittest tools.tests.test_todo_engine -v`
- [ ] **Step 2:** Run `bash tools/doctor-checks.sh`
- [ ] **Step 3:** Commit on branch `fix/todo-obscure-path`, push, PR, merge.
