#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: post-squash-cleanup.sh
# PURPOSE: After a feature branch is squash-merged on the remote, the local
#          tracking branch (typically `dev`) is "ahead" of the remote by the
#          old unsquashed commits even though they were collapsed upstream.
#          A naive `git pull` or `git merge` re-introduces the pre-squash
#          history and pollutes the linear graph.
#
#          This script detects that exact state and offers a safe reset
#          (`git reset --hard origin/<branch>`) plus pruning of any local
#          feature branches that were merged via the squashed PR.
#
# USAGE:   tools/post-squash-cleanup.sh [--branch dev] [--dry-run] [--yes]
#            --branch   integration branch to check (default: dev)
#            --dry-run  print what would be done; do not modify anything
#            --yes      skip the confirmation prompt (CI / scripted use)
#
# EXIT:    0 = clean (no action needed) OR cleanup completed
#          1 = user aborted, or unsafe state (worktree dirty, branch
#              diverged in both directions, etc.) — surfaced explicitly
#          2 = argument / usage error
# -----------------------------------------------------------------------------
set -uo pipefail

BRANCH="dev"
DRY_RUN=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --branch)
            [[ $# -ge 2 ]] || { echo "❌ --branch requires a value" >&2; exit 2; }
            BRANCH="$2"; shift 2 ;;
        --branch=*) BRANCH="${1#--branch=}"; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        --yes|-y)   ASSUME_YES=1; shift ;;
        *) echo "❌ Unknown flag: $1" >&2; exit 2 ;;
    esac
done

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "❌ Not inside a git repository" >&2
    exit 2
}
cd "$repo_root" || { echo "❌ Could not cd to $repo_root" >&2; exit 2; }

if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "ℹ️  Local branch '$BRANCH' does not exist; nothing to clean up."
    exit 0
fi

remote_ref="origin/$BRANCH"
if ! git show-ref --verify --quiet "refs/remotes/$remote_ref"; then
    echo "❌ Remote ref '$remote_ref' missing. Run: git fetch origin"
    exit 1
fi

echo "→ Fetching origin (lightweight)..."
git fetch --quiet origin "$BRANCH" || true

ahead=$(git rev-list --count "$remote_ref..$BRANCH" 2>/dev/null || echo 0)
behind=$(git rev-list --count "$BRANCH..$remote_ref" 2>/dev/null || echo 0)

echo "  $BRANCH:        $(git rev-parse --short "$BRANCH")"
echo "  $remote_ref: $(git rev-parse --short "$remote_ref")"
echo "  ahead:  $ahead    behind: $behind"

if [[ "$ahead" -eq 0 ]]; then
    echo "✅ Local '$BRANCH' is not ahead of '$remote_ref'. Nothing to do."
    exit 0
fi

if [[ "$behind" -eq 0 && "$ahead" -gt 0 ]]; then
    echo "⚠️  Local '$BRANCH' is ahead but NOT behind — this is not a post-squash state."
    echo "   It looks like genuine local work. Refusing to reset."
    echo "   If you intend to discard these commits: git reset --hard $remote_ref"
    exit 1
fi

# Diverged: ahead AND behind. Verify the local-only commits are content-equivalent
# to what's already on the remote (post-squash signature: same tree, different SHAs).
echo ""
echo "→ Checking whether local 'ahead' commits are content-equivalent to the squashed merge..."
local_tree=$(git rev-parse "$BRANCH^{tree}")
remote_tree=$(git rev-parse "$remote_ref^{tree}")

if [[ "$local_tree" != "$remote_tree" ]]; then
    echo "❌ Trees differ. This is NOT a clean post-squash state — refusing to reset:"
    echo "     local  tree: $local_tree"
    echo "     remote tree: $remote_tree"
    echo "   Investigate manually (git log $remote_ref..$BRANCH, git diff $remote_ref..$BRANCH)."
    exit 1
fi

# Safety: refuse to modify a dirty worktree.
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Worktree is dirty. Stash or commit changes before running cleanup."
    exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "Plan:"
echo "  1. Check out '$BRANCH' (currently on '$current_branch')"
echo "  2. git reset --hard $remote_ref     # safe: trees are identical"
[[ "$current_branch" != "$BRANCH" ]] && echo "  3. Return to '$current_branch'"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "(--dry-run; no changes applied)"
    exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
    echo ""
    read -r -p "Proceed? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

git checkout "$BRANCH"
git reset --hard "$remote_ref"
if [[ "$current_branch" != "$BRANCH" ]]; then
    git checkout "$current_branch"
fi
echo ""
echo "✅ Local '$BRANCH' fast-forwarded to '$remote_ref'."
