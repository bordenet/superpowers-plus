#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: verify-perplexity-setup.sh
# PURPOSE: Comprehensive verification of Perplexity MCP + skill setup.
#          Tests superpowers framework, skill installation, stats file, MCP
#          configuration, and API key presence (without revealing it).
# USAGE: ./setup/verify-perplexity-setup.sh
# PLATFORM: macOS, Linux, WSL
# VERSION: 1.0.0
# TESTS:
#   1. Superpowers framework installed
#   2. Perplexity skill installed and discoverable
#   3. Stats file exists and valid
#   4. Perplexity MCP configured (Claude Desktop, Claude Code, or Augment)
#   5. API key configured (without revealing it)
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELP'
verify-perplexity-setup.sh — Verify Perplexity MCP + skill setup

USAGE
  ./setup/verify-perplexity-setup.sh

DESCRIPTION
  Runs 5 verification tests:
    1. Superpowers framework installed
    2. Perplexity skill installed and discoverable
    3. Stats file exists and valid
    4. Perplexity MCP configured (Claude Desktop, Claude Code, or Augment)
    5. API key configured (without revealing it)
HELP
  exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() { printf '%b\n' "${GREEN}[PASS]${NC} $1"; }
log_fail() { printf '%b\n' "${RED}[FAIL]${NC} $1"; }
log_warn() { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
log_info() { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }

errors=0
warnings=0

echo ""
echo "=========================================="
echo "  Perplexity MCP + Skill Verification"
echo "=========================================="
echo ""

# Test 1: Superpowers framework
echo "--- Superpowers Framework ---"
if [[ -d "$HOME/.codex/superpowers-plus" ]]; then
    log_pass "Superpowers framework installed"
else
    log_fail "Superpowers framework not found at ~/.codex/superpowers-plus"
    errors=$((errors + 1))
fi

if [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]]; then
    log_pass "Superpowers-augment bridge installed"
else
    log_fail "Superpowers-augment bridge not found"
    errors=$((errors + 1))
fi
echo ""

# Test 2: Perplexity skill (check every modern deployment target; any one passes)
echo "--- Perplexity Research Skill ---"
# Order matters: first hit wins the display. The `sp-research` name is what
# install.sh produces when deploying to ~/.agents/skills/ (augment_menu export).
SKILL_CANDIDATES=(
    "$HOME/.agents/skills/sp-research/SKILL.md"
    "$HOME/.codex/skills/perplexity-research/skill.md"
    "$HOME/.codex/skills/perplexity-research/SKILL.md"
    "$HOME/.claude/skills/perplexity-research/skill.md"
    "$HOME/.claude/skills/perplexity-research/SKILL.md"
)
found_skill_path=""
for candidate in "${SKILL_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
        found_skill_path="$candidate"
        break
    fi
done

if [[ -n "$found_skill_path" ]]; then
    log_pass "Skill file found at $found_skill_path"
    # Accept either the canonical 'perplexity-research' or the slash-menu
    # rename 'sp-research'; both are valid per lib/install/deploy.sh.
    if head -10 "$found_skill_path" | grep -qE '^name:[[:space:]]*(perplexity-research|sp-research)[[:space:]]*$'; then
        log_pass "Skill frontmatter has expected name"
    else
        log_fail "Skill frontmatter name is neither perplexity-research nor sp-research"
        errors=$((errors + 1))
    fi
else
    log_fail "Skill not installed at any known path:"
    for candidate in "${SKILL_CANDIDATES[@]}"; do echo "        $candidate"; done
    echo "        Fix: run  bash install.sh  from the superpowers-plus repo root"
    if [[ -d "$HOME/.codex/superpowers/skills" ]]; then
        log_warn "Found legacy v2.5 path ~/.codex/superpowers/skills -- run install.sh to migrate to v2.6+"
        warnings=$((warnings + 1))
    fi
    errors=$((errors + 1))
fi

# Check discoverability via superpowers-augment.js. Anchor the match so
# hypothetical suffixes like `perplexity-research-extra` don't pass.
if command -v node &>/dev/null && [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]]; then
    if node "$HOME/.codex/superpowers-augment/superpowers-augment.js" find-skills 2>/dev/null \
            | grep -qE '(^|[^A-Za-z0-9_-])(superpowers:)?(perplexity-research|sp-research)([^A-Za-z0-9_-]|$)'; then
        log_pass "Skill discoverable via superpowers-augment find-skills"
    else
        log_fail "Skill not discoverable via find-skills"
        errors=$((errors + 1))
    fi
fi
echo ""

