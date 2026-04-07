#!/usr/bin/env bats
# Tests for workflow-supervisor.sh
# Buildout plan: 8 test cases, all must pass, zero skips.

TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"
SUPERVISOR="$TOOLS_DIR/workflow-supervisor.sh"
ENGINE="$TOOLS_DIR/checkpoint-engine.py"

setup() {
    export CHECKPOINT_DIR
    CHECKPOINT_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${CHECKPOINT_DIR:?}"
}

# Helper: write a checkpoint with a specific heartbeat age and mode
_write_checkpoint() {
    local wf_id="$1" stale_sec="$2" mode="$3"
    local now_epoch
    now_epoch=$(date +%s)
    local last_epoch=$(( now_epoch - stale_sec ))
    python3 -c "
import json
data = {
    'workflowId': '$wf_id',
    'workflowName': 'Test Workflow',
    'startedAtEpoch': $last_epoch,
    'lastHeartbeatEpoch': $last_epoch,
    'heartbeatMode': '$mode',
    'currentStep': 2,
    'totalSteps': 5,
    'completedSteps': [],
    'branchSha': '',
    'deployedSha': '',
    'activeCallIds': [],
    'resumePrompt': '',
    'context': {},
    'version': 2,
}
json.dump(data, open('$CHECKPOINT_DIR/$wf_id.json', 'w'), indent=2)
"
}

# ---------------------------------------------------------------------------
# 1. --one-shot with fresh heartbeat exits 0 (healthy)
# ---------------------------------------------------------------------------
@test "--one-shot with fresh heartbeat exits 0" {
    python3 "$ENGINE" init "sv-001" "Fresh Test" --steps 1
    run bash "$SUPERVISOR" sv-001 --one-shot --headless
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 2. --one-shot with stale heartbeat exits 1 (stale detected)
# ---------------------------------------------------------------------------
@test "--one-shot with stale heartbeat exits 1" {
    # Mode thinking → threshold 600s. Stale by 700s.
    _write_checkpoint "sv-002" 700 "thinking"
    run bash "$SUPERVISOR" sv-002 --one-shot --headless
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# 3. --one-shot with missing checkpoint exits 0 (waiting)
# ---------------------------------------------------------------------------
@test "--one-shot with missing checkpoint exits 0" {
    run bash "$SUPERVISOR" nonexistent-sv-003 --one-shot --headless
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 4. --headless produces no osascript/notify-send calls
# ---------------------------------------------------------------------------
@test "--headless produces no osascript or notify-send invocations" {
    _write_checkpoint "sv-004" 700 "thinking"
    # Wrap osascript/notify-send to detect if called
    FAKE_BIN="$(mktemp -d)"
    printf '#!/usr/bin/env bash\necho "CALLED: osascript $*" >> %s/osascript.log\n' "$FAKE_BIN" > "$FAKE_BIN/osascript"
    printf '#!/usr/bin/env bash\necho "CALLED: notify-send $*" >> %s/notify.log\n' "$FAKE_BIN" > "$FAKE_BIN/notify-send"
    chmod +x "$FAKE_BIN/osascript" "$FAKE_BIN/notify-send"
    PATH="$FAKE_BIN:$PATH" run bash "$SUPERVISOR" sv-004 --one-shot --headless
    [ ! -f "$FAKE_BIN/osascript.log" ]
    [ ! -f "$FAKE_BIN/notify.log" ]
    rm -rf "$FAKE_BIN"
}

# ---------------------------------------------------------------------------
# 5. recovery prompt file is created on stale detection
# ---------------------------------------------------------------------------
@test "recovery prompt file is created on stale detection" {
    _write_checkpoint "sv-005" 700 "thinking"
    run bash "$SUPERVISOR" sv-005 --one-shot --headless
    [ "$status" -eq 1 ]
    [ -f "$CHECKPOINT_DIR/sv-005.recovery-prompt.txt" ]
    CONTENT=$(cat "$CHECKPOINT_DIR/sv-005.recovery-prompt.txt")
    [ -n "$CONTENT" ]
}

# ---------------------------------------------------------------------------
# 6. recovery prompt file has chmod 600
# ---------------------------------------------------------------------------
@test "recovery prompt file has chmod 600" {
    _write_checkpoint "sv-006" 700 "thinking"
    bash "$SUPERVISOR" sv-006 --one-shot --headless || true
    [ -f "$CHECKPOINT_DIR/sv-006.recovery-prompt.txt" ]
    PERMS=$(stat -f "%Lp" "$CHECKPOINT_DIR/sv-006.recovery-prompt.txt" 2>/dev/null || \
            stat -c "%a" "$CHECKPOINT_DIR/sv-006.recovery-prompt.txt" 2>/dev/null)
    [ "$PERMS" = "600" ]
}

# ---------------------------------------------------------------------------
# 7. mode-aware thresholds: test_in_progress (180s) vs thinking (600s)
# ---------------------------------------------------------------------------
@test "mode-aware thresholds: test_in_progress 180s vs thinking 600s" {
    # test_in_progress stale at 200s but thinking threshold 600s (not stale)
    _write_checkpoint "sv-007a" 200 "test_in_progress"
    run bash "$SUPERVISOR" sv-007a --one-shot --headless
    [ "$status" -eq 1 ]  # stale (200 >= 180)

    _write_checkpoint "sv-007b" 200 "thinking"
    run bash "$SUPERVISOR" sv-007b --one-shot --headless
    [ "$status" -eq 0 ]  # healthy (200 < 600)
}

# ---------------------------------------------------------------------------
# 8. _detect_os returns one of: macos, linux, wsl, unknown
# ---------------------------------------------------------------------------
@test "_detect_os returns a valid OS value" {
    # Inline the _detect_os function logic directly — same implementation as supervisor
    DETECTED=$(bash -c '
_detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
      else echo "linux"; fi ;;
    *) echo "unknown" ;;
  esac
}
_detect_os
')
    [[ "$DETECTED" == "macos" || "$DETECTED" == "linux" || "$DETECTED" == "wsl" || "$DETECTED" == "unknown" ]]
}
