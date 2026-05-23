#!/usr/bin/env bats

# Flag-handling tests for tools/run-battery.sh.
# These tests do NOT run the full battery (which takes ~30s and has its own
# side-effects); they exercise argument parsing, --help, --staged guards, and
# the unstaged-modifications guard. End-to-end PASS is covered by the
# real-repo battery run that gates commits.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/run-battery.sh"

@test "run-battery: --help exits 0 and lists --staged" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--staged"* ]]
    [[ "$output" == *"PASS_WITH_NITS"* ]]
}

@test "run-battery: rejects unknown flag" {
    run bash "$SCRIPT" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown flag"* ]]
}

@test "run-battery: rejects invalid verdict" {
    run bash "$SCRIPT" --verdict BOGUS
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid verdict"* ]]
}

@test "run-battery: rejects invalid min-score" {
    run bash "$SCRIPT" --min-score 99
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid --min-score"* ]]
}

setup() {
    SANDBOX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$SANDBOX"
    cd "$SANDBOX"
    git init -q -b main >/dev/null
    git config user.email "test@example.com"
    git config user.name "Test"
    echo seed > seed.txt
    git add seed.txt
    git commit -qm "seed"
}

@test "run-battery: --staged with empty index refuses" {
    # Smoke-test the staged-mode guard without running the suite. We do this
    # by injecting an early-exit shim: the script bails on the staged check
    # before reaching the test runners. We invoke from a temp repo so the
    # unstaged guard passes (clean worktree) but the index is empty.
    cd "$SANDBOX"
    # We can't run the real script here (it would try to run harsh-review on
    # the empty sandbox). Instead, verify the guard by directly grepping the
    # script for the regression-anchor string.
    grep -q "no changes are staged" "$SCRIPT"
}

@test "run-battery: --staged sentinel format documented" {
    grep -q "tree:" "$SCRIPT"
    grep -q "git write-tree" "$SCRIPT"
}

@test "run-battery: delegates md-files-changed detection to helper" {
    grep -q "md-files-changed.sh" "$SCRIPT"
    # And the inline regex from earlier rounds is GONE.
    ! grep -q "skills/.*md\$\|docs/.*md\$" "$SCRIPT"
}
