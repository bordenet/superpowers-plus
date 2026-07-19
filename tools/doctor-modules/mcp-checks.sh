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
      if [[ ! -d "$server_dir/node_modules" ]]; then
        echo "🟠 ERROR: MCP server '${name}' — node_modules missing at ${server_dir}"
        # Check if install.sh --repair is available
        local repo_dir
        repo_dir=$(dirname "$server_dir")
        if [[ -f "$repo_dir/install.sh" ]]; then
          echo "   Fix: '${repo_dir}/install.sh' --repair ${name}"
        else
          echo "   Fix: cd '${server_dir}' && npm install  (or yarn install / pnpm install)"
        fi
        ERRORS=$((ERRORS + 1))
        issues=$((issues + 1))
      elif [[ ! -f "$server_dir/node_modules/.package-lock.json" ]]; then
        # .package-lock.json only exists for npm ≥7; yarn/pnpm installs won't have it.
        # Warn (not error): normal for yarn/pnpm/npm<7, but could indicate interrupted install.
        echo "🟡 WARNING: MCP server '${name}' — no .package-lock.json (normal for yarn/pnpm/npm<7; verify install is complete)"
        WARNINGS=$((WARNINGS + 1))
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
# Single jq call extracts all server fields as TSV (O(1) processes vs O(N) prev).
# @tsv escapes tab/newline in values — safe since server names/paths never contain tabs.
if [[ -f "$augment_settings" ]] && command -v jq &>/dev/null; then
  local name cmd first_arg
  while IFS=$'\t' read -r name cmd first_arg; do
    [[ -z "$name" || -z "$cmd" ]] && continue
    found_any=true
    _check_mcp_server "$name" "$cmd" "$first_arg"
  done < <(jq -r '.mcpServers // {} | to_entries[]
    | select(.value.type != "http" and .value.type != "sse")
    | [.key, (.value.command // ""), (.value.args[0] // "")] | @tsv' \
    "$augment_settings" 2>/dev/null || true)
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

# Runs regardless of $found_any above: Check 28's flag only tracks servers
# that survived its http/sse/npx filtering, but a parity comparison cares
# about ALL registered names -- an install with only http/npx servers would
# otherwise silently skip this check too.
_doctor_mcp_parity_check

if [[ "$found_any" == false ]]; then
  return 0  # No MCP config found for dependency checking — not a warning
fi

if [[ "$issues" -eq 0 ]]; then
  echo "✅ MCP server dependencies intact"
fi
# trap RETURN handles unset -f _check_mcp_server
}

# --- Check 31: MCP Registration Parity Across Claude Code and Augment ---
# A server registered in one tool's config but silently absent from the
# other's is easy to miss -- you configure an MCP server while working in
# Claude Code, forget it needs a separate registration step for Augment (or
# vice versa), and only notice when a skill that depends on it behaves
# differently across the two agents. This is independent of Check 28's
# per-server dependency health above: it compares the two REGISTERED-NAME
# SETS directly (including http/sse/npx entries, which Check 28 intentionally
# skips for dependency purposes but which are still real registrations for
# parity purposes), and only reports asymmetry -- never blocks, never
# assumes one tool is the source of truth.
_doctor_mcp_parity_check() {
  local augment_settings="${HOME}/.augment/settings.json"
  local -a augment_names=() claude_names=()

  if [[ -f "$augment_settings" ]] && command -v jq &>/dev/null; then
    while IFS= read -r name; do
      [[ -n "$name" ]] && augment_names+=("$name")
    done < <(jq -r '.mcpServers // {} | keys[]' "$augment_settings" 2>/dev/null || true)
  fi

  if command -v claude &>/dev/null; then
    local claude_list
    if command -v timeout &>/dev/null; then
      claude_list=$(timeout 5 claude mcp list 2>/dev/null || true)
    else
      claude_list=$(claude mcp list 2>/dev/null || true)
    fi
    if [[ -n "$claude_list" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == "Checking"* ]] && continue
        [[ "$line" != *:* ]] && continue
        local cname="${line%%:*}"
        cname="${cname#claude.ai }"
        [[ -n "$cname" ]] && claude_names+=("$cname")
      done <<< "$claude_list"
    fi
  fi

  # Neither tool configured (or neither has any servers) — nothing to compare.
  [[ ${#augment_names[@]} -eq 0 && ${#claude_names[@]} -eq 0 ]] && return 0

  local -a augment_only=() claude_only=()
  local a c found

  # Guard each loop on non-empty array before expanding "${arr[@]}" -- under
  # `set -u` (which doctor-checks.sh sets) an empty array's expansion is an
  # unbound-variable error on bash <=4.3 (confirmed against macOS's stock
  # /bin/bash 3.2: it kills the whole script, not just this function), even
  # though the same expansion is safe on bash 4.4+. This is exactly the
  # common case where only one tool has any servers registered at all.
  if [[ ${#augment_names[@]} -gt 0 ]]; then
    for a in "${augment_names[@]}"; do
      found=false
      if [[ ${#claude_names[@]} -gt 0 ]]; then
        for c in "${claude_names[@]}"; do
          [[ "$a" == "$c" ]] && { found=true; break; }
        done
      fi
      [[ "$found" == false ]] && augment_only+=("$a")
    done
  fi

  if [[ ${#claude_names[@]} -gt 0 ]]; then
    for c in "${claude_names[@]}"; do
      found=false
      if [[ ${#augment_names[@]} -gt 0 ]]; then
        for a in "${augment_names[@]}"; do
          [[ "$c" == "$a" ]] && { found=true; break; }
        done
      fi
      [[ "$found" == false ]] && claude_only+=("$c")
    done
  fi

  if [[ ${#augment_only[@]} -eq 0 && ${#claude_only[@]} -eq 0 ]]; then
    echo "✅ MCP registration parity: Claude Code and Augment agree"
    return 0
  fi

  echo "🟡 WARNING: MCP registration drift between Claude Code and Augment:"
  if [[ ${#augment_only[@]} -gt 0 ]]; then
    echo "   Registered in Augment only: ${augment_only[*]}"
  fi
  if [[ ${#claude_only[@]} -gt 0 ]]; then
    echo "   Registered in Claude Code only: ${claude_only[*]}"
  fi
  echo "   This may be intentional (a tool-specific server) -- verify before adding the missing registration."
  WARNINGS=$((WARNINGS + 1))
}
