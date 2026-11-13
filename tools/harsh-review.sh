#!/usr/bin/env bash
# Repeatable static validation uses shared receipts; review-token issuance is fresh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -gt 0 || "${_SP_HARSH_REVIEW_OVERLAY:-}" == 1 ]]; then
    # Overlay and mutating/changed-only modes retain their exact legacy contract.
    exec bash "$SCRIPT_DIR/lib/harsh-review-body.sh" "$@"
fi
python3 "$SCRIPT_DIR/validation-receipt.py" "$SCRIPT_DIR/test-all.sh" --check harsh
# shellcheck source=tools/lib/review-token.sh
source "$SCRIPT_DIR/lib/review-token.sh"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"
    # Write review proof token
    REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    mkdir -p "$REVIEW_TOKEN_DIR"
    token_file="${REVIEW_TOKEN_DIR}/$(date +%s)"
    # Canonicalize so symlinked paths (/var → /private/var) match pre-commit's
    # git-rev-parse based REPO_ROOT.  pwd -P is POSIX; realpath fallback is
    # available on Linux but absent on stock macOS without coreutils.
    _canon_repo="$(cd "$REPO_ROOT" && pwd -P 2>/dev/null)" || _canon_repo="$REPO_ROOT"
    # Token filename: <repo_cksum>.<epoch>.<pid>  — collision-safe (two concurrent
    # harsh-review runs can't overwrite each other) and repo-namespaced (GC can
    # restrict deletion to the current repo without reading file contents).
    _repo_cksum=$(printf '%s' "$_canon_repo" | cksum | awk '{print $1}')
    token_file="${REVIEW_TOKEN_DIR}/${_repo_cksum}.$(date +%s).$$"
    # The token used to contain only the repo path, so it
    # proved "harsh-review.sh ran on this repo within the TTL window" and
    # nothing about WHAT it reviewed — any staged change made after minting,
    # before the one-time-use token is consumed at commit, was silently
    # covered by a review that never saw it. Bind the token to the current
    # staged tree hash (git write-tree — same content-addressing pre-push's
    # SHA-bound .code-review-cleared --staged mode already relies on) so
    # pre-commit can verify the staged content hasn't changed since review.
    _staged_tree="$(cd "$REPO_ROOT" && git write-tree 2>/dev/null)" || _staged_tree=""
    review_token_write "$token_file" "$_canon_repo" "$_staged_tree"
