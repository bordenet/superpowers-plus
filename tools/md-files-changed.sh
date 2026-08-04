#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: md-files-changed.sh
# PURPOSE: Single source of truth for "did this branch change AI-guidance
#          .md files?", AND for the ownership split within that set between
#          llm-skill-review (Gate 6) and PHR (Gate 5). Used by
#          tools/run-battery.sh, tools/pre-push-phr-gate.sh,
#          tools/pre-push-llm-skill-review-gate.sh, and the
#          finishing-a-development-branch skill so neither the trigger
#          regex nor the ownership boundary is ever duplicated.
#
# Scope counted as AI-guidance-relevant (the default, undecorated output):
#   - any path under skills/*.md, docs/*.md, or .ai-guidance/*.md
#   - repo-root *.md whose filename starts with an uppercase letter
#     (e.g. AGENTS.md, DESIGN.md, ARCHITECTURE.md)
#   - AGENTS.md, CLAUDE.md, GEMINI.md, CODEX.md, COPILOT.md, or AGENT.md at
#     ANY path depth (e.g. a nested guidance/AGENTS.md), not just repo root
# Always excluded from the result:
#   - README.md and CHANGELOG.md at the repo root (they match the uppercase
#     pattern but are not PHR gates)
#
# Within that set, files owned EXCLUSIVELY by llm-skill-review (content
# expressly written FOR an LLM to execute, not human-facing docs/design --
# see skills/engineering/llm-skill-review/skill.md's own "When to Use"):
#   - skills/**/*.md
#   - .ai-guidance/**/*.md (AGENTS.md overflow -- AGENTS.md's own
#     self-management protocol moves content here purely on a line-count
#     limit, not because the audience changes)
#   - any AGENTS.md / CLAUDE.md / GEMINI.md / CODEX.md / COPILOT.md /
#     AGENT.md file, at any path depth
# Everything else in the AI-guidance-relevant set (docs/*.md, and root- or
# nested- uppercase *.md that is NOT one of the agent-file basenames above,
# e.g. DESIGN.md, ARCHITECTURE.md) remains PHR's (Gate 5's) territory.
#
# USAGE:
#   tools/md-files-changed.sh                   # diff against best-guess base
#   tools/md-files-changed.sh --base <ref>      # diff against an explicit ref
#   tools/md-files-changed.sh --files <list>    # filter newline-separated names
#                                               # (e.g. for staged-only checks)
#   tools/md-files-changed.sh --print-base      # echo the resolved base ref
#   tools/md-files-changed.sh --llm-owned       # narrow to the llm-skill-review
#                                               # -exclusive subset only
#   tools/md-files-changed.sh --exclude-llm-owned  # the complement: everything
#                                               # PHR still owns
#
# EXIT CODES:
#   0  one or more matching .md files changed (and printed on stdout)
#   1  no matching .md files changed
#   2  could not resolve a base ref (orphan/root commit); over-warn upstream
#   3  argument/usage error
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
    sed -n '2,51p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-3}"
}

BASE_OVERRIDE=""
FILE_LIST=""
PRINT_BASE_ONLY=0
LLM_OWNED_ONLY=0
EXCLUDE_LLM_OWNED=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage 0 ;;
        --base)
            [[ $# -ge 2 ]] || { echo "❌ --base requires a ref" >&2; exit 3; }
            BASE_OVERRIDE="$2"; shift 2 ;;
        --base=*) BASE_OVERRIDE="${1#--base=}"; shift ;;
        --files)
            [[ $# -ge 2 ]] || { echo "❌ --files requires a value" >&2; exit 3; }
            FILE_LIST="$2"; shift 2 ;;
        --files=*) FILE_LIST="${1#--files=}"; shift ;;
        --print-base) PRINT_BASE_ONLY=1; shift ;;
        --llm-owned) LLM_OWNED_ONLY=1; shift ;;
        --exclude-llm-owned) EXCLUDE_LLM_OWNED=1; shift ;;
        *) echo "❌ Unknown flag: $1" >&2; usage 3 ;;
    esac
done

