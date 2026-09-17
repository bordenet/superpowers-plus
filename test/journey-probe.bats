#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/journey-probe.sh"
FIXTURES="$REPO_ROOT/test/fixtures/journeys"
STREAM_FIXTURE="$REPO_ROOT/test/fixtures/journey-probe-stream.jsonl"
STREAM_META_FIXTURE="$STREAM_FIXTURE.meta.json"

setup() {
    REAL_GIT="$(command -v git)"
    REAL_PYTHON3="$(command -v python3)"
    FAKE_BIN="$BATS_TEST_TMPDIR/bin"
    CLAUDE_MARKER="$BATS_TEST_TMPDIR/claude-invoked"
    CLAUDE_VERSION_MARKER="$BATS_TEST_TMPDIR/claude-version-invoked"
    mkdir -p "$FAKE_BIN"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
    touch "$CLAUDE_VERSION_MARKER"
    printf '2.1.274-test\n'
    exit 0
fi
touch "$CLAUDE_MARKER"
echo "test failure: offline journey-probe mode invoked claude" >&2
exit 99
EOF
    chmod +x "$FAKE_BIN/claude"
    export PATH="$FAKE_BIN:$PATH"
    export JOURNEY_PROBE_FIXTURES_DIR="$FIXTURES"
}

assert_claude_not_invoked() {
    [ ! -e "$CLAUDE_MARKER" ]
    [ ! -e "$CLAUDE_VERSION_MARKER" ]
}

