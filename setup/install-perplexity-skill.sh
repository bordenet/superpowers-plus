#!/usr/bin/env bash
set -euo pipefail

# Description: Install the perplexity-research skill to ~/.codex/superpowers/skills/
# Usage: ./setup/install-perplexity-skill.sh [--verify-only]
#
# This script:
# 1. Creates the skill directory structure
# 2. Copies the skill file
# 3. Initializes the stats file (if not exists)
# 4. Runs verification tests
#
# Prerequisites:
# - superpowers framework installed (~/.codex/superpowers/)
# - Perplexity MCP server configured (run setup/mcp-perplexity.sh first)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_SOURCE="$REPO_DIR/skills/perplexity-research/SKILL.md"
SKILL_DEST_DIR="$HOME/.codex/superpowers/skills/perplexity-research"
STATS_FILE="$HOME/.codex/perplexity-stats.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

verify_only=false
if [[ "${1:-}" == "--verify-only" ]]; then
    verify_only=true
fi

# Verification function
run_verification() {
    local errors=0
    
    echo ""
    echo "=== Verification Tests ==="
    echo ""
    
    # Test 1: Skill file exists
    if [[ -f "$SKILL_DEST_DIR/SKILL.md" ]]; then
        log_info "✓ Skill file exists at $SKILL_DEST_DIR/SKILL.md"
    else
        log_error "✗ Skill file not found at $SKILL_DEST_DIR/SKILL.md"
        ((errors++))
    fi
    
    # Test 2: Stats file exists and is valid JSON
    if [[ -f "$STATS_FILE" ]]; then
        if jq empty "$STATS_FILE" 2>/dev/null; then
            log_info "✓ Stats file exists and is valid JSON"
        else
            log_error "✗ Stats file exists but is not valid JSON"
            ((errors++))
        fi
    else
        log_error "✗ Stats file not found at $STATS_FILE"
        ((errors++))
    fi
    
    # Test 3: Skill is discoverable via superpowers
    if command -v node &>/dev/null && [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]]; then
        if node "$HOME/.codex/superpowers-augment/superpowers-augment.js" find-skills 2>/dev/null | grep -q "perplexity-research"; then
            log_info "✓ Skill is discoverable via superpowers:perplexity-research"
        else
            log_error "✗ Skill not discoverable via superpowers framework"
            ((errors++))
        fi
    else
        log_warn "⚠ Cannot verify skill discovery (superpowers-augment not found)"
    fi
    
    # Test 4: Stats file has required fields
    if [[ -f "$STATS_FILE" ]]; then
        local required_fields=("total_invocations" "successful" "unsuccessful" "success_rate" "by_trigger" "by_tool" "recent")
        for field in "${required_fields[@]}"; do
            if jq -e "has(\"$field\")" "$STATS_FILE" &>/dev/null; then
                log_info "✓ Stats file has required field: $field"
            else
                log_error "✗ Stats file missing required field: $field"
                ((errors++))
            fi
        done
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_info "=== All verification tests passed ==="
        return 0
    else
        log_error "=== $errors verification test(s) failed ==="
        return 1
    fi
}

# If verify-only, just run verification
if [[ "$verify_only" == true ]]; then
    run_verification
    exit $?
fi

echo ""
echo "=== Installing perplexity-research skill ==="
echo ""

# Check prerequisites
if [[ ! -d "$HOME/.codex/superpowers" ]]; then
    log_error "Superpowers framework not found at ~/.codex/superpowers/"
    log_error "Please install superpowers first: https://github.com/obra/superpowers"
    exit 1
fi

if [[ ! -f "$SKILL_SOURCE" ]]; then
    log_error "Skill source not found at $SKILL_SOURCE"
    log_error "Please run this script from the superpowers-plus repository"
    exit 1
fi

# Step 1: Create skill directory
log_info "Creating skill directory..."
mkdir -p "$SKILL_DEST_DIR"

# Step 2: Copy skill file
log_info "Copying skill file..."
cp "$SKILL_SOURCE" "$SKILL_DEST_DIR/SKILL.md"
log_info "Installed to: $SKILL_DEST_DIR/SKILL.md"

# Step 3: Initialize stats file (if not exists)
if [[ ! -f "$STATS_FILE" ]]; then
    log_info "Initializing stats file..."
    cat > "$STATS_FILE" << 'EOF'
{
  "total_invocations": 0,
  "successful": 0,
  "unsuccessful": 0,
  "success_rate": 0,
  "last_invocation": null,
  "by_trigger": {},
  "by_tool": {},
  "recent": []
}
EOF
    log_info "Created: $STATS_FILE"
else
    log_info "Stats file already exists, preserving existing data"
fi

# Step 4: Run verification
run_verification

echo ""
log_info "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Ensure Perplexity MCP is configured: ./setup/mcp-perplexity.sh"
echo "  2. Bootstrap superpowers in your AI session"
echo "  3. The skill will auto-invoke on 2+ failures or uncertainty"
echo ""

