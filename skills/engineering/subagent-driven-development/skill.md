---
name: subagent-driven-development
source: superpowers-plus
overrides: superpowers/subagent-driven-development
triggers: ["execute plan with subagents", "subagent per task", "subagent-driven", "implement plan with subagents", "fresh subagent per task"]
description: "Use when executing implementation plans with independent tasks in the current session"
---

# Subagent-Driven Development

## When to Use

- You have a written implementation plan with independent tasks to execute in the current session
- You want isolated context per task (fresh subagent = no pollution from prior tasks)
- NOT for: writing the plan (`writing-plans`), execution across multiple sessions (`executing-plans`)

Execute plan by dispatching fresh subagent per task, with two-stage review after each: spec compliance first, then code quality.

**Why:** Fresh subagent per task = isolated context, no pollution. You construct exactly what they need.

## Process (per task)

1. **Read plan** — extract all tasks with full text upfront, create TodoWrite
2. **Dispatch implementer** subagent with full task text + context (never make subagent read plan file)
3. **Handle status** — DONE → review | DONE_WITH_CONCERNS → assess then review | NEEDS_CONTEXT → provide and re-dispatch | BLOCKED → see below
4. **Spec compliance review** — dispatch spec reviewer subagent. Issues? → implementer fixes → re-review until ✅
5. **Code quality review** — dispatch quality reviewer subagent. Issues? → implementer fixes → re-review until ✅
6. **Mark task complete** → next task
7. **After all tasks** — Dispatch final sub-agent-code-reviewer for entire implementation
8. **Finish** — invoke `superpowers:finishing-a-development-branch`

## Model Selection

| Task type | Model tier | Signal |
|-----------|-----------|--------|
| Mechanical (1-2 files, clear spec) | Cheap/fast | Complete spec, isolated scope |
| Integration (multi-file) | Standard | Cross-file coordination |
| Architecture/design/review | Most capable | Judgment, broad understanding |

## Handling BLOCKED Status

1. Context problem → provide more context, re-dispatch same model
2. Reasoning limit → re-dispatch with more capable model
3. Task too large → break into smaller pieces
4. Plan is wrong → escalate to human

Never force retry without changes. If stuck, something must change.

## Subagent Roles

- **Implementer** — receives full task text + context, implements the change
- **Spec compliance reviewer** — verifies implementation matches the plan/spec
- **Code quality reviewer** — checks code quality, patterns, edge cases

## Rules

- **Never** start on main/master without user consent
- **Never** skip either review stage (spec compliance THEN quality — order matters)
- **Never** dispatch parallel implementers (conflicts)
- **Never** provide plan file path instead of full text
- **Never** proceed with unfixed review issues
- **Never** let self-review replace actual review (both needed)
- Answer subagent questions completely before letting them proceed
- If reviewer finds issues → implementer fixes → reviewer re-reviews → repeat until approved

## Integration

| Skill | Role |
|-------|------|
| `superpowers:using-git-worktrees` | Set up isolated workspace (REQUIRED) |
| `superpowers:writing-plans` | Creates the plan this executes |
| `superpowers:finishing-a-development-branch` | After all tasks complete |
| `superpowers:executing-plans` | Alternative: parallel session execution |

## Example: Dispatch Prompt

```
Implement task 3: "Add retry logic to API client."
Files: src/api/client.ts (main), test/api/client.test.ts (tests).
Constraints: max 3 retries, exponential backoff, no new dependencies.
Reply DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Subagent given plan file path instead of full text | Re-dispatch with complete task text inline |
| Skipped spec compliance review, went straight to quality | Go back — spec compliance THEN quality, order matters |
| Parallel implementers caused merge conflicts | Never dispatch parallel implementers — sequential only |
