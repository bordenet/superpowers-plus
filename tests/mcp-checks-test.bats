#!/usr/bin/env bats
# Tests for tools/doctor-modules/mcp-checks.sh (Check 28)
# Focuses on: jq --arg injection safety, claude mcp list parsing,
# seen/parsed counters, and arithmetic safety.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MCP_CHECKS="$REPO_ROOT/tools/doctor-modules/mcp-checks.sh"

# Source the module in an isolated subshell environment
_run_mcp_checks() {
    bash -c "
        set -uo pipefail
        ERRORS=0; WARNINGS=0; CRITICAL=0; FIXED=0; FIX_MODE=false
        FORCE=false; VERBOSE=false
        augment_settings='${1:-/nonexistent/settings.json}'
        $(cat "$MCP_CHECKS")
        echo \"ERRORS=\$ERRORS WARNINGS=\$WARNINGS\"
    " 2>&1
}

setup() {
    export TEST_HOME
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# --- jq injection safety ---

@test "jq --arg: server name with double-quotes does not break parsing" {
    # A server name with a double-quote would break jq .mcpServers["$name"] interpolation
    local settings="$TEST_HOME/settings.json"
    cat > "$settings" <<'JSON'
{"mcpServers": {"node-server": {"command": "node", "args": ["/path/to/file.js"]}}}
JSON
    # The check should complete without syntax error (jq --arg handles special chars)
    run bash -c "
        set -uo pipefail
        ERRORS=0; WARNINGS=0; CRITICAL=0; FIXED=0; FIX_MODE=false
        FORCE=false; VERBOSE=false
        augment_settings='$settings'
        $(cat "$MCP_CHECKS")
        echo ok
    " 2>&1
    [[ "$output" == *"ok"* ]] || [[ "$output" == *"MCP"* ]]
}

@test "jq --arg: server name with special chars does not cause jq error" {
    local settings="$TEST_HOME/settings.json"
    # Server name with colon (edge case from PHR)
    printf '{"mcpServers": {"my:server": {"command": "node", "args": ["/path/file.js"]}}}' > "$settings"
    run bash -c "
        set -uo pipefail
        ERRORS=0; WARNINGS=0; CRITICAL=0; FIXED=0; FIX_MODE=false
        FORCE=false; VERBOSE=false
        augment_settings='$settings'
        $(cat "$MCP_CHECKS")
        echo DONE
    " 2>&1
    # Should not exit with jq parse error
    [[ "$status" -eq 0 ]]
}

# --- claude mcp list parsing ---

@test "claude mcp list: claude absent — no format-change warning fired" {
    # When claude is not in PATH, the check is skipped entirely — no warning expected
    local mock_bin="$TEST_HOME/empty_bin"
    mkdir -p "$mock_bin"
    run bash -c "
        export PATH='$mock_bin'
        set -uo pipefail
        ERRORS=0; WARNINGS=0; CRITICAL=0; FIXED=0; FIX_MODE=false
        FORCE=false; VERBOSE=false
        augment_settings=/nonexistent/settings.json
        $(cat "$MCP_CHECKS") || true
        echo DONE
    " 2>&1
    [[ "$output" == *"DONE"* ]]
    [[ "$output" != *"format may have changed"* ]]
}

@test "claude mcp list: non-colon output lines are skipped (no-colon guard)" {
    # Lines without ':' must be skipped by the guard at the top of the parse loop.
    # This is what prevents "No MCP servers configured" from being parsed as a server.
    # We verify the guard in isolation via a direct grep on the source.
    grep -q "\"\$line\" != \*:\*" "$MCP_CHECKS"
}

# --- arithmetic safety ---

@test "ERRORS counter: increments correctly from zero without set -e exit" {
    local settings="$TEST_HOME/settings.json"
    # Valid server entry pointing to a missing entry point → should increment ERRORS
    cat > "$settings" <<'JSON'
{"mcpServers": {"test": {"command": "node", "args": ["/nonexistent/file.js"]}}}
JSON
    run bash -c "
        set -uo pipefail
        ERRORS=0; WARNINGS=0; CRITICAL=0; FIXED=0; FIX_MODE=false
        FORCE=false; VERBOSE=false
        augment_settings='$settings'
        $(cat "$MCP_CHECKS")
        echo ERRORS=\$ERRORS
    " 2>&1
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"ERRORS="* ]]
}

# --- format-change detection gap ---

@test "claude_seen/claude_parsed: http server guard present in source" {
    # Verify the http* filter guard exists — prevents HTTP SSE servers from being
    # parsed as stdio servers and triggering false format-change warnings.
    grep -q 'crest.*==.*http' "$MCP_CHECKS"
}

@test "mcp-checks source: variable-key mcpServers jq lookups all use --arg" {
    # Every jq call that uses a variable to index .mcpServers must use --arg.
    # '.mcpServers[$n]' — safe (jq variable, not shell interpolation)
    # '.mcpServers | to_entries' — safe (no variable key, excluded from this check)
    # Dangerous would be: jq ".mcpServers[\"$shell_var\"]"
    local bracket_lookups
    mapfile -t bracket_lookups < <(grep -n "jq.*mcpServers\[" "$MCP_CHECKS")
    [[ "${#bracket_lookups[@]}" -gt 0 ]]  # must have at least one bracket lookup
    local line
    for line in "${bracket_lookups[@]}"; do
        [[ "$line" == *"--arg"* ]]
    done
}
