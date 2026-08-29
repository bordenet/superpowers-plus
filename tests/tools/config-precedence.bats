#!/usr/bin/env bats
# Unit tests for tools/resolve-config.sh -- the unified four-tier config resolver.
#
# Precedence asserted (highest -> lowest):
#   1. SP_CONFIG_<KIND>_<KEY>   env-var override
#   2. <nearest .git>/.codex-config/<kind>/<key>   project-local
#   3. Repos in ~/.codex/repos.txt, each /.codex-config/<kind>/<key>   repo-source
#   4. ~/.codex/config/<kind>/<key>   global install
#
# Hermetic: HOME and cwd are stubbed to temp dirs; no real network calls.

setup() {
    RESOLVER="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/tools/resolve-config.sh"
    FAKEHOME="$(mktemp -d)"
    FAKECWD="$(mktemp -d)"
    export HOME="$FAKEHOME"
    mkdir -p "$FAKEHOME/.codex"
    mkdir -p "$FAKECWD"
    # Make FAKECWD a fake git root so the tier-2 project walk terminates there.
    mkdir -p "$FAKECWD/.git"
}

teardown() {
    rm -rf "$FAKEHOME" "$FAKECWD"
}

# ---------------------------------------------------------------------------
# --list-kinds
# ---------------------------------------------------------------------------

@test "--list-kinds prints all five kinds" {
    run bash "$RESOLVER" --list-kinds
    [ "$status" -eq 0 ]
    [[ "$output" == *"mcp"* ]]
    [[ "$output" == *"env"* ]]
    [[ "$output" == *"allowlist"* ]]
    [[ "$output" == *"hook"* ]]
    [[ "$output" == *"template"* ]]
}

# ---------------------------------------------------------------------------
# Tier 1: env-var override
# ---------------------------------------------------------------------------

@test "tier-1 env-var override wins (get)" {
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        SP_CONFIG_MCP_LINEAR_API_URL="https://override.example" \
        bash "$RESOLVER" get mcp LINEAR_API_URL
    [ "$status" -eq 0 ]
    [ "$output" = "https://override.example" ]
}

@test "tier-1 env-var with lower-case kind uppercased correctly" {
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        SP_CONFIG_TEMPLATE_SKILLS_DIR="/tmp/skills" \
        bash "$RESOLVER" get template SKILLS_DIR
    [ "$status" -eq 0 ]
    [ "$output" = "/tmp/skills" ]
}

# ---------------------------------------------------------------------------
# Tier 2: project-local (.git boundary)
# ---------------------------------------------------------------------------

@test "tier-2 project-local file wins when no env-var" {
    mkdir -p "$FAKECWD/.codex-config/mcp"
    printf 'https://project.example/graphql' > "$FAKECWD/.codex-config/mcp/LINEAR_API_URL"
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get mcp LINEAR_API_URL"
    [ "$status" -eq 0 ]
    [ "$output" = "https://project.example/graphql" ]
}

@test "tier-1 env-var beats tier-2 project-local" {
    mkdir -p "$FAKECWD/.codex-config/mcp"
    printf 'https://project.example/graphql' > "$FAKECWD/.codex-config/mcp/LINEAR_API_URL"
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        SP_CONFIG_MCP_LINEAR_API_URL="https://override.example" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get mcp LINEAR_API_URL"
    [ "$status" -eq 0 ]
    [ "$output" = "https://override.example" ]
}

# ---------------------------------------------------------------------------
# Tier 3: repo-source (repos.txt)
# ---------------------------------------------------------------------------

@test "tier-3 repo-source file is found" {
    local FAKEREPO
    FAKEREPO="$(mktemp -d)"
    mkdir -p "$FAKEREPO/.codex-config/hook"
    printf 'skip' > "$FAKEREPO/.codex-config/hook/HOOK_BYPASS"
    printf '%s\n' "$FAKEREPO" > "$FAKEHOME/.codex/repos.txt"

    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get hook HOOK_BYPASS"
    [ "$status" -eq 0 ]
    [ "$output" = "skip" ]
    rm -rf "$FAKEREPO"
}

@test "tier-2 project-local beats tier-3 repo-source" {
    local FAKEREPO
    FAKEREPO="$(mktemp -d)"
    mkdir -p "$FAKEREPO/.codex-config/hook"
    printf 'repo-value' > "$FAKEREPO/.codex-config/hook/HOOK_BYPASS"
    printf '%s\n' "$FAKEREPO" > "$FAKEHOME/.codex/repos.txt"

    mkdir -p "$FAKECWD/.codex-config/hook"
    printf 'project-value' > "$FAKECWD/.codex-config/hook/HOOK_BYPASS"

    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get hook HOOK_BYPASS"
    [ "$status" -eq 0 ]
    [ "$output" = "project-value" ]
    rm -rf "$FAKEREPO"
}

# ---------------------------------------------------------------------------
# Tier 4: global install
# ---------------------------------------------------------------------------

@test "tier-4 global config file is found when nothing else matches" {
    mkdir -p "$FAKEHOME/.codex/config/template"
    printf '/home/user/.agents/skills' > "$FAKEHOME/.codex/config/template/AUGMENT_MENU_DIR"

    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get template AUGMENT_MENU_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "/home/user/.agents/skills" ]
}

@test "tier-3 beats tier-4 global" {
    local FAKEREPO
    FAKEREPO="$(mktemp -d)"
    mkdir -p "$FAKEREPO/.codex-config/template"
    printf '/repo/skills' > "$FAKEREPO/.codex-config/template/AUGMENT_MENU_DIR"
    printf '%s\n' "$FAKEREPO" > "$FAKEHOME/.codex/repos.txt"

    mkdir -p "$FAKEHOME/.codex/config/template"
    printf '/global/skills' > "$FAKEHOME/.codex/config/template/AUGMENT_MENU_DIR"

    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get template AUGMENT_MENU_DIR"
    [ "$status" -eq 0 ]
    [ "$output" = "/repo/skills" ]
    rm -rf "$FAKEREPO"
}

# ---------------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------------

@test "get exits 1 when key not found in any tier" {
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' get mcp NONEXISTENT_KEY"
    [ "$status" -eq 1 ]
}

@test "invalid kind exits 2" {
    run bash "$RESOLVER" get badkind somekey
    [ "$status" -eq 2 ]
}

@test "get rejects path-traversal key (exit 2)" {
    run bash "$RESOLVER" get mcp "../etc/passwd"
    [ "$status" -eq 2 ]
}

@test "get rejects slash in key (exit 2)" {
    run bash "$RESOLVER" get mcp "some/nested/key"
    [ "$status" -eq 2 ]
}

@test "audit prints all four tier rows" {
    run env -i HOME="$FAKEHOME" PATH="$PATH" \
        SP_CONFIG_MCP_TEST_KEY="val1" \
        bash -c "cd '$FAKECWD' && bash '$RESOLVER' audit mcp TEST_KEY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1-env-var"* ]]
    [[ "$output" == *"2-project"* ]]
    [[ "$output" == *"3-repo"* ]]
    [[ "$output" == *"4-global"* ]]
    [[ "$output" == *"val1"* ]]
}
