#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-battery.sh
# PURPOSE: Run the automated quality suite and write .code-review-cleared.
#          This is the ONLY permitted way to write the sentinel file.
#          Run AFTER completing the AI judgment component of code-review-battery.
# USAGE:   tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS]
# EXIT:    0 = all checks pass, sentinel written
#          1 = failure, sentinel NOT written
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
cd "$REPO_ROOT"

# --- Parse flags ---
VERDICT="PASS"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verdict)
            if [[ $# -lt 2 ]]; then
                echo "❌ --verdict requires a value: PASS or PASS_WITH_NITS" >&2
                echo "Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS]" >&2
                exit 1
            fi
            VERDICT="$2"
            shift 2
            ;;
        --verdict=*)
            VERDICT="${1#--verdict=}"
            shift
            ;;
        *)
            echo "Unknown flag: $1" >&2
            echo "Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS]" >&2
            exit 1
            ;;
    esac
done

if [[ "$VERDICT" != "PASS" && "$VERDICT" != "PASS_WITH_NITS" ]]; then
    echo "❌ Invalid verdict '$VERDICT'. Must be PASS or PASS_WITH_NITS." >&2
    exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  run-battery.sh — automated quality suite"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  ⚠  AI JUDGMENT PREREQUISITE"
echo "  The code-review-battery AI judgment component MUST be"
echo "  completed before calling this script. This script only"
echo "  covers automated verification."
echo ""

ERRORS=0

echo "─── Step 1/3: harsh-review ───"
if "$SCRIPT_DIR/harsh-review.sh"; then
    echo "✓ harsh-review passed"
else
    echo "❌ harsh-review FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 2/3: trigger routing tests ───"
if bash "$SCRIPT_DIR/tests/test_trigger_routing.sh" 2>&1; then
    echo "✓ trigger routing tests passed"
else
    echo "❌ trigger routing tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 3/3: skill router unit tests ───"
if node "$REPO_ROOT/test/skill-router.test.js" 2>&1; then
    echo "✓ skill router tests passed"
else
    echo "❌ skill router tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "  ❌ BATTERY FAILED — ${ERRORS} check(s) did not pass."
    echo "  Sentinel NOT written. Fix failures and re-run."
    echo "═══════════════════════════════════════════════════════════"
    exit 1
fi

# All automated checks passed — write sentinel.
# The sentinel SHA must match the commit being pushed.
# Do NOT commit .code-review-cleared; push immediately after this script.
SHA=$(git rev-parse HEAD)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "v1|${SHA}|${VERDICT}|${TIMESTAMP}" > "$REPO_ROOT/.code-review-cleared"

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ BATTERY PASSED — sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Commit:    ${SHA:0:8}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  Next step: git push"
echo ""
echo "  ⚠  Do NOT commit .code-review-cleared or make additional"
echo "     commits before pushing. The sentinel expires if HEAD"
echo "     moves. Re-run this script if you need to commit more."
echo "═══════════════════════════════════════════════════════════"
