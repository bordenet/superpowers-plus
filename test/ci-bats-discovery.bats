#!/usr/bin/env bats

# Behavioral tests for tools/ci-bats-discovery.sh.
#
# WHY THIS TOOL EXISTS (2026-08-26): .github/workflows/test.yml enumerated every
# bats suite by hand. The list drifted -- an audit found 39 of 67 suites were
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

@test "--root handles sed metacharacters without corrupting relative paths" {
    special_root="$BATS_TEST_TMPDIR/root|with&chars"
    mkdir -p "$special_root/test"
    printf '#!/usr/bin/env bats\n@test "passes" { true; }\n' > "$special_root/test/special.bats"

    run bash "$SCRIPT" --root "$special_root" --list
    [ "$status" -eq 0 ]
    [ "$output" = "test/special.bats" ]
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
    printf 'env tests/beta.bats BUDGET_MODE=advisory  beta needs it\n' > "$POLICY"
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
    printf 'exclude test/alpha.bats  first\nenv test/alpha.bats BUDGET_MODE=V  second\n' > "$POLICY"
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
@test "sees BUDGET_MODE" { [ "$BUDGET_MODE" = "advisory" ]; }
EOF
    printf 'env test/needs-env.bats BUDGET_MODE=advisory  suite needs it set\n' > "$POLICY"
    run_tool --run
    [ "$status" -eq 0 ]
}

