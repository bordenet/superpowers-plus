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

**If removal is refused** (`contains modified or untracked files`): the
worktree holds files that exist nowhere else — uncommitted plans, notes,
or scratch work. Never `--force` on your own initiative. Show your human
partner what is at stake and ask:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```
Worktree removal refused — these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

Carry out the choice, then remove the worktree.

**If no human is reachable** (headless/non-interactive invocation, no
terminal to ask on): do not guess which of the three to do — that is a
destructive, irreversible-by-default decision. Print the file list, exit
non-zero, and leave the worktree in place uncleaned.

Otherwise: the host owns this workspace — leave it, use its own
workspace-exit tool if it has one.
