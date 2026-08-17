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
#   - .ai-guidance/**/*.md
#   - AGENTS.md, CLAUDE.md, GEMINI.md, CODEX.md, COPILOT.md, AGENT.md, at
#     any path depth
#
# ADR-003: Gate 6 verifies sentinel v2 schema + unresolved_s0_s1=0 +
# evidence_replay=(ok|bypassed with PASS). Prose/Design mean is metadata only
# -- this gate does NOT compare mean to a numeric floor.
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
        echo "  llm-skill-review (ADR-003: verdict PASS|PASS_WITH_RISKS, unresolved"
        echo "  S0/S1 = 0, non-vacuous clean_dimensions, evidence replay)."
        echo "    tools/run-llm-skill-review.sh --verdict PASS --min-score <Prose/Design-mean>"
        echo ""
        return 1
    fi

    local sentinel_line sentinel_ver sentinel_sha sentinel_verdict sentinel_ts
    local sentinel_mean sentinel_unresolved sentinel_replay
    local field_count line_count
    line_count=$(awk 'NF{c++} END{print c+0}' "$LLM_SKILL_REVIEW_SENTINEL" 2>/dev/null || echo "0")
    sentinel_line=$(head -n1 "$LLM_SKILL_REVIEW_SENTINEL" 2>/dev/null || echo "")
    field_count=$(awk -F'|' '{print NF; exit}' <<< "$sentinel_line")
    IFS='|' read -r sentinel_ver sentinel_sha sentinel_verdict sentinel_ts \
        sentinel_mean sentinel_unresolved sentinel_replay <<< "$sentinel_line"

    if [[ "$sentinel_ver" != "v2" ]] || [[ "$field_count" -ne 7 ]] || [[ "$line_count" -gt 1 ]] || \
       [[ -z "$sentinel_sha" ]] || [[ -z "$sentinel_verdict" ]] || [[ -z "$sentinel_ts" ]] || \
       [[ -z "$sentinel_mean" ]] || [[ -z "$sentinel_unresolved" ]] || [[ -z "$sentinel_replay" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel format unrecognized (expected v2|SHA|VERDICT|TIMESTAMP|mean=N|unresolved_s0_s1=0|evidence_replay=ok).${NC}"
        echo "    Delete .llm-skill-review-cleared and re-run: tools/run-llm-skill-review.sh --verdict PASS --min-score <mean>"
        return 1
    fi

    if [[ "$sentinel_verdict" != "PASS" && "$sentinel_verdict" != "PASS_WITH_RISKS" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review verdict was not passing (got '$sentinel_verdict').${NC}"
        echo "    Only PASS or PASS_WITH_RISKS clear the gate (ADR-003)."
        return 1
    fi

    if [[ ! "$sentinel_mean" =~ ^mean=[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel mean field malformed: '$sentinel_mean'.${NC}"
        echo "    Expected mean=<Prose/Design-mean> (metadata only; not floor-compared)."
        return 1
    fi

    if [[ "$sentinel_unresolved" != "unresolved_s0_s1=0" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel unresolved_s0_s1 is not 0 (got '$sentinel_unresolved').${NC}"
        return 1
    fi

    if [[ "$sentinel_replay" != "evidence_replay=ok" && "$sentinel_replay" != "evidence_replay=bypassed" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel evidence_replay field malformed: '$sentinel_replay'.${NC}"
        return 1
    fi

    if [[ "$sentinel_replay" == "evidence_replay=bypassed" && "$sentinel_verdict" != "PASS" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: evidence_replay=bypassed is only allowed with verdict PASS (got '$sentinel_verdict').${NC}"
        return 1
    fi

    if [[ "$sentinel_sha" != "$pushed_sha" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: llm-skill-review sentinel is stale.${NC}"
        echo "    Review was for: ${sentinel_sha:0:8}"
        echo "    Pushing:        ${pushed_sha:0:8}"
        echo "    Commits were made after the review. Re-run then tools/run-llm-skill-review.sh."
        return 1
    fi

    echo -e "  ${GREEN}✓ llm-skill-review cleared: $sentinel_verdict ${sentinel_mean} ${sentinel_unresolved} ${sentinel_replay} (${sentinel_sha:0:8})${NC}"
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
