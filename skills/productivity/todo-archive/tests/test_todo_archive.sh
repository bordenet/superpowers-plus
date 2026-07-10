#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_SCRIPT="$SCRIPT_DIR/../todo-archive.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local root
  root=$(mktemp -d /tmp/todo-archive-test-XXXXXX)
  mkdir -p "$root/home/.codex" "$root/data/todo-archives"
  printf 'TODO_FILE_PATH=%s\n' "$root/data/default.md" > "$root/home/.codex/.env"
  echo "$root"
}

write_large_todo() {
  local path="$1"
  {
    echo '# ACTIVE TASKS'
    echo
    echo '## P1 - Today'
    echo
    for i in $(seq 1 18); do
      printf -- '- [ ] [20260323-%02d] Filler active task %02d #test\n' "$i" "$i"
      echo '  - Added: 2026-03-23'
      echo
    done
    echo '## P2 - This Week'
    echo
    echo '## P3 - Backlog'
    echo
    echo '---'
    echo
    echo '# HISTORY'
    echo
    echo '## 2026-03-22'
    echo '- [x] [20260322-34] Purge stale DocForge branches while preserving unique work #engineering'
    echo '  - Added: 2026-03-22'
    echo '  - Done: 2026-03-22T17:00:00'
    echo
    echo '- [x] [20260322-31] Verify hosted DocForge app includes the PDF blank-export fix #engineering'
    echo '  - Added: 2026-03-22'
    echo '  - Done: 2026-03-22T18:00:00'
    echo
    echo '---'
    echo
    echo '# DEFERRED'
    echo
    echo '---'
    echo
    echo '# METRICS'
  } > "$path"
}

write_small_valid_todo() {
  local path="$1"
  cat > "$path" <<'EOF'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260322-10] Keep one active task #misc
  - Added: 2026-03-22

## P2 - This Week

## P3 - Backlog

---

# HISTORY

## 2026-03-01
- [x] [20260301-01] Done one #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00

- [x] [20260301-02] Done two #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T11:00:00

- [x] [20260301-03] Done three #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T12:00:00

- [x] [20260301-04] Done four #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T13:00:00

- [x] [20260301-05] Done five #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T14:00:00

---

# DEFERRED

---

# METRICS
EOF
}

test_duplicate_archive_entries_are_not_readded() {
  local root output todo history_count
  root=$(make_fixture)
  write_large_todo "$root/data/default.md"
  cat > "$root/data/todo-archives/2026-03.md" <<'EOF'
# TODO Archive — March 2026

> Tasks archived from TODO.md

---

- [x] [20260322-34] Purge stale DocForge branches while preserving unique work #engineering
  - Added: 2026-03-22
  - Done: 2026-03-22T17:00:00
EOF
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) || fail "archive command failed unexpectedly"
  [[ "$output" != *'INTEGRITY WARNING'* ]] || fail 'integrity warning should not appear for duplicate-only archive case'
  [[ "$(grep -c '20260322-34' "$root/data/todo-archives/2026-03.md")" == "1" ]] || fail 'duplicate archived task should not be appended again'
  [[ "$(grep -c '20260322-31' "$root/data/todo-archives/2026-03.md")" == "1" ]] || fail 'new archived task should be appended once'
  todo=$(cat "$root/data/default.md")
  history_count=$(printf '%s\n' "$todo" | awk '/^# HISTORY/{flag=1;next}/^# DEFERRED/{flag=0} flag' | grep -cE '^- \[(x|-)\]' || true)
  [[ "$history_count" == "0" ]] || fail "expected 0 history tasks after forced archive, found $history_count"
}

test_explicit_todo_file_path_overrides_env_default() {
  local root output
  root=$(make_fixture)
  write_large_todo "$root/data/default.md"
  write_large_todo "$root/data/target.md"
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/target.md" "$ARCHIVE_SCRIPT" --dry-run 2>&1) || fail 'dry-run should succeed'
  [[ "$output" == *"$root/data/target.md"* ]] || fail 'explicit TODO_FILE_PATH should take precedence over ~/.codex/.env'
}

