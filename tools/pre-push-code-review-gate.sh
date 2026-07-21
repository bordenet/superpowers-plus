#!/usr/bin/env bash
# shellcheck disable=SC2153  # RANGE is set by lib/pre-push-diff-range.sh's resolve_diff_range(), not a typo of "range"
# -----------------------------------------------------------------------------
# pre-push-code-review-gate.sh
#
# Gate 2 of the pre-push composer. Blocks pushes of code changes that have
# not been cleared by code-review-battery. The battery writes
# .code-review-cleared (format: v1|SHA|VERDICT|TIMESTAMP[|min-score=N]) when
# it passes PASS or PASS_WITH_NITS; this gate verifies the clearance exists,
# matches the pushed ref SHA, and has a passing verdict. Docs-only pushes
# (prose/metadata that cannot alter runtime behavior) are exempt.
#
# Bypass:  Local git hooks can be bypassed with --no-verify. This is a
#          workflow gate, not a security boundary. For hard enforcement, add
#          server-side push rules or CI required checks.
# Threat:  Local soft gate only. An agent can forge the file. This is
#          intentional -- policy-enforced, not security-enforced.
# -----------------------------------------------------------------------------
set -euo pipefail

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck source=tools/lib/pre-push-diff-range.sh
source "$REPO_ROOT/tools/lib/pre-push-diff-range.sh"

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

SENTINEL_FILE="$REPO_ROOT/.code-review-cleared"

# Remote name is passed as $1 by git; used only to seed resolve_push_base_ref's
# remote-qualified candidates for a brand-new branch push.
REMOTE_NAME="${1:-origin}"

# Reads filenames from stdin, prints the first one that is classified as code,
# or prints nothing if all files are docs/metadata. AGENTS.md / CLAUDE.md are
# policy files treated as code; skills/ is always code; .md/.txt/.rst and
# well-known root metadata files are exempted.
_first_code_file() {
    awk '
        /^\s*$/                             { next }
        /^(AGENTS|CLAUDE)(\.md)?$/          { print; next }
        /^skills\//                         { print; next }
        /\.(md|txt|rst)$/                   { next }
        /^(\.gitignore|\.gitattributes|\.editorconfig|README|CHANGELOG|LICENSE|\.env\.example)$/ { next }
        { print }
    ' | head -1
}

# Returns 0 if the range contains only prose/metadata files that cannot alter
# runtime behavior. JSON/YAML/TOML/shell config ARE code for purposes of this
# check -- they can change scope guards, deploy behavior, and security
# boundaries. Only pure docs and well-known root metadata files are exempted.
range_is_docs_only() {
    local range="$1"
    local all_files code_files
    # For single-SHA ranges (new branch with no merge-base), git diff compares
    # to the working tree -- use diff-tree instead to enumerate only the
    # commit's changed files. --root handles root commits; -m handles merge
    # commits; sort -u deduplicates multi-parent output. Use `if !` to fail
    # closed on git errors without triggering set -e.
    if [[ "$range" != *".."* ]]; then
        if ! all_files=$(git diff-tree --root -m --no-commit-id --name-only -r "${range}" 2>/dev/null | sort -u); then
            return 1  # Cannot enumerate commit files -- fail closed (not docs-only)
        fi
    else
        if ! all_files=$(git diff --name-only "$range" 2>/dev/null); then
            return 1  # Cannot enumerate range files -- fail closed
        fi
    fi
    # The || true is scoped to the FILTER pipeline only -- not the git commands
    # above -- so real git failures still fail closed (return 1 via if ! above).
    code_files=$(printf '%s\n' "$all_files" | _first_code_file || true)
    [[ -z "$code_files" ]]
}

