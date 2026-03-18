#!/usr/bin/env bash
# todo-archive.sh — Archive completed tasks from TODO.md to monthly satellite files
# Usage: todo-archive.sh [--dry-run] [--force] [--max-age DAYS]
#   --dry-run    Show what would be archived without modifying files
#   --force      Archive ALL history entries regardless of age
#   --max-age N  Override age threshold (default: 7 days for auto, 30 for staleness)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Configuration ---
AGE_THRESHOLD=7    # Days before auto-archive kicks in
STALE_THRESHOLD=30 # Days before staleness rule forces archive
LINE_THRESHOLD=400 # Soft limit triggering auto-archive

# --- Resolve paths (BEFORE arg parsing to avoid .env clobbering flags) ---
# shellcheck source=/dev/null
source ~/.codex/.env 2>/dev/null || true

# --- Parse arguments (AFTER .env to prevent .env from overwriting flags) ---
ARCHIVE_DRY_RUN=false
ARCHIVE_FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) ARCHIVE_DRY_RUN=true; shift ;;
    --force)   ARCHIVE_FORCE=true; shift ;;
    --max-age) AGE_THRESHOLD="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TODO_PATH="${TODO_FILE_PATH:-$HOME/.codex/TODO.md}"
ARCHIVE_DIR="$(dirname "$TODO_PATH")/todo-archives"

if [[ ! -f "$TODO_PATH" ]]; then
  echo "ERROR: TODO.md not found at $TODO_PATH" >&2
  exit 1
fi

TODO_LINES=$(wc -l < "$TODO_PATH" | tr -d ' ')
echo "📋 TODO.md: $TODO_LINES lines ($TODO_PATH)"

# --- Phase 1: Parse and classify HISTORY tasks ---
# shellcheck source=lib/parse-history.sh
source "$SCRIPT_DIR/lib/parse-history.sh"

echo "📊 Found $TASK_COUNT tasks to archive"

if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "ℹ️  No tasks meet archival criteria."
  exit 0
fi

# --- Dry-run exit ---
if [[ "$ARCHIVE_DRY_RUN" == "true" ]]; then
  echo ""
  echo "🔍 DRY RUN — would archive these tasks:"
  echo "$TASKS_TO_ARCHIVE" | grep -E '^\- \[(x|-)\]' | head -20
  echo ""
  kept_count=$(echo "$KEPT_LINES" | grep -cE '^\- \[(x|-)\]' || true)
  echo "Would keep $kept_count tasks in HISTORY"
  echo ""
  echo "Estimated post-archive lines: ~$((TODO_LINES - TASK_COUNT * 3))"
  exit 0
fi

# --- Phase 2: Write archives, rebuild TODO.md, verify ---
mkdir -p "$ARCHIVE_DIR"

# shellcheck source=lib/write-archives.sh
source "$SCRIPT_DIR/lib/write-archives.sh"