# Test 3: Stats file
echo "--- Stats Tracking ---"
STATS_FILE="$HOME/.codex/perplexity-stats.json"
STATS_INIT_HINT="scripts/perplexity-stats.sh show   # initializes the stats file"
# `jq empty` passes on a 0-byte file (no input = no error), so we also assert
# the file has content and parses to an object. An empty/corrupt file gets a
# single actionable error rather than a cascade of "missing field" failures.
if [[ ! -f "$STATS_FILE" ]]; then
    log_fail "Stats file not found at $STATS_FILE"
    echo "        Fix: $STATS_INIT_HINT"
    errors=$((errors + 1))
elif [[ ! -s "$STATS_FILE" ]] || ! jq -e 'type == "object"' "$STATS_FILE" &>/dev/null; then
    log_fail "Stats file at $STATS_FILE is empty or not a JSON object"
    echo "        Fix: $STATS_INIT_HINT"
    errors=$((errors + 1))
else
    log_pass "Stats file exists and is a JSON object"
    missing_fields=()
    for field in total_invocations successful unsuccessful success_rate; do
        if jq -e "has(\"$field\")" "$STATS_FILE" &>/dev/null; then
            log_pass "Stats has field: $field"
        else
            missing_fields+=("$field")
        fi
    done
    if (( ${#missing_fields[@]} > 0 )); then
        log_fail "Stats missing fields: ${missing_fields[*]}"
        echo "        Fix: $STATS_INIT_HINT"
        errors=$((errors + 1))
    else
        total=$(jq -r '.total_invocations' "$STATS_FILE")
        success_rate=$(jq -r '.success_rate' "$STATS_FILE")
        log_info "Current stats: $total invocations, ${success_rate}% success rate"
    fi
fi
echo ""

# Test 4: MCP configuration — must find the server in at least one client
echo "--- Perplexity MCP Configuration ---"
mcp_found=false

# Reusable jq probe: returns 0 iff .mcpServers.perplexity exists and is an object
_has_perplexity_server() {
    local cfg="$1"
    [[ -f "$cfg" ]] || return 1
    command -v jq &>/dev/null || return 1
    jq -e '.mcpServers.perplexity | type == "object"' "$cfg" &>/dev/null
}

# Claude Desktop
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if _has_perplexity_server "$CLAUDE_DESKTOP_CONFIG"; then
    log_pass "Perplexity MCP configured in Claude Desktop"
    mcp_found=true
elif [[ -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
    log_warn "Claude Desktop config present but lacks .mcpServers.perplexity"
    warnings=$((warnings + 1))
fi

# Claude Code CLI
if command -v claude &>/dev/null; then
    if claude mcp list 2>/dev/null | grep -qE '^[[:space:]]*perplexity[[:space:]]*:'; then
        log_pass "Perplexity MCP configured in Claude Code CLI"
        mcp_found=true
    fi
fi

# Augment Code
AUGMENT_SETTINGS="$HOME/.augment/settings.json"
if _has_perplexity_server "$AUGMENT_SETTINGS"; then
    log_pass "Perplexity MCP configured in Augment Code ($AUGMENT_SETTINGS)"
    mcp_found=true
elif [[ -f "$AUGMENT_SETTINGS" ]]; then
    log_warn "Augment settings.json present but lacks .mcpServers.perplexity"
    warnings=$((warnings + 1))
fi

if [[ "$mcp_found" == false ]]; then
    log_fail "Perplexity MCP not configured in any detected client"
    echo "        Fix: ./setup/mcp-perplexity.sh"
    errors=$((errors + 1))
fi
echo ""

# Test 5: API key resolvable
echo "--- Perplexity API Key ---"
key_source=""
if [[ -n "${PERPLEXITY_API_KEY:-}" ]]; then
    key_source="environment"
elif [[ -f "$HOME/.codex/.env" ]] && \
     grep -qE '^[[:space:]]*(export[[:space:]]+)?PERPLEXITY_API_KEY[[:space:]]*=' "$HOME/.codex/.env"; then
    key_source="$HOME/.codex/.env"
fi
if [[ -n "$key_source" ]]; then
    log_pass "PERPLEXITY_API_KEY resolvable (source: $key_source)"
else
    log_fail "PERPLEXITY_API_KEY not set in environment or ~/.codex/.env"
    echo "        Fix: ./setup/mcp-perplexity.sh  (will prompt and persist)"
    errors=$((errors + 1))
fi
echo ""

# Summary
echo "=========================================="
echo "  Summary"
echo "=========================================="
if [[ $errors -eq 0 ]]; then
    if [[ $warnings -eq 0 ]]; then
        log_pass "All tests passed! Perplexity integration is ready."
    else
        log_pass "All critical tests passed ($warnings warning(s))"
    fi
    exit 0
else
    log_fail "$errors test(s) failed, $warnings warning(s)"
    echo ""
    echo "To fix, run: ./setup/mcp-perplexity.sh"
    exit 1
fi
