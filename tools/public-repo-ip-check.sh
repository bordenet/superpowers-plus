#!/usr/bin/env bash
# public-repo-ip-check.sh
#
# Audit a public repository for proprietary IP before commit/push.
# Part of the public-repo-ip-audit skill.
#
# Usage: ./public-repo-ip-check.sh [--patterns "REGEX"] [--history]
#
# Options:
#   --patterns "REGEX"  Custom pattern regex (default: generic patterns)
#   --history           Also check full git history (slower)
#
# Exit codes:
#   0 - PASS: No IP found
#   1 - FAIL: IP found
#   2 - ERROR: Script error

set -euo pipefail

# Default patterns (generic - customize for your organization)
DEFAULT_PATTERNS="INTERNAL-[0-9]+|internal\.company\.com|@company\.com"

PATTERNS="${DEFAULT_PATTERNS}"
CHECK_HISTORY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --patterns)
            PATTERNS="$2"
            shift 2
            ;;
        --history)
            CHECK_HISTORY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--patterns \"REGEX\"] [--history]"
            echo ""
            echo "Options:"
            echo "  --patterns \"REGEX\"  Custom pattern regex"
            echo "  --history           Also check full git history"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Public Repository IP Audit                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Patterns: ${PATTERNS:0:60}..."
echo ""

FAILED=false

# Check 1: Working tree
echo "▶ Checking working tree..."
if grep -rE "$PATTERNS" . 2>/dev/null | grep -v "\.git/" | grep -v "public-repo-ip-check.sh"; then
    echo "  ❌ FAIL: IP found in working tree"
    FAILED=true
else
    echo "  ✓ Working tree clean"
fi

# Check 2: Staged changes
echo "▶ Checking staged changes..."
if git diff --staged 2>/dev/null | grep -E "$PATTERNS"; then
    echo "  ❌ FAIL: IP found in staged changes"
    FAILED=true
else
    echo "  ✓ Staged changes clean"
fi

# Check 3: Unpushed commits (if remote exists)
echo "▶ Checking unpushed commits..."
if git remote get-url origin &>/dev/null; then
    if git log -p origin/main..HEAD 2>/dev/null | grep -E "$PATTERNS"; then
        echo "  ❌ FAIL: IP found in unpushed commits"
        FAILED=true
    else
        echo "  ✓ Unpushed commits clean"
    fi
else
    echo "  ⚠ No remote configured, skipping"
fi

# Check 4: Full history (optional, slow)
if [[ "$CHECK_HISTORY" == true ]]; then
    echo "▶ Checking full git history (this may take a while)..."
    HISTORY_MATCHES=$(git log --all --oneline | while read -r sha msg; do
        if git show "$sha" 2>/dev/null | grep -qE "$PATTERNS"; then
            echo "$sha"
        fi
    done)
    
    if [[ -n "$HISTORY_MATCHES" ]]; then
        echo "  ❌ FAIL: IP found in git history"
        echo "  Contaminated commits:"
        echo "$HISTORY_MATCHES" | head -10
        FAILED=true
    else
        echo "  ✓ Git history clean"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAILED" == true ]]; then
    echo "❌ AUDIT FAILED: Proprietary IP detected"
    echo ""
    echo "DO NOT commit or push until all issues are resolved."
    echo "See: skills/security/public-repo-ip-audit/skill.md"
    exit 1
else
    echo "✅ AUDIT PASSED: No proprietary IP detected"
    echo ""
    echo "Safe to commit and push."
    exit 0
fi
