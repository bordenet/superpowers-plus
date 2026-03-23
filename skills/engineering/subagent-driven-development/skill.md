---
name: subagent-driven-development
source: superpowers-plus
overrides: superpowers/subagent-driven-development
description: "Use when executing implementation plans with independent tasks in the current session"
---

# Subagent-Driven Development

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

## Prompt Templates

- `./implementer-prompt.md` — dispatch implementer
- `./spec-reviewer-prompt.md` — dispatch spec compliance reviewer
- `./code-quality-reviewer-prompt.md` — dispatch code quality reviewer

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
