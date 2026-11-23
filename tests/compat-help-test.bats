#!/usr/bin/env bats
# Regression: tools/compat.sh must not leak its help when sourced by other scripts

@test "todo-crud.sh --help prints todo-crud usage, not compat.sh usage" {
    run ./tools/todo-crud.sh --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage: todo-crud.sh"* ]]
    [[ "${output}" != *"tools/compat.sh — Cross-platform"* ]]
}

@test "skill-cost-analyzer.sh --help shows usage, not compat help" {
    run ./tools/skill-cost-analyzer.sh --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage"* ]]
    [[ "${output}" != *"tools/compat.sh — Cross-platform"* ]]
}

@test "test-content-coherence.sh --help shows usage, not compat help" {
    run ./tools/test-content-coherence.sh --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage"* ]]
    [[ "${output}" != *"tools/compat.sh — Cross-platform"* ]]
}

@test "compat.sh executed directly still prints its help" {
    run bash tools/compat.sh --help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"tools/compat.sh — Cross-platform"* ]]
}

@test "todo-crud.sh self-test still passes after compat fix" {
    local fixture_home="$BATS_TEST_TMPDIR/home"
    mkdir -p "$fixture_home/.codex"
    printf '# TODO\n' > "$fixture_home/.codex/TODO.md"
    run env HOME="$fixture_home" TODO_FILE_PATH="$fixture_home/.codex/TODO.md" ./tools/todo-crud.sh self-test
    # The engine protects the real file even after a read. Release our fixture.
    source ./tools/compat.sh
    clear_immutable "$fixture_home/.codex/TODO.md" || true
    [ "$status" -eq 0 ]
}
