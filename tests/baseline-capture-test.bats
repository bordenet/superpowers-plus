#!/usr/bin/env bats
# tests/baseline-capture-test.bats
# Non-regression tests for scripts/capture-augment-baseline.sh (PR-0)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/capture-augment-baseline.sh"
OUTPUT="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"

setup() {
    # Save a copy of the baseline so we can restore it after each test
    _BASELINE_BACKUP="$(mktemp)"
    if [[ -f "$OUTPUT" ]]; then
        cp "$OUTPUT" "$_BASELINE_BACKUP"
        _BASELINE_EXISTED=true
    else
        _BASELINE_EXISTED=false
    fi
}

teardown() {
    # Restore baseline to its pre-test state
    if [[ "$_BASELINE_EXISTED" == "true" ]]; then
        cp "$_BASELINE_BACKUP" "$OUTPUT"
    else
        rm -f "$OUTPUT"
    fi
    rm -f "$_BASELINE_BACKUP"
}

# ---------------------------------------------------------------------------
# Test 1: capture mode exits 0 and produces valid JSON
# ---------------------------------------------------------------------------
@test "capture exits 0 and produces valid JSON" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$OUTPUT" ]
    run python3 -c "import json; json.load(open('$OUTPUT'))"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 2: captured JSON has required top-level keys
# ---------------------------------------------------------------------------
@test "captured JSON contains required keys" {
    bash "$SCRIPT"
    run python3 - "$OUTPUT" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
required = {"captured_at", "sp_doctor", "skill_catalog", "run_battery", "file_hashes"}
missing = required - set(d.keys())
if missing:
    print("Missing keys:", missing)
    sys.exit(1)
# Each tool section must have output and exit_code
for section in ("sp_doctor", "skill_catalog", "run_battery"):
    assert "output" in d[section], f"{section} missing 'output'"
    assert "exit_code" in d[section], f"{section} missing 'exit_code'"
# file_hashes must be non-empty
assert len(d["file_hashes"]) > 0, "file_hashes is empty"
PYEOF
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 3: --check exits 0 immediately after a fresh capture (no drift)
# ---------------------------------------------------------------------------
@test "check mode exits 0 on fresh baseline (no drift)" {
    bash "$SCRIPT"
    run bash "$SCRIPT" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"No drift detected"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: --check exits non-zero and names the file when drift is detected
# ---------------------------------------------------------------------------
@test "check mode detects drift in a tracked file" {
    # Ensure we have a clean baseline
    bash "$SCRIPT"

    # Mutate a tracked file (append a harmless comment)
    local tracked_file="$REPO_ROOT/tools/commit-gate.sh"
    local file_backup
    file_backup="$(mktemp)"
    cp "$tracked_file" "$file_backup"

    echo "# drift-test-marker" >> "$tracked_file"

    # --check should now detect a hash mismatch
    run bash "$SCRIPT" --check

    # Restore the file regardless of outcome
    cp "$file_backup" "$tracked_file"
    rm -f "$file_backup"

    [ "$status" -ne 0 ]
    [[ "$output" == *"commit-gate.sh"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: --check exits non-zero with informative message when no baseline exists
# ---------------------------------------------------------------------------
@test "check mode fails gracefully when no baseline exists" {
    rm -f "$OUTPUT"
    run bash "$SCRIPT" --check
    [ "$status" -ne 0 ]
    [[ "$output" == *"No baseline found"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: capture is idempotent — re-running overwrites with current state
# ---------------------------------------------------------------------------
@test "capture is idempotent — second run overwrites the file" {
    bash "$SCRIPT"
    local first_ts
    first_ts="$(python3 -c "import json; print(json.load(open('$OUTPUT'))['captured_at'])")"

    # Small sleep to ensure timestamp differs
    sleep 1
    bash "$SCRIPT"

    local second_ts
    second_ts="$(python3 -c "import json; print(json.load(open('$OUTPUT'))['captured_at'])")"

    # Timestamps should differ (re-run produced a new capture)
    [ "$first_ts" != "$second_ts" ]

    # And the new baseline should still be drift-free
    run bash "$SCRIPT" --check
    [ "$status" -eq 0 ]
}
