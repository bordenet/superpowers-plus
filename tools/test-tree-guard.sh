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
# EXIT: 0 = clean
#       1 = undeclared pollution (verify), a refused manifest pattern
#           (sweep) -- sweep heals silently; it only fails on a pattern it
#           refused to expand, which is a manifest bug, not debris -- or a
#           missing/unreadable snapshot file passed to verify.
#       2 = usage error
#       (cr-battery 2026-09-19, ShellRuntimeAuditor: git itself can also
#       propagate its own fatal exit code, e.g. 128, if REPO_ROOT is ever
#       not inside a git repository -- not expected in this repo's own use,
#       guarded against below so a caller never sees an undocumented code.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# cr-battery 2026-09-19 (ShellRuntimeAuditor): every subcommand shells out to
# `git status`; without this guard, running from a copy of this script
# outside a git checkout propagates git's own raw fatal exit code (128), not
# the documented 0/1/2 contract, with git's bare stderr as the only
# diagnostic. Confirmed live before adding this.
if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'test-tree-guard: %s is not a git repository\n' "$REPO_ROOT" >&2
    exit 1
fi

MANIFEST="$REPO_ROOT/test/.test-artifacts"

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
    exit "${1:-2}"
}

# Declared artifact globs, comments and blank lines stripped.
read_manifest() {
    [[ -f "$MANIFEST" ]] || return 0
    grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" || true
}

# Does $1 (a repo-relative path) match any declared glob?
#
# cr-battery 2026-09-19 (Defect Finder, reproduced): this previously used
# bash's `[[ == $pattern ]]` string-pattern match, where a bare `*` crosses
# `/` -- but cmd_sweep enumerates candidates via `compgen -G`, real pathname
# expansion, where `*` does NOT cross `/`. For any pattern with a glob in a
# non-terminal segment (e.g. `skills/*/leak.md`), the two disagreed: a file
# one segment deeper than the pattern anticipates was called "declared,
# sweep will heal it" by verify, while sweep's own compgen -G could never
# actually find it to delete -- permanent, silently-tolerated pollution that
# both defeats detection and defeats remediation. Fixed by driving is_declared
# off the exact same compgen -G expansion sweep uses, so the two functions
# can never diverge again.
is_declared() {
    local path="$1" pattern match
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        while IFS= read -r match; do
            [[ "$match" == "$path" ]] && return 0
        done < <(cd "$REPO_ROOT" && compgen -G "$pattern" 2>/dev/null || true)
    done < <(read_manifest)
    return 1
}

# Reject a manifest pattern that could reach outside the repo BEFORE it is
# expanded. sweep runs `rm -rf` on whatever this yields, on every test-all.sh
# invocation including the pre-push gate, so a single bad line -- a typo, or a
# hostile one-line diff on a branch someone is reviewing -- must not be able to
# delete anything outside the working tree. `../x` was confirmed to escape and
# delete files in $HOME before this check existed.
validate_pattern() {
    local pattern="$1"
    case "$pattern" in
        /*|'~'*)
            printf 'test-tree-guard: REFUSED absolute pattern: %s\n' "$pattern" >&2
            return 1 ;;
        ..|../*|*/../*|*/..)
            printf 'test-tree-guard: REFUSED parent-traversal pattern: %s\n' "$pattern" >&2
            return 1 ;;
    esac
    # Refuse a pattern whose FIRST path component contains a glob. `*` and `**`
    # are inside the repo, so the traversal and absolute checks above both pass
    # them -- and a one-line manifest diff of `*` then rm -rf'd every top-level
    # entry in the working tree and reported "tree healed", exit 0, on every
    # test-all.sh run including the pre-push gate. A declared artifact always
    # knows which directory it lives in, so requiring a literal first component
    # costs a real manifest nothing.
    local first="${pattern%%/*}"
    case "$first" in
        *'*'*|*'?'*|*'['*)
            printf 'test-tree-guard: REFUSED pattern with a glob in its first path component: %s\n' "$pattern" >&2
            printf '  a declared artifact must name the directory it lives in.\n' >&2
            return 1 ;;
    esac
    return 0
}

# Final gate: the resolved path must be a real descendant of REPO_ROOT. This
# catches what pattern syntax cannot -- notably an in-repo symlink whose target
# lives outside, where deleting "inside" the repo destroys outside content.
path_is_inside_repo() {
    local path="$1" parent resolved
    parent="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)" || return 1
    resolved="$parent/$(basename "$path")"
    local root_real
    root_real="$(cd "$REPO_ROOT" && pwd -P)" || return 1
    [[ "$resolved" == "$root_real"/* ]]
}

cmd_sweep() {
    local pattern found=0 path refused=0
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        validate_pattern "$pattern" || { refused=1; continue; }
        while IFS= read -r path; do
            [[ -e "$path" || -L "$path" ]] || continue
            # Never follow a symlink out of the tree: remove the link itself.
            if [[ -L "$path" ]]; then
                rm -f "$path"
            else
                path_is_inside_repo "$path" || {
                    printf 'test-tree-guard: REFUSED path outside repo: %s\n' "$path" >&2
                    refused=1
                    continue
                }
                rm -rf "$path"
            fi
            printf 'test-tree-guard: swept leftover artifact: %s\n' \
                "${path#"$REPO_ROOT"/}" >&2
            found=1
        done < <(cd "$REPO_ROOT" && compgen -G "$pattern" 2>/dev/null | sed "s|^|$REPO_ROOT/|" || true)
    done < <(read_manifest)
    if [[ "$found" -eq 1 ]]; then
        printf 'test-tree-guard: a previous run died before cleanup; tree healed.\n' >&2
    fi
    # A refused pattern is a manifest bug, not routine housekeeping: fail so it
    # is fixed rather than silently ignored on every future run.
    [[ "$refused" -eq 1 ]] && return 1
    return 0
}

cmd_snapshot() {
    local state="${1:-}"
    [[ -n "$state" ]] || usage 2
    (cd "$REPO_ROOT" && git status --porcelain --untracked-files=all) > "$state"
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
    (cd "$REPO_ROOT" && git status --porcelain --untracked-files=all) > "$after"

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
