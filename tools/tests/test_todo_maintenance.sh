#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAINT_SCRIPT="$SCRIPT_DIR/../todo-maintenance.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local root
  root=$(mktemp -d /tmp/todo-maintenance-test-XXXXXX)
  mkdir -p "$root/home/.codex" "$root/data"
  printf 'TODO_FILE_PATH=%s\n' "$root/data/TODO.md" > "$root/home/.codex/.env"
  echo "$root"
}

write_due_todo() {
  local path="$1"
  cat > "$path" <<'EOF'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260310-01] Old maintenance task #plan-maintenance-upgrade #superpowers-plus
  - Added: 2026-03-10

- [ ] [20260322-03] Filler active task 03 #misc
  - Added: 2026-03-22

- [ ] [20260322-04] Filler active task 04 #misc
  - Added: 2026-03-22

- [ ] [20260322-05] Filler active task 05 #misc
  - Added: 2026-03-22

## P2 - This Week

- [ ] [20260322-02] Fresh task #misc
  - Added: 2026-03-22

- [ ] [20260322-06] Filler active task 06 #misc
  - Added: 2026-03-22

- [ ] [20260322-07] Filler active task 07 #misc
  - Added: 2026-03-22

- [ ] [20260322-08] Filler active task 08 #misc
  - Added: 2026-03-22

## P3 - Backlog

- [ ] [20260322-09] Filler backlog task 09 #misc
  - Added: 2026-03-22

- [ ] [20260322-10] Filler backlog task 10 #misc
  - Added: 2026-03-22

- [ ] [20260322-11] Filler backlog task 11 #misc
  - Added: 2026-03-22

- [ ] [20260322-12] Filler backlog task 12 #misc
  - Added: 2026-03-22

---

# HISTORY

## 2026-03-01
- [x] [20260301-01] Done one #superpowers-plus
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00

- [x] [20260301-02] Done two #superpowers-plus
  - Added: 2026-03-01
  - Done: 2026-03-01T11:00:00

- [x] [20260301-03] Done three #superpowers-plus
  - Added: 2026-03-01
  - Done: 2026-03-01T12:00:00

- [x] [20260301-04] Done four #superpowers-plus
  - Added: 2026-03-01
  - Done: 2026-03-01T13:00:00

- [x] [20260301-05] Done five #superpowers-plus
  - Added: 2026-03-01
  - Done: 2026-03-01T14:00:00

---

# DEFERRED

- [ ] [20260305-01] Deferred task #misc
  - Deferred: 2026-03-05
  - Reason: Waiting on input

---

# METRICS
EOF
}

write_clean_todo() {
  local path="$1"
  cat > "$path" <<'EOF'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260322-01] Normal task #misc
  - Added: 2026-03-22

## P2 - This Week

## P3 - Backlog

---

# HISTORY

---

# DEFERRED

---

# METRICS
EOF
}

test_dry_run_reports_due_and_stale_plan_tasks() {
  local root output
  root=$(make_fixture)
  write_due_todo "$root/data/TODO.md"
  output=$(HOME="$root/home" "$MAINT_SCRIPT" --json --dry-run 2>&1) || fail "dry-run failed unexpectedly"
  JSON_OUTPUT="$output" python3 - <<'PY'
import json, os
data = json.loads(os.environ["JSON_OUTPUT"])
assert data["archive_due"] is True, data
assert data["archive_requested"] is True, data
assert data["archive_performed"] is False, data
assert "history_count>=5" in data["archive_reasons"], data
assert "oldest_history_age_days>7" in data["archive_reasons"], data
assert data["before"]["stale_plan_count"] == 1, data
PY
  [[ ! -f "$root/data/todo-archives/INDEX.md" ]] || fail "dry-run should not create archives"
}

test_apply_runs_archive_and_updates_summary() {
  local root output history_count
  root=$(make_fixture)
  write_due_todo "$root/data/TODO.md"
  output=$(HOME="$root/home" "$MAINT_SCRIPT" --json 2>&1) || fail "maintenance run failed unexpectedly"
  JSON_OUTPUT="$output" python3 - <<'PY'
import json, os
data = json.loads(os.environ["JSON_OUTPUT"])
assert data["archive_performed"] is True, data
assert data["after"]["history_count"] == 0, data
assert data["after"]["stale_plan_count"] == 1, data
PY
  [[ -f "$root/data/todo-archives/INDEX.md" ]] || fail "archive index should be created"
  history_count=$(awk '/^# HISTORY/{flag=1;next}/^# DEFERRED/{flag=0} flag' "$root/data/TODO.md" | grep -cE '^- \[(x|-)\]' || true)
  [[ "$history_count" == "0" ]] || fail "expected 0 history tasks after maintenance archive, found $history_count"
}

test_clean_todo_skips_archive() {
  local root output
  root=$(make_fixture)
  write_clean_todo "$root/data/TODO.md"
  output=$(HOME="$root/home" "$MAINT_SCRIPT" --json 2>&1) || fail "clean maintenance run failed unexpectedly"
  JSON_OUTPUT="$output" python3 - <<'PY'
import json, os
data = json.loads(os.environ["JSON_OUTPUT"])
assert data["archive_due"] is False, data
assert data["archive_performed"] is False, data
assert data["before"]["stale_plan_count"] == 0, data
PY
}

test_dry_run_reports_due_and_stale_plan_tasks
test_apply_runs_archive_and_updates_summary
test_clean_todo_skips_archive
echo 'PASS: todo-maintenance tests'
