---
name: requesting-code-review
source: superpowers-plus
overrides: superpowers/requesting-code-review
# Override rationale: Routes review requests through code-review-battery (the
# superpowers-plus specialist engine) instead of the upstream single-reviewer
# template. Adds the "Cardinal Rule" — autonomous review before presenting work
# as ready — and integrates with the commit-gate and completion-gate chains.
triggers:
  - request code review
  - review my changes
  - before merging
  - review before PR
  - thorough review
anti_triggers:
  - providing code review
  - receiving code review
  - code review battery
  - ready to commit
  - ready to push
description: "Use when you want a thorough specialist review of code changes — dispatches code-review-battery. The Cardinal Rule: you MUST run autonomous code review BEFORE presenting ANY work as 'ready' to a human. For commit-time review, see progressive-code-review-gate."
summary: "Use when: you want a thorough review. Routes through code-review-battery. Skip when: progressive-code-review-gate already fired, or review already dispatched this round."
coordination:
  group: code-quality
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Requesting Code Review

Dispatch `code-review-battery` to catch issues before they cascade. The battery dispatches 5 specialist reviewers in parallel — each focused on a distinct set of review dimensions — producing deeper analysis than any single-pass review.

**Core principle:** Review early, review often.

## 🔴 The Cardinal Rule

**You MUST run autonomous code review BEFORE presenting ANY work as "ready" to a human.**

This is a hard gate. If you are about to say "ready to commit," "ready to push," "implementation complete," or ANY variation — you MUST have already dispatched the `code-review-battery` and acted on its findings.

The autonomous review is not the human's job to request. You must do it yourself, every time, before speaking.

**Why this rule exists:** See the 2026-04-02 incident in `verification-before-completion` Incident History.

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
