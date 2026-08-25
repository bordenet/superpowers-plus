# Worktree Capture and Cleanup

## Step 4: Capture first

Before any option below `cd`'s away (Options 1 and 4 checkout the base repo
to merge or force-delete the branch), capture these once:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

Deriving these values afterward silently resolves to the base repo instead
— `GIT_DIR == GIT_COMMON` would then look true even when you started in a
worktree, and cleanup would no-op or check the wrong path. Use these three
variables for the rest of Step 4 and all of Step 5; never recompute them.

## Step 5: Cleanup Worktree

For Options 1, 2, 4 — using the values captured above. For Option 3 — keep
worktree, skip this step.

`GIT_DIR == GIT_COMMON`: normal repo, nothing to clean up, done.

`WORKTREE_PATH` under `.worktrees/`, `worktrees/`, or the global
`~/.config/superpowers/worktrees/<project>/` (all three are conventions
`using-git-worktrees` itself creates — see that skill for the selection
logic): this skill created it, so we own cleanup:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # self-healing: clears any stale registrations
```

Otherwise: the host owns this workspace — leave it, use its own
workspace-exit tool if it has one.