copy_fixtures() {
    local destination="$1"
    mkdir -p "$destination"
    cp "$FIXTURES"/*.txt "$destination/"
}

copy_stream_with_meta() {
    local destination="$1"
    cp "$STREAM_FIXTURE" "$destination"
    cp "$STREAM_META_FIXTURE" "$destination.meta.json"
}

make_config_dir() {
    local destination="$1"
    mkdir -p \
        "$destination/skills/sp-debate" \
        "$destination/skills/sp-phr" \
        "$destination/skills/context-ferry"
    printf '{"env":{}}\n' > "$destination/settings.json"
    printf '%s\n' '# debate treatment' > "$destination/skills/sp-debate/skill.md"
    printf '%s\n' '# PHR treatment' > "$destination/skills/sp-phr/skill.md"
    printf '%s\n' '# context-ferry treatment' > "$destination/skills/context-ferry/skill.md"
}

file_mode() {
    local path="$1"
    local mode
    if mode="$(stat -c "%a" "$path" 2>/dev/null)"; then
        printf '%s\n' "$mode"
        return 0
    fi
    stat -f "%Lp" "$path" 2>/dev/null
}

run_harness_with_watchdog() {
    local watchdog_seconds="$1"
    shift
    run "$REAL_PYTHON3" - "$watchdog_seconds" "$@" <<'PY'
import os
import signal
import subprocess
import sys

watchdog_seconds = float(sys.argv[1])
process = subprocess.Popen(
    sys.argv[2:],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    output, _ = process.communicate(timeout=watchdog_seconds)
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    output, _ = process.communicate()
    sys.stdout.write(output)
    print("WATCHDOG_TIMEOUT")
    sys.exit(124)
sys.stdout.write(output)
sys.exit(process.returncode)
PY
}

run_harness_with_runtime_measurement() {
    local setup_watchdog_seconds="$1"
    local fake_start_file="$2"
    shift 2
    run "$REAL_PYTHON3" - "$setup_watchdog_seconds" "$fake_start_file" "$@" <<'PY'
import os
import pathlib
import signal
import subprocess
import sys
import time

setup_watchdog_seconds = float(sys.argv[1])
fake_start_file = pathlib.Path(sys.argv[2])
process = subprocess.Popen(
    sys.argv[3:],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    output, _ = process.communicate(timeout=setup_watchdog_seconds)
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    output, _ = process.communicate()
    sys.stdout.write(output)
    print("SETUP_WATCHDOG_TIMEOUT")
    sys.exit(124)
completed_at = time.monotonic()
sys.stdout.write(output)
try:
    fake_started_at = float(fake_start_file.read_text(encoding="utf-8"))
except (OSError, ValueError):
    print("FAKE_START_TIME_MISSING")
    sys.exit(125)
print(f"FAKE_RUNTIME_ELAPSED={completed_at - fake_started_at:.6f}")
sys.exit(process.returncode)
PY
}

install_valid_fake_claude() {
    local args_file="$1"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
touch "$CLAUDE_MARKER"
printf '%s\n' "\$@" > "$args_file"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"
}

make_gate_dataset() {
    local destination="$1"
    local treatment_fingerprint="$2"
    local variant="$3"
    local template_file="$destination.template"
    bash "$SCRIPT" --parse-stream "$STREAM_FIXTURE" > "$template_file"
    python3 - "$template_file" "$destination" "$treatment_fingerprint" "$variant" <<'PY'
import copy
import hashlib
import json
import sys

template_path, destination, treatment_fingerprint, variant = sys.argv[1:]
with open(template_path, encoding="utf-8") as source:
    template = json.load(source)

journeys = {
    "J8": ("J8-debate.txt", ["debate"]),
    "J9": ("J9-phr.txt", ["progressive-harsh-review"]),
    "J10": ("J10-ferry.txt", ["context-ferry"]),
}
contexts = {
    "baseline": [120, 140, 160],
    "all_fail_baseline": [120, 140, 160],
    "all_fail_treatment": [100, 120, 160],
    "mixed_floor": [100, 120, 160],
    "pass": [100, 120, 160],
    "control_drift": [100, 120, 160],
    "median_equal": [100, 140, 150],
    "worst_regression": [90, 110, 170],
    "verdict_regression": [100, 120, 160],
}[variant]


def set_outcome(record, verdict):
    expected = record["expected_skills"]
    if verdict == "PASS":
        actual = list(expected)
    elif verdict == "PASS_WITH_NITS":
        actual = list(expected) + ["systematic-debugging"]
    else:
        actual = []
    record["actual_skills_main"] = actual
    record["actual_skills_subagent"] = []
    record["missing_skills"] = [] if verdict != "FAIL" else list(expected)
    record["unexpected_skills"] = (
        ["systematic-debugging"] if verdict == "PASS_WITH_NITS" else []
    )
    record["verdict"] = verdict
    record["verdict_reasons"] = (
        ["unexpected_skills"] if verdict == "PASS_WITH_NITS"
        else ["missing_skills"] if verdict == "FAIL"
        else []
    )
    matched = len(expected) if verdict != "FAIL" else 0
    record["quality"] = {
        "expected_count": len(expected),
        "actual_unique_count": len(actual),
        "matched_count": matched,
        "recall": float(matched / len(expected)),
        "precision": float(matched / len(actual)) if actual else 0.0,
    }


with open(destination, "w", encoding="utf-8") as output:
    for journey, (fixture, expected) in journeys.items():
        for repeat_index, context_tokens in enumerate(contexts, start=1):
            record = copy.deepcopy(template)
            record["journey"] = journey
            record["fixture"] = fixture
            record["fixture_sha256"] = hashlib.sha256(fixture.encode()).hexdigest()
            record["expected_skills"] = expected
            record["repeat_index"] = repeat_index
            record["repeat_count"] = len(contexts)
            record["control_config_fingerprint"] = (
                "3" * 64 if variant == "control_drift" else "1" * 64
            )
            record["treatment_skill_fingerprint"] = treatment_fingerprint
            verdict = "PASS_WITH_NITS" if variant == "baseline" else "PASS"
            if variant in ("all_fail_baseline", "all_fail_treatment"):
                verdict = "FAIL"
            if variant == "mixed_floor" and journey == "J8":
                verdict = {
                    1: "PASS",
                    2: "PASS_WITH_NITS",
                    3: "FAIL",
                }[repeat_index]
            if variant == "verdict_regression" and journey == "J9" and repeat_index == 2:
                verdict = "FAIL"
            set_outcome(record, verdict)
            record["reported_usage"] = {
                "input_tokens": context_tokens,
                "output_tokens": 20,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
            }
            record["cost"] = {
                "context_tokens": context_tokens,
                "output_tokens": 20,
                "total_tokens": context_tokens + 20,
            }
            output.write(json.dumps(record, sort_keys=True) + "\n")
PY
    rm "$template_file"
}

@test "fixture lint accepts the canonical corpus without invoking claude" {
    run bash "$SCRIPT" --lint-fixtures

    [ "$status" -eq 0 ]
    [[ "$output" == *"fixtures OK:"* ]]
    [[ "$output" == *"J8"* ]]
    [[ "$output" == *"J9"* ]]
    [[ "$output" == *"J10"* ]]
    [[ "$output" == *"J11"* ]]
    assert_claude_not_invoked
}

@test "list is deterministic and exposes J8 through J11 without invoking claude" {
    run bash "$SCRIPT" --list
    [ "$status" -eq 0 ]
    first="$output"

    run bash "$SCRIPT" --list
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [[ "$output" == *$'J8\tJ8-debate.txt'* ]]
    [[ "$output" == *$'J9\tJ9-phr.txt'* ]]
    [[ "$output" == *$'J10\tJ10-ferry.txt'* ]]
    [[ "$output" == *$'J11\tJ11-ip-audit.txt'* ]]
    assert_claude_not_invoked
}

@test "fixture lint fails closed when a required journey is missing" {
    local fixture_dir="$BATS_TEST_TMPDIR/missing"
    copy_fixtures "$fixture_dir"
    rm "$fixture_dir/J10-ferry.txt"

    run env JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" bash "$SCRIPT" --lint-fixtures

    [ "$status" -eq 1 ]
    [[ "$output" == *"missing required journey fixture: J10"* ]]
    assert_claude_not_invoked
}

@test "fixture lint fails closed on malformed expectation metadata" {
    local fixture_dir="$BATS_TEST_TMPDIR/malformed"
    copy_fixtures "$fixture_dir"
    printf '# expect: Debate Skill\nPrompt body.\n' > "$fixture_dir/J8-debate.txt"

    run env JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" bash "$SCRIPT" --lint-fixtures

    [ "$status" -eq 1 ]
    [[ "$output" == *"J8-debate.txt:1"* ]]
    [[ "$output" == *"expect"* ]]
    assert_claude_not_invoked
}

@test "fixture lint fails closed on duplicate journey IDs" {
    local fixture_dir="$BATS_TEST_TMPDIR/duplicate"
    copy_fixtures "$fixture_dir"
    cp "$fixture_dir/J8-debate.txt" "$fixture_dir/J8-alternate.txt"

    run env JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" bash "$SCRIPT" --lint-fixtures

    [ "$status" -eq 1 ]
    [[ "$output" == *"duplicate journey ID J8"* ]]
    assert_claude_not_invoked
}

@test "journey selection fails closed when any requested ID is missing" {
    run bash "$SCRIPT" --dry-run --journeys J8,J404

    [ "$status" -eq 1 ]
    [[ "$output" == *"requested journey fixture not found: J404"* ]]
    assert_claude_not_invoked
}

@test "required-value parsing rejects another flag as the model value without entering live mode" {
    run bash "$SCRIPT" --model --lint-fixtures

    [ "$status" -eq 2 ]
    [[ "$output" == *"--model requires a value"* ]]
    assert_claude_not_invoked
}

@test "compare parsing requires two non-option values without entering live mode" {
    run bash "$SCRIPT" --compare before.jsonl --list

    [ "$status" -eq 2 ]
    [[ "$output" == *"--compare requires two files"* ]]
    assert_claude_not_invoked
}

@test "primary offline modes are mutually exclusive" {
    run bash "$SCRIPT" --list --lint-fixtures

    [ "$status" -eq 2 ]
    [[ "$output" == *"choose exactly one primary mode"* ]]
    assert_claude_not_invoked
}

@test "parse-stream-only options cannot silently select live mode" {
    run bash "$SCRIPT" --journey J1

    [ "$status" -eq 2 ]
    [[ "$output" == *"--journey is valid only with --parse-stream"* ]]
    assert_claude_not_invoked
}

@test "parse-stream reports reproducible verdict quality and context cost" {
    run bash "$SCRIPT" --parse-stream "$STREAM_FIXTURE" --journey J1

    [ "$status" -eq 0 ]
    record="$output"
    run python3 -c '
import json
import re
import sys

r = json.loads(sys.argv[1])
assert r["schema_version"] == 3
assert r["timestamp"] == "2026-01-01T00:00:00Z"
assert r["journey"] == "J1"
assert r["fixture"] == "J1-debug.txt"
assert re.fullmatch(r"[0-9a-f]{64}", r["fixture_sha256"])
assert r["observed_model"] == "claude-sonnet-5"
assert r["requested_model"] is None
assert r["repeat_count"] == 1
assert r["control_config_fingerprint"] == "0c8bd20d966658b166e4c77b799417ac29469535790bb570b374ec666ab821cc"
assert r["treatment_skill_fingerprint"] == "198df20b859c967f299c886caf349eda54f3109baebfb9101298b273cc55b26f"
assert r["claude_cli_version"] == "2.1.274-test"
assert r["permission_mode"] == "manual"
assert r["max_budget_usd"] == 0.5
assert r["verdict"] == "PASS_WITH_NITS"
assert r["verdict_reasons"] == ["unexpected_skills"]
assert r["quality"] == {
    "expected_count": 1,
    "actual_unique_count": 2,
    "matched_count": 1,
    "recall": 1.0,
    "precision": 0.5,
}
assert r["cost"] == {
    "context_tokens": 3350,
    "output_tokens": 300,
    "total_tokens": 3650,
}
' "$record"
    [ "$status" -eq 0 ]
    assert_claude_not_invoked
}

@test "parse-stream fails closed on malformed JSONL" {
    local stream="$BATS_TEST_TMPDIR/malformed.jsonl"
    copy_stream_with_meta "$stream"
    printf '{not-json}\n' >> "$stream"

    run bash "$SCRIPT" --parse-stream "$stream" --journey J1

    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid JSON"* ]]
    assert_claude_not_invoked
}

@test "parse-stream rejects non-standard JSON numeric constants" {
    local stream="$BATS_TEST_TMPDIR/nonstandard-number.jsonl"
    sed '$s/"duration_ms":8342/"duration_ms":NaN/' "$STREAM_FIXTURE" > "$stream"
    cp "$STREAM_META_FIXTURE" "$stream.meta.json"

    run bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 1 ]
    [[ "$output" == *"non-standard JSON constant NaN"* ]]
    assert_claude_not_invoked
}

@test "parse-stream fails closed when the terminal result event is missing" {
    local stream="$BATS_TEST_TMPDIR/no-result.jsonl"
    sed '$d' "$STREAM_FIXTURE" > "$stream"
    cp "$STREAM_META_FIXTURE" "$stream.meta.json"

    run bash "$SCRIPT" --parse-stream "$stream" --journey J1

    [ "$status" -eq 1 ]
    [[ "$output" == *"exactly one result event"* ]]
    assert_claude_not_invoked
}

@test "parse-stream requires immutable capture metadata" {
    local stream="$BATS_TEST_TMPDIR/no-sidecar.jsonl"
    cp "$STREAM_FIXTURE" "$stream"

    run bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 1 ]
    [[ "$output" == *"metadata sidecar not found"* ]]
    assert_claude_not_invoked
}

@test "parse-stream rejects malformed sidecars and raw config path fields" {
    local stream="$BATS_TEST_TMPDIR/malformed-sidecar.jsonl"
    copy_stream_with_meta "$stream"
    python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    metadata = json.load(source)
metadata["config_dir"] = "/private/sensitive/config"
with open(sys.argv[1], "w", encoding="utf-8") as destination:
    json.dump(metadata, destination)
' "$stream.meta.json"

    run bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 1 ]
    [[ "$output" == *"unsupported field config_dir"* ]]
    [[ "$output" != *"/private/sensitive/config"* ]]
    assert_claude_not_invoked
}

@test "parse-stream rejects duplicate init events" {
    local stream="$BATS_TEST_TMPDIR/duplicate-init.jsonl"
    head -n 1 "$STREAM_FIXTURE" > "$stream"
    cat "$STREAM_FIXTURE" >> "$stream"
    cp "$STREAM_META_FIXTURE" "$stream.meta.json"

    run bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 1 ]
    [[ "$output" == *"exactly one system init event"* ]]
    assert_claude_not_invoked
}

@test "parse-stream requires one init event with a non-empty model" {
    local missing_init="$BATS_TEST_TMPDIR/missing-init.jsonl"
    local empty_model="$BATS_TEST_TMPDIR/empty-model.jsonl"
    tail -n +2 "$STREAM_FIXTURE" > "$missing_init"
    sed '1s/"claude-sonnet-5"/""/' "$STREAM_FIXTURE" > "$empty_model"
    cp "$STREAM_META_FIXTURE" "$missing_init.meta.json"
    cp "$STREAM_META_FIXTURE" "$empty_model.meta.json"

    run bash "$SCRIPT" --parse-stream "$missing_init"
    [ "$status" -eq 1 ]
    [[ "$output" == *"system init event"* ]]

    run bash "$SCRIPT" --parse-stream "$empty_model"
    [ "$status" -eq 1 ]
    [[ "$output" == *"system init model must be a non-empty string"* ]]
    assert_claude_not_invoked
}

@test "parse-stream rejects events after the terminal result" {
    local stream="$BATS_TEST_TMPDIR/post-result.jsonl"
    copy_stream_with_meta "$stream"
    printf '%s\n' '{"type":"user","message":{"role":"user","content":[]}}' >> "$stream"

    run bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 1 ]
    [[ "$output" == *"result event must be terminal"* ]]
    assert_claude_not_invoked
}

@test "replay identity comes from the immutable sidecar rather than the current fixture corpus" {
    local stream="$BATS_TEST_TMPDIR/replay.jsonl"
    local fixture_dir="$BATS_TEST_TMPDIR/changed-fixtures"
    copy_stream_with_meta "$stream"
    copy_fixtures "$fixture_dir"
    printf '\nChanged after capture.\n' >> "$fixture_dir/J1-debug.txt"

    run env JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" bash "$SCRIPT" --parse-stream "$stream"

    [ "$status" -eq 0 ]
    [[ "$output" == *"7a95e4ac517e5ab921b5eb08fa75efcc6d47482a9792aa344b2d9d9121f8e5e3"* ]]
    assert_claude_not_invoked
}

@test "compare accepts an intended treatment-only delta and emits a passing Phase 2 verdict" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    make_gate_dataset "$before" "a000000000000000000000000000000000000000000000000000000000000000" baseline
    make_gate_dataset "$after" "b000000000000000000000000000000000000000000000000000000000000000" pass

    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 0 ]
    [[ "$output" == *"A verdicts (P/N/F)"* ]]
    [[ "$output" == *"B verdicts (P/N/F)"* ]]
    [[ "$output" == *"A median ctx"* ]]
    [[ "$output" == *"B median ctx"* ]]
    [[ "$output" == *"d median ctx"* ]]
    [[ "$output" == *"J8"* ]]
    [[ "$output" == *'MACHINE_VERDICT {"gate":"phase2-j8-j10","reasons":[],"verdict":"PASS"}'* ]]
    assert_claude_not_invoked
}

@test "compare rejects control drift even when the treatment delta and metrics would pass" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    make_gate_dataset "$before" "a000000000000000000000000000000000000000000000000000000000000000" baseline
    make_gate_dataset "$after" "b000000000000000000000000000000000000000000000000000000000000000" control_drift

    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 1 ]
    [[ "$output" == *"control config fingerprint mismatch for J8"* ]]
    assert_claude_not_invoked
}

@test "compare requires a measured treatment skill delta" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    local same="a000000000000000000000000000000000000000000000000000000000000000"
    make_gate_dataset "$before" "$same" baseline
    make_gate_dataset "$after" "$same" pass

    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 1 ]
    [[ "$output" == *"treatment skill fingerprint did not change"* ]]
    assert_claude_not_invoked
}

@test "Phase 2 gate rejects verdict, strict-median, and worst-case boundaries" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    local variant reason
    make_gate_dataset "$before" "a000000000000000000000000000000000000000000000000000000000000000" baseline

    while IFS='|' read -r variant reason; do
        make_gate_dataset "$after" "b000000000000000000000000000000000000000000000000000000000000000" "$variant"
        run bash "$SCRIPT" --compare "$before" "$after"
        [ "$status" -eq 1 ]
        [[ "$output" == *'"verdict":"REGRESSION"'* ]]
        [[ "$output" == *"$reason"* ]]
    done <<'EOF'
verdict_regression|J9:verdict_downgrade_repeat_2
median_equal|J8:median_context_not_lower
worst_regression|J8:worst_context_regressed
EOF
    assert_claude_not_invoked
}

@test "Phase 2 gate enforces a PASS_WITH_NITS treatment floor for all and mixed FAIL repeats" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    local baseline_fingerprint="a000000000000000000000000000000000000000000000000000000000000000"
    local treatment_fingerprint="b000000000000000000000000000000000000000000000000000000000000000"
    make_gate_dataset "$before" "$baseline_fingerprint" all_fail_baseline
    make_gate_dataset "$after" "$treatment_fingerprint" all_fail_treatment

    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 1 ]
    [[ "$output" == *'"verdict":"REGRESSION"'* ]]
    [[ "$output" == *"J8:treatment_verdict_below_floor_repeat_1"* ]]
    [[ "$output" != *"verdict_downgrade"* ]]
    [[ "$output" != *"median_context_not_lower"* ]]
    [[ "$output" != *"worst_context_regressed"* ]]

    make_gate_dataset "$after" "$treatment_fingerprint" mixed_floor
    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 1 ]
    [[ "$output" == *'"verdict":"REGRESSION"'* ]]
    [[ "$output" == *"J8:treatment_verdict_below_floor_repeat_3"* ]]
    [[ "$output" != *"J8:treatment_verdict_below_floor_repeat_1"* ]]
    [[ "$output" != *"J8:treatment_verdict_below_floor_repeat_2"* ]]
    assert_claude_not_invoked
}

@test "compare fails closed on malformed result records" {
    local malformed="$BATS_TEST_TMPDIR/malformed-results.jsonl"
    printf '{"journey":"J1"}\n' > "$malformed"

    run bash "$SCRIPT" --compare "$malformed" "$malformed"

    [ "$status" -eq 1 ]
    [[ "$output" == *"missing required field"* ]]
    assert_claude_not_invoked
}

@test "compare refuses fixture drift between Phase 1 and Phase 2 inputs" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    bash "$SCRIPT" --parse-stream "$STREAM_FIXTURE" --journey J1 > "$before"
    python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    record = json.load(source)
record["fixture_sha256"] = "0" * 64
with open(sys.argv[2], "w", encoding="utf-8") as destination:
    json.dump(record, destination)
    destination.write("\n")
' "$before" "$after"

    run bash "$SCRIPT" --compare "$before" "$after"

    [ "$status" -eq 1 ]
    [[ "$output" == *"fixture hash mismatch for J1"* ]]
    assert_claude_not_invoked
}

@test "compare rejects drift in every measurement compatibility identity" {
    local before="$BATS_TEST_TMPDIR/before.jsonl"
    local after="$BATS_TEST_TMPDIR/after.jsonl"
    bash "$SCRIPT" --parse-stream "$STREAM_FIXTURE" > "$before"

    local field value label
    while IFS='|' read -r field value label; do
        python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    record = json.load(source)
record[sys.argv[3]] = json.loads(sys.argv[4])
with open(sys.argv[2], "w", encoding="utf-8") as destination:
    json.dump(record, destination)
    destination.write("\n")
' "$before" "$after" "$field" "$value"

        run bash "$SCRIPT" --compare "$before" "$after"
        [ "$status" -eq 1 ]
        [[ "$output" == *"$label mismatch for J1"* ]]
    done <<'EOF'
fixture|"J1-alternate.txt"|fixture name
control_config_fingerprint|"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"|control config fingerprint
claude_cli_version|"different-cli"|Claude CLI version
requested_model|"different-request"|requested model
observed_model|"different-observed"|observed model
permission_mode|"plan"|permission mode
EOF
    assert_claude_not_invoked
}

@test "compare rejects incomplete repeat indices even when both inputs match" {
    local one="$BATS_TEST_TMPDIR/one.jsonl"
    local gapped="$BATS_TEST_TMPDIR/gapped.jsonl"
    bash "$SCRIPT" --parse-stream "$STREAM_FIXTURE" > "$one"
    python3 -c '
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
record["repeat_count"] = 3
with open(sys.argv[2], "w", encoding="utf-8") as destination:
    destination.write(json.dumps(record) + "\n")
    record["repeat_index"] = 3
    destination.write(json.dumps(record) + "\n")
' "$one" "$gapped"

    run bash "$SCRIPT" --compare "$gapped" "$gapped"

    [ "$status" -eq 1 ]
    [[ "$output" == *"repeat indices for J1 must be complete"* ]]
    assert_claude_not_invoked
}

@test "live mode refuses to append to an existing results file" {
    local results="$BATS_TEST_TMPDIR/existing.jsonl"
    local config_dir="$BATS_TEST_TMPDIR/config"
    make_config_dir "$config_dir"
    printf '{"existing":true}\n' > "$results"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" --results-file "$results"

    [ "$status" -eq 1 ]
    [[ "$output" == *"results file already exists"* ]]
    assert_claude_not_invoked
}

@test "live stream failure removes the throwaway repository and prompt" {
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results="$BATS_TEST_TMPDIR/failed-run.jsonl"
    local config_dir="$BATS_TEST_TMPDIR/config"
    mkdir -p "$run_tmp"
    make_config_dir "$config_dir"

    run env TMPDIR="$run_tmp" bash "$SCRIPT" \
        --journeys J8 \
        --config-dir "$config_dir" \
        --results-file "$results"

    [ "$status" -eq 1 ]
    [ -e "$CLAUDE_MARKER" ]
    # System Git on macOS may create an unrelated xcrun_db under TMPDIR. Check
    # only the probe-owned repository, template, snapshot, and prompt shapes.
    run find "$run_tmp" -mindepth 1 -maxdepth 1 \
        \( -name 'journey-probe.*' -o -name 'journey-probe-template.*' \
           -o -name 'journey-probe-fixtures.*' -o -name 'tmp.*' \) \
        -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "live mode sends and records one private fixture snapshot despite post-discovery source mutation" {
    local fixture_dir="$BATS_TEST_TMPDIR/fixtures"
    local config_dir="$BATS_TEST_TMPDIR/config"
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local expected_prompt="$BATS_TEST_TMPDIR/expected-prompt.txt"
    local sent_prompt="$BATS_TEST_TMPDIR/sent-prompt.txt"
    local snapshot_audit="$BATS_TEST_TMPDIR/snapshot-audit.txt"
    local mutation_marker="$BATS_TEST_TMPDIR/source-mutated"
    local source_fixture expected_hash snapshot_dir snapshot_dir_mode snapshot_file_mode
    copy_fixtures "$fixture_dir"
    make_config_dir "$config_dir"
    mkdir -p "$run_tmp"
    source_fixture="$fixture_dir/J8-debate.txt"
    tail -n +2 "$source_fixture" > "$expected_prompt"
    expected_hash="$("$REAL_PYTHON3" -c '
import hashlib
import sys

print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
' "$source_fixture")"

    cat > "$FAKE_BIN/python3" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$REAL_PYTHON3" "\$@"
status=\$?
if [[ "\${2:-}" == "fixtures" && " \$* " == *" --list "* && ! -e "$mutation_marker" ]]; then
    snapshot_dir=""
    previous=""
    for argument in "\$@"; do
        if [[ "\$previous" == "--directory" ]]; then
            snapshot_dir="\$argument"
            break
        fi
        previous="\$argument"
    done
    dir_mode="\$(stat -c '%a' "\$snapshot_dir" 2>/dev/null || stat -f '%Lp' "\$snapshot_dir")"
    file_mode="\$(stat -c '%a' "\$snapshot_dir/J8-debate.txt" 2>/dev/null || stat -f '%Lp' "\$snapshot_dir/J8-debate.txt")"
    printf '%s|%s|%s\n' "\$snapshot_dir" "\$dir_mode" "\$file_mode" > "$snapshot_audit"
    printf '%s\n' 'MUTATED AFTER DISCOVERY' >> "$source_fixture"
    touch "$mutation_marker"
fi
exit "\$status"
EOF
    chmod +x "$FAKE_BIN/python3"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
touch "$CLAUDE_MARKER"
printf '%s' "\${2:-}" > "$sent_prompt"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"

    run env TMPDIR="$run_tmp" JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" \
        bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results"

    [ "$status" -eq 0 ]
    [ -e "$mutation_marker" ]
    run cmp "$expected_prompt" "$sent_prompt"
    [ "$status" -eq 0 ]
    run "$REAL_PYTHON3" -c '
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
assert record["fixture_sha256"] == sys.argv[2]
' "$results" "$expected_hash"
    [ "$status" -eq 0 ]
    [ -s "$snapshot_audit" ]
    IFS='|' read -r snapshot_dir snapshot_dir_mode snapshot_file_mode < "$snapshot_audit"
    [ "$snapshot_dir" != "$fixture_dir" ]
    [ "$snapshot_dir_mode" = "700" ]
    [ "$snapshot_file_mode" = "400" ]
    [ ! -e "$snapshot_dir" ]
}

@test "live mode derives prompt and identity from one snapshot read despite between-phase mutation" {
    local fixture_dir="$BATS_TEST_TMPDIR/fixtures"
    local config_dir="$BATS_TEST_TMPDIR/config"
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local expected_prompt="$BATS_TEST_TMPDIR/expected-prompt.txt"
    local sent_prompt="$BATS_TEST_TMPDIR/sent-prompt.txt"
    local mutation_marker="$BATS_TEST_TMPDIR/snapshot-mutated"
    local source_fixture expected_hash
    copy_fixtures "$fixture_dir"
    make_config_dir "$config_dir"
    mkdir -p "$run_tmp"
    source_fixture="$fixture_dir/J8-debate.txt"
    tail -n +2 "$source_fixture" > "$expected_prompt"
    expected_hash="$("$REAL_PYTHON3" -c '
import hashlib
import sys

print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
' "$source_fixture")"

    cat > "$FAKE_BIN/python3" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$REAL_PYTHON3" "\$@"
status=\$?
if [[ "\${2:-}" == "fixtures" && " \$* " == *" --list "* && ! -e "$mutation_marker" ]]; then
    snapshot_dir=""
    previous=""
    for argument in "\$@"; do
        if [[ "\$previous" == "--directory" ]]; then
            snapshot_dir="\$argument"
            break
        fi
        previous="\$argument"
    done
    chmod 600 "\$snapshot_dir/J8-debate.txt"
    printf '%s\n' 'MUTATED BETWEEN DISCOVERY AND RUN' >> "\$snapshot_dir/J8-debate.txt"
    touch "$mutation_marker"
fi
exit "\$status"
EOF
    chmod +x "$FAKE_BIN/python3"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
printf '%s' "\${2:-}" > "$sent_prompt"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"

    run env TMPDIR="$run_tmp" JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" \
        bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results"

    [ "$status" -eq 0 ]
    [ -e "$mutation_marker" ]
    run cmp "$expected_prompt" "$sent_prompt"
    [ "$status" -eq 0 ]
    run "$REAL_PYTHON3" -c '
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
assert record["fixture_sha256"] == sys.argv[2]
' "$results" "$expected_hash"
    [ "$status" -eq 0 ]
    run find "$run_tmp" -mindepth 1 -maxdepth 1 \
        -name 'journey-probe-fixtures.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "snapshot inputs reject FIFO socket device and symlink paths without hanging" {
    local kind fixture_dir special_path socket_pid="" tested_kinds=""
    local existing_socket=""
    for kind in fifo socket device symlink; do
        fixture_dir="$BATS_TEST_TMPDIR/fixtures-$kind"
        copy_fixtures "$fixture_dir"
        special_path="$fixture_dir/J8-debate.txt"
        rm "$special_path"
        case "$kind" in
            fifo)
                mkfifo "$special_path"
                ;;
            socket)
                "$REAL_PYTHON3" - "$special_path" 2>/dev/null <<'PY' &
import signal
import socket
import sys
import time

sock = socket.socket(socket.AF_UNIX)
sock.bind(sys.argv[1])
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
while True:
    time.sleep(1)
PY
                socket_pid=$!
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                    [ -S "$special_path" ] && break
                    sleep 0.05
                done
                if [ ! -S "$special_path" ]; then
                    kill "$socket_pid" 2>/dev/null || true
                    wait "$socket_pid" 2>/dev/null || true
                    socket_pid=""
                    existing_socket="$(find /private/tmp /private/var/run /tmp /var/run \
                        -type s -print -quit 2>/dev/null)"
                    [ -n "$existing_socket" ] || continue
                    ln "$existing_socket" "$special_path" 2>/dev/null || continue
                fi
                ;;
            device)
                if [ "$(uname -s)" = "Darwin" ]; then
                    mknod "$special_path" c 3 2 2>/dev/null || continue
                else
                    mknod "$special_path" c 1 3 2>/dev/null || continue
                fi
                ;;
            symlink)
                ln -s "$fixture_dir/J9-phr.txt" "$special_path"
                ;;
        esac
        tested_kinds="$tested_kinds $kind"

        run_harness_with_watchdog 3 env JOURNEY_PROBE_FIXTURES_DIR="$fixture_dir" \
            bash "$SCRIPT" --lint-fixtures
        local harness_status="$status"
        local harness_output="$output"
        if [ -n "$socket_pid" ]; then
            kill "$socket_pid" 2>/dev/null || true
            wait "$socket_pid" 2>/dev/null || true
            socket_pid=""
        fi
        [ "$harness_status" -eq 1 ]
        [[ "$harness_output" != *"WATCHDOG_TIMEOUT"* ]]
        [[ "$harness_output" == *"regular file"* || "$harness_output" == *"must not be a symlink"* ]]
    done
    [[ "$tested_kinds" == *" fifo"* ]]
    [[ "$tested_kinds" == *" socket"* ]]
    [[ "$tested_kinds" == *" symlink"* ]]

    run_harness_with_watchdog 3 bash "$SCRIPT" --dry-run --journeys J8 \
        --config-dir /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" != *"WATCHDOG_TIMEOUT"* ]]
    [[ "$output" == *"config source must be a directory"* ]]
}

@test "fixture Git setup ignores hostile global hooks without bypassing verification" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local hook_dir="$BATS_TEST_TMPDIR/hostile-hooks"
    local hook_marker="$BATS_TEST_TMPDIR/hook-ran"
    local git_args="$BATS_TEST_TMPDIR/git-args"
    local claude_args="$BATS_TEST_TMPDIR/claude-args"
    local global_config="$BATS_TEST_TMPDIR/global.gitconfig"
    make_config_dir "$config_dir"
    install_valid_fake_claude "$claude_args"
    mkdir -p "$hook_dir"
    cat > "$hook_dir/pre-commit" <<EOF
#!/usr/bin/env bash
touch "$hook_marker"
exit 91
EOF
    chmod +x "$hook_dir/pre-commit"
    printf '[core]\n\thooksPath = %s\n' "$hook_dir" > "$global_config"
    cat > "$FAKE_BIN/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$git_args"
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$FAKE_BIN/git"

    run env GIT_CONFIG_GLOBAL="$global_config" \
        GIT_CONFIG_COUNT=1 \
        GIT_CONFIG_KEY_0=core.hooksPath \
        GIT_CONFIG_VALUE_0="$hook_dir" \
        bash "$SCRIPT" \
        --journeys J8 --config-dir "$config_dir" --results-file "$results"

    [ "$status" -eq 0 ]
    [ ! -e "$hook_marker" ]
    run grep -F -- '--no-verify' "$git_args"
    [ "$status" -eq 1 ]
}

@test "fixture Git failure stops before Claude is invoked" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    make_config_dir "$config_dir"
    cat > "$FAKE_BIN/git" <<EOF
#!/usr/bin/env bash
if [[ " \$* " == *" commit "* ]]; then
    exit 73
fi
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$FAKE_BIN/git"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" --results-file "$results"

    [ "$status" -eq 1 ]
    [[ "$output" == *"failed to create fixture repository"* ]]
    [ ! -e "$CLAUDE_MARKER" ]
}

@test "live mode passes bounded privacy flags and stores only private fingerprinted metadata" {
    local config_dir="$BATS_TEST_TMPDIR/private-config"
    local results_dir="$BATS_TEST_TMPDIR/results-dir"
    local results="$results_dir/results.jsonl"
    local claude_args="$BATS_TEST_TMPDIR/claude-args"
    make_config_dir "$config_dir"
    install_valid_fake_claude "$claude_args"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results" --max-budget-usd 0.25 --verbose

    [ "$status" -eq 0 ]
    run grep -Fx -- '--no-session-persistence' "$claude_args"
    [ "$status" -eq 0 ]
    run grep -A1 -Fx -- '--permission-mode' "$claude_args"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'--permission-mode\nmanual'* ]]
    run grep -A1 -Fx -- '--max-budget-usd' "$claude_args"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'--max-budget-usd\n0.25'* ]]
    run grep -R -F -- "$config_dir" "$results_dir"
    [ "$status" -eq 1 ]
    [ "$(file_mode "$results")" = "600" ]
    [ "$(file_mode "$results_dir/raw")" = "700" ]
    while IFS= read -r private_file; do
        [ "$(file_mode "$private_file")" = "600" ]
    done < <(find "$results_dir/raw" -type f -print)
    run python3 -c '
import json
import re
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
assert re.fullmatch(r"[0-9a-f]{64}", record["control_config_fingerprint"])
assert re.fullmatch(r"[0-9a-f]{64}", record["treatment_skill_fingerprint"])
assert record["claude_cli_version"] == "2.1.274-test"
assert record["permission_mode"] == "manual"
assert record["max_budget_usd"] == 0.25
assert record["observed_model"] == "claude-sonnet-5"
assert "config_dir" not in record
' "$results"
    [ "$status" -eq 0 ]
}

@test "fingerprints isolate fixed J8-J10 treatment skills from control configuration" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local before_control before_treatment treatment_control treatment_fingerprint
    local changed_control changed_treatment
    make_config_dir "$config_dir"

    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"
    [ "$status" -eq 0 ]
    before_control="$(printf '%s\n' "$output" | sed -n 's/.*control-config-fingerprint=\([0-9a-f]*\).*/\1/p')"
    before_treatment="$(printf '%s\n' "$output" | sed -n 's/.*treatment-skill-fingerprint=\([0-9a-f]*\).*/\1/p')"

    printf '%s\n' '# changed treatment' >> "$config_dir/skills/sp-debate/skill.md"
    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"
    [ "$status" -eq 0 ]
    treatment_control="$(printf '%s\n' "$output" | sed -n 's/.*control-config-fingerprint=\([0-9a-f]*\).*/\1/p')"
    treatment_fingerprint="$(printf '%s\n' "$output" | sed -n 's/.*treatment-skill-fingerprint=\([0-9a-f]*\).*/\1/p')"
    [ "$treatment_control" = "$before_control" ]
    [ "$treatment_fingerprint" != "$before_treatment" ]

    printf '%s\n' '{"env":{"CONTROL":"changed"}}' > "$config_dir/settings.json"
    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"
    [ "$status" -eq 0 ]
    changed_control="$(printf '%s\n' "$output" | sed -n 's/.*control-config-fingerprint=\([0-9a-f]*\).*/\1/p')"
    changed_treatment="$(printf '%s\n' "$output" | sed -n 's/.*treatment-skill-fingerprint=\([0-9a-f]*\).*/\1/p')"
    [ "$changed_control" != "$treatment_control" ]
    [ "$changed_treatment" = "$treatment_fingerprint" ]
    assert_claude_not_invoked
}

