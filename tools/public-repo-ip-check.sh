#!/usr/bin/env bash
# public-repo-ip-check.sh
#
# Audit a public repository for proprietary IP before commit/push.
# Part of the public-repo-ip-audit skill.
#
# Usage: ./public-repo-ip-check.sh [--patterns "REGEX"] [--history] [--verbose]
#                                   [--staged-only] [--range RANGE] [--all-files]
#                                   [--stdin [--stdin-label LABEL]]
#
# Options:
#   --patterns "REGEX"  Custom pattern regex (default: repo/local pattern files)
#   --history           Also check full git history (slower)
#   --verbose           Show matching lines (CAUTION: may print sensitive identifiers)
#   --staged-only       Check only staged additions (used by pre-commit)
#   --range RANGE       Check only a commit range (used by pre-push)
#   --all-files         Diagnostic mode: scan all tracked files, not just new changes
#   --stdin             Scan arbitrary text piped on stdin (e.g. a PR title/body)
#                        instead of any git-derived source. Requires no git repo.
#   --stdin-label LABEL Label used in output for --stdin mode (default: "stdin text")
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

# Every content-matching grep against $PATTERNS below uses
# -i. check_commit_metadata() (further down) already did; the file/diff scans
# didn't, so the identical pattern string was matched case-sensitively in the
# scans that matter most (diff hunks, tracked/untracked files) and case-
# insensitively only for commit-author emails -- an operator or downstream
# adopter adding a custom pattern got silently weaker coverage everywhere
# except the one scan that happened to have -i.
DEFAULT_PATTERNS="INTERNAL-[0-9]+|internal\.company\.com|@company\.com"
PATTERNS=""
CUSTOM_PATTERNS=false
CHECK_HISTORY=false
VERBOSE=false
STAGED_ONLY=false
ALL_FILES=false
COMMIT_RANGE=""
STDIN_MODE=false
STDIN_LABEL="stdin text"
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
        --stdin)
            STDIN_MODE=true
            shift
            ;;
        --stdin-label)
            [[ $# -ge 2 ]] || { echo "Missing value for --stdin-label"; exit 2; }
            STDIN_LABEL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--patterns \"REGEX\"] [--history] [--verbose] [--staged-only] [--range RANGE] [--all-files] [--stdin [--stdin-label LABEL]]"
            echo ""
            echo "Options:"
            echo "  --patterns \"REGEX\"  Custom pattern regex"
            echo "  --history           Also check full git history"
            echo "  --verbose           Show matching lines (use with care)"
            echo "  --staged-only       Check only staged additions"
            echo "  --range RANGE       Check only a commit range"
            echo "  --all-files         Scan all tracked files (diagnostic)"
            echo "  --stdin             Scan text piped on stdin (e.g. a PR title/body)"
            echo "  --stdin-label LABEL Label for --stdin mode output"
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

# Shared by both the pattern-grep scan and the hash-based scan below, so the
# two matching engines can never silently drift apart on what counts as "an
# added line" (e.g. diff-header edge cases). Ends in `|| true` and is always
# the tail of any pipeline it's used in, so a diff with zero added lines
# (grep finds no match) can never itself trigger errexit under pipefail.
extract_added_lines() {
    grep -E '^\+' | grep -vE '^\+\+\+ ' | sed 's/^+//' || true
}

count_added_line_matches() {
    extract_added_lines | grep -ciE "$PATTERNS" || true
}

show_added_line_matches() {
    extract_added_lines | grep -iE "$PATTERNS" | indent_output || true
}

# Hash-based banned-term scan (permanent internal-codename denylist). See
# tools/check-banned-term-hashes.py -- terms are salted hashes, never
# plaintext, so the guard cannot itself leak what it's guarding against.
#
# Resolved via REPO_ROOT (not a SCRIPT_DIR relative to this file) even
# though install-hooks.sh never copies this script elsewhere today --
# tools/commit-msg IS copied into .git/hooks/ and shipped with exactly this
# bug (a BASH_SOURCE-relative path silently stopped finding this file once
# installed). Matching commit-msg's resolution strategy here means this
# script keeps working correctly if it's ever copied the same way.
BANNED_HASH_SCRIPT="$REPO_ROOT/tools/check-banned-term-hashes.py"

# Cached once at script load, not re-checked per call -- file_has_banned_hash
# runs once per tracked/untracked file, so a per-call `command -v python3`
# would otherwise print the same warning below hundreds of times in a large
# repo. Previously these two functions silently returned 1 ("no banned hash
# found") when python3 was absent, with zero warning -- the hash-obfuscated
# codename denylist went dark with no visible signal, unlike
# check_commit_messages_for_banned_hashes below, which always warned
# (llm-skill-review, 2026-07-17, S1). The plaintext $PATTERNS scan still runs
# regardless, so this is a warn-and-skip, not a fail-closed, degradation --
# consistent with check_commit_messages_for_banned_hashes' existing choice
# for the identical missing-python3 condition, not a new, stricter policy.
PYTHON3_AVAILABLE=false
command -v python3 >/dev/null 2>&1 && PYTHON3_AVAILABLE=true

# NOTE on set -e/pipefail safety: every risky pipeline below is either the
# direct condition of an `if` or immediately followed by an explicit
# `return` inside that if/else -- never a bare statement whose exit status
# is read via a later `$?`. Under `pipefail` (active for this whole script),
# a bare failing pipeline statement would trigger errexit and abort the
# script before the exit code could be inspected; pipelines used directly as
# an if-condition are exempt from that regardless of pipefail.
added_lines_have_banned_hash() {
    [[ "$PYTHON3_AVAILABLE" == "true" ]] || return 1
    [[ -f "$BANNED_HASH_SCRIPT" ]] || return 1
    if extract_added_lines | python3 "$BANNED_HASH_SCRIPT" >/dev/null 2>&1; then
        return 1  # python exit 0 = clean
    fi
    return 0  # python exit 1 = banned term found
}

file_has_banned_hash() {
    local target="$1"
    [[ "$PYTHON3_AVAILABLE" == "true" ]] || return 1
    [[ -f "$BANNED_HASH_SCRIPT" ]] || return 1
    if python3 "$BANNED_HASH_SCRIPT" < "$target" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

check_commit_messages_for_banned_hashes() {
    local range="$1"
    command -v python3 >/dev/null 2>&1 || { echo "  ⚠ python3 not found; skipping commit-message hash scan"; return 0; }
    [[ -f "$BANNED_HASH_SCRIPT" ]] || return 0
    # Capture git log's own output/exit status separately (same rationale as
    # check_diff_stream above) so a failed git invocation -- bad revision
    # range, unreachable SHA -- is never silently indistinguishable from a
    # genuinely clean, empty range.
    local msgs
    if ! msgs="$(git log "$range" --format='%B' 2>&1)"; then
        echo "  ❌ FAIL: could not read commit messages for banned-term scan (range: $range) — treating as unscanned, not clean"
        return 1
    fi
    if printf '%s' "$msgs" | python3 "$BANNED_HASH_SCRIPT" >/dev/null 2>&1; then
        echo "  ✓ Commit messages clean (banned-term scan)"
        return 0
    fi
    echo "  ❌ FAIL: banned internal term detected in commit message(s)"
    return 1
}

check_untracked_files() {
    local hits file
    hits=()

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -f "$file" ]] || continue
        is_excluded_file "$file" && continue
        is_binary_file "$file" && continue
        if grep -qiE "$PATTERNS" "$file" 2>/dev/null || file_has_banned_hash "$file"; then
            hits+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard)

    if [[ ${#hits[@]} -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in untracked files"
        printf '%s\n' "${hits[@]}" | indent_output
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            for file in "${hits[@]}"; do
                grep -niE "$PATTERNS" "$file" 2>/dev/null | indent_output || true
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
        if grep -qiE "$PATTERNS" "$file" 2>/dev/null || file_has_banned_hash "$file"; then
            hits+=("$file")
        fi
    done < <(git ls-files)

    if [[ ${#hits[@]} -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in tracked files"
        printf '%s\n' "${hits[@]}" | indent_output
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            for file in "${hits[@]}"; do
                grep -niE "$PATTERNS" "$file" 2>/dev/null | indent_output || true
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
    # The old `matches="$("$@" | count_added_line_matches)"`
    # discarded the upstream command's own exit status -- count_added_line_
    # matches ends in `|| true` so its own return is always 0, and being the
    # RIGHT side of a pipe, that's also what a bare `pipefail` would report.
    # A failed git invocation (bad revision range, unreachable SHA in a
    # shallow clone, a GC/rebase race) produced empty stdin, which counted as
    # zero matches -- reported as "clean" even though nothing was ever
    # scanned. Capture the command's own output and exit status separately,
    # BEFORE any grep-based counting, so a real failure is never silently
    # indistinguishable from a genuinely empty, successful diff.
    local diff_output
    if ! diff_output="$("$@")"; then
        echo "  ❌ FAIL: could not compute diff for ${label} (command exited non-zero — see error above) — treating as unscanned, not clean"
        return 1
    fi
    local matches
    matches="$(printf '%s\n' "$diff_output" | count_added_line_matches)"
    if [[ "$matches" -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in ${label} ($matches pattern match(es))"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            printf '%s\n' "$diff_output" | show_added_line_matches
        fi
        return 1
    fi
    if printf '%s\n' "$diff_output" | added_lines_have_banned_hash; then
        echo "  ❌ FAIL: banned internal term detected in ${label}"
        return 1
    fi

    echo "  ✓ ${label} clean"
    return 0
}

check_stdin_text() {
    local label="$1"
    local text
    text="$(cat)"

    local matches
    matches="$(printf '%s\n' "$text" | grep -ciE "$PATTERNS" || true)"
    if [[ "$matches" -gt 0 ]]; then
        echo "  ❌ FAIL: IP found in ${label} ($matches pattern match(es))"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  --- verbose output (may contain sensitive identifiers) ---"
            printf '%s\n' "$text" | grep -niE "$PATTERNS" | indent_output || true
        fi
        return 1
    fi

    if [[ "$PYTHON3_AVAILABLE" == "true" && -f "$BANNED_HASH_SCRIPT" ]]; then
        if ! printf '%s' "$text" | python3 "$BANNED_HASH_SCRIPT" >/dev/null 2>&1; then
            echo "  ❌ FAIL: banned internal term detected in ${label}"
            return 1
        fi
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
if [[ "$PYTHON3_AVAILABLE" == "false" ]]; then
    echo "⚠ python3 not found — the hash-based banned-term scan (codename denylist) is DISABLED for this run. The plaintext pattern scan above still runs, but obfuscated/hash-only banned terms will NOT be caught. Install python3 to restore full coverage." >&2
fi
echo ""

FAILED=false

if [[ "$ALL_FILES" == "true" ]]; then
    echo "▶ Checking all tracked files..."
    check_all_tracked_files || FAILED=true
fi

if [[ "$STDIN_MODE" == "true" ]]; then
    echo "▶ Checking ${STDIN_LABEL}..."
    check_stdin_text "$STDIN_LABEL" || FAILED=true
elif [[ -n "$COMMIT_RANGE" ]]; then
    echo "▶ Checking commit range..."
    echo "  Range: $COMMIT_RANGE"
    check_diff_stream "commit range" git log -p --no-ext-diff --unified=0 "$COMMIT_RANGE" -- . ':(exclude).ip-patterns' ':(exclude).ip-check-patterns' || FAILED=true
    check_commit_metadata "$COMMIT_RANGE" || FAILED=true
    check_commit_messages_for_banned_hashes "$COMMIT_RANGE" || FAILED=true
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
        check_commit_messages_for_banned_hashes "$AUDIT_RANGE" || FAILED=true
    else
        echo "  ⚠ No upstream/base branch configured, skipping"
    fi
fi

# Check 4: Full history (optional, slow)
if [[ "$CHECK_HISTORY" == true ]]; then
    echo "▶ Checking full git history (this may take a while)..."
    HISTORY_MATCHES=$(git log --all --oneline | while read -r sha _; do
        if git show "$sha" 2>/dev/null | grep -qiE "$PATTERNS"; then
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
