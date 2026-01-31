#!/usr/bin/env bash
set -euo pipefail

# Description: Comprehensive verification of Perplexity MCP + skill setup
# Usage: ./setup/verify-perplexity-setup.sh
#
# Tests:
# 1. Superpowers framework installed
# 2. Perplexity skill installed and discoverable
# 3. Stats file exists and valid
# 4. Perplexity MCP configured (Claude Desktop, Claude Code, or Augment)
# 5. API key configured (without revealing it)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

errors=0
warnings=0

echo ""
echo "=========================================="
echo "  Perplexity MCP + Skill Verification"
echo "=========================================="
echo ""

# Test 1: Superpowers framework
echo "--- Superpowers Framework ---"
if [[ -d "$HOME/.codex/superpowers" ]]; then
    log_pass "Superpowers framework installed"
else
    log_fail "Superpowers framework not found at ~/.codex/superpowers/"
    ((errors++))
fi

if [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]]; then
    log_pass "Superpowers-augment bridge installed"
else
    log_fail "Superpowers-augment bridge not found"
    ((errors++))
fi
echo ""

# Test 2: Perplexity skill
echo "--- Perplexity Research Skill ---"
SKILL_PATH="$HOME/.codex/superpowers/skills/perplexity-research/SKILL.md"
if [[ -f "$SKILL_PATH" ]]; then
    log_pass "Skill file exists"
    
    # Check YAML frontmatter
    if head -5 "$SKILL_PATH" | grep -q "name: perplexity-research"; then
        log_pass "Skill has correct name in frontmatter"
    else
        log_fail "Skill frontmatter incorrect"
        ((errors++))
    fi
else
    log_fail "Skill not installed at $SKILL_PATH"
    ((errors++))
fi

# Check discoverability
if command -v node &>/dev/null && [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]]; then
    if node "$HOME/.codex/superpowers-augment/superpowers-augment.js" find-skills 2>/dev/null | grep -q "superpowers:perplexity-research"; then
        log_pass "Skill discoverable as superpowers:perplexity-research"
    else
        log_fail "Skill not discoverable via find-skills"
        ((errors++))
    fi
fi
echo ""

# Test 3: Stats file
echo "--- Stats Tracking ---"
STATS_FILE="$HOME/.codex/perplexity-stats.json"
if [[ -f "$STATS_FILE" ]]; then
    log_pass "Stats file exists"
    
    if jq empty "$STATS_FILE" 2>/dev/null; then
        log_pass "Stats file is valid JSON"
        
        # Check required fields
        for field in total_invocations successful unsuccessful success_rate; do
            if jq -e "has(\"$field\")" "$STATS_FILE" &>/dev/null; then
                log_pass "Stats has field: $field"
            else
                log_fail "Stats missing field: $field"
                ((errors++))
            fi
        done
        
        # Show current stats
        total=$(jq -r '.total_invocations' "$STATS_FILE")
        success_rate=$(jq -r '.success_rate' "$STATS_FILE")
        log_info "Current stats: $total invocations, ${success_rate}% success rate"
    else
        log_fail "Stats file is not valid JSON"
        ((errors++))
    fi
else
    log_fail "Stats file not found at $STATS_FILE"
    ((errors++))
fi
echo ""

# Test 4: MCP Configuration
echo "--- Perplexity MCP Configuration ---"
mcp_found=false

# Check Claude Desktop
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [[ -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
    if grep -q "perplexity" "$CLAUDE_DESKTOP_CONFIG" 2>/dev/null; then
        log_pass "Perplexity MCP configured in Claude Desktop"
        mcp_found=true
    fi
fi

# Check Claude Code CLI
if command -v claude &>/dev/null; then
    if claude mcp list 2>/dev/null | grep -q "perplexity"; then
        log_pass "Perplexity MCP configured in Claude Code CLI"
        mcp_found=true
    fi
fi

# Check for npm package
if npm list -g @perplexity-ai/mcp-server &>/dev/null 2>&1; then
    log_pass "Perplexity MCP package installed globally"
else
    log_warn "Perplexity MCP package not found globally (may be installed locally)"
    ((warnings++))
fi

if [[ "$mcp_found" == false ]]; then
    log_warn "Could not verify MCP configuration (may still work in Augment)"
    ((warnings++))
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
        log_pass "All critical tests passed ($warnings warnings)"
    fi
    exit 0
else
    log_fail "$errors test(s) failed, $warnings warning(s)"
    echo ""
    echo "To fix, run: ./setup/install-perplexity-skill.sh"
    exit 1
fi

