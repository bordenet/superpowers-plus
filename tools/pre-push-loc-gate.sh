#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-push-loc-gate.sh
#
# Per-commit large-diff gate for git pre-push. Detects any push that contains a
# single commit with > MAX_LOC insertions+deletions (default 500).
#
# Mode (override via LOC_GATE_MODE env var or .loc-gate-mode file):
#
#   warn  -> advisory: print the LOC findings to stderr, exit 0 (DEFAULT)
#   block -> refuses oversize pushes (exit 1)
#
# Set LOC_GATE_MODE=block in your environment or create a .loc-gate-mode file
# at the repo root containing "block" to opt into hard enforcement.
#
# In block mode: ALLOW_LARGE_DIFF=1 bypasses with a stderr warning; LOC_GATE_MODE=warn
# downgrades that one push to advisory.
#
# This is the structural backstop the 2026-06-10 incident-2026-1507 incident asked for:
# a branch with +8,750 / -4,195 across 73 files on a hotfix branch; no
# gate ever asked "is this push doing more than the ticket said?" before the
# push left the developer's machine. Outside the dogfood repo, the goal is to
# INFORM developers about commit LOC counts, not block them (a senior-engineer-
# in-the-room advisory, not a CI-style blocker).
#
# WIRING (REQUIRED -- the tool does not auto-install). Pick one:
#
#   1. As the pre-push hook for a single repo (simplest):
#        cd <your-repo>
#        ln -sf /absolute/path/to/tools/pre-push-loc-gate.sh .git/hooks/pre-push
#        chmod +x .git/hooks/pre-push
#
#   2. Composed alongside an existing pre-push runner (e.g. CI-gate):
#        # In .git/hooks/pre-push, add BEFORE the existing checks:
#        /absolute/path/to/tools/pre-push-loc-gate.sh < /dev/stdin || exit $?
#
#   3. Globally for every clone, via git's core.hooksPath:
#        git config --global core.hooksPath ~/.config/git-hooks
#        ln -sf /absolute/path/to/tools/pre-push-loc-gate.sh \
#               ~/.config/git-hooks/pre-push
#
# Until wiring step happens, the gate provides ZERO protection.
#
# Invocation:
#   tools/pre-push-loc-gate.sh                  # reads stdin (real hook mode)
#   tools/pre-push-loc-gate.sh HEAD             # ad-hoc check on one commit
#   MAX_LOC=200 tools/pre-push-loc-gate.sh HEAD # override threshold
#   tools/pre-push-loc-gate.sh --help           # usage
#
# Exit codes (stable contract):
#   0  No commit exceeds MAX_LOC; OR mode is 'warn' (advisory regardless of
#      findings); OR mode is 'block' AND ALLOW_LARGE_DIFF=1 bypass set
#   1  Mode is 'block' AND at least one commit exceeds MAX_LOC AND no bypass
#   2  Usage / git error (bad arg, MAX_LOC not a positive integer,
#      LOC_GATE_MODE invalid, git diff or git rev-list failed)
#
# Design notes (READ BEFORE TRUSTING):
#   - Per-COMMIT gate, not per-push aggregate. A 2000-LOC change spread across
#     five 400-LOC commits will PASS. The intent is to catch a single broken
#     gigantic commit (the MR !19 shape); aggregate scope-control is the
#     scope-tripwire gate (TODO 20260610-08), not this one.
#   - Bypass: ALLOW_LARGE_DIFF=1 prints WARNING to stderr but writes no audit
#     trail to git history. Reviewers cannot see bypass usage from the commit
#     log alone -- they must read the developer's terminal output. Use sparingly
#     and call out the bypass in the MR description.
#   - `git push --no-verify` skips this hook entirely (git design limit; the
#     hook can't defend against it). Document in your team's review checklist.
#   - Octopus merges (3+ parents) are inspected via first-parent diff only,
#     like single-parent merges. A malicious 3-parent merge whose 2nd/3rd
#     parents cancel out into the first-parent tree will under-report.
#
# Bypass: ALLOW_LARGE_DIFF=1 git push   (prints WARNING but proceeds)

