#!/usr/bin/env bash
# public-repo-ip-check.sh
#
# Audit a public repository for proprietary IP before commit/push.
# Part of the public-repo-ip-audit skill.
#
# Usage: ./public-repo-ip-check.sh [--patterns "REGEX"] [--history] [--verbose]
#                                   [--staged-only] [--range RANGE] [--all-files]
#
# Options:
#   --patterns "REGEX"  Custom pattern regex (default: repo/local pattern files)
#   --history           Also check full git history (slower)
#   --verbose           Show matching lines (CAUTION: may print sensitive identifiers)
#   --staged-only       Check only staged additions (used by pre-commit)
#   --range RANGE       Check only a commit range (used by pre-push)
#   --all-files         Diagnostic mode: scan all tracked files, not just new changes
#
# Exit codes:
#   0 - PASS: No IP found
#   1 - FAIL: IP found
#   2 - ERROR: Script error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    if [[ "$SCRIPT_DIR" == *".git/hooks"* ]]; then
        REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    else
        REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi

cd "$REPO_ROOT"

DEFAULT_PATTERNS="INTERNAL-[0-9]+|internal\.company\.com|@company\.com"
PATTERNS=""
CUSTOM_PATTERNS=false
CHECK_HISTORY=false
VERBOSE=false
STAGED_ONLY=false
ALL_FILES=false
COMMIT_RANGE=""
LOADED_PATTERN_FILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --patterns)
            [[ $# -ge 2 ]] || { echo "Missing value for --patterns"; exit 2; }
            PATTERNS="$2"
            CUSTOM_PATTERNS=true
            shift 2
            ;;
        --history)
            CHECK_HISTORY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --staged-only)
            STAGED_ONLY=true
            shift
            ;;
        --range)
            [[ $# -ge 2 ]] || { echo "Missing value for --range"; exit 2; }
            COMMIT_RANGE="$2"
            shift 2
            ;;
        --all-files)
            ALL_FILES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--patterns \"REGEX\"] [--history] [--verbose] [--staged-only] [--range RANGE] [--all-files]"
            echo ""
            echo "Options:"
            echo "  --patterns \"REGEX\"  Custom pattern regex"
            echo "  --history           Also check full git history"
            echo "  --verbose           Show matching lines (use with care)"
            echo "  --staged-only       Check only staged additions"
            echo "  --range RANGE       Check only a commit range"
            echo "  --all-files         Scan all tracked files (diagnostic)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

indent_output() {
    while IFS= read -r line; do
        printf '    %s\n' "$line"
    done
}

join_patterns_from_file() {
    local file="$1"
    grep -v '^#' "$file" 2>/dev/null | grep -v '^[[:space:]]*$' | paste -sd'|' -
}

load_patterns() {
    local combined file_patterns
    combined=("$DEFAULT_PATTERNS")

    if [[ "$CUSTOM_PATTERNS" == "true" ]]; then
        return 0
    fi

    for file in "$REPO_ROOT/.ip-patterns" "$REPO_ROOT/.ip-check-patterns"; do
        [[ -f "$file" ]] || continue
        file_patterns="$(join_patterns_from_file "$file")"
        [[ -n "$file_patterns" ]] || continue
        combined+=("$file_patterns")
        LOADED_PATTERN_FILES+=("$(basename "$file")")
    done

    PATTERNS="$(IFS='|'; echo "${combined[*]}")"
}

resolve_audit_base() {
    local candidate tracking
    tracking="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"

    for candidate in \
        "$tracking" \
        origin/dev origin/staging origin/main origin/master \
        upstream/dev upstream/staging upstream/main upstream/master \
        gitlab/dev gitlab/staging gitlab/main gitlab/master
    do
        [[ -n "$candidate" ]] || continue
        if git rev-parse --verify "$candidate" &>/dev/null; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

is_excluded_file() {
    case "$1" in
        .ip-patterns|.ip-check-patterns) return 0 ;;
        *) return 1 ;;
    esac
}

is_binary_file() {
    local file="$1"
    file "$file" 2>/dev/null | grep -q "binary"
}

count_added_line_matches() {
    grep -E '^\+' \
        | grep -vE '^\+\+\+ (a/|b/|/dev/null)' \
        | sed 's/^+//' \
        | grep -cE "$PATTERNS" || true
}

show_added_line_matches() {
    grep -E '^\+' \
        | grep -vE '^\+\+\+ (a/|b/|/dev/null)' \
        | sed 's/^+//' \
        | grep -E "$PATTERNS" | indent_output || true
}

