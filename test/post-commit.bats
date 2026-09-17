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

@test "post-commit: promotes .phr-cleared on amend with no tree change" {
    head1=$(git rev-parse HEAD)
    echo "v1|${head1}|PASS|2026-05-23T00:00:00Z|min-score=9.5" > .phr-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    head2=$(git rev-parse HEAD)
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(cut -d'|' -f2 < .phr-cleared)
    [[ "$sentinel_sha" == "$head2" ]]
    grep -q "min-score=9.5" .phr-cleared   # trailing field preserved
}

@test "post-commit: leaves .phr-cleared alone on non-PASS verdict" {
    head1=$(git rev-parse HEAD)
    echo "v1|${head1}|PASS_WITH_FIXES|2026-05-23T00:00:00Z|min-score=7.0" > .phr-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(cut -d'|' -f2 < .phr-cleared)
    [[ "$sentinel_sha" == "$head1" ]]
}

@test "post-commit: promotes .llm-skill-review-cleared (v2, 7 fields) preserving trailing fields" {
    head1=$(git rev-parse HEAD)
    echo "v2|${head1}|PASS_WITH_RISKS|2026-05-23T00:00:00Z|mean=8.5|unresolved_s0_s1=0|evidence_replay=ok" > .llm-skill-review-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    head2=$(git rev-parse HEAD)
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    line=$(cat .llm-skill-review-cleared)
    [[ "$line" == "v2|${head2}|PASS_WITH_RISKS|2026-05-23T00:00:00Z|mean=8.5|unresolved_s0_s1=0|evidence_replay=ok" ]]
}

@test "post-commit: leaves .llm-skill-review-cleared alone on non-passing verdict" {
    head1=$(git rev-parse HEAD)
    echo "v2|${head1}|REJECT|2026-05-23T00:00:00Z|mean=4.0|unresolved_s0_s1=2|evidence_replay=ok" > .llm-skill-review-cleared
    git commit -q --amend --no-edit -m "seed (amended)" >/dev/null
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    sentinel_sha=$(cut -d'|' -f2 < .llm-skill-review-cleared)
    [[ "$sentinel_sha" == "$head1" ]]
}

@test "post-commit: promotes all three sentinels across a tree-identical promotion merge" {
    # Simulates dev -> staging: a merge commit whose tree matches the branch
    # it merged in ("trees match; SHAs differ only by the promotion merge
    # commit"). staging has made no independent commits, so the merge is a
    # clean fast-forward-equivalent and the merge commit's tree equals dev's.
    git branch dev
    git checkout -q -b staging
    git checkout -q dev
    echo feature > feature.txt
    git add feature.txt
    git commit -qm "feature work"
    dev_head=$(git rev-parse HEAD)
    echo "v1|${dev_head}|PASS|2026-05-23T00:00:00Z|min-score=8.0" > .code-review-cleared
    echo "v1|${dev_head}|PASS|2026-05-23T00:00:00Z|min-score=9.5" > .phr-cleared
    echo "v2|${dev_head}|PASS|2026-05-23T00:00:00Z|mean=9.0|unresolved_s0_s1=0|evidence_replay=ok" > .llm-skill-review-cleared

    git checkout -q staging
    git merge -q --no-ff dev -m "promote dev to staging"
    merge_head=$(git rev-parse HEAD)
    [[ "$merge_head" != "$dev_head" ]]

    run bash "$HOOK"
    [ "$status" -eq 0 ]
    [[ "$(cut -d'|' -f2 < .code-review-cleared)" == "$merge_head" ]]
    [[ "$(cut -d'|' -f2 < .phr-cleared)" == "$merge_head" ]]
    [[ "$(cut -d'|' -f2 < .llm-skill-review-cleared)" == "$merge_head" ]]
}
