#!/usr/bin/env bats
# Tests for the URL-based auto-detect block in tools/scope-tripwire-check.sh.
# Covers the dogfood-repo detection logic: when origin matches "superpowers-plus"
# as a path segment (not a prefix), SCOPE_TRIPWIRE_MODE is auto-set to "block".

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q
    git config user.email "test@test"
    git config user.name "Test"
    touch initial.txt
    git add .
    git commit -q -m "initial"
}

teardown() {
    rm -rf "$WORK"
}

# Run with SCOPE_TRIPWIRE_SKIP=1 so the script exits after mode dispatch —
# no API call, no diff scan. Merges stderr into stdout so bats $output captures
# the auto-detect diagnostic (which goes to stderr).
run_tripwire_skip() {
    run bash -c "cd '$WORK' && SCOPE_TRIPWIRE_SKIP=1 '$REPO_ROOT_REAL/tools/scope-tripwire-check.sh' <<< '' 2>&1"
}

@test "auto-detect: SSH superpowers-plus URL triggers block mode diagnostic" {
    git remote add origin git@github.com:bordenet/superpowers-plus.git
    run_tripwire_skip
    [ "$status" -eq 0 ]
    [[ "$output" == *"auto-detected superpowers-plus dogfood repo; mode=block"* ]]
}

@test "auto-detect: HTTPS superpowers-plus URL with trailing slash triggers block mode" {
    git remote add origin https://github.com/bordenet/superpowers-plus/
    run_tripwire_skip
    [ "$status" -eq 0 ]
    [[ "$output" == *"auto-detected superpowers-plus dogfood repo; mode=block"* ]]
}

@test "auto-detect: HTTPS superpowers-plus.git URL triggers block mode" {
    git remote add origin https://github.com/bordenet/superpowers-plus.git
    run_tripwire_skip
    [ "$status" -eq 0 ]
    [[ "$output" == *"auto-detected superpowers-plus dogfood repo; mode=block"* ]]
}

@test "auto-detect: superpowers-plus-fork URL does NOT trigger auto-detect (anchored regex)" {
    git remote add origin git@github.com:bordenet/superpowers-plus-fork.git
    run_tripwire_skip
    [ "$status" -eq 0 ]
    [[ "$output" != *"auto-detected superpowers-plus"* ]]
}

@test "auto-detect: no origin remote → no auto-detect, no error" {
    run_tripwire_skip
    [ "$status" -eq 0 ]
    [[ "$output" != *"auto-detected superpowers-plus"* ]]
}

@test "auto-detect: SCOPE_TRIPWIRE_MODE env var takes precedence over URL (auto-detect skipped)" {
    git remote add origin git@github.com:bordenet/superpowers-plus.git
    run bash -c "cd '$WORK' && SCOPE_TRIPWIRE_MODE=warn SCOPE_TRIPWIRE_SKIP=1 '$REPO_ROOT_REAL/tools/scope-tripwire-check.sh' <<< '' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"auto-detected superpowers-plus"* ]]
}
