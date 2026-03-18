#!/usr/bin/env bash
# write-archives.sh — Write tasks to monthly files, rebuild TODO.md, verify integrity
#
# Expects these variables set by caller:
#   TODO_PATH, TODO_LINES, ARCHIVE_DIR, TASKS_TO_ARCHIVE, TASK_COUNT,
#   KEPT_LINES, HISTORY_START, HISTORY_END, HISTORY_BLOCK

# --- Backup ---
BACKUP_PATH="${TODO_PATH}.$(date +%Y%m%d-%H%M%S).bak"
cp "$TODO_PATH" "$BACKUP_PATH"
echo "💾 Backup: $BACKUP_PATH"

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
TOTAL_ARCHIVED=0
for month in $(echo "${!MONTH_TASKS[@]}" | tr ' ' '\n' | sort -r); do
  ARCHIVE_FILE="$ARCHIVE_DIR/${month}.md"
  MONTH_NAME=$(date -j -f "%Y-%m" "$month" "+%B %Y" 2>/dev/null || echo "$month")
  count=${MONTH_COUNTS[$month]:-0}

  if [[ ! -f "$ARCHIVE_FILE" ]]; then
    printf "# TODO Archive — %s\n\n> Tasks archived from TODO.md\n\n---\n\n" "$MONTH_NAME" > "$ARCHIVE_FILE"
  fi

  # Deduplicate by task ID
  while IFS= read -r task_line; do
    if [[ "$task_line" =~ \[([0-9]{8}-[0-9]+)\] ]]; then
      task_id="${BASH_REMATCH[1]}"
      if grep -q "$task_id" "$ARCHIVE_FILE" 2>/dev/null; then
        echo "⏭️  Skipping duplicate: $task_id"
        count=$((count - 1))
        continue
      fi
    fi
  done <<< "$(echo "${MONTH_TASKS[$month]}" | grep -E '^\- \[(x|-)\]')"

  echo "${MONTH_TASKS[$month]}" >> "$ARCHIVE_FILE"
  TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + count))
  echo "📁 $ARCHIVE_FILE: +$count tasks"
done

# --- Update INDEX.md ---
INDEX_FILE="$ARCHIVE_DIR/INDEX.md"
{
  echo "# TODO Archive Index"
  echo ""
  echo "> Total archived: $TOTAL_ARCHIVED tasks across ${#MONTH_TASKS[@]} months"
  echo ""
  echo "| Month | Tasks | File |"
  echo "|-------|-------|------|"
  for f in $(ls -r "$ARCHIVE_DIR"/*.md 2>/dev/null | grep -v INDEX.md); do
    fname=$(basename "$f" .md)
    fcount=$(grep -cE '^\- \[(x|-)\]' "$f" 2>/dev/null || echo 0)
    echo "| $fname | $fcount | [${fname}.md](${fname}.md) |"
  done
} > "$INDEX_FILE"
echo "📇 Updated $INDEX_FILE"

# --- Rebuild TODO.md (write to temp first, validate before overwriting) ---
REBUILD_TMP="${TODO_PATH}.rebuild.tmp"
{
  head -n "$HISTORY_START" "$BACKUP_PATH"
  echo ""
  if [[ -n "$KEPT_LINES" ]]; then
    echo "$KEPT_LINES"
  fi
  if [[ "$HISTORY_END" -lt $(wc -l < "$BACKUP_PATH") ]]; then
    tail -n "+$((HISTORY_END + 1))" "$BACKUP_PATH"
  fi
} > "$REBUILD_TMP"

# --- SAFETY GATE: refuse to write catastrophically small files ---
REBUILD_LINES=$(wc -l < "$REBUILD_TMP" | tr -d ' ')
MIN_SAFE_LINES=50  # TODO.md should never be smaller than this

if [[ "$REBUILD_LINES" -lt "$MIN_SAFE_LINES" ]]; then
  echo ""
  echo "🛑 ABORT: Rebuilt file is only $REBUILD_LINES lines (minimum: $MIN_SAFE_LINES)"
  echo "   This indicates a bug in the archive logic. TODO.md has NOT been modified."
  echo "   Backup preserved at: $BACKUP_PATH"
  echo "   Archive files were written but TODO.md is UNCHANGED."
  rm -f "$REBUILD_TMP"
  exit 1
fi

# Also check we didn't lose more than 50% of the file (sanity bound)
HALF_ORIGINAL=$((TODO_LINES / 2))
if [[ "$REBUILD_LINES" -lt "$HALF_ORIGINAL" ]]; then
  echo ""
  echo "🛑 ABORT: Rebuilt file ($REBUILD_LINES lines) is less than half the original ($TODO_LINES lines)"
  echo "   This indicates a bug in the archive logic. TODO.md has NOT been modified."
  echo "   Backup preserved at: $BACKUP_PATH"
  rm -f "$REBUILD_TMP"
  exit 1
fi

# Safe to overwrite
mv "$REBUILD_TMP" "$TODO_PATH"

# --- Integrity check ---
POST_LINES=$(wc -l < "$TODO_PATH" | tr -d ' ')
POST_HISTORY=$(sed -n "$((HISTORY_START + 1)),\$p" "$TODO_PATH" | sed '/^# [A-Z]/,$d' | grep -cE '^\- \[(x|-)\]' || true)
PRE_HISTORY=$(echo "$HISTORY_BLOCK" | grep -cE '^\- \[(x|-)\]' || true)

echo ""
echo "✅ Archive complete!"
echo "   Before: $TODO_LINES lines, $PRE_HISTORY history tasks"
echo "   After:  $POST_LINES lines, $POST_HISTORY history tasks"
echo "   Archived: $TOTAL_ARCHIVED tasks"

EXPECTED_REMAINING=$((PRE_HISTORY - TOTAL_ARCHIVED))
if [[ "$POST_HISTORY" -ne "$EXPECTED_REMAINING" ]]; then
  echo ""
  echo "⚠️  INTEGRITY WARNING: Expected $EXPECTED_REMAINING remaining, found $POST_HISTORY"
  echo "   Backup preserved at: $BACKUP_PATH"
  echo "   Review manually before deleting backup."
else
  echo "   Integrity check: ✅ PASS ($POST_HISTORY remaining = $PRE_HISTORY - $TOTAL_ARCHIVED)"
fi

