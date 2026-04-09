# shellcheck shell=bash
# doctor-modules/mcp-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_mcp_checks() {
# --- Check 28: MCP Server Dependencies ---
# Validates that configured MCP servers have their local dependencies intact.
# Checks Augment settings.json and Claude Code config for stdio-based servers.
# Skips HTTP/SSE servers (remote) and npx-based servers (ephemeral).
# Reports missing node_modules or missing global binaries.
# Does NOT log env vars or secrets — only server names and commands.

local augment_settings="${HOME}/.augment/settings.json"
local found_any=false
local issues=0

# Ensure helper cleanup runs on all exit paths (normal return, early return)
trap 'unset -f _check_mcp_server 2>/dev/null' RETURN

# --- Helper: check a single MCP server entry ---
_check_mcp_server() {
  local name="$1" command="$2" first_arg="${3:-}"

  # Skip npx-based servers (ephemeral, downloaded on demand)
  [[ "$command" == "npx" ]] && return 0

  # Global binary: verify it exists on PATH
  if [[ "$command" != "node" && "$command" != /* ]]; then
    if ! command -v "$command" &>/dev/null; then
      echo "🟠 ERROR: MCP server '${name}' — command not found: ${command}"
      echo "   Suggestion: reinstall the package (e.g., npm install -g <package>)"
      ERRORS=$((ERRORS + 1))
      issues=$((issues + 1))
    fi
    return 0
  fi

  # node + absolute path: extract the server directory and check node_modules
  if [[ "$command" == "node" && "$first_arg" == /* ]]; then
    local server_dir
    server_dir=$(dirname "$first_arg")

    # Walk up to find package.json (build/ → parent)
    if [[ ! -f "$server_dir/package.json" && -f "$(dirname "$server_dir")/package.json" ]]; then
      server_dir=$(dirname "$server_dir")
    fi

    if [[ -f "$server_dir/package.json" ]]; then
      if [[ ! -d "$server_dir/node_modules" ]] || \
         [[ ! -f "$server_dir/node_modules/.package-lock.json" ]]; then
        echo "🟠 ERROR: MCP server '${name}' — node_modules missing at ${server_dir}"
        # Check if install.sh --repair is available
        local repo_dir
        repo_dir=$(dirname "$server_dir")
        if [[ -f "$repo_dir/install.sh" ]]; then
          echo "   Fix: '${repo_dir}/install.sh' --repair ${name}"
        else
          echo "   Fix: cd '${server_dir}' && npm install"
        fi
        ERRORS=$((ERRORS + 1))
        issues=$((issues + 1))
      fi
    fi

    # Also verify the entry point file exists
    if [[ ! -f "$first_arg" ]]; then
      echo "🟠 ERROR: MCP server '${name}' — entry point not found: ${first_arg}"
      ERRORS=$((ERRORS + 1))
      issues=$((issues + 1))
    fi
    return 0
  fi

  # Absolute path command (not node): verify binary exists
  if [[ "$command" == /* && ! -x "$command" ]]; then
    echo "🟠 ERROR: MCP server '${name}' — binary not found: ${command}"
    ERRORS=$((ERRORS + 1))
    issues=$((issues + 1))
  fi
}
# NOTE: _check_mcp_server leaks to global function namespace; cleaned up at end of _doctor_mcp_checks

# --- Source 1: Augment settings.json ---
if [[ -f "$augment_settings" ]] && command -v jq &>/dev/null; then
  local server_names
  server_names=$(jq -r '.mcpServers // {} | to_entries[]
    | select(.value.type != "http" and .value.type != "sse")
    | .key' "$augment_settings" 2>/dev/null || true)

  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    found_any=true
    local cmd first_arg
    cmd=$(jq -r --arg n "$name" '.mcpServers[$n].command // empty' "$augment_settings" 2>/dev/null || true)
    first_arg=$(jq -r --arg n "$name" '.mcpServers[$n].args[0] // empty' "$augment_settings" 2>/dev/null || true)
    [[ -z "$cmd" ]] && continue
    _check_mcp_server "$name" "$cmd" "$first_arg"
  done <<< "$server_names"
fi

# --- Source 2: Claude Code (if available) ---
# Format: "name: npx @pkg args - status" or "name: https://... (HTTP) - status"
# or "claude.ai Name: https://... - status"
# We only check stdio servers with node/absolute-path commands (not npx, not HTTP).
if command -v claude &>/dev/null; then
  local claude_list claude_parsed=0 claude_seen=0
  # Use timeout if available (coreutils); fall back to raw invocation on stock macOS
  if command -v timeout &>/dev/null; then
    claude_list=$(timeout 5 claude mcp list 2>/dev/null || true)
  else
    claude_list=$(claude mcp list 2>/dev/null || true)
  fi
  if [[ -n "$claude_list" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # Skip status header line
      [[ "$line" == "Checking"* ]] && continue
      # Skip lines without a colon (unexpected format)
      [[ "$line" != *:* ]] && continue
      local cname crest
      cname="${line%%:*}"
      # Strip "claude.ai " prefix if present (e.g., "claude.ai ServerName: ...")
      cname="${cname#claude.ai }"
      crest="${line#*: }"
      claude_seen=$((claude_seen + 1))
      # Skip HTTP/SSE servers
      [[ "$crest" == http* ]] && continue
      # Skip npx-based servers (ephemeral)
      [[ "$crest" == npx\ * ]] && continue
      # Skip if already checked via Augment
      if command -v jq &>/dev/null && [[ -f "$augment_settings" ]] && \
         jq -e --arg n "$cname" '.mcpServers[$n]' "$augment_settings" >/dev/null 2>&1; then
        continue
      fi
      # Extract the command (first word before " - " status suffix)
      local ccmd
      ccmd="${crest%% - *}"       # strip status
      ccmd="${ccmd%% *}"          # first word = command
      [[ -z "$ccmd" ]] && continue
      found_any=true
      claude_parsed=$((claude_parsed + 1))
      _check_mcp_server "$cname" "$ccmd"
    done <<< "$claude_list"
    # Warn only if output contained server-like lines but none were parseable
    # (all being filtered as http/npx is normal — not a format change)
    if [[ "$claude_parsed" -eq 0 && "$claude_seen" -eq 0 ]]; then
      echo "⚠️  Claude MCP list returned output but no servers were parsed — format may have changed"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
fi

if [[ "$found_any" == false ]]; then
  return 0  # No MCP config found — nothing to check, not a warning
fi

if [[ "$issues" -eq 0 ]]; then
  echo "✅ MCP server dependencies intact"
fi
# trap RETURN handles unset -f _check_mcp_server
}
