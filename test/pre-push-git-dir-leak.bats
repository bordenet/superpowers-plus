#!/usr/bin/env bats
# Regression guard: Gate 1 of tools/pre-push (local fast test suite) shells
# out to `tools/test-all.sh --fast` -> bats, whose fixtures do their own
# `git -C <tmpdir> init/commit` assuming normal cwd-based repo discovery.
# Git sets GIT_DIR (and GIT_PREFIX) in the hook subprocess environment under
# a linked worktree; left set, it overrides `-C`/cwd discovery for ANY nested
# git invocation, silently redirecting a fixture's supposedly isolated
# operations onto the real pushing repo instead. Point GIT_DIR/GIT_WORK_TREE/
# GIT_INDEX_FILE at a decoy repo lacking tools/test-all.sh; a stub test-all.sh
# reporting its own `git rev-parse --show-toplevel` must resolve to the real
# repo, never the decoy -- proving the fix's unset took effect before Gate 1's
# own git commands ran.

setup() {
    REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORK="$(mktemp -d)"
    WORK="$(cd "$WORK" && pwd -P)"   # resolve symlinks (macOS /var vs /private/var)
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"

    mkdir -p tools
    cp "$REPO_ROOT_REAL/tools/pre-push" tools/pre-push
    chmod +x tools/pre-push
    # Gate 0 hard-requires this file to exist before Gate 1 even runs.
    printf '#!/usr/bin/env bash\nexit 0\n' > tools/public-repo-ip-check.sh
    chmod +x tools/public-repo-ip-check.sh

    echo "x" > a.txt
    git add a.txt tools/pre-push tools/public-repo-ip-check.sh
    git commit -q -m "base"
    HEAD_SHA="$(git rev-parse HEAD)"

    DECOY="$(mktemp -d)"
    DECOY="$(cd "$DECOY" && pwd -P)"
    git -C "$DECOY" init -q --initial-branch=main
    git -C "$DECOY" config user.email test@test
    git -C "$DECOY" config user.name test
    echo x > "$DECOY/marker.txt"
    git -C "$DECOY" add -A && git -C "$DECOY" commit -q -m decoy
}

teardown() {
    rm -rf "$WORK" "$DECOY"
}

@test "pre-push Gate 1: unsets GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE before running the local test suite" {
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
echo "GATE1_RESOLVED_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)"
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test

    # Gate 1 only runs for a content-bearing push (real git invocations always
    # provide at least one push-ref line); feed one real, non-deletion ref
    # rather than empty stdin so Gate 1 actually executes.
    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "GIT_DIR='$DECOY/.git' GIT_WORK_TREE='$DECOY' GIT_INDEX_FILE='$DECOY/.git/index' bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [[ "$output" == *"GATE1_RESOLVED_TOPLEVEL=$WORK"* ]]
    [[ "$output" != *"GATE1_RESOLVED_TOPLEVEL=$DECOY"* ]]
}

@test "pre-push Gate 1: skipped entirely for a push containing only branch deletions" {
    # A pure branch-deletion push (local SHA all-zero) has no content to test.
    # Gate 1 must not shell out to test-all.sh at all -- previously it ran
    # unconditionally before even reading which refs were being pushed, so
    # deleting a remote branch paid for the full local suite for nothing.
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
echo "GATE1_RAN"
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/gone 0000000000000000000000000000000000000000 refs/heads/gone %s\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped — push contains only branch deletions"* ]]
    [[ "$output" != *"GATE1_RAN"* ]]
}

@test "pre-push Gate 1: still runs when a mixed push includes a real ref alongside a deletion" {
    # One deletion ref plus one content ref in the same push must NOT skip
    # Gate 1 -- HAS_CONTENT_PUSH only needs a single non-zero local SHA.
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
echo "GATE1_RAN"
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test

    local push_input
    push_input="$(mktemp)"
    {
        printf 'refs/heads/gone 0000000000000000000000000000000000000000 refs/heads/gone %s\n' "$HEAD_SHA"
        printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$HEAD_SHA"
    } > "$push_input"

    run bash -c "bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [[ "$output" == *"GATE1_RAN"* ]]
    [[ "$output" != *"skipped — push contains only branch deletions"* ]]
}