@test "fingerprinting fails closed when a fixed treatment skill is missing" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    make_config_dir "$config_dir"
    rm -r "$config_dir/skills/sp-phr"

    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"

    [ "$status" -eq 1 ]
    [[ "$output" == *"missing required treatment skill directory skills/sp-phr"* ]]
    assert_claude_not_invoked
}

@test "config snapshot rejects a symlink root before Claude is invoked" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local config_link="$BATS_TEST_TMPDIR/config-link"
    make_config_dir "$config_dir"
    ln -s "$config_dir" "$config_link"

    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_link"

    [ "$status" -eq 1 ]
    [[ "$output" == *"config source must not be a symlink"* ]]
    assert_claude_not_invoked
}

@test "Claude receives the fingerprinted private config snapshot despite source replace-restore" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local attacker_dir="$BATS_TEST_TMPDIR/attacker-config"
    local saved_dir="$BATS_TEST_TMPDIR/saved-config"
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results_dir="$BATS_TEST_TMPDIR/results"
    local results="$results_dir/results.jsonl"
    local observed_config="$BATS_TEST_TMPDIR/observed-config.json"
    local observed_secret="$BATS_TEST_TMPDIR/observed-secret.txt"
    local observed_modes="$BATS_TEST_TMPDIR/observed-modes.txt"
    local passed_config="$BATS_TEST_TMPDIR/passed-config.txt"
    make_config_dir "$config_dir"
    make_config_dir "$attacker_dir"
    mkdir -p "$run_tmp"
    printf '{"identity":"original"}\n' > "$config_dir/settings.json"
    printf '{"identity":"attacker"}\n' > "$attacker_dir/settings.json"
    printf '%s\n' 'fixture-auth-secret' > "$config_dir/.credentials.json"
    printf '%s\n' 'attacker-auth-secret' > "$attacker_dir/.credentials.json"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
