#!/usr/bin/env bash
# write-archives.sh — Write tasks to monthly files, rebuild TODO.md, verify integrity
#
# Expects these variables set by caller:
#   TODO_PATH, TODO_LINES, ARCHIVE_DIR, TASKS_TO_ARCHIVE, TASK_COUNT,
#   KEPT_LINES, HISTORY_START, HISTORY_END, HISTORY_BLOCK

# --- Bash 4+ required for declare -A ---
if ((BASH_VERSINFO[0] < 4)); then
  echo "ERROR: todo-archive requires bash 4+. You have bash ${BASH_VERSION}" >&2
  echo "  macOS fix: brew install bash" >&2
  # return instead of exit: this file is sourced by todo-archive.sh.
  # exit would kill the parent shell; return propagates a non-zero status
  # that the parent's set -e will treat as a fatal error.
  return 1
fi

# --- Snapshot current TODO for rebuild math + persistent backup via engine ---
SNAPSHOT_PATH="$(mktemp "${TMPDIR:-/tmp}/todo-archive-snapshot.XXXXXX")"
REBUILD_TMP="${TODO_PATH}.rebuild.tmp"
cp "$TODO_PATH" "$SNAPSHOT_PATH"
cleanup_tmp() {
  rm -f "$SNAPSHOT_PATH" "$REBUILD_TMP"
}
trap cleanup_tmp EXIT
# Note: write-archives.sh is sourced by todo-archive.sh which owns set -euo pipefail.
# Sourced scripts inherit the caller's set -e, so a failed command substitution
# (VAR=$(cmd) where cmd exits non-zero) aborts the shell before any guard can run.
# The || handler disarms set -e for the left side and fires on non-zero exit.
# Removing 2>&1 ensures Python's traceback reaches the terminal directly.
# The EXIT trap (cleanup_tmp) handles $SNAPSHOT_PATH/$REBUILD_TMP removal on return 1.
PERSISTENT_BACKUP=$("$PYTHON" - <<'PY' "$TODO_ENGINE" "$TODO_PATH"
import importlib.util
import sys

engine_path, todo_path = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("todo_engine", engine_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
print(module.backup(todo_path))
PY
) || {
  echo "ERROR: Failed to create persistent backup via todo-engine (Python exited non-zero)" >&2
  return 1
}
# Guard: Python may exit 0 but return an invalid/empty path (e.g. backup() returns None)
if [[ ! -f "$PERSISTENT_BACKUP" ]]; then
  echo "ERROR: Backup path invalid or missing: ${PERSISTENT_BACKUP:-<empty>}" >&2
  return 1
fi
echo "💾 Backup: $PERSISTENT_BACKUP"
echo "💾 Snapshot captured for rebuild"

# --- Group tasks by completion month ---
declare -A MONTH_TASKS
declare -A MONTH_COUNTS

current_task_block=""
current_month=""
while IFS= read -r line; do
  if [[ "$line" =~ ^-\ \[(x|-)\] ]]; then
    if [[ -n "$current_task_block" ]] && [[ -n "$current_month" ]]; then
      MONTH_TASKS[$current_month]+="$current_task_block"
      MONTH_COUNTS[$current_month]=$(( ${MONTH_COUNTS[$current_month]:-0} + 1 ))
    fi
    current_task_block="$line"$'\n'
    current_month=""
  elif [[ "$line" =~ ^##\  ]]; then
    if [[ "$line" =~ ([0-9]{4}-[0-9]{2}) ]]; then
      current_month="${BASH_REMATCH[1]}"
    fi
    continue
  elif [[ -n "$current_task_block" ]]; then
    current_task_block+="$line"$'\n'
    if [[ -z "$current_month" ]] && [[ "$line" =~ (Done|Cancelled):[[:space:]]*([0-9]{4}-[0-9]{2}) ]]; then
      current_month="${BASH_REMATCH[2]}"
    fi
  fi
done <<< "$TASKS_TO_ARCHIVE"
if [[ -n "$current_task_block" ]] && [[ -n "$current_month" ]]; then
  MONTH_TASKS[$current_month]+="$current_task_block"
  MONTH_COUNTS[$current_month]=$(( ${MONTH_COUNTS[$current_month]:-0} + 1 ))
fi

# --- Write to monthly archive files ---
TOTAL_WRITTEN=0
append_unique_task_block() {
  if [[ -z "$CURRENT_APPEND_BLOCK" ]]; then
    return
  fi

  local task_id=""
  if [[ "$CURRENT_APPEND_BLOCK" =~ \[([0-9]{8}-[0-9]+)\] ]]; then
    task_id="${BASH_REMATCH[1]}"
  fi

  if [[ -n "$task_id" ]] && { grep -q "$task_id" "$ARCHIVE_FILE" 2>/dev/null || [[ "$APPEND_TASK_IDS" == *"|$task_id|"* ]]; }; then
    echo "⏭️  Skipping duplicate: $task_id"
  else
    APPEND_BLOCKS+="$CURRENT_APPEND_BLOCK"$'\n'
    if [[ -n "$task_id" ]]; then
      APPEND_TASK_IDS+="$task_id|"
    fi
    COUNT_WRITTEN=$((COUNT_WRITTEN + 1))
  fi

  CURRENT_APPEND_BLOCK=""
}

# printf '%s\n' "${!arr[@]}" | sort -r is the safe iteration idiom:
# it avoids word-splitting and glob-expansion risks of unquoted $(...) expansion.
# Consistent with the while IFS= read -r pattern used elsewhere in this file.
while IFS= read -r month; do
  ARCHIVE_FILE="$ARCHIVE_DIR/${month}.md"
  # Cross-platform month name: macOS uses date -j, Linux uses date -d
  MONTH_NAME=$(date -j -f "%Y-%m" "$month" "+%B %Y" 2>/dev/null \
    || date -d "${month}-01" "+%B %Y" 2>/dev/null \
    || echo "$month")
  COUNT_WRITTEN=0
  APPEND_BLOCKS=""
  APPEND_TASK_IDS="|"
  CURRENT_APPEND_BLOCK=""

  if [[ ! -f "$ARCHIVE_FILE" ]]; then
    printf "# TODO Archive — %s\n\n> Tasks archived from TODO.md\n\n---\n\n" "$MONTH_NAME" > "$ARCHIVE_FILE"
  fi

  while IFS= read -r line; do
    if [[ "$line" =~ ^-\ \[(x|-)\] ]]; then
      append_unique_task_block
      CURRENT_APPEND_BLOCK="$line"$'\n'
    elif [[ -n "$CURRENT_APPEND_BLOCK" ]]; then
      CURRENT_APPEND_BLOCK+="$line"$'\n'
    fi
  done <<< "${MONTH_TASKS[$month]}"
  append_unique_task_block

  if [[ -n "$APPEND_BLOCKS" ]]; then
    printf '%s' "$APPEND_BLOCKS" >> "$ARCHIVE_FILE"
  fi

  TOTAL_WRITTEN=$((TOTAL_WRITTEN + COUNT_WRITTEN))
  echo "📁 $ARCHIVE_FILE: +$COUNT_WRITTEN tasks"
done < <(printf '%s\n' "${!MONTH_TASKS[@]}" | sort -r)

# --- Update INDEX.md ---
INDEX_FILE="$ARCHIVE_DIR/INDEX.md"
INDEX_ROWS=""
INDEX_TOTAL=0
INDEX_MONTHS=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  fname=$(basename "$f" .md)
  # grep -c exits 1 (not 0) when zero lines match but still prints "0" to stdout.
  # "|| echo 0" would fire too, producing "0\n0" in $() -- an embedded newline
  # that causes bash arithmetic syntax error in $((INDEX_TOTAL + fcount)).
  # Fix: "|| true" suppresses the non-zero exit without producing extra output.
  # ${fcount:-0} guards the empty-stdout case (e.g. file vanishes between find and grep).
  fcount=$(grep -cE '^\- \[(x|-)\]' "$f" 2>/dev/null || true)
  fcount="${fcount:-0}"
  INDEX_TOTAL=$((INDEX_TOTAL + fcount))
  INDEX_MONTHS=$((INDEX_MONTHS + 1))
  INDEX_ROWS+="| $fname | $fcount | [${fname}.md](${fname}.md) |"$'\n'
done < <(find "$ARCHIVE_DIR" -maxdepth 1 -name '*.md' ! -name 'INDEX.md' -print 2>/dev/null | sort -r)

{
  echo "# TODO Archive Index"
  echo ""
  echo "> Total archived: $INDEX_TOTAL tasks across $INDEX_MONTHS months"
  echo ""
  echo "| Month | Tasks | File |"
  echo "|-------|-------|------|"
  printf '%s' "$INDEX_ROWS"
} > "$INDEX_FILE"
echo "📇 Updated $INDEX_FILE"

# --- Rebuild TODO.md (write to temp first, validate before overwriting) ---
{
  head -n "$HISTORY_START" "$SNAPSHOT_PATH"
  echo ""
  if [[ -n "$KEPT_LINES" ]]; then
    echo "$KEPT_LINES"
  fi
  if [[ "$HISTORY_END" -lt $(wc -l < "$SNAPSHOT_PATH") ]]; then
    tail -n "+$((HISTORY_END + 1))" "$SNAPSHOT_PATH"
  fi
} > "$REBUILD_TMP"

# --- SAFETY GATE: refuse to write structurally invalid files ---
REBUILD_LINES=$(wc -l < "$REBUILD_TMP" | tr -d ' ')
MIN_SAFE_LINES=10  # catches obviously truncated rebuilds without rejecting small valid TODOs

if [[ "$REBUILD_LINES" -lt "$MIN_SAFE_LINES" ]]; then
  echo ""
  echo "🛑 ABORT: Rebuilt file is only $REBUILD_LINES lines (minimum: $MIN_SAFE_LINES)"
  echo "   This indicates a bug in the archive logic. TODO.md has NOT been modified."
  echo "   Backup preserved at: $PERSISTENT_BACKUP"
  echo "   Archive files were written but TODO.md is UNCHANGED."
  rm -f "$REBUILD_TMP"
  exit 1
fi

count_section_tasks() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"

  awk -v start="$start_marker" -v stop="$end_marker" '
    $0 == start { in_section=1; next }
    $0 == stop { in_section=0 }
    in_section { print }
  ' "$file" | grep -cE '^\- \[([ x/\-])\]' || true
}

# Verify all major sections survived the rebuild
for section in "# ACTIVE" "# HISTORY" "# DEFERRED" "# METRICS"; do
  if grep -q "^$section" "$SNAPSHOT_PATH" && ! grep -q "^$section" "$REBUILD_TMP"; then
    echo ""
    echo "🛑 ABORT: Section '$section' exists in original but missing from rebuild"
    echo "   This indicates a bug in the archive logic. TODO.md has NOT been modified."
    echo "   Backup preserved at: $PERSISTENT_BACKUP"
    rm -f "$REBUILD_TMP"
    exit 1
  fi
done

PRE_ACTIVE_TASKS=$(count_section_tasks "$SNAPSHOT_PATH" "# ACTIVE TASKS" "# HISTORY")
POST_ACTIVE_TASKS=$(count_section_tasks "$REBUILD_TMP" "# ACTIVE TASKS" "# HISTORY")
if [[ "$PRE_ACTIVE_TASKS" -ne "$POST_ACTIVE_TASKS" ]]; then
  echo ""
  echo "🛑 ABORT: ACTIVE task count changed during archive ($PRE_ACTIVE_TASKS -> $POST_ACTIVE_TASKS)"
  echo "   Archive should only modify # HISTORY. TODO.md has NOT been modified."
  echo "   Backup preserved at: $PERSISTENT_BACKUP"
  rm -f "$REBUILD_TMP"
  exit 1
fi

PRE_DEFERRED_TASKS=$(count_section_tasks "$SNAPSHOT_PATH" "# DEFERRED" "# METRICS")
POST_DEFERRED_TASKS=$(count_section_tasks "$REBUILD_TMP" "# DEFERRED" "# METRICS")
if [[ "$PRE_DEFERRED_TASKS" -ne "$POST_DEFERRED_TASKS" ]]; then
  echo ""
  echo "🛑 ABORT: DEFERRED task count changed during archive ($PRE_DEFERRED_TASKS -> $POST_DEFERRED_TASKS)"
  echo "   Archive should only modify # HISTORY. TODO.md has NOT been modified."
  echo "   Backup preserved at: $PERSISTENT_BACKUP"
  rm -f "$REBUILD_TMP"
  exit 1
fi

# Safe to overwrite via todo-engine.py, which handles the protected canonical write
"$PYTHON" - <<'PY' "$TODO_ENGINE" "$TODO_PATH" "$REBUILD_TMP"
import importlib.util
import pathlib
import sys

engine_path, todo_path, rebuild_tmp = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("todo_engine", engine_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)
content = pathlib.Path(rebuild_tmp).read_text()
module.write_file(todo_path, content)
PY

# Update shadow snapshot so annihilation detection stays in sync.
# Best-effort: archive success must not depend on shadow writability.
SHADOW_DIR="${HOME}/.codex/todo-shadow"
SHADOW_FILE="${SHADOW_DIR}/TODO.md"
if [[ -d "$SHADOW_FILE" ]]; then
  echo "WARNING: Shadow path ${SHADOW_FILE} is a directory (corrupt). Removing." >&2
  rm -rf "$SHADOW_FILE" 2>/dev/null || true
fi
SHADOW_TMP="${SHADOW_FILE}.tmp.$$"
if mkdir -p "$SHADOW_DIR" 2>/dev/null && \
   cp "$TODO_PATH" "$SHADOW_TMP" 2>/dev/null && \
   mv "$SHADOW_TMP" "${SHADOW_FILE}" 2>/dev/null; then
  :
else
  rm -f "$SHADOW_TMP" 2>/dev/null || true
  echo "WARNING: Could not refresh shadow snapshot. Annihilation detection may be stale." >&2
fi

# --- Integrity check ---
POST_LINES=$(wc -l < "$TODO_PATH" | tr -d ' ')
POST_HISTORY=$(sed -n "$((HISTORY_START + 1)),\$p" "$TODO_PATH" | sed '/^# [A-Z]/,$d' | grep -cE '^\- \[(x|-)\]' || true)
PRE_HISTORY=$(echo "$HISTORY_BLOCK" | grep -cE '^\- \[(x|-)\]' || true)

echo ""
echo "✅ Archive complete!"
echo "   Before: $TODO_LINES lines, $PRE_HISTORY history tasks"
echo "   After:  $POST_LINES lines, $POST_HISTORY history tasks"
echo "   Removed from HISTORY: $TASK_COUNT tasks"
echo "   New archive writes: $TOTAL_WRITTEN tasks"

EXPECTED_REMAINING=$((PRE_HISTORY - TASK_COUNT))
if [[ "$POST_HISTORY" -ne "$EXPECTED_REMAINING" ]]; then
  echo ""
  echo "⚠️  INTEGRITY WARNING: Expected $EXPECTED_REMAINING remaining, found $POST_HISTORY"
  echo "   Backup preserved at: $PERSISTENT_BACKUP"
  echo "   Review manually before deleting backup."
else
  echo "   Integrity check: ✅ PASS ($POST_HISTORY remaining = $PRE_HISTORY - $TASK_COUNT)"
fi
