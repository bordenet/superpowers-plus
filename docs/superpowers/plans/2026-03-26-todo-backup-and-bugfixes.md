# TODO Backup Ring + Bug Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans

**Goal:** (1) Fix 8 bugs found in harsh review of PRs #262/#264, (2) implement shadow ring buffer + time-bucketed backups.

**Repo:** `superpowers-plus` (GitHub-first)

---

## Task 1: Fix `resolve-env-path.sh` to support `.todo-registry`

- [ ] **Step 1:** Add `.todo-registry` check to `resolve_path()` — check registry before env var fallback.
- [ ] **Step 2:** Add source labeling: `registry`, `env`, or `default`.

## Task 2: Fix `todo-crud.sh` dead code

- [ ] **Step 1:** Update lines 128-133 to source `.todo-registry` instead of relying on `.env` for `TODO_FILE_PATH`.

## Task 3: Fix `todo-preflight.sh --diagnose`

- [ ] **Step 1:** Update source label to include `.todo-registry`.
- [ ] **Step 2:** Add `chflags uchg` detection to protection status.
- [ ] **Step 3:** Distinguish honeypot from stray in detection logic.

## Task 4: Fix `_clear_immutable` / `_set_immutable` logging

- [ ] **Step 1:** Log failures to stderr instead of silently passing.
- [ ] **Step 2:** Add Linux `chattr` caveat comment.

## Task 5: Implement shadow ring buffer (5 slots)

- [ ] **Step 1:** Change `SHADOW_DIR` structure: `TODO.shadow.{1-5}.md`.
- [ ] **Step 2:** Add `_rotate_ring()` function — shift 4→5, 3→4, 2→3, 1→2.
- [ ] **Step 3:** Update `_update_shadow()` to call `_rotate_ring()` then write shadow.1.
- [ ] **Step 4:** Update `_check_annihilation()` to compare against oldest ring entry (shadow.5 or highest existing).
- [ ] **Step 5:** Migrate existing single shadow to shadow.1 on first write.

## Task 6: Implement time-bucketed snapshots (30 min, keep 5)

- [ ] **Step 1:** Add `_maybe_create_timed_snapshot()` — check newest snapshot mtime, create if >30 min old.
- [ ] **Step 2:** Add snapshot rotation — delete oldest when count > 5.
- [ ] **Step 3:** Call from `write_file()` before the write.

## Task 7: Add .bak file rotation (keep last 10)

- [ ] **Step 1:** In `backup()` function, after creating new .bak, delete all but newest 10.

## Task 8: Update tests

- [ ] **Step 1:** Update existing shadow tests for ring buffer structure.
- [ ] **Step 2:** Add test for ring rotation (5 writes, verify all 5 slots).
- [ ] **Step 3:** Add test for annihilation detection against oldest ring entry.
- [ ] **Step 4:** Add test for timed snapshot creation and rotation.

## Task 9: Test, commit, PR, merge, sync

- [ ] Run all tests, doctor checks, commit, PR, merge.
