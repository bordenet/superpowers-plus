#!/usr/bin/env bats
# Tests for tools/run-llm-skill-review.sh (writes .llm-skill-review-cleared
# sentinel, ONLY after mechanically replaying every evidence.command in the
# envelope via tools/verify-cr-battery-evidence.js -- parity with
# run-battery.sh's evidence-replay gate, applied to llm-skill-review's own
# Evidence Schema findings).

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT_REAL/tools/run-llm-skill-review.sh"
    VERIFIER="$REPO_ROOT_REAL/tools/verify-cr-battery-evidence.js"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > a.txt
    git add a.txt
    git commit -q -m init
    # Both scripts must live in tools/ together, matching the real repo
    # layout -- run-llm-skill-review.sh resolves the verifier relative to its
    # OWN directory (SCRIPT_DIR), so copying it to the worktree root while the
    # verifier sits in tools/ would silently mismatch the path.
    mkdir -p tools
    cp "$SCRIPT" ./tools/run-llm-skill-review.sh
    chmod +x ./tools/run-llm-skill-review.sh
    cp "$VERIFIER" ./tools/verify-cr-battery-evidence.js
}

teardown() {
    rm -rf "$WORK"
}

_write_envelope() {
    # $1: envelope JSON content
    SHA="$(git rev-parse HEAD)"
    mkdir -p .cr-battery-runs
    printf '%s' "$1" > ".cr-battery-runs/${SHA}-llm-skill-review.json"
}

# --- Argument validation (only llm-skill-review-specific verdict vocabulary;
# generic arg/sentinel/boundary tests are covered by run-phr.bats which shares
# the same CLI contract and sentinel schema) ---

@test "args: invalid verdict (PASS WITH RISKS) -> exit 1 (only PASS clears)" {
    run ./tools/run-llm-skill-review.sh --verdict "PASS WITH RISKS" --min-score 8.0
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid verdict"* ]]
}

@test "args: invalid verdict (MAJOR REVISIONS REQUIRED) -> exit 1" {
    run ./tools/run-llm-skill-review.sh --verdict "MAJOR REVISIONS REQUIRED" --min-score 6.0
    [ "$status" -eq 1 ]
}


# --- Envelope requirement (the actual parity fix) ---

@test "envelope: missing envelope file -> exit 1, sentinel NOT written" {
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 1 ]
    [[ "$output" == *"Evidence envelope not found"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: invalid JSON -> exit 1, sentinel NOT written" {
    SHA="$(git rev-parse HEAD)"
    mkdir -p .cr-battery-runs
    printf 'not json{{{' > ".cr-battery-runs/${SHA}-llm-skill-review.json"
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not installed on this machine"
    fi
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 1 ]
    [[ "$output" == *"not valid JSON"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: verified claim -> sentinel written, exit 0" {
    _write_envelope '{"findings":[],"clean_dimensions":[{"claim":"a.txt exists","evidence":{"command":"test -f a.txt","expectation":{"type":"exit_code","value":0},"verifiable":true}}]}'
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
    [[ "$output" == *"LLM-SKILL-REVIEW PASSED"* ]]
}

@test "envelope: falsified claim -> exit 1, sentinel NOT written" {
    _write_envelope '{"findings":[{"claim":"a.txt does not exist","evidence":{"command":"test -f a.txt","expectation":{"type":"exit_code","value":1},"verifiable":true}}],"clean_dimensions":[]}'
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 1 ]
    [[ "$output" == *"FALSIFIED"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: empty findings + clean_dimensions -> sentinel written (nothing to falsify)" {
    _write_envelope '{"findings":[],"clean_dimensions":[]}'
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
}

@test "envelope: --no-envelope bypass skips the check entirely, prints warning" {
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4 --no-envelope
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
    [[ "$output" == *"bypass active"* ]]
}

@test "envelope: verifiable:false claim is not falsified, sentinel written" {
    _write_envelope '{"findings":[{"claim":"a race condition might occur","evidence":{"verifiable":false,"rationale":"not deterministically replayable"}}],"clean_dimensions":[]}'
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
}
