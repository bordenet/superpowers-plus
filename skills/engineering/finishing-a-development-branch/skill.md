---
name: finishing-a-development-branch
source: superpowers-plus
augment_menu: true
# Override rationale: Adds mandatory Step 0 (autonomous code review via
# code-review-battery) before presenting integration options. The upstream
# version goes straight to "verify tests → present options," which allows
# unreviewed work to be presented as ready for human action.
triggers:
  - /sp-finish
  - finishing a branch
  - branch is done
  - ready to merge
  - implementation complete
  - all tasks done
  - work is finished
anti_triggers:
  - starting a branch
  - creating a branch
description: "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work. Mandates autonomous code review (Step 0) before presenting options. Guides completion of development work by presenting structured options for merge, PR, or cleanup."
summary: "Use when: branch work is done. Enforces review-before-options via code-review-battery. Skip when: still actively implementing."
coordination:
  group: completion-gate
  order: 3
  requires:
    - verification-before-completion
    - issue-verify
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [merge-ready-branch]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 10
---

> **Wrong skill?** Quick pre-commit check → `unified-commit-gate`. Presenting results mid-work → `verification-before-completion`. Reviewing someone's PR → `providing-code-review`.

# Finishing a Development Branch

## When to Use

Invoke when development work on a branch is complete and ready to review, commit, or ship.

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Autonomous code review → Verify tests → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### 🔴 Step 0: Autonomous Code Review (NON-NEGOTIABLE)

**Before verifying tests, before presenting options — check the sentinel, then run battery if needed.**

First, run the `code-review-battery` Phase 0 sentinel check:

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

Then, **regardless of sentinel state**, enumerate which `.md` files were changed via the canonical helper:

```bash
# Exit 0 → files listed on stdout; exit 1 → no PHR-relevant files; exit 2 → NO_BASE_FOUND.
tools/md-files-changed.sh
case $? in
    0) echo ">>> PHR REQUIRED for the files listed above" ;;
    1) echo "NO_MD_FILES_CHANGED" ;;
    2) echo "NO_BASE_FOUND — cannot determine diff scope; review the full branch manually" ;;
esac
```

The helper is the single source of truth for the PHR-trigger regex and exclusions (`README.md`, `CHANGELOG.md`); `tools/run-battery.sh` consumes the same script. If the helper outputs any `.md` file paths, PHR is required (Row 2). If exit code is 2 (`NO_BASE_FOUND`), treat PHR as required by default and review the full branch manually.

| Result | Action |
|--------|--------|
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` AND md-file check → `NO_MD_FILES_CHANGED` | Battery evidence confirmed. Proceed directly to Step 1. |
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` AND md-file check lists any files | Battery passed. **Also invoke PHR** (`/sp-phr`) on the listed files before Step 1 — see below. |
| Any other result | Dispatch `code-review-battery` (via `sub-agent-code-reviewer`). Fix all Critical and Important findings. Re-dispatch if fixes were made. **Only proceed when the battery verdict is PASS or PASS_WITH_NITS.** Then re-run the md-file check above: if it lists any files, also invoke PHR; otherwise proceed to Step 1 directly. |

**PHR is mandatory when the md-file check lists any `.md` files.**

Scope: any `.md` file under `skills/` or `docs/`, plus repo-root `.md` files whose names start with an uppercase letter (e.g., `AGENTS.md`, `DESIGN.md`, `ARCHITECTURE.md`). Excludes: `CHANGELOG.md`, `README.md` (excluded by the post-grep `grep -vE` filter, not by the main regex — the main regex matches them).

The battery runs automated linting and tests — it does NOT run PHR. Invoke `progressive-harsh-review` (`/sp-phr`) for these files before proceeding to Step 1. A passing battery sentinel is NOT a substitute for PHR on skill and design artifacts.

> **Why separate?** `run-battery.sh` calls `harsh-review.sh` (a shell linter), not the multi-persona PHR skill. PHR is an AI judgment gate; the battery is an automated script gate. Both are required for skill/design changes.

If you skip this step and present work as "ready" to the human, you have violated the gate.

**Why this step exists:** See the 2026-04-02 incident in `verification-before-completion` Incident History.

### Step 1: Verify Tests

**After Step 0 passes, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Stop. Show failures. Do not proceed to Step 1.5.

**If tests pass:** Continue to Step 1.5.

### Step 1.5: Verify Branch Base — HARD STOP

**Before presenting options, verify the branch is not behind `origin/main`.**

> **Assumption:** This step assumes `origin/main` is the integration branch. If the branch targets a different base (feature branch, release branch), set `BASE_REF` to the correct remote ref (e.g., `origin/dev`, `origin/release-X`). Use the same `BASE_REF` in the recovery rebase below. If the repo uses a fork model with separate `origin`/`upstream` remotes, substitute accordingly.

```bash
BASE_REF="origin/main"      # ← substitute if branch targets a different remote
FORCE_PUSH_REQUIRED=false   # default; overridden in recovery steps if a rebase occurs
git fetch origin || { echo "FETCH FAILED — cannot verify branch base. Do not proceed."; false; }
git log --oneline "HEAD..${BASE_REF}"
```

If `git log` errors rather than producing empty output, the remote ref does not exist — run `git ls-remote origin` to inspect the remote's branch list before proceeding.

| Result | Action |
|--------|--------|
| Empty output | Branch is current. Proceed to Step 2. |
| Any commits listed | **HARD STOP** — *(do not open or update any PR until recovery completes)* — see recovery steps below. |

