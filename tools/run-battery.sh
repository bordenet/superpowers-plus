#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-battery.sh
# PURPOSE: Run the automated quality suite and write .code-review-cleared.
#          This is the ONLY permitted way to write the sentinel file.
#          Run AFTER completing the AI judgment component of code-review-battery.
# USAGE:   tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]
#                               [--staged]
#            N        = quality threshold, 1.0–10.0 (default 7.0)
#            --staged = verify the staged tree instead of HEAD. The sentinel
#                       records the index tree SHA (via `git write-tree`)
#                       prefixed with "tree:" so a follow-up commit can claim
#                       it without re-running the full battery.
# EXIT:    0 = all checks pass, sentinel written
#          1 = failure, sentinel NOT written
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repo root from the caller's CWD so the sentinel lands in the right
# repo when run-battery.sh is invoked from an overlay (e.g. superpowers-swat).
# Fall back to the script's own repo only when not called from inside a git tree.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
fi
[[ -n "$REPO_ROOT" ]] || { echo "❌ Cannot locate a git repo from CWD or script dir" >&2; exit 1; }
cd "$REPO_ROOT"

# --- Parse flags ---
VERDICT="PASS"
MIN_SCORE="7.0"
STAGED_MODE=0
USAGE_LINE="Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N] [--staged]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat << 'EOF'
Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N] [--staged]

Run the automated quality suite and write .code-review-cleared.
This is the ONLY permitted way to write the sentinel file.
Run AFTER completing the AI judgment component of code-review-battery.

Options:
  --verdict     PASS or PASS_WITH_NITS (default: PASS)
  --min-score   Quality threshold 1.0–10.0 (default: 7.0)
  --staged      Verify the staged tree rather than HEAD. The sentinel
                records `tree:<git-write-tree-sha>`; the post-commit hook
                promotes it to the new HEAD SHA when the tree matches.
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
                echo "$USAGE_LINE" >&2
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
                echo "$USAGE_LINE" >&2
                exit 1
            fi
            MIN_SCORE="$2"
            shift 2
            ;;
        --min-score=*)
            MIN_SCORE="${1#--min-score=}"
            shift
            ;;
        --staged)
            STAGED_MODE=1
            shift
            ;;
        *)
            echo "Unknown flag: $1" >&2
            echo "$USAGE_LINE" >&2
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
echo "  ⚠  PHR PREREQUISITE (skill/design changes)"
echo "  If the diff touches skills/ or design docs, run /sp-phr"
echo "  BEFORE this script. harsh-review.sh (Step 1) is a linter,"
echo "  NOT progressive-harsh-review. PHR is a separate AI gate."
echo ""

# Guard: block when there are UNSTAGED modifications (truly dirty worktree).
# Staged-but-uncommitted changes are allowed: battery may run pre-commit and the
# sentinel is written for current HEAD; pre-push then validates SHA on the pushed ref.
# Exclude .code-review-cleared itself (battery writes it; may be tracked by git).
# In --staged mode we additionally require there to BE a staged tree (else the
# tree-SHA sentinel is meaningless).
if ! git diff --quiet -- ':!.code-review-cleared' 2>/dev/null; then
    echo ""
    echo "❌ Unstaged modifications detected."
    echo "   Stage or stash changes before running battery:"
    echo "     git add <files>   # or: git stash"
    echo "   Then re-run: tools/run-battery.sh"
    echo ""
    exit 1
fi

if [[ "$STAGED_MODE" -eq 1 ]]; then
    if git diff --cached --quiet 2>/dev/null; then
        echo "❌ --staged passed but no changes are staged."
        echo "   Stage the changes you intend to commit, then re-run with --staged."
        exit 1
    fi
fi

ERRORS=0

# NOTE: install --upgrade is intentionally NOT run here.
# Running it as a battery step has unacceptable side-effects: it mutates the
# live routing catalog before the routing tests run, changing the system under
# test mid-suite. If you need to sync the catalog before running the battery,
# run `bash install.sh --upgrade` manually first.

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
if node "$SCRIPT_DIR/../test/skill-router.test.js" 2>&1; then
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
# In HEAD mode the sentinel SHA must match the commit being pushed.
# In --staged mode the sentinel records the staged tree SHA; the post-commit
# hook promotes it to the new HEAD SHA when the tree matches.
# Do NOT commit .code-review-cleared; push immediately after this script
# (or after the commit, when running in --staged mode).
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ "$STAGED_MODE" -eq 1 ]]; then
    TREE_SHA=$(git write-tree)
    SENTINEL_SHA="tree:${TREE_SHA}"
    SENTINEL_LABEL="Tree:      ${TREE_SHA:0:8} (staged)"
    NEXT_STEP="git commit            # post-commit hook promotes the sentinel to the new HEAD SHA"
else
    SENTINEL_SHA=$(git rev-parse HEAD)
    SENTINEL_LABEL="Commit:    ${SENTINEL_SHA:0:8}"
    NEXT_STEP="git push"
fi
echo "v1|${SENTINEL_SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$REPO_ROOT/.code-review-cleared"

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ BATTERY PASSED — sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Min-score: ${MIN_SCORE}"
echo "  ${SENTINEL_LABEL}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  Next step: ${NEXT_STEP}"
echo ""
# Only emit the PHR reminder when the diff actually touches skill/design .md files.
# Delegated to tools/md-files-changed.sh — single source of truth for the
# regex + exclusion (also consumed by the finishing-a-development-branch skill).
if MD_HITS=$("$SCRIPT_DIR/md-files-changed.sh" 2>/dev/null); then
    echo "  ⚠  PHR REQUIRED: This diff touches skills/ or docs/ .md files:"
    while IFS= read -r f; do
        [[ -n "$f" ]] && echo "       - $f"
    done <<< "$MD_HITS"
    echo ""
    echo "     Dispatch progressive-harsh-review BEFORE pushing:"
    echo "       /sp-phr"
    echo "     or, programmatically:"
    echo "       node ~/.codex/superpowers-augment/superpowers-augment.js use-skill progressive-harsh-review"
    echo ""
    echo "     Battery linting != progressive harsh review."
    echo ""
else
    PHR_EXIT=$?
    if [[ "$PHR_EXIT" -eq 2 ]]; then
        echo "  ⚠  PHR REMINDER: Could not determine merge base (no main/master ancestor)."
        echo "     Review the full branch diff manually and confirm /sp-phr was completed if any .md files changed."
        echo ""
    fi
    # exit 1 means "no PHR-relevant files changed" — no reminder needed.
fi
echo "  ⚠  Do NOT commit .code-review-cleared or make additional"
echo "     commits before pushing. The sentinel expires if HEAD"
echo "     moves. Re-run this script if you need to commit more."
echo "═══════════════════════════════════════════════════════════"
