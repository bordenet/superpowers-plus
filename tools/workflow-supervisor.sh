#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: workflow-supervisor.sh
# PURPOSE: Cross-platform workflow heartbeat monitor. Detects stale AI
#          workflows and notifies the operator with a recovery prompt.
#          Read-only — never modifies checkpoint files.
#
# USAGE:
#   workflow-supervisor.sh <workflow-id> [--headless] [--interval N] [--one-shot]
#   workflow-supervisor.sh --help
#
# Run in tmux: tmux new-session -d -s supervisor 'workflow-supervisor.sh <id>'
#
# FLAGS:
#   --headless   Skip notification/clipboard. Write to stdout + recovery file only.
#   --interval N Override polling interval in seconds (default: 30).
#   --one-shot   Check once and exit (exit 0=healthy, exit 1=stale/orphaned).
#   --help       Show this help text.
#
# PLATFORM: macOS, Ubuntu, Windows/WSL. Auto-detects OS.
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

# --- Help ---
show_help() {
  cat << 'EOF'
Usage: workflow-supervisor.sh <workflow-id> [options]

  <workflow-id>   Workflow ID matching ~/.augment-checkpoints/<id>.json

Options:
  --headless      Skip desktop notification and clipboard. Stdout + file only.
  --interval N    Polling interval in seconds (default: 30).
  --one-shot      Check once and exit (0=healthy/missing, 1=stale).
  --help          Show this help text.

Staleness thresholds by mode:
  thinking              600s (10 min)
  running_tool          300s (5 min)
  test_in_progress      180s (3 min)
  waiting_on_child      900s (15 min)
  all others            600s (10 min, fallback)

On staleness detected:
  - Writes recovery prompt to ~/.augment-checkpoints/<id>.recovery-prompt.txt
  - chmod 600 on recovery file
  - Sends desktop notification (unless --headless)
  - Copies recovery prompt to clipboard (unless --headless)

Exit codes (--one-shot):
  0  Healthy or checkpoint not found (still waiting/starting)
  1  Stale heartbeat detected
EOF
}

# --- Defaults ---
WORKFLOW_ID=""
HEADLESS=false
INTERVAL=30
ONE_SHOT=false

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) show_help; exit 0 ;;
    --headless) HEADLESS=true ;;
    --interval) INTERVAL="${2:?--interval requires a value}"; shift ;;
    --one-shot) ONE_SHOT=true ;;
    -*) echo "ERROR: Unknown option: $1" >&2; show_help >&2; exit 1 ;;
    *)
      if [[ -z "$WORKFLOW_ID" ]]; then
        WORKFLOW_ID="$1"
      else
        echo "ERROR: Unexpected argument: $1" >&2; exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$WORKFLOW_ID" ]]; then
  echo "ERROR: workflow-id is required." >&2
  show_help >&2
  exit 1
fi

CHECKPOINT_DIR="${CHECKPOINT_DIR:-$HOME/.augment-checkpoints}"
CHECKPOINT="$CHECKPOINT_DIR/$WORKFLOW_ID.json"

# ── Cross-platform helpers ──────────────────────────────────────────────────
_detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
      else echo "linux"; fi ;;
    *) echo "unknown" ;;
  esac
}
OS=$(_detect_os)

_notify() {
  local name="$1" mode="$2" step="$3" mins="$4"
  local msg="Workflow '$name' stale ${mins}m (mode: $mode, step $step)"
  if [[ "$HEADLESS" == "true" ]]; then return; fi
  case "$OS" in
    macos)
      osascript -e "display notification \"$msg\" with title \"\xe2\x9a\xa0\xef\xb8\x8f Workflow Timeout\" sound name \"Submarine\"" 2>/dev/null || true
      ;;
    linux)
      notify-send "\xe2\x9a\xa0\xef\xb8\x8f Workflow Timeout" "$msg" 2>/dev/null || echo "$msg" ;;
    wsl)
      powershell.exe -Command "[console]::beep(800,300)" 2>/dev/null || true
      wsl-notify-send.exe --category "Workflow" "\xe2\x9a\xa0\xef\xb8\x8f Timeout" "$msg" 2>/dev/null || echo "$msg"
      ;;
    *) printf "⚠️ %s\n" "$msg" ;;
  esac
}

