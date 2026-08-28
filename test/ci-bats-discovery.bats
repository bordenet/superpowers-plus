#!/usr/bin/env bats

# Behavioral tests for tools/ci-bats-discovery.sh.
#
# WHY THIS TOOL EXISTS (2026-08-26): .github/workflows/test.yml enumerated every
# bats suite by hand. The list drifted -- an audit found 39 of 70 suites were
# never run by CI, including test/ship.bats (the canonical agent workflow),
# test/pre-push-code-review-gate.bats and test/pre-push-gate4.bats. All 39
# passed when run manually, so they were dark by omission, not by exclusion.
#
# THE INVARIANT THIS LOCKS: a new .bats file is picked up with NO edit to CI
# config. The only way to keep a suite out is an explicit policy line carrying
# a reason, and --lint fails when a policy line names a path that no longer
# exists -- so the opt-out list cannot rot the way the enumeration did.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/ci-bats-discovery.sh"

setup() {
    ROOT="$BATS_TEST_TMPDIR/root"
    mkdir -p "$ROOT/test" "$ROOT/tests" "$ROOT/tools"
    POLICY="$ROOT/tests/ci-bats-policy.txt"

    # Two trivially-passing fixture suites.
    cat > "$ROOT/test/alpha.bats" <<'EOF'
#!/usr/bin/env bats
@test "alpha passes" { true; }
EOF
    cat > "$ROOT/tests/beta.bats" <<'EOF'
#!/usr/bin/env bats
@test "beta passes" { true; }
EOF
}

run_tool() { run bash "$SCRIPT" --root "$ROOT" "$@"; }

# --------------------------------------------------------------------------
# Contract surface
# --------------------------------------------------------------------------

@test "--help exits 0 and documents the discovery contract" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--list"* ]]
    [[ "$output" == *"--lint"* ]]
    [[ "$output" == *"--run"* ]]
}

@test "unknown argument is a usage error, not a silent default" {
    run bash "$SCRIPT" --nope
    [ "$status" -eq 2 ]
}

@test "--root pointing at a nonexistent dir is a usage error" {
    run bash "$SCRIPT" --root "$BATS_TEST_TMPDIR/absent" --list
    [ "$status" -eq 2 ]
}

# --------------------------------------------------------------------------
# Discovery -- the anti-drift core
# --------------------------------------------------------------------------

@test "--list discovers every .bats under test/ and tests/" {
    run_tool --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test/alpha.bats"* ]]
    [[ "$output" == *"tests/beta.bats"* ]]
}

@test "a NEW suite is discovered with no config edit (the whole point)" {
    cat > "$ROOT/test/gamma.bats" <<'EOF'
#!/usr/bin/env bats
@test "gamma passes" { true; }
EOF
    run_tool --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test/gamma.bats"* ]]
}

@test "--list emits repo-relative paths, sorted and deterministic" {
    run_tool --list
    first="$output"
    run_tool --list
    [ "$output" = "$first" ]
    [[ "$output" != *"$ROOT"* ]]   # relative, not absolute
    sorted="$(printf '%s\n' "$output" | sort)"
    [ "$output" = "$sorted" ]
}

@test "absent policy file is fine -- everything runs" {
    [ ! -f "$POLICY" ]
    run_tool --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"test/alpha.bats"* ]]
}

@test "an excluded suite is omitted from --list" {
    printf 'exclude test/alpha.bats  needs a live network\n' > "$POLICY"
    run_tool --list
    [ "$status" -eq 0 ]
    [[ "$output" != *"test/alpha.bats"* ]]
    [[ "$output" == *"tests/beta.bats"* ]]
}

@test "an env-directive suite still RUNS (env is not exclusion)" {
    printf 'env tests/beta.bats FOO=bar  beta needs FOO\n' > "$POLICY"
    run_tool --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"tests/beta.bats"* ]]
}

# --------------------------------------------------------------------------
# Lint -- stops the opt-out list rotting the way the enumeration did
# --------------------------------------------------------------------------

