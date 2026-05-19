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

Then, **regardless of sentinel state**, enumerate which `.md` files were changed:

```bash
BASE=$(git merge-base HEAD main 2>/dev/null || git rev-parse HEAD^)
git diff "$BASE"..HEAD --name-only | grep -E '(^skills/|^docs/).*\.md$|^[A-Z][A-Za-z_-]*\.md$' || echo "NO_MD_FILES_CHANGED"
```

If this command outputs any `.md` file paths (not `NO_MD_FILES_CHANGED`), PHR is required (Row 2).

| Result | Action |
|--------|--------|
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` AND md-file check → `NO_MD_FILES_CHANGED` | Battery evidence confirmed. Proceed directly to Step 1. |
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` AND md-file check lists any files | Battery passed. **Also invoke PHR** (`/sp-phr`) on the listed files before Step 1 — see below. |
| Any other result | Dispatch `code-review-battery` (via `sub-agent-code-reviewer`). Fix all Critical and Important findings. Re-dispatch if fixes were made. **Only proceed when the battery verdict is PASS or PASS_WITH_NITS.** Then re-run the md-file check above: if it lists any files, also invoke PHR; otherwise proceed to Step 1 directly. |

**PHR is mandatory when the md-file check lists any `.md` files.**

Scope: any `.md` file under `skills/` or `docs/`, plus repo-root `.md` files whose names start with an uppercase letter (e.g., `AGENTS.md`, `DESIGN.md`, `ARCHITECTURE.md`). Excludes: `CHANGELOG.md`, `README.md` (these two are excluded by the regex above — add them to a post-grep exclusion if needed).

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

**If tests fail:** Stop. Show failures. Do not proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null
```

If this returns a SHA, use `main` as the base. If it returns nothing (non-zero exit), the branch has no `main` ancestor — surface this explicitly: "Could not determine base branch automatically (git merge-base returned nothing). What branch did this work split from?"

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

**Option 2 (Push and create PR):** Push branch → create PR → cleanup worktree. Note: `unified-commit-gate` (push mode) fires before push.

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

## Red Flags

- Presenting work as "ready" without completing Step 0
- Proceeding with failing tests
- Force-pushing without explicit request
- Merging without verifying tests on result

## Companion Skills

- **code-review-battery**: The review engine Step 0 dispatches
- **progressive-code-review-gate**: Verdict mapping and dispatch procedure
- **verification-before-completion**: Fires before this skill (completion-gate order 2)
- **unified-commit-gate** (push mode): Fires when Option 2 triggers a push
- **subagent-driven-development**: Calls this skill after all tasks complete
