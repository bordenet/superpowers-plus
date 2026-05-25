#!/usr/bin/env bats
# Tests for the pre-push Gate 3 (.branch-flow-cleared consumer side).
# Extracts the check_branch_flow_sentinel function from tools/pre-push
# and exercises it directly across (match/mismatch-target/mismatch-sha/missing/
# bad-format) and verifies sentinel-consume (delete on PASS).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$(mktemp -d)"
    cd "$WORK"
    # Color codes used by the function under test.
    cat > stub-colors.sh <<'EOF'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'
EOF
    # Extract just the check_branch_flow_sentinel function from pre-push.
    awk '/^check_branch_flow_sentinel\(\)/,/^}$/' "$REPO_ROOT/tools/pre-push" \
        > extracted-fn.sh
    # Build a runnable harness.
    # Stub preflight script presence so Gate 3's self-detect short-circuit
    # doesn't fire (the actual function is what we're testing, not its presence).
    mkdir -p tools
    : > tools/branch-flow-preflight.sh
    chmod +x tools/branch-flow-preflight.sh
    cat > harness.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source ./stub-colors.sh
REPO_ROOT="$PWD"
BRANCH_FLOW_SENTINEL="$PWD/.branch-flow-cleared"
EOF
    cat extracted-fn.sh >> harness.sh
    cat >> harness.sh <<'EOF'

# Args: $1=target $2=pushed_sha
check_branch_flow_sentinel "$1" "$2"
EOF
    chmod +x harness.sh
}

teardown() {
    rm -rf "$WORK"
}

# --- PASS scenarios ---

@test "gate3: valid sentinel for dev with matching SHA -> PASS, sentinel consumed" {
    echo "v1|abc123|feature/foo|dev|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -eq 0 ]
    [[ "$output" == *"branch-flow cleared"* ]]
    [ ! -f .branch-flow-cleared ]  # consumed after PASS
}

@test "gate3: valid sentinel for staging -> PASS" {
    echo "v1|def456|dev|staging|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh staging def456
    [ "$status" -eq 0 ]
    [ ! -f .branch-flow-cleared ]
}

@test "gate3: valid sentinel for main -> PASS" {
    echo "v1|789aaa|staging|main|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh main 789aaa
    [ "$status" -eq 0 ]
    [ ! -f .branch-flow-cleared ]
}

@test "gate3: non-canonical target -> skip (returns 0 without checking sentinel)" {
    # No sentinel file at all -- skip-target shouldn't care.
    run ./harness.sh feature/foo deadbeef
    [ "$status" -eq 0 ]
}

# --- FAIL scenarios ---

@test "gate3: missing sentinel for dev push -> FAIL" {
    rm -f .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"No .branch-flow-cleared sentinel"* ]]
}

@test "gate3: sentinel with wrong target -> FAIL" {
    echo "v1|abc123|dev|staging|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123  # sentinel says staging, pushing to dev
    [ "$status" -ne 0 ]
    [[ "$output" == *"target"* ]] && [[ "$output" == *"!="* ]]
    [ -f .branch-flow-cleared ]  # NOT consumed on failure
}

@test "gate3: sentinel with wrong SHA -> FAIL" {
    echo "v1|abc123|feature/foo|dev|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev xyz789
    [ "$status" -ne 0 ]
    [[ "$output" == *"SHA"* ]]
    [ -f .branch-flow-cleared ]  # NOT consumed on failure
}

@test "gate3: sentinel with bad version -> FAIL" {
    echo "v0|abc123|feature/foo|dev|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"format unrecognized"* ]]
    [ -f .branch-flow-cleared ]
}

@test "gate3: sentinel with only 4 fields -> FAIL" {
    echo "v1|abc123|feature/foo|dev" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"format unrecognized"* ]]
    [ -f .branch-flow-cleared ]
}

@test "gate3: sentinel with empty SHA field -> FAIL" {
    echo "v1||feature/foo|dev|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"format unrecognized"* ]]
    [ -f .branch-flow-cleared ]
}

@test "gate3: sentinel with empty source field -> FAIL" {
    echo "v1|abc123||dev|2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"format unrecognized"* ]]
    [ -f .branch-flow-cleared ]
}

@test "gate3: sentinel with empty target field -> FAIL" {
    echo "v1|abc123|feature/foo||2026-05-24T00:00:00Z" > .branch-flow-cleared
    run ./harness.sh dev abc123
    [ "$status" -ne 0 ]
    [[ "$output" == *"format unrecognized"* ]]
    [ -f .branch-flow-cleared ]
}
