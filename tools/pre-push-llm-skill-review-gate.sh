#!/usr/bin/env bash
# shellcheck disable=SC2153  # RANGE is set by lib/pre-push-diff-range.sh's resolve_diff_range(), not a typo of "range"
# -----------------------------------------------------------------------------
# pre-push-llm-skill-review-gate.sh
#
# Requires .llm-skill-review-cleared when the push range touches any file
# owned exclusively by llm-skill-review -- content expressly written FOR an
# LLM to execute, not human-facing docs/design (see tools/md-files-changed.sh's
# LLM_OWNED_REGEX, the single source of truth for this set):
#   - skills/**/*.md
#   - .ai-guidance/**/*.md (AGENTS.md overflow -- same audience, just split
#     out on a line-count limit, per AGENTS.md's own self-management protocol)
#   - AGENTS.md, CLAUDE.md, GEMINI.md, CODEX.md, COPILOT.md, AGENT.md, at
#     any path depth
#
# This is the ONLY gate that applies to that content: it supersedes -- not
# supplements -- the PHR gate and the code-review gate for these file
# classes. Both of those gates explicitly exclude them from their own scope
# (see their own headers) so a push touching only these files requires
# exactly one review, not two or three redundant ones.
#
# llm-skill-review is the primary, default reviewer for this content -- it
# covers both LLM-execution safety (determinism, shell portability, tool
# contracts) and prose/design quality in one pass, folding in what
# progressive-harsh-review would otherwise separately check for this file
# class. tools/run-llm-skill-review.sh is the sentinel-writer (parallel to
# tools/run-phr.sh and tools/run-battery.sh).
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
GREEN='\033[0;32m'
NC='\033[0m'

LLM_SKILL_REVIEW_SENTINEL="$REPO_ROOT/.llm-skill-review-cleared"

# Minimum combined (Prose/Design + LLM-Execution) score required. Matches
# the pre-existing PHR_SKILLS_MIN floor this repo already enforced for
# skills/ changes before this gate existed -- moving enforcement of the same
# agreed-upon threshold from PHR to llm-skill-review, not introducing a new one.
LLM_SKILL_REVIEW_MIN="9.2"

REMOTE_NAME="${1:-origin}"

