#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# session-handoff-check.sh
#
# First-touch advisory: lists commits on remote-tracking refs that landed in
# the last N hours (default 24h) and are NOT yet reachable from any local
# branch. Surfaces sibling-machine activity at the start of a session so the
# engineer reads context BEFORE editing.
#
# Why this exists: branch-sync-gate fires on RESUME language ("continuing",
# "resuming"). The 2026-06-10 incident-2026-1507 involved two machines doing
# parallel work on the same hotfix branch without explicit handoff -- session
# B opened, edited, pushed, and only later discovered session A had been
# working concurrently. branch-sync-gate did not fire because the engineer
# never said "resuming". session-handoff is the cold-start complement that
# fires on first-touch verbs ("starting work on...", "let me check...").
#
# Invocation:
#   tools/session-handoff-check.sh                  # summary (silent if none)
#   tools/session-handoff-check.sh --verbose        # always announce result
#   tools/session-handoff-check.sh --help           # usage
#
# Exit codes (stable contract):
#   0  success -- sibling activity surfaced, OR none found, OR fetch failed,
#      OR no user.email -- in all cases this is an advisory and never blocks
#   2  not inside a git repo, OR invalid env var, OR git error during query
#
# Env vars:
#   SESSION_HANDOFF_WINDOW    "24 hours ago" -- any git log --since expression
#   SESSION_HANDOFF_VERBOSE   0|1 -- 1 prints "no sibling activity" assurance
#   SESSION_HANDOFF_NO_FETCH  0|1 -- 1 skips `git fetch` (for tests / offline)
#   SESSION_HANDOFF_FETCH_TIMEOUT  10 -- fetch wall-clock budget (seconds)

set -euo pipefail
export LC_ALL=C

# --help / -h
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        *) ;;
    esac
done
if [[ "${SESSION_HANDOFF_VERBOSE:-0}" == "1" ]]; then
    VERBOSE=1
fi

WINDOW=${SESSION_HANDOFF_WINDOW:-"24 hours ago"}
NO_FETCH=${SESSION_HANDOFF_NO_FETCH:-0}
FETCH_TIMEOUT=${SESSION_HANDOFF_FETCH_TIMEOUT:-10}

