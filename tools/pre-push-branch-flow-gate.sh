#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-push-branch-flow-gate.sh
#
# Gate 4 of the pre-push composer. When pushing to dev|staging|main, verifies
# that .branch-flow-cleared exists, is v1 format, and its target field
# matches the ref being pushed. The sentinel is written by
# tools/branch-flow-preflight.sh; if missing or mismatched, the push is
# blocked. Other branches (feature/*, fix/*, hotfix/*, etc.) are exempt
# because they don't represent a promotion landing.
# -----------------------------------------------------------------------------
set -euo pipefail

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

BRANCH_FLOW_SENTINEL="$REPO_ROOT/.branch-flow-cleared"

check_branch_flow_sentinel() {
    local target_branch="$1"
    local pushed_sha="$2"
    case "$target_branch" in
        dev|staging|main) ;;
        *) return 0 ;;  # Only enforced for canonical-flow branches
    esac
    # Self-detect: skip this gate entirely if the repo doesn't have the
    # merge-discipline preflight tooling installed. This keeps the hook
    # portable across test fixtures and repos that don't use this skill.
    if [[ ! -f "$REPO_ROOT/tools/branch-flow-preflight.sh" ]]; then
        echo "  (skipped - tools/branch-flow-preflight.sh not present in this repo)"
        return 0
    fi
    if [[ ! -f "$BRANCH_FLOW_SENTINEL" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: No .branch-flow-cleared sentinel.${NC}"
        echo "  Run: tools/branch-flow-preflight.sh <source-branch> $target_branch"
        return 1
    fi
    # Parse first line only; multi-line corruption must fail "format unrecognized"
    # rather than produce ambiguous NF values from awk-over-whole-file.
    local md_line md_ver md_sha md_source md_target md_ts field_count line_count
    line_count=$(awk 'NF{c++} END{print c+0}' "$BRANCH_FLOW_SENTINEL" 2>/dev/null || echo "0")
    md_line=$(head -n1 "$BRANCH_FLOW_SENTINEL" 2>/dev/null || echo "")
    field_count=$(awk -F'|' '{print NF; exit}' <<< "$md_line")
    IFS='|' read -r md_ver md_sha md_source md_target md_ts <<< "$md_line"
    if [[ "$md_ver" != "v1" ]] || [[ "$field_count" -ne 5 ]] || [[ "$line_count" -gt 1 ]] || \
       [[ -z "$md_sha" ]] || [[ -z "$md_source" ]] || [[ -z "$md_target" ]] || [[ -z "$md_ts" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: branch-flow sentinel format unrecognized (expected exactly 5 fields: v1|SHA|SOURCE|TARGET|TIMESTAMP, all non-empty).${NC}"
        return 1
    fi
    if [[ "$md_target" != "$target_branch" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: branch-flow sentinel target ($md_target) != pushed branch ($target_branch).${NC}"
        echo "  Re-run preflight: tools/branch-flow-preflight.sh $md_source $target_branch"
        return 1
    fi
    if [[ "$md_sha" != "$pushed_sha" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: branch-flow sentinel SHA (${md_sha:0:8}) != pushed SHA (${pushed_sha:0:8}). Branch tip moved since preflight.${NC}"
        echo "  Re-run: tools/branch-flow-preflight.sh $md_source $target_branch"
        return 1
    fi
    echo -e "  ${GREEN}✓ branch-flow cleared: $md_source -> $md_target (${md_sha:0:8})${NC}"
    # Consume the sentinel so a stale file doesn't accidentally clear the
    # NEXT push. The preflight is single-use per push.
    rm -f "$BRANCH_FLOW_SENTINEL"
    return 0
}

ERRORS=0
while IFS= read -r _line; do
    read -r _ local_sha remote_ref _ <<< "$_line"
    [[ "$local_sha" == "0000000000000000000000000000000000000000" ]] && continue

    pushed_branch="${remote_ref#refs/heads/}"
    case "$pushed_branch" in
        dev|staging|main)
            check_branch_flow_sentinel "$pushed_branch" "$local_sha" || ERRORS=$((ERRORS + 1))
            ;;
        *)
            echo "  (skipped — pushing to '$pushed_branch', not a canonical-flow branch)"
            ;;
    esac
done

exit $(( ERRORS > 0 ? 1 : 0 ))
