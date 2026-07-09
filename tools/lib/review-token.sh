#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: tools/lib/review-token.sh
# PURPOSE: Single source of truth for the review-token file FORMAT.
#          harsh-review.sh mints these tokens; pre-commit and commit-gate.sh
#          consume them. If any of these three (plus their tests) duplicate
#          the parsing logic instead of sourcing this file, a format change
#          in one place silently breaks whichever consumer wasn't updated --
#          exactly what happened when a tree-hash line was added to the
#          token without updating commit-gate.sh's own whole-file `cat`
#          comparison, caught only by CI, several commits later.
#
# FORMAT (2 lines):
#   line 1: canonicalized repo root path (pwd -P)
#   line 2: git write-tree hash of the staged tree at mint time
#           (may be empty if write-tree failed at mint time)
#
# USAGE: source "$SCRIPT_DIR/lib/review-token.sh"
# -----------------------------------------------------------------------------

review_token_write() {
    local token_file="$1" repo_path="$2" tree_hash="$3"
    printf '%s\n%s\n' "$repo_path" "$tree_hash" > "$token_file"
}

review_token_repo() {
    sed -n '1p' "$1" 2>/dev/null
}

review_token_tree() {
    sed -n '2p' "$1" 2>/dev/null
}
