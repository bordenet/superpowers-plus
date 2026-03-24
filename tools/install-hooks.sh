#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-hooks.sh
# PURPOSE: Install git hooks for the superpowers-plus repository
# USAGE: ./tools/install-hooks.sh
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELP'
install-hooks.sh — Install git hooks for superpowers-plus

USAGE
  ./tools/install-hooks.sh

DESCRIPTION
  Installs pre-commit hook to .git/hooks/ that validates file endings,
  shell syntax, and JSON syntax before each commit. Backs up any
  existing pre-commit hook to .bak.

  To bypass: git commit --no-verify
HELP
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo ""
echo "Installing git hooks for superpowers-plus..."
echo ""

# Ensure .git/hooks exists
mkdir -p "$HOOKS_DIR"

# Install pre-commit hook
if [[ -f "$HOOKS_DIR/pre-commit" ]]; then
    echo "⚠️  Existing pre-commit hook found. Backing up to pre-commit.bak"
    mv "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/pre-commit.bak"
fi

cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Installed pre-commit hook"

# Install pre-push hook
if [[ -f "$HOOKS_DIR/pre-push" ]]; then
    echo "⚠️  Existing pre-push hook found. Backing up to pre-push.bak"
    mv "$HOOKS_DIR/pre-push" "$HOOKS_DIR/pre-push.bak"
fi

cp "$SCRIPT_DIR/pre-push" "$HOOKS_DIR/pre-push"
chmod +x "$HOOKS_DIR/pre-push"
echo "✓ Installed pre-push hook"

echo ""
echo "Done! The following hooks are now active:"
echo "  • pre-commit: Validates file endings, shell syntax, JSON syntax, IP scan"
echo "  • pre-push: Scans unpushed commits for proprietary IP"
echo ""
echo "To bypass hooks (not recommended): git commit --no-verify"
echo ""