if ! [[ "$FETCH_TIMEOUT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: SESSION_HANDOFF_FETCH_TIMEOUT=$FETCH_TIMEOUT must be a non-negative integer." >&2
    exit 2
fi

# Resolve repo root; fail-CLOSED if not in a repo (exit 2).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: session-handoff-check.sh -- not inside a git repo." >&2
    exit 2
}
cd "$REPO_ROOT"

# NOTE: we deliberately do NOT filter by author. Both same-email-different-
# machine AND other-author commits are surfaced; both are actionable handoffs.
# (recon Q2: "are both 'me on another machine' and 'a teammate' actionable?
# yes -- both require context sync.")

# -----------------------------------------------------------------------------
# Fetch (optional)
# -----------------------------------------------------------------------------
# We fetch with a wall-clock timeout so a slow / unreachable remote cannot
# stall the session. macOS BSD `timeout` is not standard; prefer GNU coreutils
# `gtimeout` if present, then `timeout`, then fall back to background-kill.
if [[ "$NO_FETCH" != "1" ]]; then
    _timeout_bin=""
    if command -v gtimeout >/dev/null 2>&1; then _timeout_bin="gtimeout"
    elif command -v timeout >/dev/null 2>&1; then _timeout_bin="timeout"
    fi
    if [[ -n "$_timeout_bin" ]]; then
        if ! "$_timeout_bin" "$FETCH_TIMEOUT" git fetch --all --quiet 2>/dev/null; then
            echo "session-handoff: git fetch failed or timed out; falling back to stale remote refs." >&2
        fi
    else
        # Fallback: background fetch + kill if it exceeds the budget. Less
        # precise than timeout(1) but works on stock macOS without gtimeout.
        git fetch --all --quiet 2>/dev/null &
        _fetch_pid=$!
        _waited=0
        while kill -0 "$_fetch_pid" 2>/dev/null; do
            sleep 1
            _waited=$((_waited + 1))
            if (( _waited >= FETCH_TIMEOUT )); then
                kill -TERM "$_fetch_pid" 2>/dev/null || true
                echo "session-handoff: git fetch exceeded ${FETCH_TIMEOUT}s budget; using stale remote refs." >&2
                break
            fi
        done
        wait "$_fetch_pid" 2>/dev/null || true
    fi
fi

# -----------------------------------------------------------------------------
# Query: iterate over each remote-tracking ref individually and ask for
# commits within the window that are NOT reachable from any local branch.
# Per-ref iteration eliminates `--source` parsing fragility (the SHA/TAB/ref
# prefix that git prepends is awkward to split when `--pretty=format` is in
# use).
# -----------------------------------------------------------------------------
# TAB-delimited (not pipe) so a commit subject containing a `|` cannot shift
# the awk field split. Format: sha\temail\tname\tsubject\tcommit-iso-date.
QUERY_FORMAT='%h%x09%ae%x09%an%x09%s%x09%cI'

# Enumerate remote-tracking refs.
# Exclude only the `<remote>/HEAD` symbolic refs (one path-segment + HEAD).
# A legitimate branch named `feature/HEAD` would NOT be filtered.
_remote_refs=$(git for-each-ref --format='%(refname:short)' refs/remotes/ 2>/dev/null | \
               grep -v -E '^[^/]+/(HEAD|head)$' || true)

# Buffer per-ref output; we only emit the header / table once we know there's
# at least one commit to display.
_buffer=""
_any=0

while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    # `--not --branches` over a repo with NO local branches returns non-zero
    # from rev-list. set +e for this block; treat any non-zero as "skip".
    set +e
    _log_per_ref=$(git log "$ref" --not --branches \
                         --since="$WINDOW" \
                         --pretty=format:"$QUERY_FORMAT" \
                         2>/dev/null)
    set -e
    _log_per_ref=$(echo "$_log_per_ref" | sed '/^$/d')
    if [[ -n "$_log_per_ref" ]]; then
        _buffer="${_buffer}REF:${ref}"$'\n'"${_log_per_ref}"$'\n'
        _any=1
    fi
done <<< "$_remote_refs"

if (( _any == 0 )); then
    if (( VERBOSE )); then
        echo "session-handoff: no sibling activity in the last $WINDOW." >&2
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# Format the summary.
# -----------------------------------------------------------------------------
echo "" >&2
echo "session-handoff: sibling activity detected (window: $WINDOW)" >&2
echo "  (Read these commits before editing -- they may overlap your planned work.)" >&2
echo "" >&2

echo "$_buffer" | awk '
/^REF:/ {
    if (current != "") {
        # Flush previous group.
        print_group(current, commits, count)
    }
    current = substr($0, 5)
    delete commits
    count = 0
    next
}
/^$/ { next }
{
    count++
    commits[count] = $0
}
END {
    if (current != "") {
        print_group(current, commits, count)
    }
}
function print_group(ref, lines, n,    i, f) {
    printf "  %s\n", ref
    for (i = 1; i <= n; i++) {
        # Field split on TAB: sha \t email \t name \t subject \t iso.
        # TAB-delimited (not pipe) so subjects with `|` cannot shift fields.
        split(lines[i], f, "\t")
        printf "    %s  %s  %s\n", substr(f[5], 1, 16), f[2], f[4]
    }
    printf "\n"
}' >&2

echo "  Tip: \`git log <ref> --since=\"$WINDOW\"\` for full detail." >&2
echo "" >&2

# Note: we intentionally do NOT auto-pull. The engineer should read the
# commits first; pull comes after orientation. branch-sync-gate handles the
# fetch + sync workflow for the explicit-resume path.

exit 0