@test "--run expands \$REPO_ROOT inside a policy env value" {
    cat > "$ROOT/test/needs-root.bats" <<'EOF'
#!/usr/bin/env bats
@test "sees an absolute skills path" { case "$PERSONAL_SKILLS_DIR" in /*/skills) true ;; *) false ;; esac; }
EOF
    printf 'env test/needs-root.bats PERSONAL_SKILLS_DIR=$REPO_ROOT/skills  needs an absolute path\n' > "$POLICY"
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
    printf 'env test/alpha.bats BUDGET_MODE=1 PERSONAL_SKILLS_DIR=2  needs both\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"B=2"* ]] || [[ "$output" == *"second"* ]] || [[ "$output" == *"one assignment"* ]]
}

@test "--lint still accepts a single assignment whose reason mentions no assignment" {
    printf 'env test/alpha.bats BUDGET_MODE=advisory  alpha needs it set\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

@test "--lint accepts an assignment VALUE that itself contains an equals sign" {
    printf 'env test/alpha.bats BUDGET_MODE=k=v  value has an equals\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 0 ]
}

@test "--lint accepts equals signs in ordinary reason prose" {
    printf 'env test/alpha.bats BUDGET_MODE=advisory  issue=https://example.test/123\n' > "$POLICY"
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
@test "--lint REFUSES every key outside the allowlist (class, not enumeration)" {
    # Deliberately NOT the keys the old denylist named. Guardian and Defect
    # Finder independently probed 41 and 46 keys respectively; every one of
    # these was ACCEPTED by the denylist and yields code execution in the CI
    # job. A denylist cannot close a set that grows with every tool installed
    # on the runner, so the test asserts the CLASS, not the members.
    for k in GIT_EXTERNAL_DIFF GIT_SSH_COMMAND GIT_ASKPASS GIT_PAGER GIT_EDITOR \
             GIT_DIR GIT_INDEX_FILE HOME CDPATH GLOBIGNORE PS4 SHELLOPTS BASHOPTS \
             PERL5OPT PYTHONSTARTUP RUBYOPT RUBYLIB NODE_PATH NODE_EXTRA_CA_CERTS \
             SSL_CERT_FILE CURL_CA_BUNDLE HTTPS_PROXY TMPDIR XDG_CONFIG_HOME \
             PATH BASH_ENV ENV IFS SHELL LD_PRELOAD DYLD_INSERT_LIBRARIES \
             GIT_CONFIG PYTHONPATH PERL5LIB NODE_OPTIONS BATS_LIB_PATH; do
        printf 'env test/alpha.bats %s=/tmp/x  a plausible reason\n' "$k" > "$POLICY"
        run_tool --lint
        [ "$status" -eq 1 ] || { echo "ACCEPTED dangerous key: $k"; return 1; }
    done
}

@test "--run ALSO refuses a non-allowlisted key (enforcement must not be lint-only)" {
    # Guardian G2: every security assertion targeted --lint. --run is a
    # documented standalone mode, so a refactor moving the key check into a
    # lint-only path would silently restore full RCE with the suite green.
    for k in GIT_EXTERNAL_DIFF HOME PATH BASH_ENV; do
        printf 'env test/alpha.bats %s=/tmp/x  reason\n' "$k" > "$POLICY"
        run_tool --run
        [ "$status" -eq 1 ] || { echo "--run ACCEPTED dangerous key: $k"; return 1; }
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

# ---------------------------------------------------------------------------
# ShellRuntimeAuditor I1: --run reported a PASS when zero (or fewer) suites were
# discovered, and process substitution discarded discover()'s exit status. A
# failing suite made unreadable by a traversal error vanished and CI went green.
# This script is now the ONLY thing running bats in CI, so a silent coverage
# collapse is the exact failure the tool exists to prevent, via a new mechanism.
# ---------------------------------------------------------------------------
@test "--run REFUSES to report a pass when zero suites are discovered" {
    empty="$BATS_TEST_TMPDIR/empty"; mkdir -p "$empty"
    run bash "$SCRIPT" --root "$empty" --run
    [ "$status" -ne 0 ]
    [[ "$output" == *"0 suite"* ]] || [[ "$output" == *"refusing"* ]]
}

@test "--lint REFUSES a zero-suite tree too (the anti-rot gate must gate)" {
    empty="$BATS_TEST_TMPDIR/empty2"; mkdir -p "$empty"
    run bash "$SCRIPT" --root "$empty" --lint
    [ "$status" -ne 0 ]
}

@test "CI_BATS_MIN_SUITES enforces a coverage floor" {
    CI_BATS_MIN_SUITES=99 run_tool --run
    [ "$status" -ne 0 ]
    [[ "$output" == *"99"* ]]
}

@test "CI_BATS_MIN_SUITES must be a positive integer" {
    for floor in 0 -1 nope 1.5; do
        run env CI_BATS_MIN_SUITES="$floor" bash "$SCRIPT" --root "$ROOT" --list
        [ "$status" -ne 0 ] || { echo "accepted invalid floor: $floor"; return 1; }
        [[ "$output" == *"positive integer"* ]]
    done
    run env CI_BATS_MIN_SUITES=1 bash "$SCRIPT" --root "$ROOT" --list
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Defect Finder I5: lint checked that an exclude path EXISTS, not that it
# matches a discovered suite. './test/a.bats', 'test/../test/a.bats' and even a
# non-.bats file all linted clean and excluded nothing -- a suite quarantined
# for being flaky kept running while lint reported "policy OK".
# ---------------------------------------------------------------------------
@test "--lint FAILS on a non-canonical exclude path that would silently no-op" {
    printf 'exclude ./test/alpha.bats  flaky on CI\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

@test "--lint FAILS on an exclude path that exists but is not a discovered suite" {
    printf 'notes\n' > "$ROOT/notes.md"
    printf 'exclude notes.md  not a suite at all\n' > "$POLICY"
    run_tool --lint
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# ShellRuntimeAuditor M1: no `command -v bats` guard, unlike tools/test-all.sh.
# A fresh checkout produced 69 identical "command not found" lines and a
# FAILED list naming every suite in the repo.
# ---------------------------------------------------------------------------
@test "--run reports ONE actionable error when bats is not installed" {
    stub="$BATS_TEST_TMPDIR/nobin"; mkdir -p "$stub"
    run env PATH="$stub:/usr/bin:/bin" bash "$SCRIPT" --root "$ROOT" --run
    [ "$status" -ne 0 ]
    [[ "$output" == *"bats"* ]]
    [ "$(printf '%s' "$output" | grep -c 'command not found')" -eq 0 ]
}
