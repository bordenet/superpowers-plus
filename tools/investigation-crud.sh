#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: investigation-crud.sh
# PURPOSE: Shell entrypoint for investigation state CRUD operations.
#          Validates environment and delegates to investigation-engine.py.
#
# USAGE:
#   investigation-crud.sh create --title "Bug title" [--observed OBS] [--expected EXP] [--reproduction REP]
#   investigation-crud.sh list [--status active|paused|resolved|abandoned] [--stale]
#   investigation-crud.sh show --id UUID
#   investigation-crud.sh add-hypothesis --id UUID --text "Hypothesis text"
#   investigation-crud.sh add-evidence --id UUID --hypothesis N --source SRC --finding TEXT
#   investigation-crud.sh set-verdict --id UUID --hypothesis N --verdict confirmed|rejected|inconclusive [--reason TEXT]
#   investigation-crud.sh add-eliminated --id UUID --approach "What was tried" --reason "Why it failed"
#   investigation-crud.sh set-status --id UUID --status paused|resolved|abandoned [--resolution-type TYPE] [--summary TEXT]
#   investigation-crud.sh update --id UUID [--next-steps "step1|step2"] [--current-theory N] [--add-ticket T]
#   investigation-crud.sh export --id UUID
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
ENGINE="$SCRIPT_DIR/investigation-engine.py"

# --- Help ---
show_help() {
  cat << 'EOF'
Usage: investigation-crud.sh <command> [options]

Commands:
  create           Start a new investigation
  list             List investigations (all or filtered)
  show             Show investigation JSON
  add-hypothesis   Add a hypothesis to an investigation
  add-evidence     Add evidence to a hypothesis
  set-verdict      Set verdict on a hypothesis
  add-eliminated   Record an eliminated approach
  set-status       Change investigation status (pause, resolve, abandon, resume)
  update           Update next steps, current theory, or related tickets
  export           Generate markdown export for handoff

Create Options:
  --title          Investigation title (required)
  --observed       What actually happens
  --expected       What should happen
  --reproduction   Steps to reproduce

List Options:
  --status         Filter by status (active, paused, resolved, abandoned)
  --stale          Show only investigations updated >7 days ago

Show/Export Options:
  --id             Investigation UUID (required)

Hypothesis Options:
  --id             Investigation UUID (required)
  --text           Hypothesis text (for add-hypothesis)
  --hypothesis     Hypothesis ID number (for add-evidence, set-verdict)
  --source         Evidence source (e.g., mssql:staging-db, local:grep)
  --finding        What was found
  --verdict        confirmed, rejected, or inconclusive
  --reason         Reason for verdict

Status Options:
  --id               Investigation UUID (required)
  --status           New status (required)
  --resolution-type  fix-needed, no-fix-needed, or external (for resolved)
  --summary          Resolution summary (for resolved)

Update Options:
  --id             Investigation UUID (required)
  --next-steps     Pipe-separated steps: "step1|step2|step3"
  --current-theory Hypothesis ID to set as current theory (or "null")
  --add-ticket     Add a related ticket reference (e.g., TST-123)

Storage: ~/.superpowers/investigations/<uuid>.json
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
  echo "ERROR: investigation-engine.py not found at $ENGINE" >&2
  exit 1
fi

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
