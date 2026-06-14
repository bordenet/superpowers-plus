#!/usr/bin/env bash
# parse-history.sh — Extract and classify HISTORY tasks from TODO.md
#
# Expects these variables set by caller:
#   TODO_PATH, TODO_LINES, ARCHIVE_FORCE, AGE_THRESHOLD, STALE_THRESHOLD, LINE_THRESHOLD
#
# Sets these variables for caller:
#   HISTORY_START, HISTORY_END, HISTORY_BLOCK, TASKS_TO_ARCHIVE, TASK_COUNT, KEPT_LINES

# --- Bash 4+ required for declare -A ---
if ((BASH_VERSINFO[0] < 4)); then
  echo "ERROR: todo-archive requires bash 4+. You have bash ${BASH_VERSION}" >&2
  echo "  macOS fix: brew install bash" >&2
  exit 1
fi

# --- Locate HISTORY section ---
HISTORY_START=$(grep -n "^# HISTORY" "$TODO_PATH" | head -1 | cut -d: -f1)
if [[ -z "$HISTORY_START" ]]; then
  echo "ℹ️  No HISTORY section found. Nothing to archive."
  exit 0
fi

HISTORY_END=$(awk -v start="$HISTORY_START" 'NR > start && /^# [A-Z]/ { print NR; exit }' "$TODO_PATH")
if [[ -z "$HISTORY_END" ]]; then
  HISTORY_END=$(wc -l < "$TODO_PATH")
else
  HISTORY_END=$((HISTORY_END - 1))
fi

HISTORY_BLOCK=$(sed -n "$((HISTORY_START + 1)),${HISTORY_END}p" "$TODO_PATH")

if ! echo "$HISTORY_BLOCK" | grep -qE '^\- \[(x|-)' 2>/dev/null; then
  echo "ℹ️  No completed/cancelled tasks in HISTORY. Nothing to archive."
  exit 0
fi

# --- Classify tasks: archive vs keep ---
NOW=$(date +%s)
TASKS_TO_ARCHIVE=""
TASK_COUNT=0
KEPT_LINES=""

current_task=""
current_done_date=""
# pending_header buffers the most recent ## date section header. It is emitted
# to KEPT_LINES only when the first kept task under it is encountered. If every
# task in a section is archived, the header is silently discarded (no orphaned
# empty sections). If a new ## header arrives before any kept task, the old
# pending header is overwritten — correct because the old section is empty.
pending_header=""

process_task() {
  if [[ -z "$current_task" ]]; then return; fi

  # Only process real task lines. The state machine routes ## headers directly
  # to pending_header and never writes them into current_task, so this guard is
  # unreachable in normal operation. It is retained as a defensive circuit-breaker:
  # if the state machine is extended and a non-task token accumulates in
  # current_task, this prevents corrupt content from reaching KEPT_LINES silently.
  if ! echo "$current_task" | head -1 | grep -qE '^\- \[(x|-)\]'; then
    current_task=""
    current_done_date=""
    return
  fi

  local done_epoch=0
  local age_days=999

  if [[ -n "$current_done_date" ]]; then
    local date_part="${current_done_date%%T*}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      done_epoch=$(date -j -f "%Y-%m-%d" "$date_part" "+%s" 2>/dev/null || echo 0)
    else
      done_epoch=$(date -d "$date_part" "+%s" 2>/dev/null || echo 0)
    fi
    if [[ "$done_epoch" -gt 0 ]]; then
      age_days=$(( (NOW - done_epoch) / 86400 ))
    fi
  fi

  local dominated=false
  if [[ "$ARCHIVE_FORCE" == "true" ]]; then
    dominated=true
  elif [[ "$age_days" -ge "$STALE_THRESHOLD" ]]; then
    dominated=true
  elif [[ "$TODO_LINES" -gt "$LINE_THRESHOLD" ]] && [[ "$age_days" -ge "$AGE_THRESHOLD" ]]; then
    dominated=true
  fi

  if $dominated; then
    TASKS_TO_ARCHIVE+="$current_task"$'\n'
    TASK_COUNT=$((TASK_COUNT + 1))
  else
    # Deferred header emission: only write the section header when we confirm
    # at least one task under it is being kept. This prevents empty ## sections
    # from appearing in the rebuilt HISTORY when all tasks in a section are
    # archived.
    if [[ -n "$pending_header" ]]; then
      KEPT_LINES+="$pending_header"$'\n'
      pending_header=""
    fi
    KEPT_LINES+="$current_task"$'\n'
  fi
  current_task=""
  current_done_date=""
}

# --- State machine: parse task blocks ---
while IFS= read -r line; do
  if [[ "$line" =~ ^##\  ]]; then
    process_task              # flush current task first
    pending_header="$line"   # buffer header; emit only if a kept task follows
    current_task=""
    continue
  fi
  if [[ "$line" =~ ^-\ \[(x|-)\] ]]; then
    process_task
    current_task="$line"$'\n'
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]+-\  ]] && [[ -n "$current_task" ]]; then
    current_task+="$line"$'\n'
    if [[ "$line" =~ (Done|Cancelled):[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      current_done_date="${BASH_REMATCH[2]}"
    fi
    continue
  fi
  if [[ -z "$line" ]] || [[ "$line" == "---" ]]; then
    continue
  fi
  if [[ -n "$current_task" ]]; then
    current_task+="$line"$'\n'
  fi
done <<< "$HISTORY_BLOCK"
process_task  # flush last task
# Clear all script-scope variables that would otherwise leak into the caller's
# environment after sourcing. This file sets KEPT_LINES, TASKS_TO_ARCHIVE, and
# TASK_COUNT for the caller; all others are implementation details that must not
# pollute the caller's namespace.
pending_header=""
current_task=""
current_done_date=""
# 'line' holds the last value read by the while loop; clear it explicitly.
line=""
