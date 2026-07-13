#!/usr/bin/env bats
# Regression guard for test/setup_suite.bash (symlinked into tests/ too --
# see tests/setup_suite.bash): a real corruption incident happened because a
# fixture's own bare `git -C <tmpdir> init/commit` calls had no defensive
# unset of GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE/GIT_PREFIX, and silently
# redirected onto a REAL, already-initialized repo when the calling shell
# (the one that invoked bats) had GIT_DIR pointing at it -- landing a
# fixture's "decoy" commit directly on top of a real one. Note:
# `git rev-parse --show-toplevel` is NOT a reliable way to detect this --
# it falls back to cwd-based resolution even with a leaked GIT_DIR, while
# WRITE operations (init/config/add/commit) still honor the leaked GIT_DIR.
# The only reliable check is whether a real, external repo actually got
# mutated, which is what test 2 verifies.

teardown() {
    # Runs regardless of test outcome (unlike inline cleanup at the end of a
    # test body, which bats never reaches once an assertion fails) -- a
    # failing run of this exact test would otherwise leak decoy git repos
    # and fixture files into $TMPDIR indefinitely. The trailing `true` is
    # required, not decorative: `[[ cond ]] && cmd` returns non-zero
    # whenever cond is false (e.g. in test 1, which never sets either var),
    # and since that would otherwise be the last statement bats sees, a
    # false guard alone would make teardown() itself report as a failed
    # step for a test that never even touched these variables.
    [[ -n "${REAL_LEAK_TARGET:-}" ]] && rm -rf "$REAL_LEAK_TARGET"
    [[ -n "${UNDEFENDED_FIXTURE:-}" ]] && rm -rf "$(dirname "$UNDEFENDED_FIXTURE")"
    true
}

@test "suite isolation: GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE/GIT_PREFIX are absent in every test's own environment" {
    # This is a direct smoke check of setup_suite()'s immediate effect, not
    # an end-to-end regression guard by itself -- under this repo's actual
    # invocation paths (tools/test-all.sh, CI), bats is always launched with
    # a clean environment, so this specific assertion can't fail there
    # regardless of whether setup_suite.bash works. Its real value is for
    # the exact scenario the original incident happened under: an agent or
    # engineer manually running `bash tools/test-all.sh --fast` (or `bats
    # test/` directly) from a shell where GIT_DIR was ALREADY polluted by
    # something unrelated before bats was invoked -- run this file that way
    # (`GIT_DIR=<real-gitdir> bats test/suite-git-dir-isolation.bats`) and
    # this assertion fails exactly if setup_suite.bash's unset didn't work.
    # Test 2 below is the fully self-contained, mutation-tested regression
    # guard that doesn't depend on how THIS invocation itself was launched.
    for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX; do
        [[ -z "${!v:-}" ]] || {
            echo "FAIL: $v is set to '${!v}' -- setup_suite.bash's unset did not take effect"
            return 1
        }
    done
}

@test "suite isolation: setup_suite.bash prevents an undefended fixture from corrupting a real repo GIT_DIR happens to leak toward" {
    # By the time this test body runs, setup_suite.bash has ALREADY unset
    # these vars once for the whole suite -- so exercising the hazard from
    # inside a normal @test can't reproduce the "polluted before bats even
    # started" scenario setup_suite.bash exists to close. This test instead
    # invokes a NESTED bats process (with GIT_DIR deliberately leaked into
    # it, simulating pollution in the shell that invokes bats) against a
    # fixture that does the exact undefended `git -C <tmpdir> init/commit`
    # pattern, and checks whether a real target repo survived untouched --
    # self-contained regardless of how this outer test itself was invoked.
    REAL_LEAK_TARGET="$(mktemp -d)"
    git -C "$REAL_LEAK_TARGET" init -q --initial-branch=main
    git -C "$REAL_LEAK_TARGET" config user.email real@test
    git -C "$REAL_LEAK_TARGET" config user.name real
    echo real > "$REAL_LEAK_TARGET/real.txt"
    git -C "$REAL_LEAK_TARGET" add -A
    git -C "$REAL_LEAK_TARGET" commit -q -m "real-initial"
    REAL_HEAD_BEFORE="$(git -C "$REAL_LEAK_TARGET" rev-parse HEAD)"

    UNDEFENDED_FIXTURE="$(mktemp -d)/undefended.bats"
    mkdir -p "$(dirname "$UNDEFENDED_FIXTURE")"
    cat > "$UNDEFENDED_FIXTURE" <<'EOF'
#!/usr/bin/env bats
@test "undefended: bare git -C <tmpdir> init/commit, no unset of its own" {
    DECOY="$(mktemp -d)"
    git -C "$DECOY" init -q --initial-branch=main
    git -C "$DECOY" config user.email test@test
    git -C "$DECOY" config user.name test
    echo x > "$DECOY/marker.txt"
    git -C "$DECOY" add -A
    git -C "$DECOY" commit -q -m decoy
}
EOF

    # Run the SAME repo's real setup_suite.bash (copied alongside the
    # undefended fixture) with GIT_DIR leaked, exactly as if the shell that
    # invoked `bats test/` had it polluted going in.
    cp "$BATS_TEST_DIRNAME/setup_suite.bash" "$(dirname "$UNDEFENDED_FIXTURE")/setup_suite.bash"
    GIT_DIR="$REAL_LEAK_TARGET/.git" bats "$UNDEFENDED_FIXTURE"

    REAL_HEAD_AFTER="$(git -C "$REAL_LEAK_TARGET" rev-parse HEAD)"
    [[ "$REAL_HEAD_AFTER" == "$REAL_HEAD_BEFORE" ]]
    [[ "$(git -C "$REAL_LEAK_TARGET" log --oneline | wc -l)" -eq 1 ]]
}