printf '%s\n' "\${CLAUDE_CONFIG_DIR:-}" > "$passed_config"
dir_mode="\$(stat -c '%a' "\$CLAUDE_CONFIG_DIR" 2>/dev/null || stat -f '%Lp' "\$CLAUDE_CONFIG_DIR")"
file_mode="\$(stat -c '%a' "\$CLAUDE_CONFIG_DIR/.credentials.json" 2>/dev/null || stat -f '%Lp' "\$CLAUDE_CONFIG_DIR/.credentials.json")"
printf '%s|%s\n' "\$dir_mode" "\$file_mode" > "$observed_modes"
mv "$config_dir" "$saved_dir"
cp -R "$attacker_dir" "$config_dir"
cat "\$CLAUDE_CONFIG_DIR/settings.json" > "$observed_config"
cat "\$CLAUDE_CONFIG_DIR/.credentials.json" > "$observed_secret"
rm -rf "$config_dir"
mv "$saved_dir" "$config_dir"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"

    run env TMPDIR="$run_tmp" bash "$SCRIPT" --journeys J8 \
        --config-dir "$config_dir" --results-file "$results"

    [ "$status" -eq 0 ]
    [ "$(cat "$observed_config")" = '{"identity":"original"}' ]
    [ "$(cat "$observed_secret")" = 'fixture-auth-secret' ]
    [ "$(cat "$observed_modes")" = '500|400' ]
    [ "$(cat "$passed_config")" != "$config_dir" ]
    [ ! -e "$(cat "$passed_config")" ]
    run grep -R -F -- 'fixture-auth-secret' "$results_dir"
    [ "$status" -eq 1 ]
    run find "$run_tmp" -mindepth 1 -maxdepth 1 \
        -name 'journey-probe-config.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "non-verbose live mode records an in-memory capture timestamp without a sidecar" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results_dir="$BATS_TEST_TMPDIR/results-dir"
    local results="$results_dir/results.jsonl"
    local claude_args="$BATS_TEST_TMPDIR/claude-args"
    make_config_dir "$config_dir"
    install_valid_fake_claude "$claude_args"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" --results-file "$results"

    [ "$status" -eq 0 ]
    run python3 -c '