# check_llm_skill_review_sentinel <range> <pushed_sha> [no_base]
check_llm_skill_review_sentinel() {
    local range="$1"
    local pushed_sha="$2"
    local no_base="${3:-}"

    local md_helper="$REPO_ROOT/tools/md-files-changed.sh"
    if [[ ! -x "$md_helper" ]]; then
        echo "  [llm-skill-review-gate] (skipped — tools/md-files-changed.sh not present)"
        return 0
    fi

    # Compute changed files in the push range. Three input shapes, identical
    # to the PHR gate's own enumeration (see that file for the rationale on
    # each branch and on capturing git's exit status separately from any
    # downstream filter pipeline).
    local range_files llm_owned_files _enum_ok=true
    if [[ "$no_base" == "no_base" ]]; then
        local _log_raw
        if ! _log_raw=$(git log --name-only -m --format="" "$pushed_sha" 2>/dev/null); then
            _enum_ok=false
        else
            range_files=$(printf '%s\n' "$_log_raw" | grep -v '^$' | sort -u || true)
        fi
    elif [[ "$range" == *".."* ]]; then
        if ! range_files=$(git diff --name-only "$range" 2>/dev/null); then
            _enum_ok=false
        fi
    else
        if ! range_files=$(git diff-tree --root -m --no-commit-id --name-only -r "$range" 2>/dev/null | sort -u); then
            _enum_ok=false
        fi
    fi

    if [[ "$_enum_ok" == "false" ]]; then
        echo "  [llm-skill-review-gate] Could not enumerate push range files — failing closed (require sentinel)."
        llm_owned_files="(enumeration failed)"
    else
        if [[ -z "$range_files" ]]; then
            echo "  [llm-skill-review-gate] (skipped — no files in push range)"
            return 0
        fi
        llm_owned_files=$("$md_helper" --files "$range_files" --llm-owned 2>/dev/null || true)
        if [[ -z "$llm_owned_files" ]]; then
            echo "  [llm-skill-review-gate] (skipped — no llm-skill-review-owned files in push)"
            return 0
        fi

        echo "  [llm-skill-review-gate] llm-skill-review-owned files in push:"
        while IFS= read -r f; do
            [[ -n "$f" ]] && echo "    - $f"
        done <<< "$llm_owned_files"
    fi

    if [[ ! -f "$LLM_SKILL_REVIEW_SENTINEL" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: .llm-skill-review-cleared sentinel missing.${NC}"
        echo ""
        echo "  skills/*.md, .ai-guidance/*.md, and AGENTS.md-family changes require"
        echo "  llm-skill-review (the primary reviewer for this content -- covers"
        echo "  both LLM-execution safety and prose/design quality in one pass)."
        echo "  After it passes (>= ${LLM_SKILL_REVIEW_MIN}/10), write the sentinel:"
        echo "    tools/run-llm-skill-review.sh --verdict PASS --min-score ${LLM_SKILL_REVIEW_MIN}"
        echo ""
        echo "  This supersedes PHR and code-review-battery for this file class --"
        echo "  neither of those gates require their own sentinel for these files."
        echo ""
        return 1
    fi

    # Parse the sentinel by reading FIRST LINE ONLY -- a multi-line file
    # (corruption, manual edit, accidental append) must fail "format
    # unrecognized", not produce ambiguous NF values from a multi-line awk.
    local sentinel_line sentinel_ver sentinel_sha sentinel_verdict sentinel_ts sentinel_min field_count line_count
    line_count=$(awk 'NF{c++} END{print c+0}' "$LLM_SKILL_REVIEW_SENTINEL" 2>/dev/null || echo "0")
    sentinel_line=$(head -n1 "$LLM_SKILL_REVIEW_SENTINEL" 2>/dev/null || echo "")
    field_count=$(awk -F'|' '{print NF; exit}' <<< "$sentinel_line")
    IFS='|' read -r sentinel_ver sentinel_sha sentinel_verdict sentinel_ts sentinel_min <<< "$sentinel_line"

    if [[ "$sentinel_ver" != "v1" ]] || [[ "$field_count" -ne 5 ]] || [[ "$line_count" -gt 1 ]] || \
       [[ -z "$sentinel_sha" ]] || [[ -z "$sentinel_verdict" ]] || [[ -z "$sentinel_ts" ]] || [[ -z "$sentinel_min" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel format unrecognized (expected v1|SHA|VERDICT|TIMESTAMP|min-score=N).${NC}"
        echo "    Delete .llm-skill-review-cleared and re-run: tools/run-llm-skill-review.sh --verdict PASS --min-score ${LLM_SKILL_REVIEW_MIN}"
        return 1
    fi

    if [[ "$sentinel_verdict" != "PASS" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review verdict was not passing (got '$sentinel_verdict').${NC}"
        echo "    Only PASS clears the gate. Run another round, then:"
        echo "      tools/run-llm-skill-review.sh --verdict PASS --min-score ${LLM_SKILL_REVIEW_MIN}"
        return 1
    fi

    if [[ ! "$sentinel_min" =~ ^min-score=[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel min-score field malformed: '$sentinel_min'.${NC}"
        echo "    Delete .llm-skill-review-cleared and re-run: tools/run-llm-skill-review.sh --verdict PASS --min-score ${LLM_SKILL_REVIEW_MIN}"
        return 1
    fi

    if [[ "$sentinel_sha" != "$pushed_sha" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel is stale.${NC}"
        echo "    Review was for: ${sentinel_sha:0:8}"
        echo "    Pushing:        ${pushed_sha:0:8}"
        echo "    Commits were made after the review. Re-run then tools/run-llm-skill-review.sh."
        return 1
    fi

    local sentinel_score
    sentinel_score="${sentinel_min#min-score=}"
    if ! LC_ALL=C awk -v s="$sentinel_score" -v m="$LLM_SKILL_REVIEW_MIN" 'BEGIN { exit !(s >= m) }'; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review score below project minimum for skills/ changes.${NC}"
        echo "    Got:      min-score=${sentinel_score}"
        echo "    Required: >= ${LLM_SKILL_REVIEW_MIN}"
        echo "    Run additional rounds until the combined score >= ${LLM_SKILL_REVIEW_MIN}, then:"
        echo "      tools/run-llm-skill-review.sh --verdict PASS --min-score ${LLM_SKILL_REVIEW_MIN}"
        return 1
    fi

    # Sentinel intentionally NOT consumed here: parity with the PHR and
    # code-review sentinels, both SHA-bound so a single PASS covers re-pushes
    # of the same SHA (different remote, retry after a transient failure).
    echo -e "  ${GREEN}✓ llm-skill-review cleared: $sentinel_verdict ${sentinel_min} (${sentinel_sha:0:8})${NC}"
    return 0
}

ERRORS=0
while IFS= read -r _line; do
    read -r _ local_sha remote_ref remote_sha <<< "$_line"
    [[ "$local_sha" == "0000000000000000000000000000000000000000" ]] && continue

    resolve_diff_range "$local_sha" "$remote_sha" "$REMOTE_NAME"
    echo "  Checking commits: $RANGE (${remote_ref#refs/heads/})"

    if [[ "$NEW_BRANCH_NO_BASE" == "true" ]]; then
        check_llm_skill_review_sentinel "$RANGE" "$local_sha" "no_base" || ERRORS=$((ERRORS + 1))
    else
        check_llm_skill_review_sentinel "$RANGE" "$local_sha" || ERRORS=$((ERRORS + 1))
    fi
done

exit $(( ERRORS > 0 ? 1 : 0 ))
