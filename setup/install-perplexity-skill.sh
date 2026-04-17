#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-perplexity-skill.sh
# PURPOSE: DEPRECATED thin wrapper kept for backwards compatibility. The
#          perplexity-research skill is now installed by the top-level
#          `install.sh`, and the Perplexity MCP server is configured by
#          `setup/mcp-perplexity.sh`. This script just runs both in order.
# USAGE: ./setup/install-perplexity-skill.sh [--verify-only]
# PLATFORM: macOS, Linux, WSL
# VERSION: 2.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELP'
install-perplexity-skill.sh — DEPRECATED thin wrapper

USAGE
  ./setup/install-perplexity-skill.sh [--verify-only]

OPTIONS
  --verify-only  Skip install; just run setup/verify-perplexity-setup.sh.
  --help         Show this help message.

DESCRIPTION
  Deprecated. The perplexity-research skill is deployed by the main
  install.sh; the Perplexity MCP server is configured by setup/mcp-perplexity.sh.
  This wrapper chains both for backwards compatibility with older
  instructions and documentation.

  Preferred workflow:
    bash install.sh
    bash setup/mcp-perplexity.sh
    bash setup/verify-perplexity-setup.sh
HELP
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

YELLOW='\033[1;33m'
NC='\033[0m'
printf '%b\n' "${YELLOW}[DEPRECATED]${NC} install-perplexity-skill.sh is a thin wrapper."
printf '%b\n' "${YELLOW}[DEPRECATED]${NC} Prefer:  bash install.sh && bash setup/mcp-perplexity.sh"
echo ""

if [[ "${1:-}" == "--verify-only" ]]; then
    exec bash "$SCRIPT_DIR/verify-perplexity-setup.sh"
fi

# Step 1: run the main installer if we're inside a superpowers-plus checkout
if [[ -x "$REPO_DIR/install.sh" ]]; then
    echo "=> Running $REPO_DIR/install.sh"
    bash "$REPO_DIR/install.sh" "$@"
else
    echo "WARNING: no install.sh found at $REPO_DIR; skipping skill deployment." >&2
fi

# Step 2: configure the MCP server across all detected clients.
# mcp-perplexity.sh runs verify-perplexity-setup.sh in its main(); no separate
# verify step needed here. Flags are propagated so `--yes`, `--dry-run`, etc.
# reach the real implementation.
if [[ -x "$SCRIPT_DIR/mcp-perplexity.sh" ]]; then
    echo "=> Running $SCRIPT_DIR/mcp-perplexity.sh $*"
    bash "$SCRIPT_DIR/mcp-perplexity.sh" "$@"
fi