**Recovery when branch is behind `origin/main`** (track attempt number using `ATTEMPT_FILE="$(git rev-parse --git-common-dir)/rebase-attempt-count"`; read with `cat "$ATTEMPT_FILE" 2>/dev/null || echo 0`; if absent this is attempt 1; write `echo 1 > "$ATTEMPT_FILE"` or `echo 2 > "$ATTEMPT_FILE"`; using `--git-common-dir` works in worktrees):

1. Check for rebase in progress: `git rebase --show-current-patch 2>/dev/null && echo REBASE_IN_PROGRESS || echo CLEAN`. If `REBASE_IN_PROGRESS`, ask human to confirm abort before running `git rebase --abort`.
2. Capture stash state: `git status --short`. If uncommitted changes exist, run `git stash push -m "pre-rebase WIP" && STASHED=true || { echo "STASH FAILED — manual intervention required."; STASHED=false; return 1; }`. If clean, note `STASHED=false` — do not run `git stash pop` later.
3. Detect force-push requirement: `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null && echo FORCE_PUSH_REQUIRED=true || echo FORCE_PUSH_REQUIRED=false`. Then rebase: `git rebase "${BASE_REF:-origin/main}"`. If `FORCE_PUSH_REQUIRED=true`, push will need `--force-with-lease`; confirm with human at Step 4 Option 2.
4. If rebase produced conflicts: resolve them, `git add <files>`, `git rebase --continue`, then follow `unified-commit-gate § Post-Conflict Trap` (typecheck → lint → test). If no conflicts: proceed to step 5.
5. Restore stash (only if `STASHED=true` and rebase complete): `git stash pop`. If conflicts, resolve then re-run typecheck → lint → test.
6. Re-run Step 0 (rebase rewrites HEAD, sentinel stale), re-run Step 1 (tests), then re-run Step 1.5. If clean, run `rm -f "$ATTEMPT_FILE"`. If this was attempt 2 and Step 1.5 still shows commits: **escalate to human** — do not run a third rebase.

**Why this step exists:** A prior production incident occurred when a branch was cut before a revert landed on `main`. No branch-base check was run before pushing. Conflicts appeared only in the remote MR diff, requiring multi-session destructive rebasing and a lost typecheck that left a broken build in CI.

### Step 2: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null \
    || git merge-base HEAD origin/main 2>/dev/null \
    || git merge-base HEAD master 2>/dev/null \
    || git merge-base HEAD origin/master 2>/dev/null
```

If any of these returns a SHA, use that branch as the base. If all fail, the branch has no recognizable integration ancestor — surface this explicitly: "Could not determine base branch automatically (no `main`/`master` ancestor found). What branch did this work split from?"

### Step 3: Present Options

Present exactly these 4 options:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

### Step 4: Execute Choice

**Option 1 (Merge locally):** Checkout base → pull → merge → verify tests on result → delete branch → cleanup worktree.

**Option 2 (Push and create PR):**

1. Run `tools/branch-flow-preflight.sh <current-branch> <base-branch>` to validate the (source, target) pair against the canonical flow and write `.branch-flow-cleared`. The pre-push hook reads this sentinel and refuses pushes to dev/staging/main without it.
2. Push the branch. `unified-commit-gate` (push mode) fires before push.
3. Create the PR: `gh pr create --fill` (`--fill` pre-fills title/body from commits; override with `--title`/`--body`). If the work has an issue identifier (per git-branch-conventions' "Before Naming the Branch"), the title should include it, matching branch/commit.
4. GitHub auto-links AND auto-closes an issue if the PR body contains `Fixes #123` or `Closes #123` **and the PR merges into the repo's default branch** (not just any branch) — confirm that's actually intended before using that phrasing; a plain reference (`#123`) links without closing. If citing an issue, verify it resolves via `issue-verify` first — never construct the reference from memory.
5. `gh pr edit` has a body-replacement footgun when adding a link after the fact — see `external-cli-audit`'s CLI Default Hazards table.
6. Cleanup the worktree per **Step 5: Cleanup Worktree** below.

**Option 3 (Keep as-is):** Report status. Keep worktree.

**Option 4 (Discard):** Confirm first (require typed "discard"). Then delete branch and cleanup worktree.

### Step 5: Cleanup Worktree

For Options 1, 2, 4 — check if in worktree and remove it. For Option 3 — keep worktree.

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Presenting options without completing Step 0 | Review first, options second |
| Skipping test verification because review passed | Review ≠ tests. Both required. |
| Open-ended "What should I do next?" | Present exactly 4 structured options |
| Auto-cleanup worktree for Option 3 | Only cleanup for Options 1 and 4 |
| Deleting work without confirmation | Require typed "discard" for Option 4 |
| Citing an issue reference in a PR body without verifying it resolves | Verify via `issue-verify` before citing; never build the reference from memory |

## Red Flags

- Presenting work as "ready" without completing Step 0
- Proceeding with failing tests
- Force-pushing without explicit request
- Merging without verifying tests on result

## Companion Skills

- **code-review-battery**: The review engine Step 0 dispatches
- **progressive-code-review-gate**: Verdict mapping and dispatch procedure
- **verification-before-completion**: Fires before this skill (completion-gate order 2)
- **unified-commit-gate** (push mode): Fires when Option 2 triggers a push; § Post-Conflict Trap mandates typecheck after rebase/stash-pop conflicts
- **subagent-driven-development**: Calls this skill after all tasks complete
- **issue-verify**: Verify an issue identifier before citing it in a branch, commit, or PR
- **external-cli-audit**: CLI default hazards (e.g. `gh pr edit`'s body-replacement behavior) referenced from Option 2