import json
import re
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
assert re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", record["timestamp"])
' "$results"
    [ "$status" -eq 0 ]
    run find "$results_dir/raw" -type f -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "live mode fails closed if the private control snapshot mutates during measurement" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    make_config_dir "$config_dir"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
chmod 600 "\$CLAUDE_CONFIG_DIR/settings.json"
printf '\n' >> "\$CLAUDE_CONFIG_DIR/settings.json"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results"

    [ "$status" -eq 1 ]
    [[ "$output" == *"control configuration changed during measurement"* ]]
    [ ! -s "$results" ]
}

@test "live mode fails closed if a private treatment snapshot mutates during measurement" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    make_config_dir "$config_dir"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
chmod 600 "\$CLAUDE_CONFIG_DIR/skills/sp-debate/skill.md"
printf '\n' >> "\$CLAUDE_CONFIG_DIR/skills/sp-debate/skill.md"
cat "$STREAM_FIXTURE"
EOF
    chmod +x "$FAKE_BIN/claude"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results"

    [ "$status" -eq 1 ]
    [[ "$output" == *"treatment skills changed during measurement"* ]]
    [ ! -s "$results" ]
}

@test "live mode refuses to overwrite an existing immutable metadata sidecar" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results_dir="$BATS_TEST_TMPDIR/results-dir"
    local results="$results_dir/results.jsonl"
    local raw_dir="$results_dir/raw"
    make_config_dir "$config_dir"
    mkdir -p "$raw_dir"
    printf 'existing\n' > "$raw_dir/20200101T000000Z.J8.r1.jsonl.meta.json"
    cat > "$FAKE_BIN/date" <<'EOF'
