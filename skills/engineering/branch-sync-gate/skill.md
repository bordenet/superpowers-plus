---
name: branch-sync-gate
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-sync
  - "continuing work on"
  - "resuming work on"
  - "picking up"
  - "let's continue"
  - "let's resume"
  - "review this PR"
  - "reviewing PR"
  - "work on this PR"
  - "working on this PR"
  - "do test"
  - "run test"
  - "next test"
  - "let's do test"
  - "start test"
anti_triggers:
  - "creating a branch"
  - "new branch"
  - "checkout -b"
description: "Pull gate — MANDATORY before any work on an existing shared branch. git fetch + status check before touching code, running tests, or making changes. Fires whenever resuming, continuing, or reviewing work on a branch that exists on a remote."
summary: "Use when: about to do ANYTHING on an existing branch (write code, run tests, review). Pull first. Always."
coordination:
  group: session-start-gate
  order: 0
  requires: []
  enables:
    - pre-commit-gate
    - unified-commit-gate
    - finishing-a-development-branch
  escalates_to: []
  internal: false
composition:
  consumes: [existing-branch]
  produces: [synced-local-branch]
  capabilities: [gates-quality]
  priority: 100
---

> **Wrong skill?** Starting a brand-new branch → `using-git-worktrees`. About to commit → `unified-commit-gate`. Branch work is done → `finishing-a-development-branch`.

# Branch Sync Gate

## The Rule

**Before touching any existing shared branch — pull first.**

This is not optional. It is not skippable. It applies even if you were just working on the branch 5 minutes ago.

## When This Fires

Any time you are about to:
- Resume or continue work on a branch that exists on a remote
- Run tests on an existing branch
- Write code on an existing branch
- Review a PR branch locally
- Add commits to a branch shared with other developers

## The Gate (Run This First — Before Anything Else)

```bash
# Step 1: Where are we?
git branch --show-current
git remote -v

# Step 2: Fetch and check for remote changes
git fetch origin
git log HEAD..origin/$(git branch --show-current) --oneline 2>/dev/null
```

| Remote has commits not in local? | Action |
|---|---|
| Yes | `git pull --rebase origin $(git branch --show-current)` — then verify |
| No | Proceed — you are in sync |
| Unsure | Fetch and check. Never assume. |

```bash
# Step 3: Pull if behind
git pull --rebase origin $(git branch --show-current)

# Step 4: Confirm baseline
git log --oneline -5
git status
```

## Non-Negotiable

**Do not start work, run tests, or write a single line of code until this gate passes.**

If you find yourself already mid-work and realize you haven't pulled — stop, pull, verify the state hasn't changed under you, then continue.

## Why This Exists

**Incident 2026-04-23:** Agent began writing tests on an active PR branch without pulling first. A teammate had pushed two commits in the interim. The agent iterated tests against stale code, created a merge conflict on push, resolved it by discarding its own changes, then pushed a broken build (failing assertion + TypeScript error). Required multiple extra fix commits on a PR that was otherwise ready to merge.

**Root cause:** No skill enforced sync at session start. Every existing gate (`sp-commit`, `sp-finish`, `pre-commit-gate`) fires at commit time or later — zero enforcement at the moment work begins.

## Anti-Patterns

| Wrong | Right |
|---|---|
| Assume local is up to date because you just worked on it | `git fetch` and check |
| Pull after writing code | Pull before writing code |
| Merge conflicts on push | Prevented by pulling first |
| Re-fixing what a teammate already fixed | Prevented by pulling first |

## Companion Skills

- **git-branch-conventions**: Use when creating a brand-new branch
- **unified-commit-gate**: Fires at commit time (this fires at session start)
- **finishing-a-development-branch**: Fires when branch work is complete
