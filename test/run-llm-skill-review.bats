#!/usr/bin/env bats
# Tests for tools/run-llm-skill-review.sh (ADR-003 v2 sentinel).

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT_REAL/tools/run-llm-skill-review.sh"
    VERIFIER="$REPO_ROOT_REAL/tools/verify-cr-battery-evidence.js"
    GATE="$REPO_ROOT_REAL/tools/lib/llm-skill-review-envelope-gate.js"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > a.txt
    git add a.txt
    git commit -q -m init
    mkdir -p tools/lib
    cp "$SCRIPT" ./tools/run-llm-skill-review.sh
    chmod +x ./tools/run-llm-skill-review.sh
    cp "$VERIFIER" ./tools/verify-cr-battery-evidence.js
    cp "$GATE" ./tools/lib/llm-skill-review-envelope-gate.js
}

teardown() {
    rm -rf "$WORK"
}

_write_envelope() {
    SHA="$(git rev-parse HEAD)"
    mkdir -p .cr-battery-runs
    printf '%s' "$1" > ".cr-battery-runs/${SHA}-llm-skill-review.json"
}

_clean_dim() {
    printf '{"claim":"a.txt exists","evidence":{"command":"test -f a.txt","expectation":{"type":"exit_code","value":0},"verifiable":true}}'
}

@test "args: REJECT verdict -> exit 1" {
    run ./tools/run-llm-skill-review.sh --verdict REJECT --min-score 8.0
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid verdict"* ]]
}

@test "args: PASS_WITH_RISKS is accepted as a clearing verdict" {
    _write_envelope "{\"findings\":[],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS_WITH_RISKS --min-score 7.5
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
    [[ "$(cat .llm-skill-review-cleared)" == v2*PASS_WITH_RISKS* ]]
}

@test "args: --no-envelope with PASS_WITH_RISKS -> exit 1" {
    run ./tools/run-llm-skill-review.sh --verdict PASS_WITH_RISKS --min-score 7.5 --no-envelope
    [ "$status" -eq 1 ]
    [[ "$output" == *"disallowed"* ]]
}

@test "envelope: missing envelope file -> exit 1, sentinel NOT written" {
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"Evidence envelope not found"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: empty clean_dimensions -> refuse (non-vacuous)" {
    _write_envelope '{"findings":[],"clean_dimensions":[]}'
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"non-vacuous"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: verified clean_dimension -> sentinel v2 written" {
    _write_envelope "{\"findings\":[],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
    line=$(cat .llm-skill-review-cleared)
    [[ "$line" == v2* ]]
    [[ "$line" == *mean=8.6* ]]
    [[ "$line" == *unresolved_s0_s1=0* ]]
    [[ "$line" == *evidence_replay=ok* ]]
}

@test "envelope: finding missing severity -> refuse" {
    _write_envelope "{\"findings\":[{\"claim\":\"x\",\"evidence\":{\"verifiable\":false,\"rationale\":\"j\"}}],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"severity"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: open S0 without waiver -> refuse" {
    _write_envelope "{\"findings\":[{\"severity\":\"S0\",\"claim\":\"leak\",\"evidence\":{\"verifiable\":false,\"rationale\":\"j\"}}],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"unresolved S0/S1"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: S0 waiver without --allow-s0-waiver -> refuse" {
    _write_envelope "{\"findings\":[{\"severity\":\"S0\",\"claim\":\"leak\",\"waiver\":{\"by\":\"human\",\"ref\":\"https://example/pr#1\",\"rationale\":\"accepted\"},\"evidence\":{\"verifiable\":false,\"rationale\":\"j\"}}],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"--allow-s0-waiver"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: S0 waiver with --allow-s0-waiver -> sentinel written" {
    _write_envelope "{\"findings\":[{\"severity\":\"S0\",\"claim\":\"leak\",\"waiver\":{\"by\":\"human\",\"ref\":\"https://example/pr#1\",\"rationale\":\"accepted\"},\"evidence\":{\"verifiable\":false,\"rationale\":\"j\"}}],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6 --allow-s0-waiver
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
}

@test "envelope: falsified claim -> exit 1, sentinel NOT written" {
    _write_envelope "{\"findings\":[{\"severity\":\"S2\",\"claim\":\"a.txt does not exist\",\"evidence\":{\"command\":\"test -f a.txt\",\"expectation\":{\"type\":\"exit_code\",\"value\":1},\"verifiable\":true}}],\"clean_dimensions\":[$(_clean_dim)]}"
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
    [ "$status" -eq 1 ]
    [[ "$output" == *"FALSIFIED"* ]]
    [ ! -f .llm-skill-review-cleared ]
}

@test "envelope: --no-envelope with PASS writes evidence_replay=bypassed" {
    run ./tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6 --no-envelope
    [ "$status" -eq 0 ]
    [ -f .llm-skill-review-cleared ]
    [[ "$(cat .llm-skill-review-cleared)" == *evidence_replay=bypassed* ]]
    [[ "$output" == *"bypass active"* ]]
}