@test "--lint passes on a valid policy" {
    printf 'exclude test/alpha.bats  needs a live network\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

@test "--lint passes when there is no policy file at all" {
    run_tool --lint
    [ "$status" -eq 0 ]
}

@test "--lint FAILS when a policy line names a path that no longer exists" {
    printf 'exclude test/deleted-suite.bats  was flaky\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"deleted-suite"* ]]
}

@test "--lint fails on an unknown directive" {
    printf 'skipp test/alpha.bats  typo\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

@test "--lint fails on an env directive with no KEY=VALUE" {
    printf 'env test/alpha.bats  no assignment here\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

@test "--lint fails on a policy entry with no reason" {
    printf 'exclude test/alpha.bats\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"reason"* ]]
}

@test "--lint fails on a duplicate path across directives" {
    printf 'exclude test/alpha.bats  first\nenv test/alpha.bats K=V  second\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"duplicate"* ]]
}

@test "--lint ignores comments and blank lines" {
    printf '# a comment\n\n   \nexclude test/alpha.bats  reason here\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------

@test "--run executes discovered suites and exits 0 when all pass" {
    run_tool --run
    [ "$status" -eq 0 ]
}

@test "--run propagates a suite failure" {
    cat > "$ROOT/test/failing.bats" <<'EOF'
#!/usr/bin/env bats
@test "this one fails" { false; }
EOF
    run_tool --run
    [ "$status" -eq 1 ]
    [[ "$output" == *"failing.bats"* ]]
}

@test "--run keeps going after a failure and reports every failed suite" {
    cat > "$ROOT/test/fail-one.bats" <<'EOF'
#!/usr/bin/env bats
@test "fail one" { false; }
EOF
    cat > "$ROOT/tests/fail-two.bats" <<'EOF'
#!/usr/bin/env bats
@test "fail two" { false; }
EOF
    run_tool --run
    [ "$status" -eq 1 ]
    [[ "$output" == *"fail-one.bats"* ]]
    [[ "$output" == *"fail-two.bats"* ]]
}

@test "--run does NOT execute an excluded suite" {
    cat > "$ROOT/test/failing.bats" <<'EOF'
#!/usr/bin/env bats
@test "would fail if run" { false; }
EOF
    printf 'exclude test/failing.bats  deliberately quarantined\n' > "$POLICY"
    run_tool --run
    [ "$status" -eq 0 ]
}

@test "--run applies the env assignment from the policy" {
    cat > "$ROOT/test/needs-env.bats" <<'EOF'
#!/usr/bin/env bats
@test "sees FOO" { [ "$FOO" = "bar" ]; }
EOF
    printf 'env test/needs-env.bats FOO=bar  suite needs FOO set\n' > "$POLICY"
    run_tool --run
    [ "$status" -eq 0 ]
}

@test "--run expands \$REPO_ROOT inside a policy env value" {
    cat > "$ROOT/test/needs-root.bats" <<'EOF'
#!/usr/bin/env bats
@test "sees an absolute skills path" { case "$SKILLS_DIR" in /*/skills) true ;; *) false ;; esac; }
EOF
    printf 'env test/needs-root.bats SKILLS_DIR=$REPO_ROOT/skills  needs an absolute path\n' > "$POLICY"
    run_tool --run
    [ "$status" -eq 0 ]
}

@test "--run refuses to start when the policy is rotten" {
    printf 'exclude test/deleted-suite.bats  was flaky\n' > "$POLICY"
    run_tool --run
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Regression (Design Critic F3, 2026-08-27): the env directive's field boundary
# is positional -- only $3 is read as the assignment and everything after is
# swallowed as prose. `env <path> A=1 B=2  reason` linted CLEAN while exporting
# only A=1. The duplicate-path lint blocks the obvious workaround (two lines for
# one suite), so a suite needing two vars was inexpressible AND the near-miss
# failed silently. That is exactly the rot this tool exists to prevent.
# ---------------------------------------------------------------------------
@test "--lint FAILS on an env line carrying a second KEY=VALUE it would silently drop" {
    printf 'env test/alpha.bats A=1 B=2  needs both\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"B=2"* ]] || [[ "$output" == *"second"* ]] || [[ "$output" == *"one assignment"* ]]
}

@test "--lint still accepts a single assignment whose reason mentions no assignment" {
    printf 'env test/alpha.bats A=1  alpha needs A set\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

@test "--lint accepts an assignment VALUE that itself contains an equals sign" {
    printf 'env test/alpha.bats A=k=v  value has an equals\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Regression (Design Critic F4): --root validates its argument but --policy did
# not, so an explicitly-named policy path that does not exist was silently
# treated as "no policy at all" -- every env directive evaporating on a typo.
# ---------------------------------------------------------------------------
@test "an explicitly-supplied --policy path that does not exist is a usage error" {
    run bash "$SCRIPT" --root "$ROOT" --policy "$ROOT/NOPE.txt" --lint
    [ "$status" -eq 2 ]
}

@test "an ABSENT default policy is still fine (not a usage error)" {
    [ ! -f "$POLICY" ]
    run_tool --lint
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Security (AttackerPersona I4, 2026-08-27): the env directive accepted ANY
# identifier as a key and exported it into the bats child. A policy line setting
# PATH replaced the test runner and CI still reported "All suites passed"; a
# startup-file variable executed arbitrary code inside the job; --lint accepted
# both. The policy file is repo-committed and agent-editable, so this is a CI
# code-execution path, not a config typo.
# ---------------------------------------------------------------------------
@test "--lint REJECTS a policy env key that hijacks the executable search path" {
    printf 'env test/alpha.bats PATH=/tmp/evil  make it pass\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"PATH"* ]]
}

@test "--lint REJECTS a policy env key that executes code at shell startup" {
    printf 'env test/alpha.bats BASH_ENV=/tmp/pwn.sh  make it pass\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

@test "--lint REJECTS dynamic-loader injection keys" {
    for k in LD_PRELOAD LD_LIBRARY_PATH DYLD_INSERT_LIBRARIES; do
        printf 'env test/alpha.bats %s=/tmp/evil  reason\n' "$k" > "$POLICY"
        run_tool --lint
        [ "$status" -eq 1 ]
    done
}

@test "--lint REJECTS IFS, SHELL and GIT_CONFIG overrides" {
    for k in IFS SHELL GIT_CONFIG GIT_CONFIG_GLOBAL; do
        printf 'env test/alpha.bats %s=x  reason\n' "$k" > "$POLICY"
        run_tool --lint
        [ "$status" -eq 1 ]
    done
}

@test "--lint REJECTS a lowercase or malformed env key" {
    printf 'env test/alpha.bats path=/tmp/evil  sneaky\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

@test "--lint still ACCEPTS the ordinary suite env keys this repo needs" {
    printf 'env test/alpha.bats BUDGET_MODE=advisory  budgets are advisory\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
    printf 'env test/alpha.bats PERSONAL_SKILLS_DIR=$REPO_ROOT/skills  needs the skills tree\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}
