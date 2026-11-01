#!/usr/bin/env bats
# tests/baseline-capture-test.bats
# Non-regression tests for scripts/capture-augment-baseline.sh (PR-0)

SOURCE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"

# Tests exercise a disposable source tree. Restoring bytes after deleting a
# real tracked file lost its mode (0644 -> mktemp0600) on a clean CI checkout.
_source_fingerprint() {
    python3 - "$SOURCE_ROOT" <<'PYMODE'
import hashlib,pathlib,stat,sys
root=pathlib.Path(sys.argv[1]);h=hashlib.sha256()
for name in ["tests/fixtures/augment-baseline-pre-claude-guardrails.json", "tools/commit-gate.sh"]:
    p=root/name;h.update(name.encode()+str(stat.S_IMODE(p.stat().st_mode)).encode()+p.read_bytes())
print(h.hexdigest())
PYMODE
}

setup_file() {
    _source_fingerprint > "$BATS_FILE_TMPDIR/source-fingerprint"
}

teardown_file() {
    [ "$(_source_fingerprint)" = "$(cat "$BATS_FILE_TMPDIR/source-fingerprint")" ]
}

# Stub the three heavy external probes. These tests assert this script's JSON
# shape, idempotency and drift detection -- NOT sp-doctor's or run-battery's
# correctness. Unstubbed, the script is invoked 10 times across the 6 tests
# below and each invocation walks 123 skills x 30 checks (sp-doctor) plus a
# full review battery, which made this the slowest file in the entire suite
# by a wide margin. The script defaults these to the real tools, so production
# behaviour is untouched; only this test substitutes stubs.
# The stubs mimic the contract the script actually depends on: exit 0 and, for
# the augment probe, JSON-ish text on stdout. augment.js is invoked via `node`
# (scripts/capture-augment-baseline.sh:98), not bash -- it must be valid JS.
_make_stubs() {
    _STUB_DIR="$(mktemp -d)"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_STUB_DIR/sp-doctor.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$_STUB_DIR/run-battery.sh"
    printf 'process.stdout.write("stub-bootstrap");\nprocess.exit(0);\n' > "$_STUB_DIR/augment.js"
    chmod +x "$_STUB_DIR/sp-doctor.sh" "$_STUB_DIR/run-battery.sh" "$_STUB_DIR/augment.js"
    export CAPTURE_SP_DOCTOR="$_STUB_DIR/sp-doctor.sh"
    export CAPTURE_RUN_BATTERY="$_STUB_DIR/run-battery.sh"
    export CAPTURE_AUGMENT_JS="$_STUB_DIR/augment.js"
}

setup() {
    REPO_ROOT="$BATS_TEST_TMPDIR/repo"
    SCRIPT="$REPO_ROOT/scripts/capture-augment-baseline.sh"
    OUTPUT="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"
    mkdir -p "$REPO_ROOT/scripts" "$REPO_ROOT/tools" "$REPO_ROOT/tests/fixtures" "$REPO_ROOT/lib"
    cp -p "$SOURCE_ROOT/scripts/capture-augment-baseline.sh" "$SCRIPT"
    cp -R "$SOURCE_ROOT/lib/install" "$REPO_ROOT/lib/install"
    local tool
    for tool in commit-gate.sh public-repo-ip-check.sh dangerous-pattern-scan.sh run-battery.sh sp-doctor.sh; do
        cp -p "$SOURCE_ROOT/tools/$tool" "$REPO_ROOT/tools/$tool"
    done
    cp -p "$SOURCE_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json" "$OUTPUT"
    _make_stubs
}

teardown() {
    [[ -n "${_STUB_DIR:-}" ]] && rm -rf "$_STUB_DIR"
    return 0
}

@test "capture and drift mutations remain inside the disposable source tree" {
    [ "$REPO_ROOT" != "$SOURCE_ROOT" ]
    [[ "$SCRIPT" == "$BATS_TEST_TMPDIR/"* ]]
    [[ "$OUTPUT" == "$BATS_TEST_TMPDIR/"* ]]
    printf '# isolated mutation\n' >> "$REPO_ROOT/tools/commit-gate.sh"
    rm -f "$OUTPUT"
    [ "$(_source_fingerprint)" = "$(cat "$BATS_FILE_TMPDIR/source-fingerprint")" ]
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
assert "lib/install/deploy.sh" in d["file_hashes"], "installer module inventory missing"
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
