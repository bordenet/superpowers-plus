#!/usr/bin/env bats
# Tests for the remote_name parameter threading in tools/pre-push-loc-gate.sh.
# Covers the multi-remote fix: enumerate_commits now scopes --not --remotes=<name>
# to the target remote, preventing commits on *other* remotes from being excluded.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
ZERO_SHA="0000000000000000000000000000000000000000"

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

@test "multi-remote fix: commit on remote1 is counted when pushing to remote2 in block mode" {
    # Regression test for the multi-remote under-count bug.
    # Before fix: --not --remotes excluded commits on ANY remote (including remote1),
    # so pushing to remote2 would silently skip LOC checks for commits already on remote1.
    # After fix: --not --remotes=remote2 excludes only remote2 refs; commits on remote1
    # are correctly detected as new to remote2 and LOC-checked.
    local REMOTE1 REMOTE2
    REMOTE1="$(mktemp -d)" && REMOTE2="$(mktemp -d)"
    git init --bare -q "$REMOTE1"
    git init --bare -q "$REMOTE2"
    git remote add remote1 "$REMOTE1"
    git remote add remote2 "$REMOTE2"
    # Create a commit large enough to fail MAX_LOC=1
    printf 'line\n%.0s' {1..50} > big.txt
    git add big.txt && git commit -q -m "big commit"
    local LOCAL_SHA
    LOCAL_SHA=$(git rev-parse HEAD)
    # Push ONLY to remote1 — remote2 has never seen this commit
    git push -q remote1 HEAD:main
    # Simulate a push to remote2 (new branch: remote_sha is ZERO_SHA).
    # With fix: remote_name=remote2 → commit is found (not on remote2) → LOC check fires → exit 1
    run bash -c "echo 'refs/heads/main $LOCAL_SHA refs/heads/main $ZERO_SHA' | MAX_LOC=1 LOC_GATE_MODE=block '$REPO_ROOT_REAL/tools/pre-push-loc-gate.sh' remote2 'file://$REMOTE2'"
    [ "$status" -eq 1 ]
}

@test "backward compat: no remote_name arg uses --not --remotes (warn mode exits 0)" {
    # When invoked without a remote name argument, the script defaults to
    # --not --remotes (original behavior). Verify it exits 0 in warn mode
    # even if LOC exceeds MAX_LOC (warn mode is advisory, never blocks).
    printf 'line\n%.0s' {1..50} > big.txt
    git add big.txt && git commit -q -m "big commit"
    local LOCAL_SHA
    LOCAL_SHA=$(git rev-parse HEAD)
    run bash -c "echo 'refs/heads/main $LOCAL_SHA refs/heads/main $ZERO_SHA' | MAX_LOC=1 LOC_GATE_MODE=warn '$REPO_ROOT_REAL/tools/pre-push-loc-gate.sh'"
    [ "$status" -eq 0 ]
}

@test "nonexistent remote name does not cause a script error (exit 0 for small commit)" {
    # --not --remotes=nonexistent should produce an empty exclusion set (not an error).
    # The commit still gets LOC-checked but is small enough to pass.
    printf 'line\n%.0s' {1..5} > small.txt
    git add small.txt && git commit -q -m "small commit"
    local LOCAL_SHA
    LOCAL_SHA=$(git rev-parse HEAD)
    run bash -c "echo 'refs/heads/main $LOCAL_SHA refs/heads/main $ZERO_SHA' | MAX_LOC=500 LOC_GATE_MODE=block '$REPO_ROOT_REAL/tools/pre-push-loc-gate.sh' nonexistent-remote 'file:///dev/null'"
    [ "$status" -eq 0 ]
}
