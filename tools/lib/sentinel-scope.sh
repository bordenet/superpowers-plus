#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/lib/sentinel-scope.sh
# PURPOSE: Decide whether a review sentinel still covers a pushed commit.
# SOURCED BY: tools/pre-push-code-review-gate.sh,
#             tools/pre-push-llm-skill-review-gate.sh,
#             tools/pre-push-phr-gate.sh, tools/push-readiness.sh
#
# The defect this fixes
# ---------------------
# A review attests to CONTENT. Every gate bound it to a COMMIT: it rejected any
# push where `sentinel_sha != pushed_sha`. So amending a commit message,
# rebasing onto a moved base, or committing an unrelated file each invalidated
# every review -- and each re-review minted a fresh SHA the next fix would
# invalidate again. That loop, not review depth, is why a 3-file change could
# cost hours and several hundred thousand tokens.
#
# tools/try-sentinel-fast-forward.sh (254 lines) worked AROUND the binding for
# one narrow case (generator-owned files) because changing the sentinel FORMAT
# meant editing four independently hand-rolled parsers in lockstep. This module
# needs no format change at all: the sentinel still names the reviewed commit,
# and this decides whether the pushed commit's in-scope content is identical.
#
# Security model
# --------------
# Strictly no weaker than exact-SHA binding for the thing review protects.
# A sentinel carries forward ONLY when no file in the gate's own scope differs
# between the reviewed commit and the pushed one -- so the reviewed bytes and
# the pushed bytes are provably identical. Any added, modified, deleted or
# renamed in-scope file invalidates it. Anything this cannot prove (unknown
# commit, git failure, classifier failure) fails CLOSED.
# -----------------------------------------------------------------------------

# --- Scope classifiers: stdin paths -> in-scope subset -----------------------
# One definition each. The pre-push gates use these to decide what they gate
# AND to decide whether a sentinel still covers a push, so "what was reviewed"
# and "what is checked" cannot diverge.

# Code files gated by .code-review-cleared.
sentinel_scope_code_files() {
    awk '
        /^\s*$/                             { next }
        /^skills\/.*\.md$/                  { next }
        /^skills\//                         { print; next }
        /^tests\/ci-bats-policy\.txt$/       { print; next }
        /^test\/golden-compression\/.*\.golden\.txt$/ { print; next }
        /\.(md|txt|rst)$/                   { next }
        /^(\.gitignore|\.gitattributes|\.editorconfig|README|CHANGELOG|LICENSE|\.env\.example)$/ { next }
        { print }
    '
}

# skills/*.md, .ai-guidance/*.md, AGENTS.md family -- gated by .llm-skill-review-cleared.
sentinel_scope_llm_owned() {
    local _paths
    _paths="$(cat)"
    [[ -z "$_paths" ]] && return 0
    "${REPO_ROOT:?}/tools/md-files-changed.sh" --files "$_paths" --llm-owned
}

# Design docs gated by .phr-cleared (md, excluding llm-skill-review-owned).
sentinel_scope_phr_eligible() {
    local _paths
    _paths="$(cat)"
    [[ -z "$_paths" ]] && return 0
    "${REPO_ROOT:?}/tools/md-files-changed.sh" --files "$_paths" --exclude-llm-owned
}

# Map a sentinel file to its scope classifier. Prints nothing (and returns 1)
# for sentinels whose validity is not content-scoped -- .branch-flow-cleared
# certifies branch topology, not reviewed bytes, so it stays exact-SHA.
sentinel_scope_classifier_for() {
    case "$(basename "$1")" in
        .code-review-cleared)      echo sentinel_scope_code_files ;;
        .llm-skill-review-cleared) echo sentinel_scope_llm_owned ;;
        .phr-cleared)              echo sentinel_scope_phr_eligible ;;
        *) return 1 ;;
    esac
}

