#!/usr/bin/env bash
# shellcheck disable=SC2153  # RANGE is set by lib/pre-push-diff-range.sh's resolve_diff_range(), not a typo of "range"
# -----------------------------------------------------------------------------
# pre-push-phr-gate.sh
#
# Gate 5 of the pre-push composer: requires .phr-cleared when the push range
# touches PHR-eligible files EXCLUDING skills/*.md (docs/*.md, repo-root
# UPPERCASE.md, AGENTS.md). PHR is the multi-persona AI judgment gate
# (Junior + SeniorArch + ProdOps); it is SEPARATE from code-review-battery
# (automated lint/test). Without this gate, PHR is discipline-only and gets
# skipped.
#
# skills/*.md is deliberately OUT OF SCOPE here: it's owned exclusively by
# tools/pre-push-llm-skill-review-gate.sh, which supersedes (not supplements)
# both this gate and the code-review gate for that specific file class --
# see that gate's own header for why a skill.md push should require exactly
# one review, not two or three redundant ones.
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

PHR_SENTINEL="$REPO_ROOT/.phr-cleared"

REMOTE_NAME="${1:-origin}"

# check_phr_sentinel <range> <pushed_sha> [no_base]
# $3 (optional): "no_base" -> use git log over the full history reachable
# from $pushed_sha. On an orphan branch with no merge-base, single-SHA
# diff-tree only inspects the tip and misses skill changes in earlier
# commits -- exactly the silent-bypass class this gate exists to close.
check_phr_sentinel() {
    local range="$1"
    local pushed_sha="$2"
    local no_base="${3:-}"

    # Determine if the push touches PHR-eligible md files. Use the existing
    # tools/md-files-changed.sh helper (single source of truth for the
    # PHR-trigger regex; also consumed by run-battery.sh and the
    # finishing-a-development-branch skill).
    local md_helper="$REPO_ROOT/tools/md-files-changed.sh"
    if [[ ! -x "$md_helper" ]]; then
        # Helper missing -- treat as "gate not installed in this repo" and
        # skip, but ANNOUNCE it. Silent fail-open silently regresses to the
        # original pre-fix state where PHR was skipped.
        echo "  [phr-gate] (skipped — tools/md-files-changed.sh not present)"
        return 0
    fi

    # Compute changed files in the push range and filter via md-files-changed.sh.
    # Three input shapes:
    #   (a) "A..B" range  -> git diff
    #   (b) single SHA (merge/root commit) -> git diff-tree --root -m
    #   (c) no_base -> git log --name-only -m over full tip history
    # Track enumeration success separately from "enumerated zero files": a
    # failed git command (e.g. an unreachable SHA) must fail closed (require
    # the sentinel), not be treated identically to a genuinely empty, valid
    # range -- mirrors the code-review gate's range_is_docs_only(), which
    # makes the same distinction for the identical failure class.
    local range_files md_files _enum_ok=true
    if [[ "$no_base" == "no_base" ]]; then
        # git log's own exit status must be captured BEFORE piping through
        # grep -v: grep exits 1 on zero matching lines (e.g. a branch of
        # only --allow-empty commits, where git log legitimately produces no
        # output at all) -- pipefail would otherwise misreport that as an
        # enumeration failure, not "genuinely zero files."
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
        # Cannot enumerate -- fail closed rather than let an empty $range_files
        # fall through the "no files in push range" / "no PHR-eligible files"
        # skip checks below, which would silently un-require the sentinel.
        echo "  [phr-gate] Could not enumerate push range files — failing closed (require sentinel)."
        md_files="(enumeration failed)"
    else
        if [[ -z "$range_files" ]]; then
            echo "  [phr-gate] (skipped — no files in push range)"
            return 0
        fi
        # Exclude skills/*.md: owned exclusively by the llm-skill-review
        # gate (see this file's header). Without this filter, a skills-only
        # push would require BOTH .phr-cleared and .llm-skill-review-cleared
        # for the same content -- exactly the redundancy this split removes.
        md_files=$("$md_helper" --files "$range_files" 2>/dev/null | grep -v '^skills/' || true)
        if [[ -z "$md_files" ]]; then
            echo "  [phr-gate] (skipped — no PHR-eligible md files in push)"
            return 0
        fi

        echo "  [phr-gate] PHR-eligible md files in push:"
        while IFS= read -r f; do
            [[ -n "$f" ]] && echo "    - $f"
        done <<< "$md_files"
    fi

    if [[ ! -f "$PHR_SENTINEL" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: .phr-cleared sentinel missing.${NC}"
        echo ""
        echo "  Design docs (docs/*.md, AGENTS.md, etc.) require Progressive"
        echo "  Harsh Review. After PHR passes (>= the project's minimum score),"
        echo "  write the sentinel:"
        echo "    tools/run-phr.sh --verdict PASS --min-score 9.5   # or your project min"
        echo ""
        echo "  PHR is the multi-persona AI judgment gate (Junior + SeniorArch +"
        echo "  ProdOps). It is SEPARATE from code-review-battery (automated"
        echo "  lint/test) and from llm-skill-review (which owns skills/*.md"
        echo "  exclusively -- see tools/pre-push-llm-skill-review-gate.sh)."
        echo ""
        return 1
    fi

    # Parse the sentinel by reading FIRST LINE ONLY -- a multi-line file
    # (corruption, manual edit, accidental append) must fail "format unrecognized",
    # not produce ambiguous NF values from a multi-line awk.
    local phr_line phr_ver phr_sha phr_verdict phr_ts phr_min field_count line_count
    line_count=$(awk 'NF{c++} END{print c+0}' "$PHR_SENTINEL" 2>/dev/null || echo "0")
    phr_line=$(head -n1 "$PHR_SENTINEL" 2>/dev/null || echo "")
    field_count=$(awk -F'|' '{print NF; exit}' <<< "$phr_line")
    IFS='|' read -r phr_ver phr_sha phr_verdict phr_ts phr_min <<< "$phr_line"

    if [[ "$phr_ver" != "v1" ]] || [[ "$field_count" -ne 5 ]] || [[ "$line_count" -gt 1 ]] || \
       [[ -z "$phr_sha" ]] || [[ -z "$phr_verdict" ]] || [[ -z "$phr_ts" ]] || [[ -z "$phr_min" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: PHR sentinel format unrecognized (expected v1|SHA|VERDICT|TIMESTAMP|min-score=N).${NC}"
        echo "    Delete .phr-cleared and re-run: tools/run-phr.sh --verdict PASS --min-score 9.5   # or your project min"
        return 1
    fi

    # Only PASS clears the gate. PASS_WITH_FIXES means another round is required;
    # REJECT means fix findings.
    if [[ "$phr_verdict" != "PASS" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: PHR verdict was not passing (got '$phr_verdict').${NC}"
        echo "    Only PASS clears the gate. Run another PHR round, then:"
        echo "      tools/run-phr.sh --verdict PASS --min-score 9.5   # or your project min"
        return 1
    fi

    if [[ ! "$phr_min" =~ ^min-score=[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: PHR sentinel min-score field malformed: '$phr_min'.${NC}"
        echo "    Delete .phr-cleared and re-run: tools/run-phr.sh --verdict PASS --min-score 9.5   # or your project min"
        return 1
    fi

    if [[ "$phr_sha" != "$pushed_sha" ]]; then
        echo -e "  ${RED}❌ PUSH BLOCKED: PHR sentinel is stale.${NC}"
        echo "    PHR was for: ${phr_sha:0:8}"
        echo "    Pushing:     ${pushed_sha:0:8}"
        echo "    Commits were made after PHR. Re-run PHR then tools/run-phr.sh."
        return 1
    fi

    # Sentinel intentionally NOT consumed here: PHR is SHA-bound, so a single
    # PASS covers re-pushes of the same SHA (e.g., to a different remote, or
    # retry after a transient network failure). Stale-on-amend is caught above.
    echo -e "  ${GREEN}✓ PHR cleared: $phr_verdict ${phr_min} (${phr_sha:0:8})${NC}"
    return 0
}

ERRORS=0
while IFS= read -r _line; do
    read -r _ local_sha remote_ref remote_sha <<< "$_line"
    [[ "$local_sha" == "0000000000000000000000000000000000000000" ]] && continue

    resolve_diff_range "$local_sha" "$remote_sha" "$REMOTE_NAME"
    echo "  Checking commits: $RANGE (${remote_ref#refs/heads/})"

    if [[ "$NEW_BRANCH_NO_BASE" == "true" ]]; then
        check_phr_sentinel "$RANGE" "$local_sha" "no_base" || ERRORS=$((ERRORS + 1))
    else
        check_phr_sentinel "$RANGE" "$local_sha" || ERRORS=$((ERRORS + 1))
    fi
done

exit $(( ERRORS > 0 ? 1 : 0 ))
