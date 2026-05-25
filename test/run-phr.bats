#!/usr/bin/env bats
# Tests for tools/run-phr.sh (writes .phr-cleared sentinel)
# and the Gate 4 consumer in tools/pre-push.

setup() {
    REPO_ROOT_REAL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT_REAL/tools/run-phr.sh"
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > a.txt
    git add a.txt
    git commit -q -m init
    cp "$SCRIPT" ./run-phr.sh
    chmod +x ./run-phr.sh
}

teardown() {
    rm -rf "$WORK"
}

# --- Argument validation ---

@test "args: missing --verdict and --min-score -> exit 1" {
    run ./run-phr.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"both required"* ]]
}

@test "args: missing --min-score -> exit 1" {
    run ./run-phr.sh --verdict PASS
    [ "$status" -eq 1 ]
}

@test "args: missing --verdict -> exit 1" {
    run ./run-phr.sh --min-score 9.5
    [ "$status" -eq 1 ]
}

@test "args: invalid verdict (REJECT) -> exit 1" {
    run ./run-phr.sh --verdict REJECT --min-score 9.5
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid verdict"* ]]
}

@test "args: invalid verdict (FAIL) -> exit 1" {
    run ./run-phr.sh --verdict FAIL --min-score 9.5
    [ "$status" -eq 1 ]
}

@test "args: PASS_WITH_NITS no longer accepted (verdict vocabulary aligned to skill)" {
    run ./run-phr.sh --verdict PASS_WITH_NITS --min-score 9.5
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid verdict"* ]]
}

@test "args: PASS_WITH_FIXES not accepted (means another round required)" {
    run ./run-phr.sh --verdict PASS_WITH_FIXES --min-score 7.5
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid verdict"* ]]
}

@test "args: invalid min-score (>10) -> exit 1" {
    run ./run-phr.sh --verdict PASS --min-score 11
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid"* ]]
}

@test "args: invalid min-score (<1) -> exit 1" {
    run ./run-phr.sh --verdict PASS --min-score 0.5
    [ "$status" -eq 1 ]
}

@test "args: non-numeric min-score -> exit 1" {
    run ./run-phr.sh --verdict PASS --min-score foo
    [ "$status" -eq 1 ]
}

@test "args: unknown flag -> exit 1" {
    run ./run-phr.sh --bogus value
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown flag"* ]]
}

# --- Sentinel write ---

@test "write: PASS verdict + valid min-score -> sentinel written, exit 0" {
    run ./run-phr.sh --verdict PASS --min-score 9.5
    [ "$status" -eq 0 ]
    [ -f .phr-cleared ]
    [[ "$output" == *"PHR PASSED"* ]]
}

@test "write: rejects when worktree has unstaged modifications" {
    # Modify an already-tracked file; git diff --quiet fails on this.
    echo "modified" >> a.txt
    run ./run-phr.sh --verdict PASS --min-score 9.5
    [ "$status" -eq 1 ]
    [[ "$output" == *"unstaged modifications"* ]]
    [ ! -f .phr-cleared ]
}

@test "write: sentinel format is exactly 5 pipe-separated fields" {
    ./run-phr.sh --verdict PASS --min-score 9.5 >/dev/null
    fields=$(awk -F'|' '{print NF}' < .phr-cleared)
    [ "$fields" -eq 5 ]
}

@test "write: sentinel v1 prefix" {
    ./run-phr.sh --verdict PASS --min-score 9.5 >/dev/null
    grep -q "^v1|" .phr-cleared
}

@test "write: sentinel records current HEAD SHA" {
    expected_sha=$(git rev-parse HEAD)
    ./run-phr.sh --verdict PASS --min-score 9.5 >/dev/null
    grep -q "v1|${expected_sha}|" .phr-cleared
}

@test "write: sentinel records min-score field" {
    ./run-phr.sh --verdict PASS --min-score 9.42 >/dev/null
    grep -q "min-score=9.42$" .phr-cleared
}

@test "args: --staged flag removed (was a documented foot-gun)" {
    run ./run-phr.sh --verdict PASS --min-score 9.5 --staged
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown flag"* ]]
}

@test "write: sentinel is 0644 mode" {
    ./run-phr.sh --verdict PASS --min-score 9.5 >/dev/null
    perms=$(stat -f "%Lp" .phr-cleared 2>/dev/null || stat -c "%a" .phr-cleared 2>/dev/null)
    [ "$perms" = "644" ]
}

# --- Equals-form flags ---

@test "args: --verdict=PASS works" {
    run ./run-phr.sh --verdict=PASS --min-score 9.5
    [ "$status" -eq 0 ]
}

@test "args: --min-score=9.5 works" {
    run ./run-phr.sh --verdict PASS --min-score=9.5
    [ "$status" -eq 0 ]
}

# --- Boundary scores ---

@test "args: min-score 1.0 (lower bound) -> accepted" {
    run ./run-phr.sh --verdict PASS --min-score 1.0
    [ "$status" -eq 0 ]
}

@test "args: min-score 10.0 (upper bound) -> accepted" {
    run ./run-phr.sh --verdict PASS --min-score 10.0
    [ "$status" -eq 0 ]
}

@test "args: --help exits 0" {
    run ./run-phr.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
