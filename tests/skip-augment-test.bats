#!/usr/bin/env bats
# skip-augment-test.bats — contract tests for install.sh --skip-augment
#
# Verifies the --skip-augment flag's user-facing contract:
#   1. --help documents the flag and the four paths it skips
#   2. --skip-augment --check passes prerequisites without flagging SKILLS_DIR absence
#   3. SKIP_AUGMENT=true env var has the same effect as --skip-augment flag
#   4. A bare `install.sh` run (no flag, no env) still defaults to installing Augment
#   5. SKIP_AUGMENT inherited from environment emits a visible warning
#
# These are static / dry-run tests; the full deployment path is exercised by
# install-test.bats via install-augment-superpowers.sh.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

@test "--help documents --skip-augment with all four target paths" {
    run bash "$INSTALLER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--skip-augment"* ]]
    [[ "$output" == *"~/.codex/skills/"* ]]
    [[ "$output" == *"~/.agents/skills/"* ]]
    [[ "$output" == *"~/.codex/superpowers-augment/"* ]]
    [[ "$output" == *"~/.augment/rules/"* ]]
}

@test "--skip-augment --check passes and omits Augment target from listing" {
    run bash "$INSTALLER" --skip-augment --check
    [ "$status" -eq 0 ]
    [[ "$output" == *".claude/skills"* ]]
    [[ "$output" != *"target: "*".codex/skills"* ]]
}

@test "default --check (no flag) still lists both Augment and Claude targets" {
    run bash "$INSTALLER" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *".claude/skills"* ]]
    # Augment target line is shown unless explicitly skipped
    [[ "$output" == *".codex/skills"* ]]
}

@test "SKIP_AUGMENT=true env var produces same --check output as --skip-augment flag" {
    run env SKIP_AUGMENT=true bash "$INSTALLER" --check
    [ "$status" -eq 0 ]
    [[ "$output" != *"target: "*".codex/skills"* ]]
}

@test "SKIP_AUGMENT inherited from environment emits visible warning" {
    run env SKIP_AUGMENT=true bash "$INSTALLER" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP_AUGMENT=true inherited from environment"* ]]
}

@test "--skip-augment flag (not env) does NOT emit inheritance warning" {
    run bash "$INSTALLER" --skip-augment --check
    [ "$status" -eq 0 ]
    [[ "$output" != *"inherited from environment"* ]]
}

@test "deploy.sh defensively reads SKIP_AUGMENT with default fallback" {
    # Lib code is sourced and may run before install.sh's init. Every
    # SKIP_AUGMENT read in deploy.sh must use ${SKIP_AUGMENT:-false} form
    # so it survives `set -u` even when sourced standalone.
    run grep -nE '\[\[ "\$SKIP_AUGMENT"' "$REPO_ROOT/lib/install/deploy.sh"
    # No matches means all reads use the defensive form
    [ "$status" -ne 0 ]
}
