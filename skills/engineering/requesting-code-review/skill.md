---
name: requesting-code-review
source: superpowers-plus
overrides: superpowers/requesting-code-review
# Override rationale: Routes review requests through code-review-battery (the
# superpowers-plus specialist engine) instead of the upstream single-reviewer
# template. Adds the "Cardinal Rule" — autonomous review before presenting work
# as ready — and integrates with the commit-gate and completion-gate chains.
# Triggers are INTENT-BASED (what the agent is about to do), not output-phrase-based.
triggers:
  - request code review
  - review my changes
  - before merging
  - review before PR
  - thorough review
  - please review my changes
  - please review my implementation
  - here's what I built
  - here's what I implemented
  - here's what I changed
anti_triggers:
  - providing code review
  - receiving code review
  - code review battery
  - ready to commit
  - ready to push
description: "Use when presenting code changes to a human for review — dispatches code-review-battery. Self-fires on intent to present (see Cardinal Rule in skill body). Skips battery dispatch if valid sentinel exists for clean HEAD. Always runs battery before presenting, never after."
summary: "Use when: about to present code to a human (even informally). Skip when: valid sentinel exists for HEAD (battery already ran this unit of work)."
coordination:
  group: code-quality
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [review-feedback]
  capabilities: [dispatches-review]
  priority: 25
---

# Requesting Code Review

Dispatch `code-review-battery` to catch issues before they cascade. The battery dispatches 5 specialist reviewers in parallel — each focused on a distinct set of review dimensions — producing deeper analysis than any single-pass review.

**Core principle:** Review early, review often.

## 🔴 Before Asking the Human to Review

Apply this protocol whenever you are about to show a human your work — PR links, summaries, "here's what I built," "please review my changes." **Run this check before writing that message.**

**Step 1 — Read the sentinel, HEAD SHA, and worktree state:**

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

**Step 2 — Decide:**

| Result | Action |
|--------|--------|
| `NO CLEARANCE` | STOP. Run `code-review-battery` first. Do not write the review request. |
| Sentinel SHA ≠ HEAD SHA | STOP. Changes were made after last review. Re-run `code-review-battery`. |
| Sentinel valid for HEAD but `WORKTREE_DIRTY` | STOP. Staged/unstaged changes exist that battery didn't review. Commit or stash, then re-run battery. |
| `v1\|SHA\|PASS\|...` or `PASS_WITH_NITS`, SHA matches HEAD, AND `WORKTREE_CLEAN` | Proceed — include the clearance line in your message (see Step 3) |
| Anything else | STOP. Sentinel is malformed. Delete `.code-review-cleared`, re-run battery. |

**Step 3 — Include the clearance in your human-facing message:**

Every message that presents work to the human for review MUST open with the clearance line:

```
🔍 Review cleared: PASS | SHA: abc12345 | 2026-04-02T21:29Z
```

This is not optional decoration. It lets the human verify at a glance that battery ran on exactly the code being reviewed.
If you cannot produce this line, you have not run battery on HEAD. Run it now.

## 🔴 The Cardinal Rule

**The INTENT TO PRESENT is the trigger — not the words you use.**

The moment you are forming a response to the human that describes code you wrote — that is the trigger. Before the words exist. Not after you say "done". Before you start writing the sentence.

This applies unconditionally. No threshold for simplicity. No exception for small fixes. No exception for "the user will just look at the diff themselves." Every response. Every time.

| Internal state (INTENT) | Required gate |
|------------------------|--------------|
| Forming a response that describes code changes | Battery must have PASSED |
| About to commit or push | Battery must have PASSED; sentinel must exist |
| About to share an MR/PR link | Sentinel must exist for HEAD |
| About to write a completion summary | Battery must have PASSED |
| **ANY moment of transitioning from "working" to "reporting"** | **This IS the trigger. There is no hesitation threshold.** |

**If battery already ran and sentinel exists for HEAD**: Evidence confirmed. Do not re-dispatch. Note the clearance and proceed.

**If battery has not run**: Run it now, before writing a single word of the response.

The autonomous review is not the human's job to request. You must do it yourself, every time, before the response is formed.

**Why this rule exists:** See the 2026-04-02b incident in `verification-before-completion` Incident History. The gate failed because the implementation→reporting transition was not recognized as a trigger despite an explicit incident log entry from earlier the same session. The fix: trigger on INTENT, not on output language.

## When to Request Review

**Always (hard gates):**
- Before presenting ANY work as "ready/done/complete" to a human
- After completing a major feature or bug fix
- Before merge to main
- Before offering to commit, push, or create a PR
- After each task in subagent-driven development

**Also valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing a complex bug

## How to Request

### 1. Gather context

```bash
BASE_SHA=$(git merge-base HEAD main)   # or origin/dev, origin/main
HEAD_SHA=$(git rev-parse HEAD)
git diff $BASE_SHA..$HEAD_SHA          # the diff to review
```

### 2. Dispatch code-review-battery

Follow the `code-review-battery` procedure:

1. **Triage** the diff → select relevant specialist reviewers
2. **Dispatch** all activated reviewers in parallel via `sub-agent-code-reviewer`
3. Each reviewer gets: reviewer prompt + full diff + source context (callers, field readers, state types)
4. **Aggregate** findings → triple-filter → classify Implement/Defer/Reject

### 3. Act on findings

| Severity | Action |
|----------|--------|
| Critical | Fix immediately. Re-dispatch battery. |
| Important | Fix before proceeding. Re-dispatch if >1 fixed. |
| Minor | Fix now or document for follow-up. |
| Reviewer wrong | Push back with technical reasoning and evidence. |

### 4. Confirm verdict

Only proceed to presenting work as "ready" when battery verdict is **PASS** or **PASS_WITH_NITS** (with nits fixed).

## Integration with Workflows

| Workflow | When to Review |
|----------|---------------|
| **Subagent-driven development** | After EACH task — catch issues before they compound |
| **Feature development** | After implementation, before presenting options |
| **Ad-hoc development** | Before merge or when stuck |
| **Finishing a branch** | Step 0 of `finishing-a-development-branch` dispatches `code-review-battery` directly |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Skipping review because "it's simple" | Complexity doesn't determine risk |
| Ignoring Critical findings | Critical = broken if shipped |
| Proceeding with unfixed Important findings | Fix first, then re-dispatch |
| Arguing with valid technical feedback | Push back only with evidence |
| Presenting work as "ready" then reviewing | Review first, present second |

## Companion Skills

- **code-review-battery**: The review engine this skill dispatches
- **progressive-code-review-gate**: Fires at commit time (uses battery) — handles "ready to commit/push" triggers
- **verification-before-completion**: Completion gate that requires review evidence
- **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