set -euo pipefail

# Force C locale so `git diff --shortstat` output stays English ("insertion",
# "deletion") -- the regex parser depends on these literal tokens. A localized
# git on a Linux box with LANG=de_DE would otherwise silently parse to 0 LOC.
export LC_ALL=C

# --help / -h: print usage to STDOUT, exit 0 (must run before SHA-arg dispatch
# so `--help` isn't mistaken for a commit ref).
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

MAX_LOC=${MAX_LOC:-500}
ALLOW_LARGE_DIFF=${ALLOW_LARGE_DIFF:-0}
ZERO_SHA="0000000000000000000000000000000000000000"

# Mode dispatch: 'block' refuses oversize pushes (exit 1); 'warn' prints the
# same findings table to stderr but exits 0.
# Precedence: LOC_GATE_MODE env var > .loc-gate-mode file > default (warn).
LOC_GATE_MODE=${LOC_GATE_MODE:-}
if [[ -z "$LOC_GATE_MODE" ]]; then
    _loc_mode_file="$(git rev-parse --show-toplevel 2>/dev/null)/.loc-gate-mode"
    if [[ -f "$_loc_mode_file" ]]; then
        _file_mode=$(grep -v '^#' "$_loc_mode_file" | awk 'NF{gsub(/^[ \t]+|[ \t]+$/, ""); print; exit}')
        [[ -n "$_file_mode" ]] && LOC_GATE_MODE="$_file_mode"
    fi
    unset _loc_mode_file _file_mode
fi
if [[ -z "$LOC_GATE_MODE" ]]; then
    LOC_GATE_MODE="warn"
fi
if [[ "$LOC_GATE_MODE" != "block" && "$LOC_GATE_MODE" != "warn" ]]; then
    echo "ERROR: LOC_GATE_MODE=$LOC_GATE_MODE invalid (expected 'block' or 'warn')" >&2
    exit 2
fi

