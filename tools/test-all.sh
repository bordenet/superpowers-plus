#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: test-all.sh
# PURPOSE: Unified test entry point for superpowers-plus. Runs the full test
#          surface in the order that catches the most failures earliest:
#          static lint, then bats, then node tests. AGENTS.md points here so
#          first-time contributors can not silently miss half the suite.
# USAGE:   tools/test-all.sh [--no-shellcheck] [--no-bats] [--no-node]
#                            [--no-harsh] [--fast]
#            --fast = node + bats only; skip shellcheck and harsh-review.
#                     Intended for tight inner loops; CI must run the full
#                     suite without --fast.
# EXIT:    0 = all selected suites pass
#          1 = one or more suites failed (summary printed at end)
# -----------------------------------------------------------------------------
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || { echo "❌ Could not cd to $REPO_ROOT" >&2; exit 1; }

RUN_SHELLCHECK=1
RUN_BATS=1
RUN_NODE=1
RUN_HARSH=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --no-shellcheck) RUN_SHELLCHECK=0; shift ;;
        --no-bats)       RUN_BATS=0;       shift ;;
        --no-node)       RUN_NODE=0;       shift ;;
        --no-harsh)      RUN_HARSH=0;      shift ;;
        --fast)          RUN_SHELLCHECK=0; RUN_HARSH=0; shift ;;
        *) echo "❌ Unknown flag: $1" >&2; exit 1 ;;
    esac
done

declare -a FAILED=()
declare -a PASSED=()

run_suite() {
    local label="$1"; shift
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ▶ $label"
    echo "═══════════════════════════════════════════════════════════"
    if "$@"; then
        echo "✓ $label passed"
        PASSED+=("$label")
    else
        echo "❌ $label failed"
        FAILED+=("$label")
    fi
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite "label" run_shellcheck
run_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "⚠️  shellcheck not installed; skipping"
        return 0
    fi
    # Match the scope used by tools/harsh-review.sh: every tracked .sh plus
    # extensionless hooks under tools/. Exclude vendored / generated paths.
    local files
    files=$(git ls-files '*.sh' tools/pre-commit tools/pre-push tools/commit-msg 2>/dev/null | sort -u)
    [[ -z "$files" ]] && { echo "no shell files tracked"; return 0; }
    # shellcheck disable=SC2086  # word-splitting intentional
    shellcheck -x $files
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        echo "⚠️  bats not installed; skipping"
        return 0
    fi
    bats test/
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_node_tests() {
    if ! command -v node >/dev/null 2>&1; then
        echo "❌ node not installed; required for JS test suite"
        return 1
    fi
    local rc=0
    # Iterate explicitly so a single failing suite doesn't mask the rest.
    local f
    for f in test/*.test.js; do
        [[ -e "$f" ]] || continue
        echo ""
        echo "── $f ──"
        if ! node "$f"; then
            rc=1
            echo "✗ $f"
        fi
    done
    # The .test.sh files are independent shell harnesses.
    for f in test/*.test.sh; do
        [[ -e "$f" ]] || continue
        echo ""
        echo "── $f ──"
        if ! bash "$f"; then
            rc=1
            echo "✗ $f"
        fi
    done
    return "$rc"
}

# shellcheck disable=SC2329  # invoked indirectly via run_suite
run_harsh_review() {
    bash "$SCRIPT_DIR/harsh-review.sh"
}

[[ "$RUN_SHELLCHECK" -eq 1 ]] && run_suite "shellcheck"      run_shellcheck
[[ "$RUN_HARSH"      -eq 1 ]] && run_suite "harsh-review.sh" run_harsh_review
[[ "$RUN_BATS"       -eq 1 ]] && run_suite "bats test/"      run_bats
[[ "$RUN_NODE"       -eq 1 ]] && run_suite "node test/*"     run_node_tests

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════════════"
for s in "${PASSED[@]}"; do echo "  ✓ $s"; done
for s in "${FAILED[@]}"; do echo "  ✗ $s"; done
echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "❌ ${#FAILED[@]} suite(s) failed."
    exit 1
fi
echo "✅ All ${#PASSED[@]} suite(s) passed."
exit 0
