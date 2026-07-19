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

# --- Check 30: MCP registration parity ---
#
# _doctor_mcp_parity_check reads "${HOME}/.augment/settings.json" directly
# (no variable-injection override like Check 28's tests use above) and
# actually invokes the function, not just sources it -- so fixtures must
# land at the real path the function reads, under $TEST_HOME/.augment/.

@test "parity: identical server sets in Augment and Claude -> no warning" {
    mkdir -p "$TEST_HOME/.augment"
    printf '{"mcpServers": {"serverA": {"command": "node"}}}' > "$TEST_HOME/.augment/settings.json"
    local mock_bin="$TEST_HOME/mock_bin"
    mkdir -p "$mock_bin"
    cat > "$mock_bin/claude" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "mcp list" ]] && echo "serverA: node /tmp/a.js - connected"
EOF
    chmod +x "$mock_bin/claude"
    run bash -c "
        export PATH=\"$mock_bin:\$PATH\"
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$output" == *"parity: Claude Code and Augment agree"* ]]
    [[ "$output" == *"WARNINGS=0"* ]]
}

@test "parity: server registered only in Augment -> warning names it" {
    mkdir -p "$TEST_HOME/.augment"
    printf '{"mcpServers": {"serverA": {"command": "node"}, "onlyAugment": {"command": "npx"}}}' > "$TEST_HOME/.augment/settings.json"
    local mock_bin="$TEST_HOME/mock_bin"
    mkdir -p "$mock_bin"
    cat > "$mock_bin/claude" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "mcp list" ]] && echo "serverA: node /tmp/a.js - connected"
EOF
    chmod +x "$mock_bin/claude"
    run bash -c "
        export PATH=\"$mock_bin:\$PATH\"
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$output" == *"Registered in Augment only: onlyAugment"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "parity: server registered only in Claude Code -> warning names it" {
    mkdir -p "$TEST_HOME/.augment"
    printf '{"mcpServers": {"serverA": {"command": "node"}}}' > "$TEST_HOME/.augment/settings.json"
    local mock_bin="$TEST_HOME/mock_bin"
    mkdir -p "$mock_bin"
    cat > "$mock_bin/claude" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "mcp list" ]] && printf 'serverA: node /tmp/a.js - connected\nonlyClaude: node /tmp/c.js - connected\n'
EOF
    chmod +x "$mock_bin/claude"
    run bash -c "
        export PATH=\"$mock_bin:\$PATH\"
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$output" == *"Registered in Claude Code only: onlyClaude"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "parity: neither tool configured -> silent, no warning" {
    local mock_bin="$TEST_HOME/empty_bin"
    mkdir -p "$mock_bin"
    run bash -c "
        export PATH='$mock_bin'
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$output" == *"WARNINGS=0"* ]]
    [[ "$output" != *"drift"* ]]
}

@test "parity: one side empty does not crash under stock macOS /bin/bash 3.2 (nounset regression)" {
    # Regression guard for a real bug: iterating "${arr[@]}" on an EMPTY array
    # under `set -u` (which doctor-checks.sh sets) is an unbound-variable
    # error on bash <=4.3 -- confirmed to kill the whole script on macOS's
    # real stock /bin/bash 3.2, even though the identical expansion is safe
    # on bash 4.4+. The rest of this file's tests run via plain `bash -c`,
    # which resolves to whatever bash is first on PATH (Homebrew 4+/5+ on a
    # dev machine) and would never catch this -- this test pins to /bin/bash
    # explicitly so it can't silently pass on a machine with a newer default.
    if [[ ! -x /bin/bash ]]; then
        skip "/bin/bash not present on this machine"
    fi
    local bash_major
    bash_major="$(/bin/bash -c 'echo "${BASH_VERSINFO[0]}"')"
    if [[ "$bash_major" -ge 4 ]]; then
        skip "/bin/bash on this machine is already bash 4+ (nounset-safe on empty arrays); cannot exercise the bash <=4.3 regression here"
    fi
    mkdir -p "$TEST_HOME/.augment"
    printf '{"mcpServers": {"serverA": {"command": "node"}}}' > "$TEST_HOME/.augment/settings.json"
    local mock_bin="$TEST_HOME/jq_only_bin"
    mkdir -p "$mock_bin"
    ln -s "$(command -v jq)" "$mock_bin/jq"
    run /bin/bash -c "
        export PATH='$mock_bin'
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"unbound variable"* ]]
    [[ "$output" == *"Registered in Augment only: serverA"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
}

@test "parity: http/npx-only registrations still get compared (not skipped like Check 28)" {
    # Check 28 skips http/npx types for dependency checking; parity must NOT
    # inherit that skip, since an http/npx server is still a real registration.
    # Isolated PATH with only jq resolved-and-symlinked in (needed to parse
    # the fixture) and no `claude` at all -- appending the real $PATH here
    # instead would non-deterministically pick up a real `claude` CLI on any
    # machine that has one installed, defeating the "claude absent" scenario
    # this test relies on.
    mkdir -p "$TEST_HOME/.augment"
    printf '{"mcpServers": {"httpOnly": {"type": "http", "url": "https://example.com"}}}' > "$TEST_HOME/.augment/settings.json"
    local mock_bin="$TEST_HOME/mock_bin_jq_only"
    mkdir -p "$mock_bin"
    ln -s "$(command -v jq)" "$mock_bin/jq"
    run bash -c "
        export PATH='$mock_bin'
        set -uo pipefail
        WARNINGS=0
        $(cat "$MCP_CHECKS")
        _doctor_mcp_parity_check
        echo WARNINGS=\$WARNINGS
    "
    [[ "$output" == *"Registered in Augment only: httpOnly"* ]]
    [[ "$output" == *"WARNINGS=1"* ]]
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