# sentinel_scope_unchanged REVIEWED_SHA PUSHED_SHA SCOPE_CLASSIFIER [ARGS...]
#
#   SCOPE_CLASSIFIER is a command that reads newline-separated paths on stdin
#   and prints those in the gate's scope. Each gate passes the classifier it
#   ALREADY uses to decide what it gates, so "what was reviewed" and "what is
#   checked" can never disagree -- there is no second, drifting rule set here.
#
#   Returns 0 iff both commits exist and no in-scope path differs between them.
#   Sets SENTINEL_SCOPE_CHANGED to the in-scope paths that differ (for error
#   messages), or to a reason string when it fails closed.
sentinel_scope_unchanged() {
    local reviewed_sha="$1" pushed_sha="$2"
    shift 2
    SENTINEL_SCOPE_CHANGED=""

    if [[ -z "$reviewed_sha" || -z "$pushed_sha" || $# -eq 0 ]]; then
        SENTINEL_SCOPE_CHANGED="(missing argument)"
        return 1
    fi

    # Identical commits are trivially equivalent -- the common, fast path.
    [[ "$reviewed_sha" == "$pushed_sha" ]] && return 0

    # The reviewed commit may have been rewritten away by amend/rebase and
    # garbage-collected. Without it, identity cannot be proven: fail closed.
    if ! git cat-file -e "${reviewed_sha}^{commit}" 2>/dev/null; then
        SENTINEL_SCOPE_CHANGED="(reviewed commit ${reviewed_sha:0:8} not found locally)"
        return 1
    fi
    if ! git cat-file -e "${pushed_sha}^{commit}" 2>/dev/null; then
        SENTINEL_SCOPE_CHANGED="(pushed commit ${pushed_sha:0:8} not found locally)"
        return 1
    fi

    # --no-renames reports a rename as delete+add, so BOTH the old and the new
    # path reach the classifier; with rename detection a move out of scope
    # could otherwise surface only under its new, out-of-scope name.
    local changed
    if ! changed="$(git diff --no-renames --name-only "$reviewed_sha" "$pushed_sha" 2>/dev/null)"; then
        SENTINEL_SCOPE_CHANGED="(git diff failed)"
        return 1
    fi

    # Nothing differs anywhere: content-identical commits (e.g. message-only
    # amend, or a rebase that did not touch these files).
    [[ -z "$changed" ]] && return 0

    local in_scope classifier_rc=0
    in_scope="$(printf '%s\n' "$changed" | "$@")" || classifier_rc=$?
    # A classifier that errors must not read as "nothing in scope": that would
    # silently carry a stale review forward. Exit 1 with empty output is how
    # grep-style filters say "no match", so only >1, or 1 WITH output, is a
    # real failure.
    if [[ $classifier_rc -gt 1 ]] || [[ $classifier_rc -eq 1 && -n "$in_scope" ]]; then
        SENTINEL_SCOPE_CHANGED="(scope classifier failed: exit $classifier_rc)"
        return 1
    fi

    if [[ -n "$in_scope" ]]; then
        SENTINEL_SCOPE_CHANGED="$in_scope"
        return 1
    fi
    return 0
}

# Print the stale-sentinel diagnosis every gate shares. Explains WHY the review
# no longer covers the push, rather than the old bare "commits were made after
# the review" -- which was false for message-only amends and gave no signal
# about which file actually needs re-review.
sentinel_scope_report() {
    local gate="$1" reviewed_sha="$2" pushed_sha="$3"
    echo "  Clearance was for commit: ${reviewed_sha:0:8}"
    echo "  Pushing commit:           ${pushed_sha:0:8}"
    if [[ "$SENTINEL_SCOPE_CHANGED" == \(* ]]; then
        echo "  Cannot prove the reviewed content is unchanged: $SENTINEL_SCOPE_CHANGED"
    else
        echo "  In-scope files changed since the review (only these need re-review):"
        while IFS= read -r _f; do
            [[ -n "$_f" ]] && echo "    - $_f"
        done <<< "$SENTINEL_SCOPE_CHANGED"
    fi
    echo "  Re-run the $gate review, then push."
}
