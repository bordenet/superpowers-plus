#!/usr/bin/env bats
# Tests for checkpoint.sh + checkpoint-engine.py
# Buildout plan: 18 test cases, all must pass, zero skips.

TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"
CHECKPOINT_SH="$TOOLS_DIR/checkpoint.sh"

setup() {
    export CHECKPOINT_DIR
    CHECKPOINT_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${CHECKPOINT_DIR:?}"
}

# ---------------------------------------------------------------------------
# 1. init creates valid checkpoint file
# ---------------------------------------------------------------------------
@test "init creates valid checkpoint file" {
    run bash "$CHECKPOINT_SH" init "wf-001" "Test Workflow" --steps 5
    [ "$status" -eq 0 ]
    [ -f "$CHECKPOINT_DIR/wf-001.json" ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-001.json')); assert d['version']==2; assert d['currentStep']==0; assert d['totalSteps']==5; assert d['workflowId']=='wf-001'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 2. step increments currentStep and records in completedSteps
# ---------------------------------------------------------------------------
@test "step increments currentStep and records completedSteps" {
    bash "$CHECKPOINT_SH" init "wf-002" "Step Test" --steps 3
    run bash "$CHECKPOINT_SH" step "wf-002" --description "First step" --result success
    [ "$status" -eq 0 ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-002.json')); assert d['currentStep']==1; assert len(d['completedSteps'])==1; assert d['completedSteps'][0]['result']=='success'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 3. step on nonexistent workflow exits 1
# ---------------------------------------------------------------------------
@test "step on nonexistent workflow exits 1" {
    run bash "$CHECKPOINT_SH" step "nonexistent-wf" --description "x" --result success
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# 4. heartbeat updates timestamp and mode
# ---------------------------------------------------------------------------
@test "heartbeat updates timestamp and mode" {
    bash "$CHECKPOINT_SH" init "wf-004" "Heartbeat Test"
    BEFORE=$(python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-004.json')); print(d['lastHeartbeatEpoch'])")
    sleep 1
    run bash "$CHECKPOINT_SH" heartbeat "wf-004" --mode thinking
    [ "$status" -eq 0 ]
    AFTER=$(python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-004.json')); print(d['lastHeartbeatEpoch'])")
    python3 -c "assert $AFTER > $BEFORE, 'timestamp not updated'"
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-004.json')); assert d['heartbeatMode']=='thinking'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 5. heartbeat rejects invalid mode
# ---------------------------------------------------------------------------
@test "heartbeat rejects invalid mode" {
    bash "$CHECKPOINT_SH" init "wf-005" "Mode Test"
    run bash "$CHECKPOINT_SH" heartbeat "wf-005" --mode "not_a_valid_mode"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# 6. read prints valid JSON
# ---------------------------------------------------------------------------
@test "read prints valid JSON" {
    bash "$CHECKPOINT_SH" init "wf-006" "Read Test"
    run bash "$CHECKPOINT_SH" read "wf-006"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

# ---------------------------------------------------------------------------
# 7. set-context adds key-value pair
# ---------------------------------------------------------------------------
@test "set-context adds key-value pair" {
    bash "$CHECKPOINT_SH" init "wf-007" "Context Test"
    run bash "$CHECKPOINT_SH" set-context "wf-007" --key branch --value main
    [ "$status" -eq 0 ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-007.json')); assert d['context']['branch']=='main'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 8. set-calls sets activeCallIds
# ---------------------------------------------------------------------------
@test "set-calls sets activeCallIds" {
    bash "$CHECKPOINT_SH" init "wf-008" "Calls Test"
    run bash "$CHECKPOINT_SH" set-calls "wf-008" --calls '["call-a","call-b"]'
    [ "$status" -eq 0 ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-008.json')); assert d['activeCallIds']==['call-a','call-b']"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 9. cleanup-calls clears activeCallIds and prints old values
# ---------------------------------------------------------------------------
@test "cleanup-calls clears activeCallIds and prints old values" {
    bash "$CHECKPOINT_SH" init "wf-009" "Cleanup Test"
    bash "$CHECKPOINT_SH" set-calls "wf-009" --calls '["call-x"]'
    run bash "$CHECKPOINT_SH" cleanup-calls "wf-009"
    [ "$status" -eq 0 ]
    [[ "$output" == *"call-x"* ]]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-009.json')); assert d['activeCallIds']==[]"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 10. generate-resume-prompt produces non-empty string
# ---------------------------------------------------------------------------
@test "generate-resume-prompt produces non-empty string" {
    bash "$CHECKPOINT_SH" init "wf-010" "Resume Test" --steps 2
    bash "$CHECKPOINT_SH" step "wf-010" --description "Done step" --result success
    run bash "$CHECKPOINT_SH" generate-resume-prompt "wf-010"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"wf-010"* ]]
}

# ---------------------------------------------------------------------------
# 11. lock creates lock file
# ---------------------------------------------------------------------------
@test "lock creates lock file" {
    bash "$CHECKPOINT_SH" init "wf-011" "Lock Test"
    OWNER=$(python3 -c "import uuid; print(uuid.uuid4())")
    run bash "$CHECKPOINT_SH" lock "wf-011" --owner "$OWNER"
    [ "$status" -eq 0 ]
    [ -f "$CHECKPOINT_DIR/wf-011.lock" ]
}

# ---------------------------------------------------------------------------
# 12. lock fails if active lock exists (fencing)
# ---------------------------------------------------------------------------
@test "lock fails if active lock exists" {
    bash "$CHECKPOINT_SH" init "wf-012" "Fencing Test"
    OWNER_A=$(python3 -c "import uuid; print(uuid.uuid4())")
    OWNER_B=$(python3 -c "import uuid; print(uuid.uuid4())")
    bash "$CHECKPOINT_SH" lock "wf-012" --owner "$OWNER_A" --lease 600
    run bash "$CHECKPOINT_SH" lock "wf-012" --owner "$OWNER_B"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# 13. lock overrides expired lock
# ---------------------------------------------------------------------------
@test "lock overrides expired lock" {
    bash "$CHECKPOINT_SH" init "wf-013" "Expired Lock Test"
    OWNER_A=$(python3 -c "import uuid; print(uuid.uuid4())")
    OWNER_B=$(python3 -c "import uuid; print(uuid.uuid4())")
    # Write an already-expired lock directly
    python3 -c "
import json, time
lock = {'owner': '$OWNER_A', 'claimedEpoch': int(time.time())-300, 'expiryEpoch': int(time.time())-60}
json.dump(lock, open('$CHECKPOINT_DIR/wf-013.lock', 'w'))
"
    run bash "$CHECKPOINT_SH" lock "wf-013" --owner "$OWNER_B" --lease 120
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 14. unlock by non-owner exits 1 (fencing)
# ---------------------------------------------------------------------------
@test "unlock by non-owner exits 1" {
    bash "$CHECKPOINT_SH" init "wf-014" "Unlock Fencing Test"
    OWNER_A=$(python3 -c "import uuid; print(uuid.uuid4())")
    OWNER_B=$(python3 -c "import uuid; print(uuid.uuid4())")
    bash "$CHECKPOINT_SH" lock "wf-014" --owner "$OWNER_A" --lease 120
    run bash "$CHECKPOINT_SH" unlock "wf-014" --owner "$OWNER_B"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# 15. renew by owner extends expiry
# ---------------------------------------------------------------------------
@test "renew by owner extends expiry" {
    bash "$CHECKPOINT_SH" init "wf-015" "Renew Test"
    OWNER=$(python3 -c "import uuid; print(uuid.uuid4())")
    bash "$CHECKPOINT_SH" lock "wf-015" --owner "$OWNER" --lease 30
    BEFORE_EXP=$(python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-015.lock')); print(d['expiryEpoch'])")
    run bash "$CHECKPOINT_SH" renew "wf-015" --owner "$OWNER" --lease 600
    [ "$status" -eq 0 ]
    AFTER_EXP=$(python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-015.lock')); print(d['expiryEpoch'])")
    python3 -c "assert $AFTER_EXP > $BEFORE_EXP, 'expiry not extended'"
}

# ---------------------------------------------------------------------------
# 16. concurrent init doesn't corrupt (parallel)
# ---------------------------------------------------------------------------
@test "concurrent init does not corrupt checkpoint" {
    for i in $(seq 1 5); do
        bash "$CHECKPOINT_SH" init "wf-016-$i" "Parallel Init $i" --steps 1 &
    done
    wait
    for i in $(seq 1 5); do
        run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-016-$i.json')); assert d['version']==2"
        [ "$status" -eq 0 ]
    done
}

# ---------------------------------------------------------------------------
# 17. 100 steps don't blow up (size check)
# ---------------------------------------------------------------------------
@test "100 steps do not blow up or corrupt" {
    bash "$CHECKPOINT_SH" init "wf-017" "100 Steps" --steps 100
    for i in $(seq 1 100); do
        bash "$CHECKPOINT_SH" step "wf-017" --description "Step $i" --result success
    done
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-017.json')); assert d['currentStep']==100; assert len(d['completedSteps'])==100"
    [ "$status" -eq 0 ]
    FILE_SIZE=$(wc -c < "$CHECKPOINT_DIR/wf-017.json")
    # File should be reasonable (< 100KB for 100 steps)
    python3 -c "assert $FILE_SIZE < 102400, 'File too large: $FILE_SIZE bytes'"
}

# ---------------------------------------------------------------------------
# 18. set-resume-prompt round-trips correctly
# ---------------------------------------------------------------------------
@test "set-resume-prompt stores and read retrieves prompt" {
    bash "$CHECKPOINT_SH" init "wf-018" "Prompt Test"
    PROMPT="Resume this workflow from step 42. Check checkpoint file."
    run bash "$CHECKPOINT_SH" set-resume-prompt "wf-018" --prompt "$PROMPT"
    [ "$status" -eq 0 ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-018.json')); assert d['resumePrompt'] == '$PROMPT'"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 19. init without --force fails on existing checkpoint (data loss guard)
# ---------------------------------------------------------------------------
@test "init without --force fails on existing checkpoint" {
    bash "$CHECKPOINT_SH" init "wf-019" "Guard Test" --steps 3
    bash "$CHECKPOINT_SH" step "wf-019" --description "Step 1" --result success
    run bash "$CHECKPOINT_SH" init "wf-019" "Guard Test"
    [ "$status" -eq 1 ]
    # Data must still be intact
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-019.json')); assert d['currentStep']==1"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 20. init with --force overwrites existing checkpoint
# ---------------------------------------------------------------------------
@test "init with --force overwrites existing checkpoint" {
    bash "$CHECKPOINT_SH" init "wf-020" "Force Test" --steps 3
    bash "$CHECKPOINT_SH" step "wf-020" --description "Step 1" --result success
    run bash "$CHECKPOINT_SH" init "wf-020" "Force Test Reset" --force
    [ "$status" -eq 0 ]
    run python3 -c "import json; d=json.load(open('$CHECKPOINT_DIR/wf-020.json')); assert d['currentStep']==0"
    [ "$status" -eq 0 ]
}
