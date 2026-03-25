#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-crud.sh
# PURPOSE: Shell entrypoint for TODO.md CRUD operations. Validates environment
#          and delegates to todo-engine.py for cross-platform safe file ops.
#
# USAGE:
#   todo-crud.sh add --priority P3 --description "Build feature" --tags "#eng"
#   todo-crud.sh complete --id 20260322-01 --note "Shipped"
#   todo-crud.sh move --id 20260322-01 --to P1
#   todo-crud.sh list [--priority P1] [--tag "#plan-foo"] [--all]
#   todo-crud.sh next-id
#   todo-crud.sh defer --id 20260322-01 --reason "Blocked"
#   todo-crud.sh claim --id 20260322-01 [--agent myagent] [--ttl 30]
#   todo-crud.sh unclaim --id 20260322-01
#   todo-crud.sh reap
#   todo-crud.sh --json <subcommand> [args]   # JSON output mode
#
# PLATFORM: macOS, Linux, WSL (requires Python 3.6+)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/todo-engine.py"

# --- Help ---
show_help() {
  cat << 'EOF'
Usage: todo-crud.sh [--json] <command> [options]

Commands:
  add        Add a new task
  complete   Mark a task as done (moves to HISTORY)
  move       Move a task to a different priority
  list       List/filter tasks
  next-id    Get next available task ID for today
  defer      Defer a task (moves to DEFERRED)
  claim      Claim a task for this agent (multi-agent coordination)
  unclaim    Release a claim on a task
  reap       Reap all expired claims (reverts to open)

Global Options:
  --json     Machine-readable JSON output

Add Options:
  --priority, -p    P1, P2, or P3 (default: P2)
  --description, -d Task description (required)
  --tags, -t        Space-separated tags (e.g., "#eng #plan-foo")
  --note, -n        Additional note

Complete Options:
  --id              Task ID to complete (required)
  --note, -n        Completion note

Move Options:
  --id              Task ID to move (required)
  --to              Target priority P1/P2/P3 (required)

List Options:
  --priority, -p    Filter by priority
  --tag, -t         Filter by tag
  --all             Include history and deferred

Defer Options:
  --id              Task ID to defer (required)
  --reason, -r      Reason for deferral

Claim Options:
  --id              Task ID to claim (required)
  --agent, -a       Agent identifier (default: AGENT_ID env or hostname:ppid)
  --ttl             Claim TTL in minutes (default: 30)

Unclaim Options:
  --id              Task ID to unclaim (required)

Environment:
  TODO_FILE_PATH    Path to TODO.md (from ~/.codex/.env)

Examples:
  todo-crud.sh add -p P3 -d "Build feature X" -t "#engineering #plan-feat-x"
  todo-crud.sh complete --id 20260322-01
  todo-crud.sh list -p P1
  todo-crud.sh --json list --all
  todo-crud.sh claim --id 20260322-01 --agent "augment-session-1" --ttl 30
  todo-crud.sh unclaim --id 20260322-01
  todo-crud.sh reap
EOF
}

# --- Validate Python ---
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

# Verify Python version >= 3.6
PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION#*.}"
if [[ "$PY_MAJOR" -lt 3 || ("$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 6) ]]; then
  echo "ERROR: Python 3.6+ required, found $PY_VERSION" >&2
  exit 1
fi

# --- Validate engine exists ---
if [[ ! -f "$ENGINE" ]]; then
  echo "ERROR: todo-engine.py not found at $ENGINE" >&2
  exit 1
fi

# --- Source env for TODO_FILE_PATH (only if not already set) ---
if [[ -z "${TODO_FILE_PATH:-}" && -f "$HOME/.codex/.env" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.codex/.env" 2>/dev/null || true
fi
export TODO_FILE_PATH="${TODO_FILE_PATH:-}"

# --- Dispatch ---
case "${1:-}" in
  -h|--help|help|"")
    show_help
    exit 0
    ;;
  *)
    exec "$PYTHON" "$ENGINE" "$@"
    ;;
esac
