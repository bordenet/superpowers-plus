#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-battery.sh
# PURPOSE: Run the automated quality suite and write .code-review-cleared.
#          This is the ONLY permitted way to write the sentinel file.
#          Run AFTER completing the AI judgment component of code-review-battery.
# USAGE:   tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]
#            N = quality threshold, 1.0–10.0 (default 7.0)
# EXIT:    0 = all checks pass, sentinel written
#          1 = failure, sentinel NOT written
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
cd "$REPO_ROOT"

# --- Parse flags ---
VERDICT="PASS"
MIN_SCORE="7.0"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat << 'EOF'
Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]

Run the automated quality suite and write .code-review-cleared.
This is the ONLY permitted way to write the sentinel file.
Run AFTER completing the AI judgment component of code-review-battery.

Options:
  --verdict     PASS or PASS_WITH_NITS (default: PASS)
  --min-score   Quality threshold 1.0–10.0 (default: 7.0)
  -h, --help    Show this help

Exit codes:
  0  All checks pass, sentinel written
  1  Failure, sentinel NOT written
EOF
            exit 0
            ;;
        --verdict)
            if [[ $# -lt 2 ]]; then
                echo "❌ --verdict requires a value: PASS or PASS_WITH_NITS" >&2
                echo "Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]" >&2
                exit 1
            fi
            VERDICT="$2"
            shift 2
            ;;
        --verdict=*)
            VERDICT="${1#--verdict=}"
            shift
            ;;
        --min-score)
            if [[ $# -lt 2 ]]; then
                echo "❌ --min-score requires a value (1.0–10.0)" >&2
                echo "Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]" >&2
                exit 1
            fi
            MIN_SCORE="$2"
            shift 2
            ;;
        --min-score=*)
            MIN_SCORE="${1#--min-score=}"
            shift
            ;;
        *)
            echo "Unknown flag: $1" >&2
            echo "Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]" >&2
            exit 1
            ;;
    esac
done

if [[ "$VERDICT" != "PASS" && "$VERDICT" != "PASS_WITH_NITS" ]]; then
    echo "❌ Invalid verdict '$VERDICT'. Must be PASS or PASS_WITH_NITS." >&2
    exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "❌ Invalid --min-score '$MIN_SCORE'. Must be a number between 1.0 and 10.0." >&2
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

# Guard: block when there are UNSTAGED modifications (truly dirty worktree).
# Staged-but-uncommitted changes are allowed: battery may run pre-commit and the
# sentinel is written for current HEAD; pre-push then validates SHA on the pushed ref.
# Exclude .code-review-cleared itself (battery writes it; may be tracked by git).
if ! git diff --quiet -- ':!.code-review-cleared' 2>/dev/null; then
    echo ""
    echo "❌ Unstaged modifications detected."
    echo "   Stage or stash changes before running battery:"
    echo "     git add <files>   # or: git stash"
    echo "   Then re-run: tools/run-battery.sh"
    echo ""
    exit 1
fi

ERRORS=0

echo "─── Step 1/4: harsh-review ───"
if "$SCRIPT_DIR/harsh-review.sh"; then
    echo "✓ harsh-review passed"
else
    echo "❌ harsh-review FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 2/4: trigger routing tests ───"
if bash "$SCRIPT_DIR/tests/test_trigger_routing.sh" 2>&1; then
    echo "✓ trigger routing tests passed"
else
    echo "❌ trigger routing tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 3/4: Augment export integrity ───"
if bash "$SCRIPT_DIR/tests/test_augment_export.sh" 2>&1; then
    echo "✓ Augment export tests passed"
else
    echo "❌ Augment export tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 4/4: skill router unit tests ───"
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
echo "v1|${SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$REPO_ROOT/.code-review-cleared"

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ BATTERY PASSED — sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Min-score: ${MIN_SCORE}"
echo "  Commit:    ${SHA:0:8}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  Next step: git push"
echo ""
echo "  ⚠  Do NOT commit .code-review-cleared or make additional"
echo "     commits before pushing. The sentinel expires if HEAD"
echo "     moves. Re-run this script if you need to commit more."
echo "═══════════════════════════════════════════════════════════"