if [[ "$LLM_OWNED_ONLY" -eq 1 && "$EXCLUDE_LLM_OWNED" -eq 1 ]]; then
    echo "❌ --llm-owned and --exclude-llm-owned are mutually exclusive." >&2
    exit 3
fi

# Resolve the merge base.
# Fallback chain: explicit override > this branch's own tracking upstream >
# dev > staging > main > master (each tried as both origin/<name> and a bare
# local branch name) > HEAD^.
#
# This repo's actual workflow base for feature/fix branches is `dev` --
# `main` is a downstream promotion target reached via dev -> staging -> main,
# often many commits ahead of dev. Falling back straight to main (the
# previous chain here) diffed against a stale ancestor and picked up every
# file that had landed in dev but not yet promoted to main, producing
# false-positive PHR-eligible-file hits on branches that never touched those
# files themselves. Mirrors the equivalent, already-correct fallback chain in
# tools/lib/pre-push-diff-range.sh's resolve_push_base_ref(), which this
# repo's own pre-push hook relies on for the identical problem.
#
# This helper is the single source of truth — `tools/run-battery.sh` and the
# finishing-a-development-branch skill both invoke this script rather than
# duplicating the chain.
#
# IMPORTANT: every git command here MUST use `--verify` (or already-resolving
# verbs like merge-base). `git rev-parse HEAD^` without --verify prints the
# literal argument "HEAD^" to stdout on failure, which would silently feed a
# bogus base into the downstream diff.
resolve_base() {
    if [[ -n "$BASE_OVERRIDE" ]]; then
        git rev-parse --verify "$BASE_OVERRIDE" 2>/dev/null
        return
    fi

    local tracking candidate merge_base
    tracking="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"

    for candidate in \
        "$tracking" \
        origin/dev dev origin/staging staging origin/main main origin/master master
    do
        [[ -n "$candidate" ]] || continue
        if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
            if merge_base=$(git merge-base HEAD "$candidate" 2>/dev/null); then
                echo "$merge_base"
                return
            fi
        fi
    done

    git rev-parse --verify HEAD^ 2>/dev/null || true
}

# Single source of truth for the llm-skill-review-exclusive ownership
# boundary -- consumed both here (to narrow/exclude) and nowhere else; every
# other gate/script asks THIS script via --llm-owned / --exclude-llm-owned
# rather than re-deriving the pattern.
LLM_OWNED_REGEX='(^skills/|^\.ai-guidance/).*\.md$|(^|/)(AGENTS|CLAUDE|GEMINI|CODEX|COPILOT|AGENT)\.md$'

# Apply the AI-guidance-relevance filter to a newline-separated file list on
# stdin. Superset of the llm-skill-review-owned files above.
filter() {
    grep -E '(^skills/|^docs/|^\.ai-guidance/).*\.md$|^[A-Z][A-Za-z_-]*\.md$|(^|/)(AGENTS|CLAUDE|GEMINI|CODEX|COPILOT|AGENT)\.md$' \
        | grep -vE '^(README|CHANGELOG)\.md$' || true
}

BASE=""
if [[ -z "$FILE_LIST" ]]; then
    BASE=$(resolve_base)
    if [[ -z "$BASE" ]]; then
        if [[ "$PRINT_BASE_ONLY" -eq 1 ]]; then
            echo "NO_BASE_FOUND"
        fi
        exit 2
    fi
fi

if [[ "$PRINT_BASE_ONLY" -eq 1 ]]; then
    echo "$BASE"
    exit 0
fi

if [[ -n "$FILE_LIST" ]]; then
    matches=$(printf '%s\n' "$FILE_LIST" | filter)
else
    matches=$(git diff "$BASE"..HEAD --name-only 2>/dev/null | filter)
fi

if [[ "$LLM_OWNED_ONLY" -eq 1 ]]; then
    matches=$(printf '%s\n' "$matches" | grep -E "$LLM_OWNED_REGEX" || true)
elif [[ "$EXCLUDE_LLM_OWNED" -eq 1 ]]; then
    matches=$(printf '%s\n' "$matches" | grep -vE "$LLM_OWNED_REGEX" || true)
fi

if [[ -z "$matches" ]]; then
    exit 1
fi
printf '%s\n' "$matches"
exit 0
