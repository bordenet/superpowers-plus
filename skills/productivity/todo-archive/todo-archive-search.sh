#!/usr/bin/env bash
# todo-archive-search.sh — Search across archived TODO tasks
# Usage: todo-archive-search.sh <command> [args]
#   keyword <text>         Search by keyword across all archives
#   linear <DELTA-XXX>     Search by Linear issue ID
#   month <YYYY-MM>        Show all tasks for a specific month
#   range <start> <end>    Show tasks in date range (YYYY-MM-DD)
#   stats                  Show archive statistics
#   recent [N]             Show N most recently archived tasks (default: 10)

set -euo pipefail

# --- Resolve paths ---
# shellcheck source=/dev/null
source ~/.codex/.env 2>/dev/null || true
TODO_PATH="${TODO_FILE_PATH:-$HOME/.codex/TODO.md}"
ARCHIVE_DIR="$(dirname "$TODO_PATH")/todo-archives"

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "ℹ️  No archive directory found at $ARCHIVE_DIR"
  echo "   Run 'todo-archive.sh' first to create archives."
  exit 0
fi

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  keyword|search|grep)
    QUERY="$*"
    if [[ -z "$QUERY" ]]; then
      echo "Usage: todo-archive-search.sh keyword <text>" >&2
      exit 1
    fi
    echo "🔍 Searching archives for: \"$QUERY\""
    echo "---"
    grep -rn --include="*.md" -i "$QUERY" "$ARCHIVE_DIR"/ 2>/dev/null | grep -v "INDEX.md" | while IFS=: read -r file line content; do
      fname=$(basename "$file")
      echo "  [$fname:$line] $content"
    done || echo "  No results found."
    ;;

  linear|issue)
    ISSUE="${1:-}"
    if [[ -z "$ISSUE" ]]; then
      echo "Usage: todo-archive-search.sh linear <DELTA-XXX>" >&2
      exit 1
    fi
    echo "🔍 Searching archives for Linear issue: $ISSUE"
    echo "---"
    grep -rn --include="*.md" -i "$ISSUE" "$ARCHIVE_DIR"/ 2>/dev/null | grep -v "INDEX.md" | while IFS=: read -r file line content; do
      fname=$(basename "$file")
      echo "  [$fname:$line] $content"
    done || echo "  No results found."
    ;;

  month|show)
    MONTH="${1:-}"
    if [[ -z "$MONTH" ]]; then
      echo "Usage: todo-archive-search.sh month <YYYY-MM>" >&2
      exit 1
    fi
    ARCHIVE_FILE="$ARCHIVE_DIR/${MONTH}.md"
    if [[ -f "$ARCHIVE_FILE" ]]; then
      echo "📁 Archive: $MONTH"
      echo "---"
      cat "$ARCHIVE_FILE"
    else
      echo "ℹ️  No archive found for $MONTH"
      echo "   Available archives:"
      for f in "$ARCHIVE_DIR"/*.md; do
        [ -f "$f" ] || continue
        [[ "$(basename "$f")" == "INDEX.md" ]] && continue
        echo "   - $(basename "$f" .md)"
      done
    fi
    ;;

  range)
    START="${1:-}"
    END="${2:-}"
    if [[ -z "$START" ]] || [[ -z "$END" ]]; then
      echo "Usage: todo-archive-search.sh range <YYYY-MM-DD> <YYYY-MM-DD>" >&2
      exit 1
    fi
    echo "🔍 Tasks archived between $START and $END"
    echo "---"
    # Determine which monthly files to scan
    START_MONTH="${START:0:7}"
    END_MONTH="${END:0:7}"
    for f in "$ARCHIVE_DIR"/*.md; do
      [[ "$(basename "$f")" == "INDEX.md" ]] && continue
      fname=$(basename "$f" .md)
      if [[ ! "$fname" < "$START_MONTH" ]] && [[ ! "$fname" > "$END_MONTH" ]]; then
        grep -A5 -E "^\- \[(x|-)\]" "$f" 2>/dev/null | while IFS= read -r line; do
          if [[ "$line" =~ Done:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            done_date="${BASH_REMATCH[1]}"
            if [[ ! "$done_date" < "$START" ]] && [[ ! "$done_date" > "$END" ]]; then
              echo "  [match]"
            fi
          fi
          echo "  $line"
        done
      fi
    done
    ;;

  stats)
    echo "📊 Archive Statistics"
    echo "---"
    if [[ -f "$ARCHIVE_DIR/INDEX.md" ]]; then
      cat "$ARCHIVE_DIR/INDEX.md"
    else
      echo "No INDEX.md found. Scanning archives..."
    fi
    echo ""
    TOTAL=0
    for f in "$ARCHIVE_DIR"/*.md; do
      [[ "$(basename "$f")" == "INDEX.md" ]] && continue
      count=$(grep -cE '^\- \[(x|-)\]' "$f" 2>/dev/null || echo 0)
      TOTAL=$((TOTAL + count))
      echo "  $(basename "$f"): $count tasks"
    done
    echo ""
    echo "  Total: $TOTAL archived tasks"
    ;;

  recent)
    N="${1:-10}"
    echo "📋 $N Most Recently Archived Tasks"
    echo "---"
    # Search all archive files, extract task lines with Done dates, sort by date, take N
    for f in $(find "$ARCHIVE_DIR" -maxdepth 1 -name '*.md' ! -name 'INDEX.md' -print 2>/dev/null | sort -r | head -3); do
      grep -E '^\- \[(x|-)\]' "$f" 2>/dev/null | head -"$N"
    done | head -"$N"
    ;;

  help|*)
    echo "todo-archive-search.sh — Search archived TODO tasks"
    echo ""
    echo "Commands:"
    echo "  keyword <text>         Search by keyword"
    echo "  linear <DELTA-XXX>     Search by Linear issue ID"
    echo "  month <YYYY-MM>        Show monthly archive"
    echo "  range <start> <end>    Show tasks in date range"
    echo "  stats                  Show archive statistics"
    echo "  recent [N]             Show N most recent tasks"
    ;;
esac