# $1 = RANGE (commit range being pushed)
# $2 = local_sha (the actual ref SHA being pushed -- may differ from HEAD)
check_code_review_sentinel() {
    local range="$1"
    local pushed_sha="$2"

    if range_is_docs_only "$range"; then
        echo -e "  ${YELLOW}[code-review-gate]${NC} Docs only — sentinel not required."
        return 0
    fi

    echo "  [code-review-gate] Code changes detected — checking clearance..."

    if [[ ! -f "$SENTINEL_FILE" ]]; then
        echo ""
        echo -e "  ${RED}❌ PUSH BLOCKED: No code review clearance found.${NC}"
        echo ""
        echo "  Code changes require code-review-battery before pushing."
        echo "  The battery writes .code-review-cleared when it passes PASS or PASS_WITH_NITS."
        echo ""
        echo "  Steps:"
        echo "    1. node ~/.codex/superpowers-augment/superpowers-augment.js use-skill code-review-battery"
        echo "    2. Dispatch reviewers with: git diff \$(git merge-base HEAD \$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo 'origin/dev'))..HEAD"
        echo "    3. Battery writes .code-review-cleared on PASS/PASS_WITH_NITS"
        echo "    4. git push"
        echo ""
        return 1
    fi

    local sentinel_ver sentinel_sha sentinel_verdict sentinel_ts
    sentinel_ver=$(cut -d'|' -f1 < "$SENTINEL_FILE" 2>/dev/null || echo "")
    sentinel_sha=$(cut -d'|' -f2 < "$SENTINEL_FILE" 2>/dev/null || echo "")
    sentinel_verdict=$(cut -d'|' -f3 < "$SENTINEL_FILE" 2>/dev/null || echo "")
    sentinel_ts=$(cut -d'|' -f4 < "$SENTINEL_FILE" 2>/dev/null || echo "")

    # Validate v1 format: 4 or 5 pipe-delimited fields. Field 1 = "v1",
    # field 2 (sha) and field 4 (timestamp) non-empty. Optional field 5 = min-score=N.
    local field_count
    field_count=$(awk -F'|' '{print NF}' "$SENTINEL_FILE" 2>/dev/null || echo "0")

    if [[ "$sentinel_ver" != "v1" ]] || [[ "$field_count" -lt 4 ]] || [[ "$field_count" -gt 5 ]] || [[ -z "$sentinel_sha" ]] || [[ -z "$sentinel_ts" ]]; then
        echo ""
        echo -e "  ${RED}❌ PUSH BLOCKED: Sentinel file format unrecognized (expected v1|SHA|VERDICT|TIMESTAMP[|min-score=N], all fields non-empty).${NC}"
        echo ""
        echo "  Delete .code-review-cleared and re-run code-review-battery."
        echo ""
        return 1
    fi

    if [[ "$field_count" -eq 5 ]]; then
        local sentinel_min_score
        sentinel_min_score=$(cut -d'|' -f5 "$SENTINEL_FILE" 2>/dev/null || echo "")
        if ! [[ "$sentinel_min_score" =~ ^min-score=[0-9]+(\.[0-9]+)?$ ]]; then
            echo ""
            echo -e "  ${RED}❌ PUSH BLOCKED: Sentinel field 5 malformed: '${sentinel_min_score}' (expected min-score=N.N).${NC}"
            echo ""
            echo "  Delete .code-review-cleared and re-run code-review-battery."
            echo ""
            return 1
        fi
    fi

    # Compare against the ref actually being pushed, not necessarily HEAD.
    # Pre-push hooks can push non-HEAD refs (e.g., worktrees, detached heads).
    if [[ "$sentinel_sha" != "$pushed_sha" ]]; then
        echo ""
        echo -e "  ${RED}❌ PUSH BLOCKED: Code review clearance is stale.${NC}"
        echo ""
        echo "  Clearance was for commit: ${sentinel_sha:0:8}"
        echo "  Pushing commit:           ${pushed_sha:0:8}"
        echo ""
        echo "  Commits were made after the review. Re-run code-review-battery, then push."
        echo ""
        return 1
    fi

    if [[ "$sentinel_verdict" != "PASS" && "$sentinel_verdict" != "PASS_WITH_NITS" ]]; then
        echo ""
        echo -e "  ${RED}❌ PUSH BLOCKED: Code review verdict was not passing.${NC}"
        echo ""
        echo "  Last verdict: $sentinel_verdict (at $sentinel_ts)"
        echo "  Fix all Critical and Important findings, re-run battery."
        echo ""
        return 1
    fi

    echo -e "  ${GREEN}✓ Code review cleared: $sentinel_verdict (${sentinel_sha:0:8}, $sentinel_ts)${NC}"
    return 0
}

ERRORS=0
while IFS= read -r _line; do
    read -r _ local_sha remote_ref remote_sha <<< "$_line"
    [[ "$local_sha" == "0000000000000000000000000000000000000000" ]] && continue

    resolve_diff_range "$local_sha" "$remote_sha" "$REMOTE_NAME"
    echo "  Checking commits: $RANGE (${remote_ref#refs/heads/})"

    if [[ "$NEW_BRANCH_NO_BASE" == "true" ]]; then
        # No merge-base found -- enumerate ALL files reachable from the tip
        # and decide if the push is truly docs-only before failing closed.
        # This over-approximates (may include ancestor commits already on the
        # remote under a different ref/tag) but is conservative: it can only
        # add false code-detections, never miss them. -m shows per-parent
        # diffs for merge commits so files introduced only during conflict
        # resolution are not silently missed.
        _no_base_files=""
        _git_enum_ok=true
        _log_raw=""
        if ! _log_raw=$(git log --name-only -m --format="" "$local_sha" 2>/dev/null); then
            _git_enum_ok=false
        else
            _no_base_files=$(printf '%s\n' "$_log_raw" | grep -v '^$' | sort -u || true)
        fi
        _no_base_code=$(printf '%s\n' "$_no_base_files" | _first_code_file || true)

        if [[ "$_git_enum_ok" == "false" ]]; then
            echo "  [code-review-gate] New branch with no common ancestor — failing closed (require sentinel)."
            check_code_review_sentinel "REQUIRE_SENTINEL" "$local_sha" || ERRORS=$((ERRORS + 1))
        elif [[ -z "$_no_base_files" ]]; then
            echo "  [code-review-gate] New branch (no common ancestor) — no file changes (allow-empty only), sentinel not required."
        elif [[ -z "$_no_base_code" ]]; then
            echo "  [code-review-gate] New branch (no common ancestor) — all commits docs-only, sentinel not required."
        else
            echo "  [code-review-gate] New branch with no common ancestor — failing closed (require sentinel)."
            check_code_review_sentinel "REQUIRE_SENTINEL" "$local_sha" || ERRORS=$((ERRORS + 1))
        fi
    else
        check_code_review_sentinel "$RANGE" "$local_sha" || ERRORS=$((ERRORS + 1))
    fi
done

exit $(( ERRORS > 0 ? 1 : 0 ))
