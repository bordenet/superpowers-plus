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
# Use pwd -P for canonical path so it matches the review token written by harsh-review.sh
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P 2>/dev/null)" || REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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
# Mirrors the pre-commit parser: EXTRA_* commands keep '#'; scalar/boolean/numeric
# keys have inline comments stripped and their values validated.
_GATES_PARSE_ERRORS=0
_parse_agent_gates_cg() {
    local _key _remainder _val
    while IFS='=' read -r _key _remainder; do
        [[ -z "$_key" || "$_key" =~ ^[[:space:]]*# ]] && continue
        _key="${_key//[[:space:]]/}"
        case "$_key" in
            EXTRA_LINT|EXTRA_TYPECHECK|EXTRA_TEST)
                # Command strings: do NOT strip '#' — they may contain '#' literally.
                # Trim surrounding whitespace, then strip a MATCHING pair of quotes only
                # (not individual leading/trailing quotes which would mangle commands that
                # use quotes internally, e.g. EXTRA_TEST=printf '# ok\n').
                _remainder="${_remainder#"${_remainder%%[![:space:]]*}"}"
                _remainder="${_remainder%"${_remainder##*[![:space:]]}"}"
                if [[ "${_remainder:0:1}" == '"' && "${_remainder: -1}" == '"' && ${#_remainder} -ge 2 ]]; then
                    _remainder="${_remainder:1:${#_remainder}-2}"
                elif [[ "${_remainder:0:1}" == "'" && "${_remainder: -1}" == "'" && ${#_remainder} -ge 2 ]]; then
                    _remainder="${_remainder:1:${#_remainder}-2}"
                fi
                printf -v "$_key" '%s' "$_remainder"
                ;;
            CLASS|SKIP_SHELLCHECK|SKIP_FILE_ENDINGS|REQUIRE_CODE_REVIEW_SENTINEL|REVIEW_TOKEN_TTL|SKIP_REVIEW_TOKEN|REQUIRE_LOOSE_ENDS_CLEAN|SKIP_DEFAULT_TESTS|SKIP_BASELINE_CHECK|AUGMENT_PARITY_OFF)
                # Scalar/boolean/numeric: strip inline comments, then validate.
                _remainder="${_remainder%%#*}"
                _remainder="${_remainder#"${_remainder%%[![:space:]]*}"}"
                _remainder="${_remainder%"${_remainder##*[![:space:]]}"}"
                _remainder="${_remainder#\"}" ; _remainder="${_remainder%\"}"
                _remainder="${_remainder#\'}" ; _remainder="${_remainder%\'}"
                _val="$_remainder"
                case "$_key" in
                    REQUIRE_CODE_REVIEW_SENTINEL|SKIP_SHELLCHECK|SKIP_FILE_ENDINGS|SKIP_REVIEW_TOKEN|REQUIRE_LOOSE_ENDS_CLEAN|SKIP_DEFAULT_TESTS|SKIP_BASELINE_CHECK|AUGMENT_PARITY_OFF)
                        if [[ "$_val" != "true" && "$_val" != "false" ]]; then
                            echo "✗ .agent-gates: invalid value for $_key: '$_val' (must be 'true' or 'false')" >&2
                            _GATES_PARSE_ERRORS=$((_GATES_PARSE_ERRORS + 1))
                            continue
                        fi ;;
                    REVIEW_TOKEN_TTL)
                        # Require positive integer > 0; TTL=0 causes instant expiry
                        if [[ ! "$_val" =~ ^[1-9][0-9]*$ ]]; then
                            echo "✗ .agent-gates: invalid value for REVIEW_TOKEN_TTL: '$_val' (must be a positive integer > 0)" >&2
                            _GATES_PARSE_ERRORS=$((_GATES_PARSE_ERRORS + 1))
                            continue
                        fi ;;
                esac
                printf -v "$_key" '%s' "$_val"
                ;;
            *) ;;
        esac
    done
}
[[ -f "$REPO_ROOT/.agent-gates" ]] && _parse_agent_gates_cg < "$REPO_ROOT/.agent-gates"
if [[ "$_GATES_PARSE_ERRORS" -gt 0 ]]; then
    echo "✗ .agent-gates has $_GATES_PARSE_ERRORS invalid value(s) — fix before committing" >&2
    exit 1
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
        ERRORS=$((ERRORS + 1))
    else
        printf '%b\n' "${GREEN}  ✓ ${GATE_VAR} passed${NC}"
    fi
    STEP=$((STEP + 1))
done

# Default test step: run bats on tests/ unless EXTRA_TEST was already configured
# or SKIP_DEFAULT_TESTS=true is set in .agent-gates.
if [[ -z "${EXTRA_TEST:-}" && "${SKIP_DEFAULT_TESTS:-false}" != "true" ]]; then
    if command -v bats &>/dev/null && compgen -G "$REPO_ROOT/tests/*.bats" > /dev/null 2>&1; then
        printf '%b\n' "${YELLOW}[${STEP}]${NC} Running default tests (bats tests/)..."
        if bats "$REPO_ROOT/tests/" 2>&1; then
            printf '%b\n' "${GREEN}  ✓ Tests passed${NC}"
        else
            printf '%b\n' "${RED}  ✗ Tests failed — fix before committing${NC}"
            ERRORS=$((ERRORS + 1))
        fi
        STEP=$((STEP + 1))
    fi
fi

# Baseline drift check — compare tracked tool SHAs against the committed baseline.
# Skipped if: SKIP_BASELINE_CHECK=true in .agent-gates, or baseline file is absent.
_BASELINE_FILE="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"
if [[ "${SKIP_BASELINE_CHECK:-false}" == "true" ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Baseline check skipped (SKIP_BASELINE_CHECK=true)"
    STEP=$((STEP + 1))
elif [[ ! -f "$_BASELINE_FILE" ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Baseline check skipped — no baseline found"
    printf '%b\n' "${YELLOW}  ⚠  Run: bash scripts/capture-augment-baseline.sh${NC}"
    STEP=$((STEP + 1))
else
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Checking baseline drift..."
    if bash "$REPO_ROOT/scripts/capture-augment-baseline.sh" --check 2>&1; then
        printf '%b\n' "${GREEN}  ✓ No baseline drift${NC}"
    else
        printf '%b\n' "${RED}  ✗ Baseline drift detected — re-capture or revert tool changes${NC}"
        printf '%b\n' "${RED}    Run: bash scripts/capture-augment-baseline.sh${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    STEP=$((STEP + 1))
fi

# Parity validation — verify Claude Code hooks are consistent (shellcheck-clean,
# bypass-clause present). Skipped when AUGMENT_PARITY_OFF=true in .agent-gates
# or when the hooks directory does not exist (graceful on fresh installs).
_HOOKS_DIR="$REPO_ROOT/tools/claude-hooks"
if [[ "${AUGMENT_PARITY_OFF:-false}" == "true" ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Parity validation skipped (AUGMENT_PARITY_OFF=true)"
    STEP=$((STEP + 1))
elif [[ ! -d "$_HOOKS_DIR" ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Parity validation skipped — no claude-hooks/ directory"
    STEP=$((STEP + 1))
else
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Checking parity (Claude Code hooks)..."
    _PARITY_ERRORS=0
    _HOOK_COUNT=0
    for _hook in "$_HOOKS_DIR"/*.sh; do
        [[ -f "$_hook" ]] || continue
        _HOOK_COUNT=$((_HOOK_COUNT + 1))
        _hname="$(basename "$_hook")"
        if ! bash -n "$_hook" 2>/dev/null; then
            printf '%b\n' "${RED}  ✗ Syntax error: $_hname${NC}"
            _PARITY_ERRORS=$((_PARITY_ERRORS + 1))
        fi
        if ! grep -q 'CLAUDE_HOOKS_BYPASS' "$_hook"; then
            printf '%b\n' "${RED}  ✗ Missing bypass clause: $_hname${NC}"
            _PARITY_ERRORS=$((_PARITY_ERRORS + 1))
        fi
    done
    if [[ $_PARITY_ERRORS -eq 0 ]]; then
        printf '%b\n' "${GREEN}  ✓ Parity OK ($_HOOK_COUNT hooks valid)${NC}"
    else
        ERRORS=$((ERRORS + _PARITY_ERRORS))
    fi
    STEP=$((STEP + 1))
fi

# Run harsh-review.sh (writes token on success)
# Snapshot pre-existing token filenames so we can verify a NEW token was
# written by THIS invocation — not just any stale-but-valid token.
REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
mkdir -p "$REVIEW_TOKEN_DIR"
_pre_tokens=()
for _tf in "$REVIEW_TOKEN_DIR"/*; do [[ -f "$_tf" ]] && _pre_tokens+=("$(basename "$_tf")"); done

if [[ $ERRORS -gt 0 ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Skipping harsh-review.sh — fix earlier gate failures first"
    printf '%b\n' "${YELLOW}  ⚠ Re-run commit-gate.sh after resolving the errors above${NC}"
    STEP=$((STEP + 1))
else

printf '%b\n' "${YELLOW}[${STEP}]${NC} Running harsh-review.sh..."
if bash "$SCRIPT_DIR/harsh-review.sh" --changed-only; then
    # Require a NEW token for this repo (a file that was not in the pre-snapshot).
    _NOW=$(date +%s)
    _FOUND_NEW_TOKEN=false
    for _tf in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$_tf" ]] || continue
        _tb=$(basename "$_tf")
        # Is this token new (not in the pre-run snapshot)?
        _is_new=true
        for _old in "${_pre_tokens[@]+"${_pre_tokens[@]}"}"; do
            [[ "$_old" == "$_tb" ]] && { _is_new=false; break; }
        done
        "$_is_new" || continue
        # Validate it's for this repo and still within TTL
        if [[ "$_tb" =~ ^[0-9]+$ ]]; then _ts="$_tb"
        else _ts=$(echo "$_tb" | awk -F'.' '{print $2}'); fi
        [[ "$_ts" =~ ^[0-9]+$ ]] || continue
        _age=$((_NOW - _ts))
        if [[ $_age -le ${REVIEW_TOKEN_TTL:-300} ]]; then
            _tr=$(cat "$_tf" 2>/dev/null || true)
            if [[ "$_tr" == "$REPO_ROOT" ]]; then _FOUND_NEW_TOKEN=true; break; fi
        fi
    done
    if [[ "$_FOUND_NEW_TOKEN" == "true" ]]; then
        printf '%b\n' "${GREEN}  ✓ harsh-review passed (new token verified)${NC}"
    else
        printf '%b\n' "${RED}  ✗ harsh-review passed, but no new token was written${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    printf '%b\n' "${RED}  ✗ harsh-review failed${NC}"
    ERRORS=$((ERRORS + 1))
fi
STEP=$((STEP + 1))

fi  # end: skip harsh-review when earlier gates failed

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
