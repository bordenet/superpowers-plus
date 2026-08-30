#!/usr/bin/env bats
# Tests for tools/env-doctor.sh
# Focus: symlink-regression detection, safe auto-heal, divergent-content
# refusal, --check non-mutation, and custom path config.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOCTOR="$REPO_ROOT/tools/env-doctor.sh"

setup() {
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    export CODEX_ENV_LINK="$TEST_DIR/link.env"
    export CODEX_ENV_CANONICAL="$TEST_DIR/canonical.env"
    export CODEX_ENV_LOCAL="$TEST_DIR/local.env"
    # canonical has a couple of keys
    printf 'FOO=1\nBAR=2\n' > "$CODEX_ENV_CANONICAL"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "healthy: symlink pointing at canonical returns 0" {
    ln -s "$CODEX_ENV_CANONICAL" "$CODEX_ENV_LINK"
    run "$DOCTOR" --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK:"* ]]
}

@test "missing: no link creates one and returns 1" {
    run "$DOCTOR"
    [ "$status" -eq 1 ]
    [ -L "$CODEX_ENV_LINK" ]
    [ "$(readlink "$CODEX_ENV_LINK")" = "$CODEX_ENV_CANONICAL" ]
}

@test "regression identical content: self-heal returns 1 and writes backup" {
    cp "$CODEX_ENV_CANONICAL" "$CODEX_ENV_LINK"  # regular file, same content
    run "$DOCTOR"
    [ "$status" -eq 1 ]
    [ -L "$CODEX_ENV_LINK" ]
    ls "$CODEX_ENV_LINK".regression.* >/dev/null 2>&1
}

@test "regression identical content: --check does NOT mutate" {
    cp "$CODEX_ENV_CANONICAL" "$CODEX_ENV_LINK"
    run "$DOCTOR" --check
    [ "$status" -eq 2 ]
    [ ! -L "$CODEX_ENV_LINK" ]   # still a regular file
    [ -f "$CODEX_ENV_LINK" ]
}

@test "regression divergent content: returns 2, writes backups both sides, no mutation" {
    printf 'FOO=1\nBAR=2\nNEW_LOCAL=99\n' > "$CODEX_ENV_LINK"
    run "$DOCTOR"
    [ "$status" -eq 2 ]
    [ ! -L "$CODEX_ENV_LINK" ]
    ls "$CODEX_ENV_LINK".regression.*          >/dev/null 2>&1
    ls "$CODEX_ENV_CANONICAL".regression.*     >/dev/null 2>&1
    [[ "$output" == *"NEW_LOCAL"* ]]           # diff summary names the key
}

@test "redirected symlink: does not auto-fix a symlink pointing elsewhere" {
    other="$TEST_DIR/other.env"
    printf 'FOO=1\n' > "$other"
    ln -s "$other" "$CODEX_ENV_LINK"
    run "$DOCTOR"
    [ "$status" -eq 2 ]
    # still points to "other", we refused to repoint
    [ "$(readlink "$CODEX_ENV_LINK")" = "$other" ]
}

@test "canonical missing: returns 3" {
    rm "$CODEX_ENV_CANONICAL"
    run "$DOCTOR"
    [ "$status" -eq 3 ]
    [[ "$output" == *"canonical"* ]]
}

@test "unknown flag: returns 2" {
    run "$DOCTOR" --bogus
    [ "$status" -eq 2 ]
}

@test "--help exits 0 and prints USAGE" {
    run "$DOCTOR" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE:"* ]]
}
