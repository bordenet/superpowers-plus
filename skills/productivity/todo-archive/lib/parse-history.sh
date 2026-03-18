#!/usr/bin/env bash
# parse-history.sh — Extract and classify HISTORY tasks from TODO.md
#
# Expects these variables set by caller:
#   TODO_PATH, TODO_LINES, ARCHIVE_FORCE, AGE_THRESHOLD, STALE_THRESHOLD, LINE_THRESHOLD
#
# Sets these variables for caller:
#   HISTORY_START, HISTORY_END, HISTORY_BLOCK, TASKS_TO_ARCHIVE, TASK_COUNT, KEPT_LINES

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

if [[ -z "$(echo "$HISTORY_BLOCK" | grep -E '^\- \[(x|-)' 2>/dev/null)" ]]; then
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

process_task() {
  if [[ -z "$current_task" ]]; then return; fi

  # Skip date headers — only process actual task lines
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
    KEPT_LINES+="$current_task"$'\n'
  fi
  current_task=""
  current_done_date=""
}

# --- State machine: parse task blocks ---
while IFS= read -r line; do
  if [[ "$line" =~ ^##\  ]]; then
    process_task
    current_task="$line"$'\n'
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

