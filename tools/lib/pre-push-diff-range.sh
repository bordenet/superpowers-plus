#!/usr/bin/env bash
# pre-push-diff-range.sh
#
# Shared push-range resolution, sourced by the pre-push gates that need to
# know which commits are being pushed for a given ref (the code-review gate,
# the IP-scan gate, and the PHR gate). Not needed by the test gate (tests the
# whole working tree, not a specific range) or the branch-flow gate (only
# cares about the target branch name + pushed SHA, not the diff range).
#
# Each gate is invoked as its own process by the composer, so this range
# computation can't be shared via in-process variables the way a single
# monolithic script could -- every gate that needs it sources this file and
# calls resolve_diff_range() once per pushed ref.

# resolve_push_base_ref <remote_name>
# Finds the best available ref to diff a NEW branch (no remote_sha yet)
# against: the branch's own upstream tracking ref first, then the pushed
# remote's canonical flow branches, then any other known remote's, in that
# order. Prints the resolved ref name on stdout; returns 1 if none exist.
resolve_push_base_ref() {
    local remote_name="$1"
    local candidate tracking
    tracking="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"

    for candidate in \
        "$tracking" \
        "$remote_name/dev" "$remote_name/staging" "$remote_name/main" "$remote_name/master" \
        origin/dev origin/staging origin/main origin/master \
        upstream/dev upstream/staging upstream/main upstream/master \
        gitlab/dev gitlab/staging gitlab/main gitlab/master
    do
        [[ -n "$candidate" ]] || continue
        if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# resolve_diff_range <local_sha> <remote_sha> <remote_name>
# Sets (does not print, so callers keep plain variables rather than a
# subshell-losing command substitution):
#   RANGE               -- the range to diff (A..B for an existing branch, or
#                           a bare SHA when no merge-base could be found)
#   NEW_BRANCH_NO_BASE  -- "true" when RANGE is a bare SHA because no common
#                           ancestor exists; callers must fail closed (treat
#                           the range as code, or enumerate the full history)
#                           rather than trust a single-commit diff-tree, which
#                           would miss earlier commits in the same push.
resolve_diff_range() {
    local local_sha="$1" remote_sha="$2" remote_name="$3"
    NEW_BRANCH_NO_BASE=false

    if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
        # New branch -- find merge-base with the repo's actual workflow base branch.
        local remote_default merge_base
        remote_default="$(resolve_push_base_ref "$remote_name" || true)"
        if [[ -n "$remote_default" ]]; then
            merge_base=$(git merge-base "$local_sha" "$remote_default" 2>/dev/null || true)
            if [[ -n "$merge_base" ]]; then
                RANGE="$merge_base..$local_sha"
            else
                # No common ancestor -- cannot enumerate only new commits safely.
                RANGE="$local_sha"
                NEW_BRANCH_NO_BASE=true
            fi
        else
            RANGE="$local_sha"
            NEW_BRANCH_NO_BASE=true
        fi
    else
        RANGE="$remote_sha..$local_sha"
    fi
}