#!/usr/bin/env bash
printf '20200101T000000Z\n'
EOF
    chmod +x "$FAKE_BIN/date"

    run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results" --verbose

    [ "$status" -eq 1 ]
    [[ "$output" == *"metadata sidecar already exists"* ]]
    [ ! -e "$CLAUDE_MARKER" ]
    [ "$(cat "$raw_dir/20200101T000000Z.J8.r1.jsonl.meta.json")" = "existing" ]
}

@test "timeout terminates and reaps the complete Claude process group" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local child_pid_file="$BATS_TEST_TMPDIR/child.pid"
    mkdir -p "$run_tmp"
    make_config_dir "$config_dir"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
touch "$CLAUDE_MARKER"
sleep 60 &
child_pid=\$!
printf '%s\n' "\$child_pid" > "$child_pid_file"
wait "\$child_pid"
EOF
    chmod +x "$FAKE_BIN/claude"

    run env TMPDIR="$run_tmp" bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
        --results-file "$results" --timeout 1

    [ "$status" -eq 1 ]
    [ -s "$child_pid_file" ]
    child_pid="$(cat "$child_pid_file")"
    run kill -0 "$child_pid"
    child_status="$status"
    if [ "$child_status" -eq 0 ]; then
        kill "$child_pid"
    fi
    [ "$child_status" -ne 0 ]
    run find "$run_tmp" -mindepth 1 -maxdepth 1 \
        -name 'journey-probe-fixtures.*' -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "partial stream line cannot bypass timeout and its process group is reaped" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local parent_pid_file="$BATS_TEST_TMPDIR/partial-parent.pid"
    local child_pid_file="$BATS_TEST_TMPDIR/partial-child.pid"
    make_config_dir "$config_dir"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
