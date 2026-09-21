#!/usr/bin/env bats

# tools/lib/sentinel-scope.sh: a review sentinel covers CONTENT, not a commit.
#
# Before this, every gate rejected `sentinel_sha != pushed_sha`, so a
# message-only amend, a rebase, or an unrelated docs commit invalidated every
# review and forced a full re-run -- whose fixes minted a new SHA and
# invalidated it again. These tests pin both halves of the contract: identical
# in-scope content carries forward; ANY in-scope change (add, modify, delete,
# rename) does not; anything unprovable fails closed.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    WORK="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$WORK/tools" "$WORK/docs"
    cd "$WORK"
    git init -q
    git config user.email t@example.com
    git config user.name t
    git config commit.gpgsign false
    printf 'echo v1\n' > tools/a.sh
    printf '# doc v1\n' > docs/design.md
    git add -A
    git commit -qm base
    REVIEWED="$(git rev-parse HEAD)"
    # shellcheck source=tools/lib/sentinel-scope.sh
    source "$REPO_ROOT/tools/lib/sentinel-scope.sh"
}

@test "scope: identical commit is covered" {
    sentinel_scope_unchanged "$REVIEWED" "$REVIEWED" sentinel_scope_code_files
}

# The headline case: the amend that used to cost a full re-review.
@test "scope: message-only amend is covered" {
    git commit -q --amend -m "reworded"
    [ "$(git rev-parse HEAD)" != "$REVIEWED" ]
    sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
}

@test "scope: docs-only follow-up keeps code clearance" {
    printf '# doc v2\n' > docs/design.md
    git commit -qam docs
    sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
}

@test "scope: modified code file invalidates, and is named" {
    printf 'echo v2\n' > tools/a.sh
    git commit -qam code
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
    [ "$status" -ne 0 ]
    sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files || true
    [ "$SENTINEL_SCOPE_CHANGED" = "tools/a.sh" ]
}

@test "scope: added code file invalidates" {
    printf 'echo new\n' > tools/b.sh
    git add tools/b.sh
    git commit -qm add
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
    [ "$status" -ne 0 ]
}

@test "scope: deleted code file invalidates" {
    git rm -q tools/a.sh
    git commit -qm del
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
    [ "$status" -ne 0 ]
}

# A move out of the gate's scope must not hide the removal of reviewed code.
@test "scope: renaming a code file to a docs path invalidates" {
    git mv tools/a.sh docs/a.md
    git commit -qm mv
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
    [ "$status" -ne 0 ]
}

@test "scope: code change after a rebase-style rewrite still invalidates" {
    git commit -q --amend -m "reworded"
    printf 'echo sneaky\n' > tools/a.sh
    git commit -qam sneak
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" sentinel_scope_code_files
    [ "$status" -ne 0 ]
}

@test "scope: unknown reviewed commit fails closed" {
    run sentinel_scope_unchanged "0123456789abcdef0123456789abcdef01234567" "$REVIEWED" sentinel_scope_code_files
    [ "$status" -ne 0 ]
}

@test "scope: a failing classifier fails closed" {
    printf 'x\n' > tools/c.sh; git add tools/c.sh; git commit -qm c
    broken() { cat >/dev/null; return 3; }
    run sentinel_scope_unchanged "$REVIEWED" "$(git rev-parse HEAD)" broken
    [ "$status" -ne 0 ]
}

@test "scope: missing classifier argument fails closed" {
    run sentinel_scope_unchanged "$REVIEWED" "$REVIEWED"
    [ "$status" -ne 0 ]
}

@test "scope: branch-flow sentinel is NOT content-scoped" {
    run sentinel_scope_classifier_for .branch-flow-cleared
    [ "$status" -ne 0 ]
    [ "$(sentinel_scope_classifier_for .code-review-cleared)" = sentinel_scope_code_files ]
    [ "$(sentinel_scope_classifier_for /x/.phr-cleared)" = sentinel_scope_phr_eligible ]
    [ "$(sentinel_scope_classifier_for .llm-skill-review-cleared)" = sentinel_scope_llm_owned ]
}

# End-to-end through the real pre-push gate, not just the library.
@test "gate: code-review gate accepts a message-only amend of a reviewed commit" {
    cp -R "$REPO_ROOT/tools/lib" tools/
    cp "$REPO_ROOT/tools/pre-push-code-review-gate.sh" tools/
    git add -A; git commit -qm "add gate"
    local reviewed; reviewed="$(git rev-parse HEAD)"
    printf 'v1|%s|PASS|2026-01-01T00:00:00Z|min-score=9.0\n' "$reviewed" > .code-review-cleared
    git commit -q --amend -m "reworded after review"
    local pushed; pushed="$(git rev-parse HEAD)"
    run bash tools/pre-push-code-review-gate.sh origin <<< "refs/heads/x $pushed refs/heads/x 0000000000000000000000000000000000000000"
    [ "$status" -eq 0 ]
    [[ "$output" == *"carried forward"* ]]
}

@test "gate: code-review gate still blocks a code change after review" {
    cp -R "$REPO_ROOT/tools/lib" tools/
    cp "$REPO_ROOT/tools/pre-push-code-review-gate.sh" tools/
    git add -A; git commit -qm "add gate"
    printf 'v1|%s|PASS|2026-01-01T00:00:00Z|min-score=9.0\n' "$(git rev-parse HEAD)" > .code-review-cleared
    printf 'echo changed\n' > tools/a.sh
    git commit -qam "change code"
    run bash tools/pre-push-code-review-gate.sh origin <<< "refs/heads/x $(git rev-parse HEAD) refs/heads/x 0000000000000000000000000000000000000000"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tools/a.sh"* ]]
}
