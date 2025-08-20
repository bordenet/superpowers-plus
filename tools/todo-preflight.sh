#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-preflight.sh
# PURPOSE: Single-command TODO.md file path resolution and validation.
#          Agents call this ONCE before any TODO operation. Returns the resolved
#          path and file status. Eliminates multi-step bash fragility.
# USAGE: ./todo-preflight.sh [--json] [--create-if-missing]
#        --json               Output machine-readable JSON (default: human-readable)
#        --create-if-missing  Create TODO.md from template if file doesn't exist
# PLATFORM: macOS, Linux, WSL (POSIX-compatible)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

JSON_MODE=false
CREATE_IF_MISSING=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --create-if-missing) CREATE_IF_MISSING=true ;;
    --help|-h)
      echo "Usage: todo-preflight.sh [--json] [--create-if-missing]"
      echo ""
      echo "Resolves TODO_FILE_PATH from ~/.codex/.env and validates the file."
      echo ""
      echo "Options:"
      echo "  --json               Output JSON (for machine consumption)"
      echo "  --create-if-missing  Create TODO.md from template if not found"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# Step 1-2: Source environment and resolve path (shared utility)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-env-path.sh
source "$SCRIPT_DIR/resolve-env-path.sh"
resolve_env
TODO_PATH=$(resolve_path "TODO_FILE_PATH" "$HOME/.codex/TODO.md")

# Step 3: Check file existence
FILE_EXISTS=false
FILE_SIZE=0
if [[ -f "$TODO_PATH" ]]; then
  FILE_EXISTS=true
  FILE_SIZE=$(wc -c < "$TODO_PATH" 2>/dev/null | tr -d ' ')
fi

# Step 4: Create if missing and requested
CREATED=false
if [[ "$FILE_EXISTS" == "false" && "$CREATE_IF_MISSING" == "true" ]]; then
  mkdir -p "$(dirname "$TODO_PATH")"
  cat > "$TODO_PATH" << 'TEMPLATE'
# ACTIVE TASKS

## P1 - Today

## P2 - This Week

## P3 - Backlog

---

# HISTORY

---

# DEFERRED

---

# METRICS
TEMPLATE
  FILE_EXISTS=true
  CREATED=true
  FILE_SIZE=$(wc -c < "$TODO_PATH" 2>/dev/null | tr -d ' ')
fi

# Step 5: Output results
if [[ "$JSON_MODE" == "true" ]]; then
  cat << EOF
{"todo_path":"$TODO_PATH","file_exists":$FILE_EXISTS,"file_size":$FILE_SIZE,"env_sourced":$ENV_SOURCED,"created":$CREATED,"source":"$(if [[ -n "${TODO_FILE_PATH:-}" ]]; then echo "env"; else echo "default"; fi)"}
EOF
else
  echo "TODO_PATH=$TODO_PATH"
  echo "FILE_EXISTS=$FILE_EXISTS"
  echo "FILE_SIZE=$FILE_SIZE"
  echo "ENV_SOURCED=$ENV_SOURCED"
  echo "CREATED=$CREATED"
  if [[ -n "${TODO_FILE_PATH:-}" ]]; then
    echo "SOURCE=env (~/.codex/.env)"
  else
    echo "SOURCE=default (\$HOME/.codex/TODO.md)"
  fi
  if [[ "$FILE_EXISTS" == "false" ]]; then
    echo ""
    echo "ERROR: TODO.md does not exist at $TODO_PATH"
    echo "FIX: Run with --create-if-missing, or create the file manually"
    exit 1
  fi
fi
