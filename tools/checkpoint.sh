#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: checkpoint.sh
# PURPOSE: Shell entrypoint for workflow checkpoint CRUD operations.
#          Validates environment and delegates to checkpoint-engine.py.
#
# USAGE:
#   checkpoint.sh init <workflow-id> <workflow-name> [--steps N]
#   checkpoint.sh step <workflow-id> --description "..." --result success|failure|skipped
#   checkpoint.sh heartbeat <workflow-id> --mode <mode>
#   checkpoint.sh read <workflow-id>
#   checkpoint.sh set-context <workflow-id> --key <key> --value <value>
#   checkpoint.sh set-calls <workflow-id> --calls '["id1","id2"]'
#   checkpoint.sh cleanup-calls <workflow-id>
#   checkpoint.sh set-resume-prompt <workflow-id> --prompt "..."
#   checkpoint.sh generate-resume-prompt <workflow-id>
#   checkpoint.sh lock <workflow-id> [--owner <uuid>] [--lease <seconds>]
#   checkpoint.sh unlock <workflow-id> --owner <uuid>
#   checkpoint.sh renew <workflow-id> --owner <uuid> [--lease <seconds>]
#   checkpoint.sh help
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
ENGINE="$SCRIPT_DIR/checkpoint-engine.py"

# --- Help ---
show_help() {
  cat << 'EOF'
Usage: checkpoint.sh <command> [options]

Commands:
  init              Create a new checkpoint file
  step              Record a completed step
  heartbeat         Update heartbeat timestamp and mode
  read              Print checkpoint JSON to stdout
  set-context       Set a key-value pair in the context dict
  set-calls         Set the active call IDs list
  cleanup-calls     Print active call IDs and clear the list
  set-resume-prompt Set the resume prompt text
  generate-resume-prompt  Auto-generate a resume prompt from state
  lock              Acquire advisory lock (fencing)
  unlock            Release advisory lock
  renew             Renew advisory lock lease
  help              Show this help text

Init Options:
  <workflow-id>     Unique workflow identifier (required)
  <workflow-name>   Human-readable workflow name (required)
  --steps N         Total expected steps (default: 0)

Step Options:
  <workflow-id>     Workflow identifier (required)
  --description,-d  Step description (required)
  --result,-r       success, failure, or skipped (required)

Heartbeat Options:
  <workflow-id>     Workflow identifier (required)
  --mode,-m         Mode: initializing, thinking, running_tool, test_in_progress,
                    waiting_on_child, waiting_on_external, step_complete, aborting

Context Options:
  <workflow-id>     Workflow identifier (required)
  --key,-k          Context key (required)
  --value,-v        Context value (required)

Set-Calls Options:
  <workflow-id>     Workflow identifier (required)
  --calls           JSON array of call IDs (required), e.g. '["id1","id2"]'

Resume Prompt Options:
  <workflow-id>     Workflow identifier (required)
  --prompt,-p       Resume prompt text (required for set-resume-prompt)

Lock Options:
  <workflow-id>     Workflow identifier (required)
  --owner           Owner UUID (auto-generated if not provided)
  --lease           Lease duration in seconds (default: 120)

Unlock/Renew Options:
  <workflow-id>     Workflow identifier (required)
  --owner           Owner UUID (required, must match lock)
  --lease           New lease duration in seconds (renew only, default: 120)

Environment:
  CHECKPOINT_DIR    Directory for checkpoint files (default: ~/.augment-checkpoints)

Valid heartbeat modes:
  initializing, thinking, running_tool, test_in_progress,
  waiting_on_child, waiting_on_external, step_complete, aborting

Examples:
  checkpoint.sh init "my-workflow" "My Workflow" --steps 5
  checkpoint.sh step "my-workflow" --description "Setup complete" --result success
  checkpoint.sh heartbeat "my-workflow" --mode thinking
  checkpoint.sh read "my-workflow"
  checkpoint.sh set-context "my-workflow" --key branch --value main
  checkpoint.sh generate-resume-prompt "my-workflow"
  OWNER=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
  checkpoint.sh lock "my-workflow" --owner "$OWNER" --lease 120
  checkpoint.sh unlock "my-workflow" --owner "$OWNER"
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
PY_VERSION=$("$PYTHON" -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))" 2>/dev/null || echo "0.0")
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION#*.}"
if [[ "$PY_MAJOR" -lt 3 || ("$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 6) ]]; then
  echo "ERROR: Python 3.6+ required, found $PY_VERSION" >&2
  exit 1
fi

# --- Validate engine exists ---
if [[ ! -f "$ENGINE" ]]; then
  echo "ERROR: checkpoint-engine.py not found at $ENGINE" >&2
  exit 1
fi

# --- UUID generator (for auto-owner on lock) ---
_generate_uuid() {
  uuidgen 2>/dev/null || "$PYTHON" -c "import uuid; print(uuid.uuid4())"
}

# --- Dispatch ---
CMD="${1:-}"
case "$CMD" in
  -h|--help|help|"")
    show_help
    exit 0
    ;;
  lock)
    # Auto-generate --owner if not provided
    ARGS=("$@")
    HAS_OWNER=false
    for arg in "${ARGS[@]}"; do
      [[ "$arg" == "--owner" ]] && HAS_OWNER=true && break
    done
    if [[ "$HAS_OWNER" == false ]]; then
      OWNER=$(_generate_uuid)
      echo "INFO: Auto-generated owner UUID: $OWNER" >&2
      exec "$PYTHON" "$ENGINE" "$@" --owner "$OWNER"
    else
      exec "$PYTHON" "$ENGINE" "$@"
    fi
    ;;
  *)
    exec "$PYTHON" "$ENGINE" "$@"
    ;;
esac
