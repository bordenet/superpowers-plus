#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-phr.sh
# PURPOSE: Write .phr-cleared sentinel after a successful Progressive Harsh
#          Review (PHR) has cleared. PARALLELS tools/run-battery.sh, which
#          writes .code-review-cleared for the automated linting/test battery.
#
#          This script is the ONLY permitted way to write .phr-cleared.
#          Call AFTER the multi-persona PHR judgment has completed (PASS
#          weighted-mean >= min-score, no active critical vetoes).
#
# USAGE:   tools/run-phr.sh --verdict PASS --min-score 9.5
# EXIT:    0  sentinel written
#          1  invalid args / refuse
#
# WHY THIS EXISTS:
#   Without a machine-checkable sentinel, PHR is discipline-only -- the agent
#   can ship skill changes without ever running it (this happened repeatedly).
#   The .phr-cleared sentinel + pre-push Gate 4 closes that gap so PHR
#   becomes script-enforced, not prose-instruction-enforced.
#
# NOTE: --staged mode was REMOVED. The post-commit hook only promotes
#   .code-review-cleared; promoting .phr-cleared from tree-SHA to commit-SHA
#   was advertised but never implemented, so --staged sentinels were guaranteed
#   to be flagged "stale" at push time. Run PHR AFTER `git commit`.
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
fi
[[ -n "$REPO_ROOT" ]] || { echo "ERROR: cannot locate git repo" >&2; exit 1; }
cd "$REPO_ROOT"

SENTINEL="$REPO_ROOT/.phr-cleared"

# --- Defaults & flags ---
VERDICT=""
MIN_SCORE=""
USAGE_LINE="Usage: tools/run-phr.sh --verdict PASS --min-score N.N"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat <<'EOF'
Usage: tools/run-phr.sh --verdict PASS --min-score N.N

Write .phr-cleared sentinel after Progressive Harsh Review (PHR) passes.

Options:
  --verdict     PASS (required). Only PASS clears the gate -- PASS_WITH_FIXES
                means another round is required (do not write the sentinel)
                and REJECT means fix findings and re-run.
  --min-score   Weighted-mean score from PHR rounds, 1.0-10.0 (required)
  -h, --help    Show this help

Sentinel format:
  v1|<HEAD_SHA>|PASS|<UTC_TIMESTAMP>|min-score=<N>

Exit codes:
  0  Sentinel written
  1  Invalid args / refusal (unstaged changes, etc.)
EOF
            exit 0
            ;;
        --verdict)
            [[ $# -ge 2 ]] || { echo "ERROR: --verdict requires a value (PASS)" >&2; exit 1; }
            VERDICT="$2"; shift 2 ;;
        --verdict=*)
            VERDICT="${1#--verdict=}"; shift ;;
        --min-score)
            [[ $# -ge 2 ]] || { echo "ERROR: --min-score requires a value (1.0-10.0)" >&2; exit 1; }
            MIN_SCORE="$2"; shift 2 ;;
        --min-score=*)
            MIN_SCORE="${1#--min-score=}"; shift ;;
        *)
            echo "ERROR: unknown flag '$1'" >&2
            echo "$USAGE_LINE" >&2
            exit 1
            ;;
    esac
done

# --- Validate ---
if [[ -z "$VERDICT" || -z "$MIN_SCORE" ]]; then
    echo "ERROR: --verdict and --min-score are both required" >&2
    echo "$USAGE_LINE" >&2
    exit 1
fi

if [[ "$VERDICT" != "PASS" ]]; then
    echo "ERROR: invalid verdict '$VERDICT'. Only PASS clears the gate." >&2
    echo "  PASS_WITH_FIXES means another round is required (do not write sentinel)." >&2
    echo "  REJECT means fix findings and re-run." >&2
    exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! LC_ALL=C awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "ERROR: invalid --min-score '$MIN_SCORE'. Must be 1.0-10.0." >&2
    exit 1
fi

# --- Refuse if worktree has unstaged modifications (parity with run-battery.sh). ---
# The sentinel binds to HEAD SHA, but the reviewer saw HEAD + unstaged diff.
# Allow the sentinel file itself (about to be written).
if ! git diff --quiet -- ':!.phr-cleared' 2>/dev/null; then
    echo "ERROR: unstaged modifications detected." >&2
    echo "  PHR runs against a specific snapshot. Stage or stash unstaged" >&2
    echo "  changes before writing the sentinel, otherwise the sentinel" >&2
    echo "  claims more was reviewed than actually was." >&2
    exit 1
fi

# --- Write sentinel ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SENTINEL_SHA="$(git rev-parse HEAD)"

echo "v1|${SENTINEL_SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$SENTINEL"
chmod 0644 "$SENTINEL" 2>/dev/null || true

echo "==========================================================="
echo "  PHR PASSED -- sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Min-score: ${MIN_SCORE}"
echo "  Commit:    ${SENTINEL_SHA:0:8}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  Next step: git push"
echo ""
echo "  IMPORTANT: do NOT commit .phr-cleared. The sentinel expires"
echo "  if HEAD moves. Re-run this script if you make additional"
echo "  commits."
echo "==========================================================="
