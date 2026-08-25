#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031  # bats: @test bodies run in subshells; that's the point.
# Tests for setup/mcp-perplexity.sh and setup/verify-perplexity-setup.sh
# Focus: jq-based idempotent merge into settings.json, API key resolution
# priority, verifier exit codes, dry-run safety.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MCP_SETUP="$REPO_ROOT/setup/mcp-perplexity.sh"
VERIFY="$REPO_ROOT/setup/verify-perplexity-setup.sh"

setup() {
    TEST_HOME="$(mktemp -d)"
    export TEST_HOME HOME="$TEST_HOME"
    # Stub external tools that would touch real state
    STUB_BIN="$TEST_HOME/bin"
    mkdir -p "$STUB_BIN"
    cat > "$STUB_BIN/claude" <<'STUB'
#!/usr/bin/env bash
# claude CLI stub — records invocations, never touches real config
: "${CLAUDE_STUB_LOG:=/dev/null}"
echo "claude $*" >> "$CLAUDE_STUB_LOG"
if [[ "${1:-}" == "mcp" && "${2:-}" == "list" ]]; then
    cat "$TEST_HOME/claude-mcp-list.txt" 2>/dev/null || true
fi
exit 0
STUB
    chmod +x "$STUB_BIN/claude"
    export PATH="$STUB_BIN:$PATH"
    export CLAUDE_STUB_LOG="$TEST_HOME/claude.log"
    : > "$CLAUDE_STUB_LOG"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# ---------------------------------------------------------------------------
# mcp-perplexity.sh: idempotent jq merge into settings.json
# ---------------------------------------------------------------------------

@test "mcp-perplexity: creates Augment settings.json when absent" {
    export PERPLEXITY_API_KEY="test-key-abc123"
    run bash "$MCP_SETUP" --yes
    [ "$status" -eq 0 ]
    local cfg="$HOME/.augment/settings.json"
    [ -f "$cfg" ]
    run jq -r '.mcpServers.perplexity.command' "$cfg"
    [ "$output" = "npx" ]
    run jq -r '.mcpServers.perplexity.env.PERPLEXITY_API_KEY' "$cfg"
    [ "$output" = "test-key-abc123" ]
}

@test "mcp-perplexity: preserves existing unrelated keys in settings.json" {
    mkdir -p "$HOME/.augment"
    cat > "$HOME/.augment/settings.json" <<'JSON'
{
  "indexingAllowDirs": ["/some/dir"],
  "mcpServers": {
    "other-server": {"command": "node", "args": ["/path/file.js"]}
  }
}
JSON
    export PERPLEXITY_API_KEY="xyz"
    run bash "$MCP_SETUP" --yes
    [ "$status" -eq 0 ]
    local cfg="$HOME/.augment/settings.json"
    run jq -r '.indexingAllowDirs[0]' "$cfg"
    [ "$output" = "/some/dir" ]
    run jq -r '.mcpServers."other-server".command' "$cfg"
    [ "$output" = "node" ]
    run jq -r '.mcpServers.perplexity.command' "$cfg"
    [ "$output" = "npx" ]
}

@test "mcp-perplexity: --yes is idempotent (second run doesn't corrupt)" {
    export PERPLEXITY_API_KEY="k1"
    bash "$MCP_SETUP" --yes >/dev/null
    bash "$MCP_SETUP" --yes >/dev/null
    run jq -r '.mcpServers | length' "$HOME/.augment/settings.json"
    [ "$output" = "1" ]
}

@test "mcp-perplexity: refuses to overwrite corrupt JSON" {
    mkdir -p "$HOME/.augment"
    echo "{ this is not json" > "$HOME/.augment/settings.json"
    export PERPLEXITY_API_KEY="x"
    run bash "$MCP_SETUP" --yes
    # Script logs error for Augment but continues for other clients, then
    # verifier runs. Either way, the corrupt file is NOT overwritten.
    grep -q "this is not json" "$HOME/.augment/settings.json"
}

@test "mcp-perplexity: --dry-run writes nothing to disk" {
    export PERPLEXITY_API_KEY="k"
    run bash "$MCP_SETUP" --yes --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.augment/settings.json" ]
    [ ! -f "$HOME/.codex/.env" ]
}

# ---------------------------------------------------------------------------
# API key resolution priority: env > ~/.codex/.env > prompt
# ---------------------------------------------------------------------------

@test "mcp-perplexity: loads key from ~/.codex/.env when env var absent" {
    mkdir -p "$HOME/.codex"
    printf 'PERPLEXITY_API_KEY="from-env-file"\n' > "$HOME/.codex/.env"
    unset PERPLEXITY_API_KEY
    run bash "$MCP_SETUP" --yes
    [ "$status" -eq 0 ]
    run jq -r '.mcpServers.perplexity.env.PERPLEXITY_API_KEY' "$HOME/.augment/settings.json"
    [ "$output" = "from-env-file" ]
}

@test "mcp-perplexity: --yes without any key fails fast" {
    unset PERPLEXITY_API_KEY
    run bash "$MCP_SETUP" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"PERPLEXITY_API_KEY"* ]]
}

@test "mcp-perplexity: claude mcp add with silent-success output is reported as success" {
    # Regression: the pipeline `claude mcp add ... 2>&1 | grep -vE '^$'` would
    # return non-zero when claude succeeded silently, flagging a good add as
    # "may already exist". Stub writes nothing on 'add', exits 0.
    export PERPLEXITY_API_KEY="k-silent"
    run bash "$MCP_SETUP" --yes
    [ "$status" -eq 0 ]
    [[ "$output" != *"may already exist under a different scope"* ]]
    [[ "$output" == *"Claude Code CLI configured"* ]]
}

# ---------------------------------------------------------------------------
# verify-perplexity-setup.sh: exit codes + actionable messages
# ---------------------------------------------------------------------------

@test "verify: FAIL when nothing is installed" {
    run bash "$VERIFY"
    [ "$status" -ne 0 ]
    [[ "$output" == *"FAIL"* ]]
    [[ "$output" == *"./setup/mcp-perplexity.sh"* ]]
}

@test "verify: finds skill at ~/.agents/skills/sp-research/SKILL.md" {
    mkdir -p "$HOME/.agents/skills/sp-research"
    cat > "$HOME/.agents/skills/sp-research/SKILL.md" <<'MD'
---
name: sp-research
---
body
MD
    run bash "$VERIFY"
    [[ "$output" == *"PASS"* ]]
    [[ "$output" == *"sp-research/SKILL.md"* ]]
}

@test "verify: detects PERPLEXITY_API_KEY in ~/.codex/.env" {
    mkdir -p "$HOME/.codex"
    echo 'PERPLEXITY_API_KEY=abc' > "$HOME/.codex/.env"
    run bash "$VERIFY"
    [[ "$output" == *"PERPLEXITY_API_KEY resolvable"* ]]
}
