---
name: finishing-a-development-branch
source: superpowers-plus
overrides: superpowers/finishing-a-development-branch
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
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

| Result | Action |
|--------|--------|
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` | Battery evidence confirmed. Skip dispatch, proceed to Step 1. |
| Any other result | Dispatch `code-review-battery` (via `sub-agent-code-reviewer`). Fix all Critical and Important findings. Re-dispatch if fixes were made. **Only proceed to Step 1 when the battery verdict is PASS or PASS_WITH_NITS.** |

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
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main — is that correct?"

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

**Option 2 (Push and create PR):** Push branch → create PR → cleanup worktree. Note: `pre-push-quality-gate` fires before push.

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
- **pre-push-quality-gate**: Fires when Option 2 triggers a push
- **subagent-driven-development**: Calls this skill after all tasks complete