test_index_total_counts_all_archive_files() {
  local root output index_line
  root=$(make_fixture)
  write_large_todo "$root/data/default.md"
  cat > "$root/data/todo-archives/2026-03.md" <<'EOF'
# TODO Archive — March 2026

> Tasks archived from TODO.md

---

- [x] [20260322-34] Purge stale DocForge branches while preserving unique work #engineering
  - Added: 2026-03-22
  - Done: 2026-03-22T17:00:00

- [x] [20260322-99] Earlier archived task #engineering
  - Added: 2026-03-22
  - Done: 2026-03-22T12:00:00
EOF
  cat > "$root/data/todo-archives/2026-02.md" <<'EOF'
# TODO Archive — February 2026

> Tasks archived from TODO.md

---

- [x] [20260228-01] Existing February task #engineering
  - Added: 2026-02-28
  - Done: 2026-02-28T11:00:00
EOF
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) || fail 'archive command failed unexpectedly'
  index_line=$(grep '^> Total archived:' "$root/data/todo-archives/INDEX.md")
  [[ "$index_line" == '> Total archived: 4 tasks across 2 months' ]] || fail "unexpected index summary: $index_line"
}

test_small_valid_todo_archives_successfully() {
  local root output line_count history_count
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) || fail "small valid todo should archive without aborting"
  [[ "$output" != *'🛑 ABORT'* ]] || fail 'small valid todo should not hit the rebuild size abort'
  line_count=$(wc -l < "$root/data/default.md" | tr -d ' ')
  (( line_count < 50 )) || fail "expected archived small TODO to remain under 50 lines, found $line_count"
  [[ -f "$root/data/todo-archives/INDEX.md" ]] || fail 'archive index should be created for small valid todo'
  grep -q '\[20260322-10\]' "$root/data/default.md" || fail 'active task should be preserved after archive'
  history_count=$(awk '/^# HISTORY/{flag=1;next}/^# DEFERRED/{flag=0} flag' "$root/data/default.md" | grep -cE '^- \[(x|-)\]' || true)
  [[ "$history_count" == "0" ]] || fail "expected 0 history tasks after forced archive, found $history_count"
}

test_archive_succeeds_on_protected_todo() {
  local root output history_count shadow_file
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"

  if command -v chflags >/dev/null 2>&1; then
    chflags uchg "$root/data/default.md"
  else
    chmod 0444 "$root/data/default.md"
  fi

  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) || {
    if command -v chflags >/dev/null 2>&1; then
      chflags nouchg "$root/data/default.md" 2>/dev/null || true
    fi
    fail "protected todo should archive without write-path failure"
  }

  [[ "$output" != *'Operation not permitted'* ]] || fail 'archive should not try to rename over a protected TODO directly'
  history_count=$(awk '/^# HISTORY/{flag=1;next}/^# DEFERRED/{flag=0} flag' "$root/data/default.md" | grep -cE '^- \[(x|-)\]' || true)
  [[ "$history_count" == "0" ]] || fail "expected 0 history tasks after protected archive, found $history_count"
  shadow_file="$root/home/.codex/todo-shadow/TODO.md"
  [[ -f "$shadow_file" ]] || fail 'shadow TODO should be refreshed after archive'
  cmp -s "$shadow_file" "$root/data/default.md" || fail 'shadow TODO should match rebuilt canonical TODO'
  local bak_file
  bak_file=$(compgen -G "$root/home/.codex/todo-shadow/TODO.*.bak" | head -1)
  [[ -n "$bak_file" ]] || fail 'persistent backup .bak should be created in todo-shadow'
  grep -q '# HISTORY' "$bak_file" || fail 'persistent backup should contain pre-archive HISTORY section'

  if command -v chflags >/dev/null 2>&1; then
    chflags nouchg "$root/data/default.md" 2>/dev/null || true
  fi
}

