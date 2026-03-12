#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-hooks.sh
# PURPOSE: Install git hooks for the superpowers-plus repository
# USAGE: ./tools/install-hooks.sh
# -----------------------------------------------------------------------------
set -euo pipefail

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

echo ""
echo "Done! The following hooks are now active:"
echo "  • pre-commit: Validates file endings, shell syntax, JSON syntax"
echo ""
echo "To bypass hooks (not recommended): git commit --no-verify"
echo ""