printf '%s\n' "\$\$" > "$parent_pid_file"
sleep 60 &
child_pid=\$!
printf '%s\n' "\$child_pid" > "$child_pid_file"
printf '{"type":"system"'
wait "\$child_pid"
EOF
    chmod +x "$FAKE_BIN/claude"

    run python3 -c '
import os
import signal
import subprocess
import sys

command = [
    "bash", sys.argv[1], "--journeys", "J8", "--config-dir", sys.argv[2],
    "--results-file", sys.argv[3], "--timeout", "1",
]
process = subprocess.Popen(
    command,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    start_new_session=True,
)
try:
    output, _ = process.communicate(timeout=6)
except subprocess.TimeoutExpired:
    os.killpg(process.pid, signal.SIGKILL)
    output, _ = process.communicate()
    sys.stdout.write(output)
    print("OUTER_WATCHDOG_TIMEOUT")
    sys.exit(124)
sys.stdout.write(output)
sys.exit(process.returncode)
' "$SCRIPT" "$config_dir" "$results"

    local harness_status="$status"
    local harness_output="$output"
    local parent_alive=0
    local child_alive=0
    local parent_pid=""
    local child_pid=""
    if [ -s "$parent_pid_file" ]; then
        parent_pid="$(cat "$parent_pid_file")"
        kill -0 "$parent_pid" 2>/dev/null && parent_alive=1
    fi
    if [ -s "$child_pid_file" ]; then
        child_pid="$(cat "$child_pid_file")"
        kill -0 "$child_pid" 2>/dev/null && child_alive=1
    fi
    if [ "$child_alive" -eq 1 ]; then
        kill "$child_pid" 2>/dev/null || true
    fi
    if [ "$parent_alive" -eq 1 ]; then
        kill "$parent_pid" 2>/dev/null || true
    fi

    [ "$harness_status" -eq 1 ]
    [[ "$harness_output" != *"OUTER_WATCHDOG_TIMEOUT"* ]]
    [ "$parent_alive" -eq 0 ]
    [ "$child_alive" -eq 0 ]
}

