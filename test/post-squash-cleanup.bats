#!/usr/bin/env bats

# Behavioral tests for tools/post-squash-cleanup.sh.
# Covers: ahead-only refusal, post-squash detection (same tree), dirty
# worktree refusal, dry-run, --branch override, and the missing-branch
# fast path.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/post-squash-cleanup.sh"

setup() {
    SANDBOX="$BATS_TEST_TMPDIR"
    REMOTE="$SANDBOX/remote.git"
    LOCAL="$SANDBOX/local"
    git init -q --bare "$REMOTE" >/dev/null

    git init -q -b main "$LOCAL" >/dev/null
    cd "$LOCAL"
    git config user.email "test@example.com"
    git config user.name "Test"
    git remote add origin "$REMOTE"
    echo seed > seed.txt
    git add seed.txt
    git commit -qm "seed"
    git checkout -qb dev
    git push -q origin main dev >/dev/null
}

@test "post-squash-cleanup: clean state exits 0" {
    run bash "$SCRIPT" --branch dev --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to do"* ]]
}

@test "post-squash-cleanup: missing branch is a no-op" {
    run bash "$SCRIPT" --branch nonexistent
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "post-squash-cleanup: ahead-only (genuine local work) is refused" {
    echo extra > extra.txt
    git add extra.txt
    git commit -qm "local-only work"
    run bash "$SCRIPT" --branch dev --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"ahead but NOT behind"* ]]
}

@test "post-squash-cleanup: post-squash state is detected and reset" {
    # Simulate the post-squash state: the remote has a single squashed commit
    # whose TREE matches the local branch's tip, but the SHAs differ. We mimic
    # that by amending the local commit (re-rooting it on a new SHA) and then
    # pushing a fresh squashed equivalent to the remote separately.

    echo work > work.txt
    git add work.txt
    git commit -qm "WIP 1"
    echo more >> work.txt
    git add work.txt
    git commit -qm "WIP 2"
    # Save the resulting tree.
    final_tree=$(git rev-parse "HEAD^{tree}")
    # Create the "squashed" commit on a parallel branch and push to remote dev.
    git checkout -q -b squash-stage origin/dev
    git read-tree "$final_tree"
    git checkout-index -af
    git add -A
    git commit -qm "squashed merge"
    git push -q --force origin squash-stage:dev >/dev/null
    git checkout -q dev
    git fetch -q origin
    # Sanity: local dev should be both ahead and behind origin/dev, with the
    # same tree as origin/dev (clean post-squash signature).
    ahead=$(git rev-list --count origin/dev..dev)
    behind=$(git rev-list --count dev..origin/dev)
    [ "$ahead" -gt 0 ]
    [ "$behind" -gt 0 ]
    [[ "$(git rev-parse dev^{tree})" == "$(git rev-parse origin/dev^{tree})" ]]

    run bash "$SCRIPT" --branch dev --yes
    [ "$status" -eq 0 ]
    # After reset, dev is no longer ahead.
    [[ "$(git rev-list --count origin/dev..dev)" == "0" ]]
}

@test "post-squash-cleanup: dirty worktree is refused" {
    # Create an ahead+behind state with matching trees, then dirty the worktree.
    echo work > work.txt && git add work.txt && git commit -qm "WIP"
    final_tree=$(git rev-parse "HEAD^{tree}")
    git checkout -q -b squash-stage origin/dev
    git read-tree "$final_tree" && git checkout-index -af && git add -A
    git commit -qm "squashed"
    git push -q --force origin squash-stage:dev >/dev/null
    git checkout -q dev
    git fetch -q origin
    # Dirty the worktree by modifying a tracked file:
    echo modified >> seed.txt
    run bash "$SCRIPT" --branch dev --yes
    [ "$status" -eq 1 ]
    [[ "$output" == *"Worktree is dirty"* ]]
}

@test "post-squash-cleanup: --dry-run does not modify the branch" {
    echo work > work.txt && git add work.txt && git commit -qm "WIP"
    final_tree=$(git rev-parse "HEAD^{tree}")
    git checkout -q -b squash-stage origin/dev
    git read-tree "$final_tree" && git checkout-index -af && git add -A
    git commit -qm "squashed"
    git push -q --force origin squash-stage:dev >/dev/null
    git checkout -q dev
    git fetch -q origin
    pre_sha=$(git rev-parse dev)
    run bash "$SCRIPT" --branch dev --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-run"* ]]
    [[ "$(git rev-parse dev)" == "$pre_sha" ]]
}
