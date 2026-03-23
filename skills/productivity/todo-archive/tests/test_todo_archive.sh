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

test_duplicate_archive_entries_are_not_readded
test_explicit_todo_file_path_overrides_env_default
echo 'PASS: todo-archive regression tests'
