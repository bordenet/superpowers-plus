#!/usr/bin/env bash
# test-tree-guard.sh -- keep the working tree clean across test runs.
#
# PURPOSE:
#   A test that writes into the live repo tree leaks its fixture whenever the
#   run dies hard. `teardown()` does not run on SIGKILL, and no trap can make
#   it. The leaked file then trips the NEXT run, which looks like a real
#   failure and costs an investigation. That happened three times in one day:
#   twice to Codex, once to Claude, and once it baited a kill of a live run.
#
#   This guard makes the failure mode self-healing and impossible to miss:
#
#     sweep    Remove DECLARED test artifacts before a run. A leftover from a
#              crashed run is cleaned automatically and reported, so the next
#              run starts from a known-good tree instead of inheriting debris.
#     snapshot Record `git status --porcelain` before the suite.
#     verify   Diff the tree against that snapshot afterwards. Any path a test
#              added or modified that is NOT declared fails the run and is
#              named. Undeclared pollution can never again pass silently.
#
#   THE RULE: a test may write inside the repo only if its artifact is
#   declared in test/.test-artifacts. Everything else belongs in
#   "$BATS_TEST_TMPDIR" (bats) or mktemp -d. Declaring an artifact is a
#   deliberate, reviewable act -- the file is the list of known exceptions.
#
# USAGE:
#   tools/test-tree-guard.sh sweep
#   tools/test-tree-guard.sh snapshot <state-file>
#   tools/test-tree-guard.sh verify   <state-file>
#
# EXIT: 0 = clean (sweep always 0; it heals rather than blocks)
#       1 = undeclared pollution found by verify
#       2 = usage error
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/test/.test-artifacts"

usage() {
    sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-2}"
}

# Declared artifact globs, comments and blank lines stripped.
read_manifest() {
    [[ -f "$MANIFEST" ]] || return 0
    grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" || true
}

# Does $1 (a repo-relative path) match any declared glob?
is_declared() {
    local path="$1" pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        # shellcheck disable=SC2053  # glob match on the right is the point
        [[ "$path" == $pattern ]] && return 0
    done < <(read_manifest)
    return 1
}

cmd_sweep() {
    local pattern found=0 path
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r path; do
            [[ -e "$path" ]] || continue
            rm -rf "$path"
            printf 'test-tree-guard: swept leftover artifact: %s\n' \
                "${path#"$REPO_ROOT"/}" >&2
            found=1
        done < <(cd "$REPO_ROOT" && compgen -G "$pattern" 2>/dev/null | sed "s|^|$REPO_ROOT/|" || true)
    done < <(read_manifest)
    if [[ "$found" -eq 1 ]]; then
        printf 'test-tree-guard: a previous run died before cleanup; tree healed.\n' >&2
    fi
    return 0
}

cmd_snapshot() {
    local state="${1:-}"
    [[ -n "$state" ]] || usage 2
    (cd "$REPO_ROOT" && git status --porcelain) > "$state"
}

cmd_verify() {
    local state="${1:-}" line path violations=0
    [[ -n "$state" ]] || usage 2
    if [[ ! -f "$state" ]]; then
        printf 'test-tree-guard: missing snapshot %s -- cannot verify.\n' "$state" >&2
        return 1
    fi

    local after
    after="$(mktemp)"
    (cd "$REPO_ROOT" && git status --porcelain) > "$after"

    # Lines present after the suite that were not there before it.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        path="${line:3}"
        # Unquote a path git rendered with spaces/specials.
        path="${path%\"}"; path="${path#\"}"
        if is_declared "$path"; then
            printf 'test-tree-guard: declared artifact still present: %s\n' "$path" >&2
            # shellcheck disable=SC2016  # literal text, not an expansion
            printf '  its test did not clean up; sweep will heal the next run.\n' >&2
            continue
        fi
        printf 'test-tree-guard: UNDECLARED test pollution: %s\n' "$path" >&2
        violations=$((violations + 1))
    done < <(comm -13 <(sort "$state") <(sort "$after"))

    rm -f "$after"

    if [[ "$violations" -gt 0 ]]; then
        printf '\ntest-tree-guard: %d path(s) were created or modified by the test suite.\n' \
            "$violations" >&2
        # shellcheck disable=SC2016  # literal text, not an expansion
        printf 'A test must write to "$BATS_TEST_TMPDIR" or mktemp -d, never the repo.\n' >&2
        printf 'If writing in-tree is genuinely unavoidable, declare the exact path in\n' >&2
        printf '%s so it is swept automatically.\n' "${MANIFEST#"$REPO_ROOT"/}" >&2
        return 1
    fi
    return 0
}

case "${1:---help}" in
    sweep)    cmd_sweep ;;
    snapshot) shift; cmd_snapshot "$@" ;;
    verify)   shift; cmd_verify "$@" ;;
    -h|--help) usage 0 ;;
    *) printf 'unknown command: %s\n\n' "$1" >&2; usage 2 ;;
esac