test_abort_leaves_no_archive_files_or_index_behind() {
  # A safety-gate abort inside write-archives.sh used to fire AFTER
  # the monthly archive file and INDEX.md were already written, permanently
  # duplicating archived tasks in both stores. Force an abort via a caller
  # contract violation (write-archives.sh's own header documents the
  # variables it expects from its caller) and verify NOTHING under
  # $ARCHIVE_DIR was written -- not the monthly file, not INDEX.md.
  local root
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"

  # A multi-statement setup-then-source sequence must run as a real external
  # script, not an inline `$(...)` subshell: when that substitution is used
  # as the operand of `&&`/`||` (needed below so this deliberately-failing
  # case doesn't trip test_todo_archive.sh's own top-level set -e), bash
  # disables errexit for the ENTIRE substitution's execution tree, and a
  # `set -e` re-asserted inside the subshell does not restore it -- so a
  # `return 1` from the sourced script would be silently ignored and
  # execution would fall through to the next line as if it had succeeded.
  local write_archives="$SCRIPT_DIR/../lib/write-archives.sh"
  local runner
  runner=$(mktemp)
  cat > "$runner" <<RUNNER_EOF
set -euo pipefail
HOME="$root/home"
PYTHON=python3
TODO_ENGINE="$SCRIPT_DIR/../../../../tools/todo-engine.py"
TODO_PATH="$root/data/default.md"
ARCHIVE_DIR="$root/data/todo-archives"
TODO_LINES=\$(wc -l < "\$TODO_PATH" | tr -d ' ')
TASKS_TO_ARCHIVE="- [x] [20260301-01] Done one #misc
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00"
TASK_COUNT=1
KEPT_LINES=""
# Deliberately wrong: real HISTORY_START/END for this fixture put the
# rebuild's ACTIVE section intact, but a caller bug could pass a boundary
# that slices into ACTIVE -- exactly what the "ACTIVE task count changed"
# gate exists to catch. HISTORY_START=2 lands inside "# ACTIVE TASKS",
# before the P1 task line, so the rebuilt ACTIVE section loses that task.
HISTORY_START=2
HISTORY_END=\$(grep -n '^---\$' "\$TODO_PATH" | sed -n '2p' | cut -d: -f1)
HISTORY_BLOCK="- [x] [20260301-01] Done one #misc"
source "$write_archives"
echo "UNEXPECTED_SUCCESS"
RUNNER_EOF

  local output status
  output=$(bash "$runner" 2>&1) && status=0 || status=$?
  rm -f "$runner"

  [[ "$status" -ne 0 ]] || fail "corrupted HISTORY_START should have triggered an abort, got: $output"
  echo "$output" | grep -q 'ABORT' || fail "expected an ABORT message, got: $output"
  [[ ! -e "$root/data/todo-archives/INDEX.md" ]] || fail 'INDEX.md must not exist after an abort (nothing should be written before validation passes)'
  local archive_files
  archive_files=$(find "$root/data/todo-archives" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  [[ "$archive_files" == "0" ]] || fail "todo-archives/ must be empty after an abort, found $archive_files entries"

  rm -rf "$root"
}

test_annihilation_guard_rejection_leaves_nothing_written() {
  # An earlier fix only reordered write-archives.sh's OWN gates ahead of
  # the archive-file/INDEX.md writes.
  # The FINAL commit still calls todo_engine.write_file(), which runs its own
  # independent checks (validate_structure(), _check_annihilation()) that
  # weren't replicated -- so a rejection there (e.g. the shadow-based
  # size-drop guard) could still fire AFTER archive files were already
  # written, reproducing the exact defect the reordering was supposed to
  # eliminate. Force that exact scenario: an artificially large shadow file
  # makes the post-archive rebuild look like a >60% wipeout.
  local root
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"

  python3 - "$root/data/default.md" "$root/home/.codex/todo-shadow/TODO.md" <<'PYEOF'
import sys
todo_path, shadow_path = sys.argv[1:3]
import os
os.makedirs(os.path.dirname(shadow_path), exist_ok=True)
content = open(todo_path).read()
padding = "- [ ] [20260709-99] padding task #pad\n  - Added: 2026-07-09\n\n" * 200
big = content.replace("## P1 - Today", "## P1 - Today\n\n" + padding, 1)
open(shadow_path, "w").write(big)
PYEOF

  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "annihilation-guard scenario should have aborted, got: $output"
  echo "$output" | grep -qi 'annihilation\|failed todo-engine' \
    || fail "expected an annihilation/validation ABORT message, got: $output"
  local archive_files
  archive_files=$(find "$root/data/todo-archives" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  [[ "$archive_files" == "0" ]] || fail "todo-archives/ must be empty when write_file()'s own gates reject the content, found $archive_files entries"

  if command -v chflags >/dev/null 2>&1; then
    chflags -R nouchg "$root" 2>/dev/null || true
  fi
  rm -rf "$root"
}

test_archive_refuses_to_run_while_lock_is_held() {
  # The lock-acquire fix in write-archives.sh had no automated coverage
  # proving it actually acquires the shared lock: only that the happy path
  # still works. Pre-hold
  # the lock (simulating a concurrent todo-crud.sh write) and confirm the
  # archive run aborts cleanly instead of racing ahead of it.
  local root
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"
  local todo_engine="$SCRIPT_DIR/../../../../tools/todo-engine.py"

  HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" python3 - "$todo_engine" "$root/data/default.md" <<'PYEOF'
import importlib.util, sys
engine_path, todo_path = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("todo_engine", engine_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.acquire_lock(todo_path), "setup: could not acquire lock"
PYEOF

  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "archive should abort while the lock is held, got: $output"
  echo "$output" | grep -qi 'could not acquire lock' \
    || fail "expected a lock-acquisition ABORT message, got: $output"
  grep -q '\[x\]' "$root/data/default.md" \
    || fail 'TODO.md must be unchanged (still contains the un-archived history task) while the lock is held'
  [[ ! -e "$root/data/todo-archives/INDEX.md" ]] \
    || fail 'no archive files should be written while the lock is held'

  rm -rf "$root"
}

test_lock_is_released_even_when_temp_file_cleanup_fails() {
  # cleanup_tmp() runs as an EXIT trap under the caller's inherited set -e.
  # A trap function aborts at its first failing statement just like normal
  # script execution -- if `rm -f` (removing $SNAPSHOT_PATH/$REBUILD_TMP)
  # ever failed with release_todo_lock listed after it, the lock would never
  # be released and would sit leaked for its full declared ttl (up to 600s).
  # Force that failure via a PATH-shadowing fake `rm` and confirm the archive
  # still completes AND the lock is released regardless.
  local root
  root=$(make_fixture)
  write_small_valid_todo "$root/data/default.md"

  local fake_bin
  fake_bin=$(mktemp -d)
  cat > "$fake_bin/rm" <<'FAKERM_EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    *.rebuild.tmp) echo "fake-rm: SIMULATED FAILURE removing $arg" >&2; exit 1 ;;
  esac
done
exec /bin/rm "$@"
FAKERM_EOF
  chmod +x "$fake_bin/rm"

  local output status
  output=$(PATH="$fake_bin:$PATH" HOME="$root/home" TODO_FILE_PATH="$root/data/default.md" "$ARCHIVE_SCRIPT" --force 2>&1) \
    && status=0 || status=$?
  rm -rf "$fake_bin"

  [[ "$status" -eq 0 ]] || fail "archive should still succeed despite the temp-file rm failure, got: $output"
  [[ -e "$root/data/todo-archives/INDEX.md" ]] \
    || fail "archive should have completed and written INDEX.md, got: $output"
  [[ ! -d "$root/data/.TODO.md.lock" ]] \
    || fail "lock must be released even when temp-file cleanup fails, but .TODO.md.lock still exists"

  if command -v chflags >/dev/null 2>&1; then
    chflags -R nouchg "$root" 2>/dev/null || true
  fi
  rm -rf "$root"
}

test_duplicate_archive_entries_are_not_readded
test_explicit_todo_file_path_overrides_env_default
test_index_total_counts_all_archive_files
test_small_valid_todo_archives_successfully
test_archive_succeeds_on_protected_todo
test_abort_leaves_no_archive_files_or_index_behind
test_annihilation_guard_rejection_leaves_nothing_written
test_archive_refuses_to_run_while_lock_is_held
test_lock_is_released_even_when_temp_file_cleanup_fails
echo 'PASS: todo-archive regression tests'
