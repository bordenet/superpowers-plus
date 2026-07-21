#!/usr/bin/env bats
# Tests for tools/pre-push-loc-gate.sh
# Exit-code contract: 0=clean/warn, 1=block+oversize, 2=usage/git-error

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/pre-push-loc-gate.sh"
ZERO_SHA="0000000000000000000000000000000000000000"

setup() {
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"
    git remote add origin "$WORK"
}

teardown() {
    rm -rf "$WORK"
}

make_commit() {
    local lines="${1:-5}"
    local fname="file_${RANDOM}.txt"
    python3 -c "import sys; [sys.stdout.write('line %d\n' % i) for i in range($lines)]" > "$fname"
    git add "$fname"
    git commit -q -m "commit ${lines} lines"
}

@test "--help exits 0 and mentions MAX_LOC" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"MAX_LOC"* ]]
}

@test "invalid LOC_GATE_MODE exits 2" {
    make_commit
    LOC_GATE_MODE=bogus run bash "$SCRIPT" HEAD
    [ "$status" -eq 2 ]
    [[ "$output" == *"LOC_GATE_MODE"* ]]
}

@test "non-integer MAX_LOC exits 2" {
    make_commit
    MAX_LOC=abc run bash "$SCRIPT" HEAD
    [ "$status" -eq 2 ]
    [[ "$output" == *"MAX_LOC"* ]]
}

@test "warn mode: small commit exits 0" {
    make_commit 5
    LOC_GATE_MODE=warn MAX_LOC=500 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
}

@test "warn mode: large commit still exits 0 (advisory not gate)" {
    make_commit 600
    LOC_GATE_MODE=warn MAX_LOC=500 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
}

@test "block mode: small commit exits 0" {
    make_commit 5
    LOC_GATE_MODE=block MAX_LOC=500 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
}

@test "block mode: large commit exits 1" {
    make_commit 600
    LOC_GATE_MODE=block MAX_LOC=500 run bash "$SCRIPT" HEAD
    [ "$status" -eq 1 ]
}

@test "block mode: ALLOW_LARGE_DIFF=1 bypasses (exits 0, warns)" {
    make_commit 600
    LOC_GATE_MODE=block MAX_LOC=500 ALLOW_LARGE_DIFF=1 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]] || [[ "$output" == *"bypass"* ]] || [[ "$output" == *"BYPASS"* ]]
}

@test ".loc-gate-mode file drives block mode" {
    make_commit 600
    echo "block" > .loc-gate-mode
    MAX_LOC=500 run bash "$SCRIPT" HEAD
    [ "$status" -eq 1 ]
}

@test "branch deletion (zero local SHA) exits 0 via stdin" {
    make_commit
    local sha
    sha="$(git rev-parse HEAD)"
    run bash -c "printf 'refs/heads/main %s refs/heads/main %s\n' '$ZERO_SHA' '$sha' | LOC_GATE_MODE=block MAX_LOC=10 bash '$SCRIPT'"
    [ "$status" -eq 0 ]
}

@test "custom MAX_LOC threshold respected" {
    make_commit 50
    LOC_GATE_MODE=block MAX_LOC=20 run bash "$SCRIPT" HEAD
    [ "$status" -eq 1 ]
    LOC_GATE_MODE=block MAX_LOC=200 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
}

@test "block mode: pure deletion commit is never blocked (deletions are free)" {
    # Add 600 lines, then delete them all -- net diff is 600 deletions, 0 insertions.
    # The gate must pass regardless of how many lines were deleted.
    make_commit 600
    local fname
    fname=$(git show --name-only --format="" HEAD | head -1)
    git rm -q "$fname"
    git commit -q -m "delete 600 lines"
    LOC_GATE_MODE=block MAX_LOC=10 run bash "$SCRIPT" HEAD
    [ "$status" -eq 0 ]
}

@test "block mode: mixed add+delete -- insertions above threshold still blocks" {
    # Single commit: delete a big file and add a small one that exceeds MAX_LOC.
    # Gate must fire on the 20 insertions even though 600 lines were also deleted.
    make_commit 600
    local big_fname new_fname
    big_fname=$(git show --name-only --format="" HEAD | head -1)
    new_fname="small_${RANDOM}.txt"
    python3 -c "import sys; [sys.stdout.write('line %d\n' % i) for i in range(20)]" > "$new_fname"
    git rm -q "$big_fname"
    git add "$new_fname"
    git commit -q -m "mixed: 20 insertions + 600 deletions"
    LOC_GATE_MODE=block MAX_LOC=10 run bash "$SCRIPT" HEAD
    [ "$status" -eq 1 ]
}