_clipboard() {
  local text="$1"
  if [[ "$HEADLESS" == "true" ]]; then return; fi
  case "$OS" in
    macos) echo "$text" | pbcopy 2>/dev/null || true ;;
    linux) echo "$text" | xclip -selection clipboard 2>/dev/null || echo "$text" | wl-copy 2>/dev/null || true ;;
    wsl)   echo "$text" | clip.exe 2>/dev/null || true ;;
  esac
}

# Mode-specific staleness thresholds (seconds)
_get_threshold() {
  case "$1" in
    thinking)             echo 600 ;;
    running_tool)         echo 300 ;;
    test_in_progress)     echo 180 ;;
    waiting_on_child)     echo 900 ;;
    *)                    echo 600 ;;
  esac
}

# ---------------------------------------------------------------------------
# Core check logic — returns 0=healthy/missing, 1=stale
# ---------------------------------------------------------------------------
_check_once() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ ! -f "$CHECKPOINT" ]]; then
    echo "$ts: Checkpoint not found for '$WORKFLOW_ID'. Waiting..."
    return 0
  fi

  local last_epoch mode now_epoch stale_sec threshold
  last_epoch=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(d.get('lastHeartbeatEpoch',0))")
  mode=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(d.get('heartbeatMode','unknown'))")
  now_epoch=$(date +%s)
  stale_sec=$(( now_epoch - last_epoch ))
  threshold=$(_get_threshold "$mode")

  if [[ "$stale_sec" -ge "$threshold" ]]; then
    local stale_min current_step workflow_name active_calls
    stale_min=$(( stale_sec / 60 ))
    current_step=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(d.get('currentStep',0))")
    workflow_name=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(d.get('workflowName','?'))")
    active_calls=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(len(d.get('activeCallIds',[])))" 2>/dev/null || echo 0)

    if [[ "$active_calls" -gt 0 ]]; then
      printf "%s: ⚠️  %s active call(s) may be orphaned. Run cleanup manually:\n" "$ts" "$active_calls"
      echo "    bash \$HOME/.codex/superpowers-plus/tools/checkpoint.sh cleanup-calls $WORKFLOW_ID"
    fi

    local resume_prompt
    resume_prompt="Resume workflow '$WORKFLOW_ID'. Read checkpoint: $CHECKPOINT. Last completed step: $current_step. Mode at death: $mode. Stale for ${stale_min}m. Run cleanup-calls before resuming any test execution."

    local recovery_file="$CHECKPOINT_DIR/$WORKFLOW_ID.recovery-prompt.txt"
    echo "$resume_prompt" > "$recovery_file"
    chmod 600 "$recovery_file"

    _notify "$workflow_name" "$mode" "$current_step" "$stale_min"
    _clipboard "$resume_prompt"

    echo "$ts: STALE -- ${stale_min}m (mode: $mode, threshold: ${threshold}s)"
    echo "$ts: Recovery prompt: $recovery_file"
    return 1
  else
    echo "$ts: OK -- ${stale_sec}s since heartbeat (mode: $mode, threshold: ${threshold}s)"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
if [[ "$ONE_SHOT" == "true" ]]; then
  _check_once
  exit $?
fi

while true; do
  if _check_once; then
    sleep "$INTERVAL"
  else
    # Re-alert after 2x threshold, not faster
    MODE=$(python3 -c "import json; d=json.load(open('$CHECKPOINT')); print(d.get('heartbeatMode','unknown'))" 2>/dev/null || echo "unknown")
    THRESHOLD=$(_get_threshold "$MODE")
    sleep $(( THRESHOLD * 2 ))
  fi
done
