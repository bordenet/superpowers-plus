#!/usr/bin/env bash
# public-repo-ip-check.sh
#
# Audit a public repository for proprietary IP before commit/push.
# Part of the public-repo-ip-audit skill.
#
# Usage: ./public-repo-ip-check.sh [--patterns "REGEX"] [--history] [--verbose]
#
# Options:
#   --patterns "REGEX"  Custom pattern regex (default: generic patterns)
#   --history           Also check full git history (slower)
#   --verbose           Show matching lines (CAUTION: may print sensitive identifiers)
#
# Exit codes:
#   0 - PASS: No IP found
#   1 - FAIL: IP found
#   2 - ERROR: Script error

set -euo pipefail

# Default patterns (generic - customize via --patterns flag or .ip-check-patterns file)
DEFAULT_PATTERNS="INTERNAL-[0-9]+|internal\.company\.com|@company\.com"

# Load org-specific patterns from local file (gitignored, never committed)
IP_PATTERNS_FILE=".ip-check-patterns"
if [[ -f "$IP_PATTERNS_FILE" ]]; then
    ORG_PATTERNS=$(grep -v '^#' "$IP_PATTERNS_FILE" | grep -v '^[[:space:]]*$' | tr '\n' '|')
    ORG_PATTERNS="${ORG_PATTERNS%|}"
    if [[ -n "$ORG_PATTERNS" ]]; then
        DEFAULT_PATTERNS="${DEFAULT_PATTERNS}|${ORG_PATTERNS}"
    fi
fi

PATTERNS="${DEFAULT_PATTERNS}"
CHECK_HISTORY=false
VERBOSE=false

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
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--patterns \"REGEX\"] [--history] [--verbose]"
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
if [[ -f "$IP_PATTERNS_FILE" ]]; then
    echo "Patterns: (defaults + local .ip-check-patterns)"
else
    echo "Patterns: (defaults only)"
fi
echo ""

FAILED=false

indent_output() {
    while IFS= read -r line; do
        printf '    %s\n' "$line"
    done
}

# Exclusions: never scan local pattern files or the audit script itself
EXCLUDE_ARGS=(--exclude=.ip-check-patterns --exclude=.ip-patterns --exclude=public-repo-ip-check.sh)

# Check 1: Working tree (file paths only by default — never leak matching content)
echo "▶ Checking working tree..."
TREE_HITS=$(grep -rlE "${EXCLUDE_ARGS[@]}" --exclude-dir=.git "$PATTERNS" . 2>/dev/null || true)
if [[ -n "$TREE_HITS" ]]; then
    echo "  ❌ FAIL: IP found in working tree"
    printf '%s\n' "$TREE_HITS" | indent_output
    if [[ "$VERBOSE" == true ]]; then
        echo "  --- verbose output (may contain sensitive identifiers) ---"
        grep -rE "${EXCLUDE_ARGS[@]}" --exclude-dir=.git "$PATTERNS" . 2>/dev/null | indent_output || true
    fi
    FAILED=true
else
    echo "  ✓ Working tree clean"
fi

# Check 2: Staged changes (count only — never print diff content)
echo "▶ Checking staged changes..."
STAGED_COUNT=$(git diff --staged 2>/dev/null | grep -cE "$PATTERNS" || true)
if [[ "$STAGED_COUNT" -gt 0 ]]; then
    echo "  ❌ FAIL: IP found in staged changes ($STAGED_COUNT match(es))"
    if [[ "$VERBOSE" == true ]]; then
        echo "  --- verbose output (may contain sensitive identifiers) ---"
        git diff --staged 2>/dev/null | grep -E "$PATTERNS" | sed 's/^/    /' || true
    fi
    FAILED=true
else
    echo "  ✓ Staged changes clean"
fi

# Check 3: Unpushed commits (count only — never print diff content)
echo "▶ Checking unpushed commits..."
if git remote get-url origin &>/dev/null; then
    UNPUSHED_COUNT=$(git log -p origin/main..HEAD 2>/dev/null | grep -cE "$PATTERNS" || true)
    if [[ "$UNPUSHED_COUNT" -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in unpushed commits ($UNPUSHED_COUNT match(es))"
        if [[ "$VERBOSE" == true ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            git log -p origin/main..HEAD 2>/dev/null | grep -E "$PATTERNS" | sed 's/^/    /' || true
        fi
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
        HISTORY_COUNT=$(echo "$HISTORY_MATCHES" | wc -l | tr -d ' ')
        echo "  ⚠️  ADVISORY: IP found in $HISTORY_COUNT historical commit(s)"
        echo "  These predate current pattern adoption and do NOT block push."
        echo "  Commits:"
        echo "$HISTORY_MATCHES" | head -10
        # History hits are advisory — do NOT set FAILED=true
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