@test "successful and nonzero Claude exits reap background descendants" {
    local claude_status config_dir results child_pid_file child_pid child_alive expected_status
    for claude_status in 0 7; do
        config_dir="$BATS_TEST_TMPDIR/config-$claude_status"
        results="$BATS_TEST_TMPDIR/results-$claude_status.jsonl"
        child_pid_file="$BATS_TEST_TMPDIR/child-$claude_status.pid"
        make_config_dir "$config_dir"
        cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
sleep 60 >/dev/null 2>&1 &
printf '%s\n' "\$!" > "$child_pid_file"
cat "$STREAM_FIXTURE"
exit $claude_status
EOF
        chmod +x "$FAKE_BIN/claude"

        run bash "$SCRIPT" --journeys J8 --config-dir "$config_dir" \
            --results-file "$results" --timeout 3

        [ "$status" -eq 0 ]
        [ -s "$child_pid_file" ]
        child_pid="$(cat "$child_pid_file")"
        child_alive=0
        kill -0 "$child_pid" 2>/dev/null && child_alive=1
        if [ "$child_alive" -eq 1 ]; then
            kill "$child_pid" 2>/dev/null || true
        fi
        [ "$child_alive" -eq 0 ]
        if [ "$claude_status" -eq 0 ]; then
            expected_status="success"
        else
            expected_status="error"
        fi
        run "$REAL_PYTHON3" -c '
import json
import sys

record = json.load(open(sys.argv[1], encoding="utf-8"))
assert record["exit_status"] == sys.argv[2]
' "$results" "$expected_status"
        [ "$status" -eq 0 ]
    done
}

@test "setup latency does not weaken the early EOF runtime deadline or cleanup" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    local run_tmp="$BATS_TEST_TMPDIR/run-tmp"
    local results="$BATS_TEST_TMPDIR/results.jsonl"
    local parent_pid_file="$BATS_TEST_TMPDIR/early-eof-parent.pid"
    local fake_start_file="$BATS_TEST_TMPDIR/fake-start.monotonic"
    make_config_dir "$config_dir"
    mkdir -p "$run_tmp"
    cat > "$FAKE_BIN/git" <<EOF
#!/usr/bin/env bash
sleep 0.4
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$FAKE_BIN/git"
    cat > "$FAKE_BIN/claude" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
    printf '2.1.274-test\n'
    exit 0
fi
"$REAL_PYTHON3" -c 'import pathlib, sys, time; pathlib.Path(sys.argv[1]).write_text(str(time.monotonic()))' "$fake_start_file"
printf '%s\n' "\$\$" > "$parent_pid_file"
exec 1>&-
sleep 60
EOF
    chmod +x "$FAKE_BIN/claude"

    run_harness_with_runtime_measurement 15 "$fake_start_file" \
        env TMPDIR="$run_tmp" bash "$SCRIPT" --journeys J8 \
        --config-dir "$config_dir" --results-file "$results" --timeout 1
    local harness_status="$status"
    local harness_output="$output"
    local runtime_elapsed
    local parent_alive=0
    runtime_elapsed="$(printf '%s\n' "$harness_output" | \
        sed -n 's/^FAKE_RUNTIME_ELAPSED=//p')"
    if [ -s "$parent_pid_file" ]; then
        kill -0 "$(cat "$parent_pid_file")" 2>/dev/null && parent_alive=1
        if [ "$parent_alive" -eq 1 ]; then
            kill "$(cat "$parent_pid_file")" 2>/dev/null || true
        fi
    fi

    [ "$harness_status" -eq 1 ]
    [[ "$harness_output" != *"SETUP_WATCHDOG_TIMEOUT"* ]]
    [[ "$harness_output" != *"FAKE_START_TIME_MISSING"* ]]
    [ "$parent_alive" -eq 0 ]
    [ -n "$runtime_elapsed" ]
    printf '# fake-Claude runtime elapsed=%ss limit=1.5s\n' "$runtime_elapsed"
    run "$REAL_PYTHON3" -c \
        'import sys; sys.exit(0 if float(sys.argv[1]) <= 1.5 else 1)' \
        "$runtime_elapsed"
    [ "$status" -eq 0 ]
    run find "$run_tmp" -mindepth 1 -maxdepth 1 \
        \( -name 'journey-probe.*' -o -name 'journey-probe-template.*' \
           -o -name 'journey-probe-fixtures.*' -o -name 'journey-probe-config.*' \
           -o -name 'tmp.*' \) -print
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dry-run hides the raw config path and shows conservative execution bounds" {
    local config_dir="$BATS_TEST_TMPDIR/sensitive-config-name"
    make_config_dir "$config_dir"

    run bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"

    [ "$status" -eq 0 ]
    [[ "$output" != *"$config_dir"* ]]
    [[ "$output" == *"--no-session-persistence"* ]]
    [[ "$output" == *"--permission-mode manual"* ]]
    [[ "$output" == *"--max-budget-usd 0.50"* ]]
    assert_claude_not_invoked
}

@test "dry-run works under stock macOS Bash 3.2" {
    local config_dir="$BATS_TEST_TMPDIR/config"
    make_config_dir "$config_dir"

    run /bin/bash "$SCRIPT" --dry-run --journeys J8 --config-dir "$config_dir"

    [ "$status" -eq 0 ]
    [[ "$output" == *"# journey J8"* ]]
    assert_claude_not_invoked
}

@test "max-budget-usd rejects missing, option-shaped, nonnumeric, and nonpositive values" {
    local invalid
    for invalid in --lint-fixtures nope 0 -1; do
        run bash "$SCRIPT" --max-budget-usd "$invalid"
        [ "$status" -eq 2 ]
        [[ "$output" == *"--max-budget-usd"* ]]
        assert_claude_not_invoked
    done
}

@test "documentation shell fences are runnable" {
    run bash "$REPO_ROOT/tools/fence-scan.sh" "$REPO_ROOT/docs/JOURNEY_PROBE.md"

    [ "$status" -eq 0 ]
}

@test "static: journey probe passes shellcheck" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"

    run shellcheck "$SCRIPT"

    [ "$status" -eq 0 ]
}
