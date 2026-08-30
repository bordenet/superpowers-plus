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

# resolve_push_base_ref <remote_name> [<anchor_sha>]
# Finds the best available ref to diff against: the branch's own upstream
# tracking ref first, then the pushed remote's canonical flow branches, then
# any other known remote's, in that order. Prints the resolved ref name on
# stdout; returns 1 if none exist.
#
# When <anchor_sha> is provided, only refs that are ancestors of that SHA are
# considered. This prevents a stale tracking ref (e.g. origin/fix/foo pointing
# to an old pre-rebase commit that is no longer an ancestor of local HEAD) from
# being chosen -- in that case the ref exists but is not an ancestor of the new
# HEAD, so it would produce a wildly expanded range.
resolve_push_base_ref() {
    local remote_name="$1" anchor_sha="${2:-}"
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
            if [[ -n "$anchor_sha" ]]; then
                git merge-base --is-ancestor "$candidate" "$anchor_sha" 2>/dev/null || continue
            fi
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
# shellcheck disable=SC2034  # RANGE and NEW_BRANCH_NO_BASE are output vars consumed by callers after sourcing
resolve_diff_range() {
    local local_sha="$1" remote_sha="$2" remote_name="$3"
    NEW_BRANCH_NO_BASE=false

    if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
        # New branch -- find merge-base with the repo's actual workflow base branch.
        local remote_default merge_base
        remote_default="$(resolve_push_base_ref "$remote_name" "$local_sha" || true)"
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
    elif git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
        # Normal update: remote tip is a direct ancestor of the new local SHA.
        RANGE="$remote_sha..$local_sha"
    else
        # Force-push / rebased branch: remote_sha is NOT an ancestor of
        # local_sha, so remote_sha..local_sha would span unrelated history.
        # Fall back to merge-base with the canonical flow branch instead.
        # Pass local_sha as anchor so stale tracking refs are skipped.
        local remote_default merge_base
        remote_default="$(resolve_push_base_ref "$remote_name" "$local_sha" || true)"
        if [[ -n "$remote_default" ]]; then
            merge_base=$(git merge-base "$local_sha" "$remote_default" 2>/dev/null || true)
            if [[ -n "$merge_base" ]]; then
                RANGE="$merge_base..$local_sha"
            else
                RANGE="$local_sha"
                NEW_BRANCH_NO_BASE=true
            fi
        else
            RANGE="$local_sha"
            NEW_BRANCH_NO_BASE=true
        fi
    fi
}
