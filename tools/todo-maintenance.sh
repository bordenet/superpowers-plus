#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-maintenance.sh
# PURPOSE: One-command TODO housekeeping — audit status, report stale plan work,
#          and run archive when maintenance thresholds are hit.
# USAGE:   todo-maintenance.sh [--json] [--dry-run] [--no-archive] [--force-archive]
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/todo-maintenance.py"

PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "ERROR: Python 3 is required but not found. Install python3." >&2
  exit 1
fi

if [[ ! -f "$ENGINE" ]]; then
  echo "ERROR: todo-maintenance.py not found at $ENGINE" >&2
  exit 1
fi

exec "$PYTHON" "$ENGINE" "$@"
