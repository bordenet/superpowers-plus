#!/usr/bin/env bats

# Behavioral tests for tools/post-commit hook.
# Covers: tree-mode sentinel promotion, HEAD-mode amend-only promotion,
# tree-mismatch refusal, and graceful no-op on missing/invalid sentinels.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK="$REPO_ROOT/tools/post-commit"

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

read_sentinel_sha() {
    cut -d'|' -f2 < .code-review-cleared
}

@test "post-commit: no-op when sentinel is absent" {
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [ ! -f .code-review-cleared ]
}

@test "post-commit: promotes tree:* sentinel when tree matches new HEAD" {
    echo new > new.txt
    git add new.txt
    tree=$(git write-tree)
    echo "v1|tree:${tree}|PASS|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    git commit -qm "add new"
    new_head=$(git rev-parse HEAD)
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "$new_head" ]]
}

@test "post-commit: refuses to promote tree:* sentinel when tree differs" {
    # Sentinel records a phony tree SHA. After commit, the real tree is
    # different — hook must leave the sentinel alone.
    echo new > new.txt
    git add new.txt
    git commit -qm "add new"
    bogus_tree="0000000000000000000000000000000000000000"
    echo "v1|tree:${bogus_tree}|PASS|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "tree:${bogus_tree}" ]]
}

@test "post-commit: promotes HEAD-mode sentinel on amend with no tree change" {
    # Pin sentinel to current HEAD, then amend the message only.
    head1=$(git rev-parse HEAD)
    echo "v1|${head1}|PASS|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    head2=$(git rev-parse HEAD)
    [[ "$head1" != "$head2" ]]
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "$head2" ]]
}

@test "post-commit: leaves HEAD-mode sentinel alone when tree changed" {
    head1=$(git rev-parse HEAD)
    echo "v1|${head1}|PASS|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    echo more > more.txt
    git add more.txt
    git commit -qm "add more"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "$head1" ]]   # unchanged
}

@test "post-commit: refuses to promote non-PASS verdict" {
    head1=$(git rev-parse HEAD)
    echo "v1|${head1}|REJECT|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "$head1" ]]
}

@test "post-commit: SP_SKIP_POST_COMMIT=1 is a no-op even with valid tree sentinel" {
    echo new > new.txt
    git add new.txt
    tree=$(git write-tree)
    echo "v1|tree:${tree}|PASS|2026-05-23T00:00:00Z|min-score=7.0" > .code-review-cleared
    git commit -qm "add new"
    SP_SKIP_POST_COMMIT=1 run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(read_sentinel_sha)
    [[ "$sentinel_sha" == "tree:${tree}" ]]
}
