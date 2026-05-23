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
  Installs the repo's pre-commit, pre-push, and commit-msg hooks into .git/hooks/.
  Backs up any existing hook to a matching .bak file on first install. On subsequent
  installs, if the currently installed hook diverges from BOTH the incoming source
  and the original .bak (i.e., user-layered modifications), the current hook is
  rotated to .bak.YYYYMMDD-HHMMSS before being overwritten. The original .bak is
  never replaced.

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

# Install a hook with safe-overwrite semantics:
#   - First install: rename existing hook to <name>.bak (preserves pre-superpowers state).
#   - Subsequent install on a hook whose content differs from BOTH the .bak and the
#     incoming source: rotate the current installed hook to <name>.bak.<timestamp>
#     so user-layered modifications (husky/lefthook overlays, ad-hoc edits) are not
#     silently lost. The original .bak is never overwritten.
install_hook() {
    local name="$1"
    local dest="$HOOKS_DIR/$name"
    local src="$SCRIPT_DIR/$name"
    local bak="$dest.bak"

    if [[ -f "$dest" ]] && [[ ! -f "$bak" ]]; then
        echo "⚠️  Existing $name hook found. Backing up to $name.bak"
        mv "$dest" "$bak"
    elif [[ -f "$dest" ]] && ! cmp -s "$dest" "$src"; then
        # Hook differs from incoming source. If it also differs from .bak, the user
        # has layered changes on top of the installed version — preserve them.
        if [[ ! -f "$bak" ]] || ! cmp -s "$dest" "$bak"; then
            local ts rotated
            ts=$(date +%Y%m%d-%H%M%S)
            rotated="$dest.bak.$ts"
            echo "⚠️  $name hook diverges from both source and .bak; rotating to $(basename "$rotated")"
            cp "$dest" "$rotated"
        fi
    fi

    cp "$src" "$dest"
    chmod +x "$dest"
    echo "✓ Installed $name hook"
}

install_hook pre-commit
install_hook pre-push
install_hook commit-msg

echo ""
echo "Done! The following hooks are now active:"
echo "  • pre-commit: sentinel presence, file endings, shell syntax (incl. extensionless hooks),"
echo "                JSON validity, IP scan, review token"
echo "  • pre-push:   sentinel SHA must match HEAD + proprietary IP scan"
echo "  • commit-msg: auto-converts em dashes/arrows to ASCII; rejects any remaining non-ASCII"
echo "                (requires python3 in PATH — install: brew install python3)"
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