check_untracked_files() {
    local hits file
    hits=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -f "$file" ]] || continue
        is_excluded_file "$file" && continue
        is_binary_file "$file" && continue
        if grep -qE "$PATTERNS" "$file" 2>/dev/null; then
            hits+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard)

    if [[ ${#hits[@]} -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in untracked files"
        printf '%s\n' "${hits[@]}" | indent_output
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            for file in "${hits[@]}"; do
                grep -nE "$PATTERNS" "$file" 2>/dev/null | indent_output || true
            done
        fi
        return 1
    fi

    echo "  ✓ Untracked files clean"
    return 0
}

check_all_tracked_files() {
    local hits file
    hits=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -f "$file" ]] || continue
        is_excluded_file "$file" && continue
        is_binary_file "$file" && continue
        if grep -qE "$PATTERNS" "$file" 2>/dev/null; then
            hits+=("$file")
        fi
    done < <(git ls-files)

    if [[ ${#hits[@]} -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in tracked files"
        printf '%s\n' "${hits[@]}" | indent_output
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            for file in "${hits[@]}"; do
                grep -nE "$PATTERNS" "$file" 2>/dev/null | indent_output || true
            done
        fi
        return 1
    fi

    echo "  ✓ Tracked files clean"
    return 0
}

check_diff_stream() {
    local label="$1"
    shift
    local matches
    matches="$("$@" | count_added_line_matches)"
    if [[ "$matches" -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in ${label} ($matches match(es))"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            "$@" | show_added_line_matches
        fi
        return 1
    fi

    echo "  ✓ ${label} clean"
    return 0
}

check_commit_metadata() {
    local range="$1"
    local bad_emails
    bad_emails="$(git log "$range" --format='%ae%n%ce' 2>/dev/null | sort -u | grep -iE "$PATTERNS" || true)"
    if [[ -n "$bad_emails" ]]; then
        echo "  ❌ FAIL: IP found in commit metadata"
        printf '%s\n' "$bad_emails" | indent_output
        return 1
    fi

    echo "  ✓ Commit metadata clean"
    return 0
}

load_patterns

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Public Repository IP Audit                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
if [[ "$CUSTOM_PATTERNS" == "true" ]]; then
    echo "Patterns: custom --patterns override"
elif [[ ${#LOADED_PATTERN_FILES[@]} -gt 0 ]]; then
    echo "Patterns: defaults + ${LOADED_PATTERN_FILES[*]}"
else
    echo "Patterns: defaults only"
fi
echo ""

FAILED=false

if [[ "$ALL_FILES" == "true" ]]; then
    echo "▶ Checking all tracked files..."
    check_all_tracked_files || FAILED=true
fi

if [[ -n "$COMMIT_RANGE" ]]; then
    echo "▶ Checking commit range..."
    echo "  Range: $COMMIT_RANGE"
    check_diff_stream "commit range" git log -p --no-ext-diff --unified=0 "$COMMIT_RANGE" -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true
    check_commit_metadata "$COMMIT_RANGE" || FAILED=true
elif [[ "$STAGED_ONLY" == "true" ]]; then
    echo "▶ Checking staged changes..."
    check_diff_stream "staged changes" git diff --staged --no-ext-diff --unified=0 --no-color -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true
else
    echo "▶ Checking unstaged changes..."
    check_diff_stream "unstaged changes" git diff --no-ext-diff --unified=0 --no-color -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true

    echo "▶ Checking untracked files..."
    check_untracked_files || FAILED=true

    echo "▶ Checking staged changes..."
    check_diff_stream "staged changes" git diff --staged --no-ext-diff --unified=0 --no-color -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true

    echo "▶ Checking unpushed commits..."
    AUDIT_BASE="$(resolve_audit_base || true)"
    if [[ -n "$AUDIT_BASE" ]]; then
        AUDIT_RANGE="$AUDIT_BASE..HEAD"
        echo "  Range: $AUDIT_RANGE"
        check_diff_stream "unpushed commits" git log -p --no-ext-diff --unified=0 "$AUDIT_RANGE" -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true
        check_commit_metadata "$AUDIT_RANGE" || FAILED=true
    else
        echo "  ⚠ No upstream/base branch configured, skipping"
    fi
fi

# Check 4: Full history (optional, slow)
if [[ "$CHECK_HISTORY" == true ]]; then
    echo "▶ Checking full git history (this may take a while)..."
    HISTORY_MATCHES=$(git log --all --oneline | while read -r sha _; do
        if git show "$sha" 2>/dev/null | grep -qE "$PATTERNS"; then
            echo "$sha"
        fi
    done)
    
    if [[ -n "$HISTORY_MATCHES" ]]; then
        HISTORY_COUNT=$(echo "$HISTORY_MATCHES" | wc -l | tr -d ' ')
        echo "  ⚠️  ADVISORY: IP found in $HISTORY_COUNT historical commit(s)"
        echo "  These predate current pattern adoption and do NOT block push."
        echo "  Commits:"
        echo "$HISTORY_MATCHES" | head -10
        # History hits are advisory — do NOT set FAILED=true
    else
        echo "  ✓ Git history clean"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAILED" == true ]]; then
    echo "❌ AUDIT FAILED: Proprietary IP detected"
    echo ""
    echo "DO NOT commit or push until all issues are resolved."
    echo "See: skills/security/public-repo-ip-audit/skill.md"
    exit 1
else
    echo "✅ AUDIT PASSED: No proprietary IP detected"
    echo ""
    echo "Safe to commit and push."
    exit 0
fi
