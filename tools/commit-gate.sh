#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: commit-gate.sh
# PURPOSE: Run full quality gate chain before committing.
#          Orchestrates: lint → typecheck → test → harsh-review
#          On success, harsh-review.sh writes the proof token that
#          the pre-commit hook verifies.
# USAGE: bash tools/commit-gate.sh
# EXIT: 0 = all gates pass (token written), 1 = gate failed
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

# Options
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: commit-gate.sh"
            exit 0
            ;;
    esac
done

# Load .agent-gates if present (safely parsed, not sourced)
if [[ -f "$REPO_ROOT/.agent-gates" ]]; then
    while IFS='=' read -r _key _remainder; do
        # Skip blank lines and comment lines
        [[ -z "$_key" || "$_key" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace from key
        _key="${_key//[[:space:]]/}"
        # Only accept known keys; ignore everything else silently
        case "$_key" in
            CLASS|SKIP_SHELLCHECK|SKIP_FILE_ENDINGS|EXTRA_LINT|EXTRA_TYPECHECK|EXTRA_TEST|REQUIRE_CODE_REVIEW_SENTINEL|REVIEW_TOKEN_TTL|SKIP_REVIEW_TOKEN)
                # Trim leading/trailing whitespace and strip surrounding quotes
                _remainder="${_remainder#"${_remainder%%[![:space:]]*}"}"
                _remainder="${_remainder%"${_remainder##*[![:space:]]}"}"
                _remainder="${_remainder#\"}" ; _remainder="${_remainder%\"}"
                _remainder="${_remainder#\'}" ; _remainder="${_remainder%\'}"
                printf -v "$_key" '%s' "$_remainder"
                ;;
            *) ;;
        esac
    done < "$REPO_ROOT/.agent-gates"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  COMMIT GATE: Full quality chain"
[[ -n "${CLASS:-}" ]] && echo "  Repo class: $CLASS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0
STEP=1

# Run EXTRA gates from .agent-gates
for GATE_VAR in EXTRA_LINT EXTRA_TYPECHECK EXTRA_TEST; do
    GATE_CMD="${!GATE_VAR:-}"
    [[ -z "$GATE_CMD" ]] && continue
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Running ${GATE_VAR}: ${GATE_CMD}..."
    if ! eval "$GATE_CMD" 2>&1; then
        printf '%b\n' "${RED}  ✗ ${GATE_VAR} failed${NC}"
        ((ERRORS++))
    else
        printf '%b\n' "${GREEN}  ✓ ${GATE_VAR} passed${NC}"
    fi
    ((STEP++))
done

# Run harsh-review.sh (writes token on success)
printf '%b\n' "${YELLOW}[${STEP}]${NC} Running harsh-review.sh..."
if bash "$SCRIPT_DIR/harsh-review.sh" --changed-only; then
    # Verify token was actually written
    REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    # shellcheck disable=SC2012
    LATEST_TOKEN=$(ls -t "$REVIEW_TOKEN_DIR" 2>/dev/null | head -1 || true)
    if [[ -n "$LATEST_TOKEN" ]] && grep -q "$REPO_ROOT" "$REVIEW_TOKEN_DIR/$LATEST_TOKEN" 2>/dev/null; then
        printf '%b\n' "${GREEN}  ✓ harsh-review passed (token verified)${NC}"
    else
        printf '%b\n' "${RED}  ✗ harsh-review passed, but token write failed${NC}"
        ((ERRORS++))
    fi
else
    printf '%b\n' "${RED}  ✗ harsh-review failed${NC}"
    ((ERRORS++))
fi
((STEP++))

# Result
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $ERRORS -gt 0 ]]; then
    printf '%b\n' "${RED}  GATE FAILED: $ERRORS error(s)${NC}"
    echo "  Fix errors, then re-run: bash tools/commit-gate.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
else
    printf '%b\n' "${GREEN}  All gates passed — ready to commit${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi
