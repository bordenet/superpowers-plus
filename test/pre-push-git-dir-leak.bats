#!/usr/bin/env bats
# Regression guard: the pre-push test gate (tools/pre-push-test-gate.sh)
# shells out to `tools/test-all.sh --fast` -> bats, whose fixtures do their
# own `git -C <tmpdir> init/commit` assuming normal cwd-based repo discovery.
# Git sets GIT_DIR (and GIT_PREFIX) in the hook subprocess environment under
# a linked worktree; left set, it overrides `-C`/cwd discovery for ANY nested
# git invocation, silently redirecting a fixture's supposedly isolated
# operations onto the real pushing repo instead. Point GIT_DIR/GIT_WORK_TREE/
# GIT_INDEX_FILE at a decoy repo lacking tools/test-all.sh; a stub test-all.sh
# reporting its own `git rev-parse --show-toplevel` must resolve to the real
# repo, never the decoy -- proving the unset took effect before the test
# gate's own git commands ran. Both the composer (tools/pre-push) and the
# test gate re-unset independently (defense in depth), so this file covers
# both the composer's forwarding path and the gate's own standalone unset.

setup() {
    REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORK="$(mktemp -d)"
    WORK="$(cd "$WORK" && pwd -P)"   # resolve symlinks (macOS /var vs /private/var)
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"

    mkdir -p tools/lib
    # Code-review-gate and ip-scan-gate are hard-required by the composer
    # (no "optional tooling" exemption -- their absence blocks the push), so
    # this fixture needs all 5 gate scripts + the shared lib present, not
    # just the two this file is specifically testing.
    for gate in pre-push-test-gate.sh pre-push-code-review-gate.sh \
                pre-push-ip-scan-gate.sh pre-push-branch-flow-gate.sh \
                pre-push-phr-gate.sh pre-push-llm-skill-review-gate.sh; do
        cp "$REPO_ROOT_REAL/tools/$gate" "tools/$gate"
        chmod +x "tools/$gate"
    done
    cp "$REPO_ROOT_REAL/tools/lib/pre-push-diff-range.sh" tools/lib/pre-push-diff-range.sh
    cp "$REPO_ROOT_REAL/tools/pre-push" tools/pre-push
    chmod +x tools/pre-push
    # Gate 0 hard-requires this file to exist before the composer's gates run.
    printf '#!/usr/bin/env bash\nexit 0\n' > tools/public-repo-ip-check.sh
    chmod +x tools/public-repo-ip-check.sh

    echo "x" > a.txt
    git add -A
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

@test "pre-push-test-gate.sh: its OWN GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE unset holds even when invoked directly, bypassing the composer entirely" {
    # Regression guard for the gate-split refactor: the test gate now unsets
    # these vars itself (not just relying on the composer having done so),
    # since it can be invoked directly -- exactly as this test does. If the
    # gate's own unset didn't hold, its REPO_ROOT resolution would resolve to
    # the decoy, and its own git commands would silently operate on the wrong
    # repo.
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
echo "GATE_RESOLVED_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)"
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "GIT_DIR='$DECOY/.git' GIT_WORK_TREE='$DECOY' GIT_INDEX_FILE='$DECOY/.git/index' bash tools/pre-push-test-gate.sh < '$push_input'"
    rm -f "$push_input"
    [[ "$output" == *"GATE_RESOLVED_TOPLEVEL=$WORK"* ]]
    [[ "$output" != *"GATE_RESOLVED_TOPLEVEL=$DECOY"* ]]
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

@test "pre-push composer: fails closed (does not silently pass) when pre-push-code-review-gate.sh is missing" {
    # Unlike the test/branch-flow/PHR gates, code-review and IP-scan have no
    # "optional tooling not installed in this repo" exemption -- the original
    # monolith enforced both unconditionally, baked into the one file that
    # was always installed. A missing gate script (bad merge, partial
    # checkout, accidental rm) must block the push, not be silently skipped.
    rm -f tools/pre-push-code-review-gate.sh
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tools/pre-push-code-review-gate.sh is missing"* ]]
}

@test "pre-push composer: fails closed (does not silently pass) when pre-push-ip-scan-gate.sh is missing" {
    rm -f tools/pre-push-ip-scan-gate.sh
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=7.0" > .code-review-cleared

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tools/pre-push-ip-scan-gate.sh is missing"* ]]
}

@test "pre-push composer: fails closed (does not silently pass) when pre-push-llm-skill-review-gate.sh is missing" {
    # Gate 6 is now the SOLE reviewer for skills/*.md (Gates 2 and 5 both
    # statically exempt that file class regardless of whether this script
    # exists), so its absence must block the push, matching Gates 2/3's
    # existing hard-fail-on-missing behavior -- not the soft-skip pattern
    # used for the optional test/branch-flow gates.
    rm -f tools/pre-push-llm-skill-review-gate.sh
    cat > tools/test-all.sh <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x tools/test-all.sh
    mkdir -p test
    echo "v1|${HEAD_SHA}|PASS|2026-05-25T00:00:00Z|min-score=7.0" > .code-review-cleared

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    [ "$status" -ne 0 ]
    [[ "$output" == *"tools/pre-push-llm-skill-review-gate.sh is missing"* ]]
}

@test "pre-push-ip-scan-gate.sh: fails closed when public-repo-ip-check.sh is missing, even for a private-to-private remote push" {
    # The IP-audit-script existence check must be unconditional (checked
    # before the IS_PUBLIC_REMOTE skip), matching the pre-split monolith --
    # a private-remote push with a non-public origin and no audit script
    # must still block, not silently pass just because the scan itself
    # would have been skipped for this remote.
    rm -f tools/public-repo-ip-check.sh
    git config remote.origin.url "https://internal.example.com/not-a-known-host/repo.git" 2>/dev/null \
        || git remote add origin "https://internal.example.com/not-a-known-host/repo.git"

    local push_input
    push_input="$(mktemp)"
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$HEAD_SHA" > "$push_input"

    run bash -c "bash tools/pre-push-ip-scan-gate.sh origin < '$push_input'"
    rm -f "$push_input"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing tools/public-repo-ip-check.sh"* ]]
}
