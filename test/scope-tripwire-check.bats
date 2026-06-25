#!/usr/bin/env bats
# Tests for tools/scope-tripwire-check.sh
# Focuses on error-handling, skip path, mode dispatch, and ref validation.
# All tests that would require a Linear API call are avoided via SKIP or no-ref branches.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/scope-tripwire-check.sh"

setup() {
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    echo "x" > a.txt
    git add a.txt
    git commit -q -m "init"
    # Non-superpowers-plus origin so auto-detect doesn't set block mode
    git remote add origin https://example.com/other-repo.git
}

teardown() {
    rm -rf "$WORK"
}

@test "--help exits 0" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
}

@test "invalid LOC_PER_POINT exits 2" {
    LOC_PER_POINT=abc run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"LOC_PER_POINT"* ]]
}

@test "invalid SCOPE_TRIPWIRE_RATIO exits 2" {
    SCOPE_TRIPWIRE_RATIO=abc run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SCOPE_TRIPWIRE_RATIO"* ]]
}

@test "zero SCOPE_TRIPWIRE_RATIO exits 2" {
    SCOPE_TRIPWIRE_RATIO=0 run bash "$SCRIPT"
    [ "$status" -eq 2 ]
}

@test "invalid SCOPE_TRIPWIRE_MODE exits 2" {
    SCOPE_TRIPWIRE_MODE=bogus run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SCOPE_TRIPWIRE_MODE"* ]]
}

@test "not in a git repo exits 2" {
    NOREPO="$BATS_TEST_TMPDIR/norepo"
    mkdir -p "$NOREPO"
    cd "$NOREPO"
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not inside a git repo"* ]]
}

@test "SCOPE_TRIPWIRE_SKIP=1 exits 0 (bypasses everything)" {
    SCOPE_TRIPWIRE_SKIP=1 run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

@test "branch with no Linear ref exits 0 (advisory skipped)" {
    git checkout -q -b feat/no-ticket-here
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no Linear ref"* ]] || [[ "$output" == *"advisory skipped"* ]]
}

@test "detached HEAD without SCOPE_TRIPWIRE_REF exits 0" {
    git checkout -q "$(git rev-parse HEAD)"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "invalid SCOPE_TRIPWIRE_REF format exits 2" {
    SCOPE_TRIPWIRE_REF="not-valid-format" run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"SCOPE_TRIPWIRE_REF"* ]]
}

@test "valid ref format but no LINEAR_API_KEY exits 0 (defers gracefully)" {
    git checkout -q -b "feat/AI-123-some-feature"
    LINEAR_API_KEY="" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"LINEAR_API_KEY"* ]] || [[ "$output" == *"advisory skipped"* ]]
}

@test "superpowers-plus origin URL auto-detects block mode" {
    git remote set-url origin https://github.com/bordenet/superpowers-plus.git
    # No Linear ref in branch name -> exits 0 (advisory skipped) but mode should be 'block'
    # bats merges stderr into $output by default; auto-detect message emits to stderr
    git checkout -q -b feat/no-ticket
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    # Require the specific auto-detect message; "no Linear ref" alone would pass even if
    # auto-detect never fired (vacuous fallback)
    [[ "$output" == *"mode=block"* ]]
}
