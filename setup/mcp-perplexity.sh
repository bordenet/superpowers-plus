#!/bin/bash
#
# mcp-perplexity.sh - Configure Perplexity MCP server for AI assistants
#
# This script configures the Perplexity MCP server for:
# - Claude Desktop (macOS)
# - Claude Code CLI
# - Augment Code (manual instructions)
#
# Usage: ./mcp-perplexity.sh
#
# Requires: PERPLEXITY_API_KEY environment variable or interactive prompt
#
# Get your API key from: https://www.perplexity.ai/settings/api
#

set -euo pipefail

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
MCP_PACKAGE="@perplexity-ai/mcp-server"

echo ""
echo -e "${BOLD}Perplexity MCP Server Setup${NC}"
echo "================================"
echo ""

# Get API key
if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
    echo -e "${YELLOW}Get your API key from:${NC} https://www.perplexity.ai/settings/api"
    echo ""
    read -sp "Enter your Perplexity API key: " PERPLEXITY_API_KEY
    echo ""
    echo ""
fi

if [[ -z "$PERPLEXITY_API_KEY" ]]; then
    log_error "API key is required"
    exit 1
fi

# Track what was configured
configured=()

# --- Claude Desktop ---
configure_claude_desktop() {
    log_info "Checking for Claude Desktop..."
    
    if [[ ! -d "/Applications/Claude.app" ]]; then
        log_warn "Claude Desktop not found at /Applications/Claude.app"
        return 1
    fi
    
    log_info "Configuring Claude Desktop..."
    
    # Create config directory if needed
    mkdir -p "$(dirname "$CLAUDE_DESKTOP_CONFIG")"
    
    # Create or update config
    if [[ -f "$CLAUDE_DESKTOP_CONFIG" ]]; then
        # Backup existing config
        cp "$CLAUDE_DESKTOP_CONFIG" "${CLAUDE_DESKTOP_CONFIG}.backup"
        
        # Add perplexity to existing config using Python
        python3 << EOF
import json
import sys

config_path = "$CLAUDE_DESKTOP_CONFIG"
api_key = "$PERPLEXITY_API_KEY"

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['perplexity'] = {
    "command": "npx",
    "args": ["-y", "$MCP_PACKAGE"],
    "env": {
        "PERPLEXITY_API_KEY": api_key
    }
}

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("Config updated successfully")
EOF
    else
        # Create new config
        cat > "$CLAUDE_DESKTOP_CONFIG" << EOF
{
  "mcpServers": {
    "perplexity": {
      "command": "npx",
      "args": ["-y", "$MCP_PACKAGE"],
      "env": {
        "PERPLEXITY_API_KEY": "$PERPLEXITY_API_KEY"
      }
    }
  }
}
EOF
    fi
    
    log_success "Claude Desktop configured"
    configured+=("Claude Desktop")
}

# --- Claude Code CLI ---
configure_claude_code() {
    log_info "Checking for Claude Code CLI..."
    
    if ! command -v claude &> /dev/null; then
        log_warn "Claude Code CLI not found"
        return 1
    fi
    
    log_info "Configuring Claude Code CLI..."
    
    # Use claude mcp add command with environment variable
    PERPLEXITY_API_KEY="$PERPLEXITY_API_KEY" claude mcp add perplexity \
        npx "$MCP_PACKAGE" \
        --scope user \
        --env PERPLEXITY_API_KEY="$PERPLEXITY_API_KEY" 2>/dev/null || {
        log_warn "Failed to add via claude mcp add - may already exist"
        return 1
    }
    
    log_success "Claude Code CLI configured"
    configured+=("Claude Code CLI")
}

# --- Augment Code ---
print_augment_instructions() {
    echo ""
    echo -e "${BOLD}Augment Code Configuration${NC}"
    echo "----------------------------"
    echo ""
    echo "To configure Perplexity MCP for Augment Code:"
    echo ""
    echo "1. Open VS Code Command Palette (Cmd+Shift+P)"
    echo "2. Search for 'Augment: Edit MCP Server Configuration'"
    echo "3. Add this configuration:"
    echo ""
    echo -e "${BLUE}{"
    echo '  "perplexity": {'
    echo '    "command": "npx",'
    echo '    "args": ["-y", "@perplexity-ai/mcp-server"],'
    echo '    "env": {'
    echo "      \"PERPLEXITY_API_KEY\": \"<your-api-key>\""
    echo '    }'
    echo '  }'
    echo -e "}${NC}"
    echo ""
}

# --- Main ---
main() {
    # Configure Claude Desktop
    configure_claude_desktop || true

    # Configure Claude Code CLI
    configure_claude_code || true

    # Print Augment instructions
    print_augment_instructions

    # Summary
    echo ""
    echo -e "${BOLD}Summary${NC}"
    echo "-------"
    if [[ ${#configured[@]} -gt 0 ]]; then
        echo -e "${GREEN}Configured:${NC}"
        for item in "${configured[@]}"; do
            echo "  ✓ $item"
        done
    else
        log_warn "No automatic configuration was performed"
    fi
    echo ""
    echo "Note: You may need to restart your AI assistant for changes to take effect."
    echo ""
    echo -e "${YELLOW}Security reminder:${NC} Your API key has been stored in local config files."
    echo "Do not commit these files to version control."
    echo ""
}

main

