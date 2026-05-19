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
  Installs the repo's pre-commit and pre-push hooks into .git/hooks/.
  Backs up any existing hook to a matching .bak file before replacement.

  To bypass: git commit --no-verify
HELP
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: $REPO_ROOT is not a git repository" >&2
  exit 1
fi
HOOKS_DIR="$(git -C "$REPO_ROOT" rev-parse --git-path hooks)"

echo ""
echo "Installing git hooks for superpowers-plus..."
echo ""

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Ensure review token directory exists
REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
mkdir -p "$REVIEW_TOKEN_DIR"
echo "✓ Review token directory ready: $REVIEW_TOKEN_DIR"

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

# Install commit-msg hook (ASCII enforcement + auto-conversion)
if [[ -f "$HOOKS_DIR/commit-msg" ]]; then
    echo "⚠️  Existing commit-msg hook found. Backing up to commit-msg.bak"
    mv "$HOOKS_DIR/commit-msg" "$HOOKS_DIR/commit-msg.bak"
fi

cp "$SCRIPT_DIR/commit-msg" "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/commit-msg"
echo "✓ Installed commit-msg hook"

echo ""
echo "Done! The following hooks are now active:"
echo "  • pre-commit: sentinel presence, file endings, shell syntax (incl. extensionless hooks),"
echo "                JSON validity, IP scan, review token"
echo "  • pre-push:   sentinel SHA must match HEAD + proprietary IP scan"
echo "  • commit-msg: auto-converts em dashes/arrows to ASCII; rejects any remaining non-ASCII"
echo ""
echo "Before your FIRST commit (bootstrap):"
echo "  1. Run code-review-battery          — writes .code-review-cleared sentinel"
echo "  2. Run 'bash tools/commit-gate.sh'  — lint/test/harsh-review + mints review token"
echo "  3. git commit                        — pre-commit verifies sentinel + consumes token"
echo ""
echo "Subsequent commits (sentinel already present):"
echo "  1. Run 'bash tools/commit-gate.sh'  — mints a fresh review token"
echo "  2. git commit                        — pre-commit verifies sentinel + consumes token"
echo ""
echo "Before pushing:"
echo "  1. Run code-review-battery          — refreshes .code-review-cleared with HEAD SHA"
echo "  2. git push                          — pre-push verifies sentinel SHA matches HEAD"
echo ""
echo "Token directory: ~/.codex/review-tokens/"
echo "To bypass (not recommended): git commit --no-verify / git push --no-verify"
echo ""