# Validate MAX_LOC is a positive integer
if ! [[ "$MAX_LOC" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: MAX_LOC=$MAX_LOC is not a positive integer." >&2
    exit 2
fi

# diff_loc_for_commit <commit-sha>
# Prints the total of insertions + deletions for the commit, against its first
# parent (so merge commits show only the merge-side delta, not the full graph).
# Returns 0 for root commits (no parent).
diff_loc_for_commit() {
    local sha="$1"
    if ! git rev-parse --verify --quiet "$sha^{commit}" >/dev/null; then
        echo "ERROR: $sha is not a commit" >&2
        return 2
    fi
    local parent
    if ! parent=$(git rev-parse --verify --quiet "$sha^1" 2>/dev/null); then
        # Root commit: count everything against the empty tree
        parent=$(git hash-object -t tree /dev/null)
    fi
    # --shortstat output looks like " 3 files changed, 12 insertions(+), 7 deletions(-)"
    # Empty diff emits nothing (legitimate -- pure rename, --allow-empty, etc).
    # A genuine `git diff` failure (corrupt object, broken repo, missing tree)
    # is distinct from empty output and MUST NOT fail-open to 0 LOC -- return 2.
    local stat
    if ! stat=$(git diff --shortstat "$parent" "$sha" -- 2>/dev/null); then
        echo "ERROR: git diff --shortstat $parent $sha failed; refusing to fail-open to 0 LOC" >&2
        return 2
    fi
    local ins del
    ins=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '^[0-9]+' || echo 0)
    del=$(echo "$stat" | grep -oE '[0-9]+ deletion'  | grep -oE '^[0-9]+' || echo 0)
    echo $(( ins + del ))
}

# enumerate_commits <local_sha> <remote_sha>
# Lists the new commits being pushed (i.e. reachable from local_sha but not
# from remote_sha). For a brand-new branch (remote_sha is the zero SHA), lists
# all commits reachable from local_sha that are not on any other ref. For a
# branch deletion (local_sha is zero), prints nothing.
enumerate_commits() {
    local local_sha="$1" remote_sha="$2"
    if [[ "$local_sha" == "$ZERO_SHA" ]]; then
        return 0   # deletion: nothing to push
    fi
    # Distinguish "git rev-list emitted no commits" (legitimate -- e.g., the
    # remote already has every commit on the local branch) from "git rev-list
    # failed" (e.g., bogus remote SHA from a stale ref after force-push, or an
    # unreachable commit). Fail-open on the latter would let an oversize commit
    # slip through silently -- the same class of bug R2 fix #2 closed in
    # diff_loc_for_commit. Capture stderr; if rev-list returns non-zero AND
    # the failure isn't "missing-commit which we'd treat as the entire branch
    # is new", propagate exit 2 via the caller.
    local out err
    local tmperr
    tmperr=$(mktemp)
    if [[ "$remote_sha" == "$ZERO_SHA" ]]; then
        # New branch: list commits reachable from local_sha but not from any
        # OTHER remote ref (to avoid re-counting commits already on the server).
        out=$(git rev-list "$local_sha" --not --remotes 2>"$tmperr") || {
            err=$(cat "$tmperr"); rm -f "$tmperr"
            echo "ERROR: git rev-list failed for new branch ($local_sha): $err" >&2
            return 2
        }
    else
        out=$(git rev-list "$local_sha" "^$remote_sha" 2>"$tmperr") || {
            err=$(cat "$tmperr"); rm -f "$tmperr"
            echo "ERROR: git rev-list failed (local=$local_sha remote=$remote_sha): $err" >&2
            return 2
        }
    fi
    rm -f "$tmperr"
    printf '%s\n' "$out"
}

# check_pushed_refs - main entry. Reads stdin (pre-push hook format) and
# checks every new commit. Returns 0 / 1 / 2 per the exit-code contract.
check_pushed_refs() {
    local violations=()
    # _remote_ref is intentionally unused -- it's the 3rd field in the pre-push
    # hook's line format `<local_ref> <local_sha> <remote_ref> <remote_sha>`
    # and must be read positionally to land remote_sha in the right variable.
    local local_ref local_sha _remote_ref remote_sha
    while IFS=' ' read -r local_ref local_sha _remote_ref remote_sha; do
        [[ -z "${local_ref:-}" ]] && continue
        # Call enumerate_commits with its exit code captured -- process
        # substitution would swallow a non-zero return, fail-opening on git
        # errors. Bash quirk: $(...) is a subshell, so we read it into a
        # variable first, check the rc, THEN feed the list into the loop.
        local commits_out commits_rc=0 commit
        # `|| commits_rc=$?` captures the rc without tripping `set -e` (which
        # would otherwise kill the parent before line 213 ran, making the
        # explicit check below dead code). Net behavior is identical -- a
        # non-zero from enumerate_commits propagates as exit 2.
        commits_out=$(enumerate_commits "$local_sha" "$remote_sha") || commits_rc=$?
        if (( commits_rc != 0 )); then
            return 2
        fi
        while read -r commit; do
            [[ -z "$commit" ]] && continue
            local loc
            loc=$(diff_loc_for_commit "$commit") || return 2
            if (( loc > MAX_LOC )); then
                violations+=("$commit:$loc:$local_ref")
            fi
        done <<<"$commits_out"
    done

    if (( ${#violations[@]} == 0 )); then
        return 0
    fi

    echo "" >&2
    local header_verb
    if [[ "$LOC_GATE_MODE" == "block" ]]; then
        header_verb="refusing push"
    else
        header_verb="advisory (LOC_GATE_MODE=warn; push proceeds)"
    fi
    echo "pre-push-loc-gate: $header_verb -- ${#violations[@]} commit(s) exceed MAX_LOC=$MAX_LOC" >&2
    for v in "${violations[@]}"; do
        local sha="${v%%:*}" rest="${v#*:}" loc ref subject
        loc="${rest%%:*}"; ref="${rest#*:}"
        subject=$(git show -s --format='%s' "$sha" 2>/dev/null || echo "")
        echo "  - $sha (loc=$loc on $ref): $subject" >&2
    done
    echo "" >&2
    if [[ "$LOC_GATE_MODE" == "warn" ]]; then
        echo "Mode: WARN (default for most repos). To enforce blocking, set LOC_GATE_MODE=block." >&2
        return 0
    fi
    # block mode
    if [[ "$ALLOW_LARGE_DIFF" == "1" ]]; then
        echo "WARNING: ALLOW_LARGE_DIFF=1 set; bypassing the gate (push proceeds)." >&2
        return 0
    fi
    echo "Mode: BLOCK. Either split the commit into smaller pieces, OR override:" >&2
    echo "  ALLOW_LARGE_DIFF=1 git push ...      # one-time bypass" >&2
    echo "  LOC_GATE_MODE=warn git push ...      # switch this push to advisory-only" >&2
    echo "(Bypasses are stderr-only; not visible in git history. Use sparingly with PM/sibling sign-off.)" >&2
    return 1
}

# --- Entry point ---
# Argument-shape dispatch (catches git's pre-push hook convention vs ad-hoc):
#
#   $# == 2 -> git's pre-push hook convention: `<remote_name> <remote_url>` args
#             WITH lines on stdin. Ignore args, read stdin.
#   $# == 1 -> ad-hoc single-SHA mode: check that one commit's diff vs parent.
#   $# == 0 -> if stdin is a pipe, treat as stdin mode; otherwise noop exit 0.
#
# Pre-fix (before TODO 20260610-17): the script routed to single-arg mode
# whenever $# > 0, which made git's invocation `pre-push origin URL` get
# treated as `pre-push origin` -- and `origin` resolved via `git rev-parse`
# to origin/HEAD, checking the wrong commit. Caught via dogfooding when a
# sibling installed the hook and a small doc push (MR !55) was blocked by
# the 666-LOC merge commit at origin/HEAD.
if [[ $# -ge 2 ]]; then
    # Git pre-push convention (currently 2 args; future-proofed for additional
    # args). Read stdin lines and ignore positional args entirely.
    check_pushed_refs
    exit $?
fi

if [[ $# -eq 0 ]]; then
    if [[ ! -t 0 ]]; then
        # No args, stdin is a pipe -- treat as stdin mode (legacy invocation)
        check_pushed_refs
        exit $?
    fi
    # No args, no stdin: nothing to check.
    exit 0
fi

# $# == 1: ad-hoc single-SHA mode.
if [[ $# -gt 0 ]]; then
    sha="$1"
    if ! git rev-parse --verify --quiet "$sha^{commit}" >/dev/null; then
        echo "ERROR: not a commit: $sha" >&2
        exit 2
    fi
    loc=$(diff_loc_for_commit "$sha") || exit 2
    if (( loc > MAX_LOC )); then
        echo "Commit $sha exceeds MAX_LOC=$MAX_LOC (loc=$loc):" >&2
        git show -s --format='  %s' "$sha" >&2
        if [[ "$LOC_GATE_MODE" == "warn" ]]; then
            echo "Mode: WARN. Push would proceed in a real pre-push invocation." >&2
            exit 0
        fi
        if [[ "$ALLOW_LARGE_DIFF" == "1" ]]; then
            echo "WARNING: ALLOW_LARGE_DIFF=1 set; bypassing the gate." >&2
            exit 0
        fi
        echo "Bypass: ALLOW_LARGE_DIFF=1 tools/pre-push-loc-gate.sh $sha" >&2
        echo "Or: LOC_GATE_MODE=warn tools/pre-push-loc-gate.sh $sha" >&2
        exit 1
    fi
    exit 0
fi

# No arg, no stdin pipe: nothing to check (e.g., manual `bash pre-push-loc-gate.sh < /dev/null`).
exit 0
