#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: md-files-changed.sh
# PURPOSE: Single source of truth for "did this branch change PHR-relevant
#          .md files?" Used by tools/run-battery.sh and the
#          finishing-a-development-branch skill so the PHR-trigger regex
#          lives in exactly one place.
#
# Scope counted as PHR-relevant:
#   - any path under skills/*.md or docs/*.md
#   - repo-root *.md whose filename starts with an uppercase letter
#     (e.g. AGENTS.md, DESIGN.md, ARCHITECTURE.md)
# Always excluded from the result:
#   - README.md and CHANGELOG.md at the repo root (they match the uppercase
#     pattern but are not PHR gates)
#
# USAGE:
#   tools/md-files-changed.sh                   # diff against best-guess base
#   tools/md-files-changed.sh --base <ref>      # diff against an explicit ref
#   tools/md-files-changed.sh --files <list>    # filter newline-separated names
#                                               # (e.g. for staged-only checks)
#   tools/md-files-changed.sh --print-base      # echo the resolved base ref
#
# EXIT CODES:
#   0  one or more PHR-relevant .md files changed (and printed on stdout)
#   1  no PHR-relevant .md files changed
#   2  could not resolve a base ref (orphan/root commit); over-warn upstream
#   3  argument/usage error
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
    sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-3}"
}

BASE_OVERRIDE=""
FILE_LIST=""
PRINT_BASE_ONLY=0

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
        *) echo "❌ Unknown flag: $1" >&2; usage 3 ;;
    esac
done

# Resolve the merge base.
# Fallback chain: explicit override > main > origin/main > master > origin/master > HEAD^.
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
    git merge-base HEAD main 2>/dev/null \
        || git merge-base HEAD origin/main 2>/dev/null \
        || git merge-base HEAD master 2>/dev/null \
        || git merge-base HEAD origin/master 2>/dev/null \
        || git rev-parse --verify HEAD^ 2>/dev/null \
        || true
}

# Apply the PHR-relevance filter to a newline-separated file list on stdin.
filter() {
    grep -E '(^skills/|^docs/).*\.md$|^[A-Z][A-Za-z_-]*\.md$' \
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

if [[ -z "$matches" ]]; then
    exit 1
fi
printf '%s\n' "$matches"
exit 0
