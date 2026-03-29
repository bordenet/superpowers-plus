---
name: subagent-driven-development
source: superpowers-plus
overrides: superpowers/subagent-driven-development
# Override rationale: Condensed from 277→91 lines. Adds two-stage review pattern
# (spec compliance + code quality), inline role descriptions instead of external
# prompt template files, and platform-agnostic sub-agent dispatch.
triggers: ["execute plan with subagents", "subagent per task", "subagent-driven", "implement plan with subagents", "fresh subagent per task"]
anti_triggers: ["simple task", "one file change", "quick fix"]
description: "Use when executing implementation plans with independent tasks in the current session"
summary: "Use when: executing plans with independent tasks that can run in parallel."
coordination:
  group: engineering
  order: 5
  requires: ["plan-and-execute"]
  enables: []
  escalates_to: []
  internal: false
composition:
  produces: [implemented-code, test-suite, review-report]
  consumes: [implementation-plan, task-list, acceptance-criteria]
  capabilities: [parallel-task-dispatch, merge-risk-analysis, integration-checkpoint]
  priority: 5
  optional: false
  requires_all: false
---

# Subagent-Driven Development

> **Wrong skill?** Simple single-file changes → just edit directly. Planning without execution → `brainstorming`. Feature workflow → `feature-development`.

## Companion Skills

- **feature-development**: Full feature workflow (this skill uses sub-agents)
- **plan-and-execute**: For multi-step implementation planning
- **test-driven-development**: TDD within sub-agent tasks

## When to Use

- You have a written implementation plan with independent tasks to execute in the current session
- You want isolated context per task (fresh subagent = no pollution from prior tasks)
- NOT for: writing the plan (`writing-plans`), execution across multiple sessions (`executing-plans`)

Execute plan by dispatching fresh subagent per task, with two-stage review after each: spec compliance first, then code quality.

**Why:** Fresh subagent per task = isolated context, no pollution. You construct exactly what they need.

### Parallel Dispatch Mode

For tasks with sufficient isolation (different files, independent interfaces), the Execution Conductor can dispatch implementers in parallel. See `references/parallel-dispatch-mode.md` for full protocol.

**Activation:** Fan-out eligibility rubric score ≥ 6 per task pair (file overlap, interface coupling, test isolation, data model coupling). **Cost cap:** 2.5× serial. **Default:** Sequential (existing behavior).

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
5. **Same error 3+ times** → invoke `think-twice` for fresh perspective before re-dispatch

Never force retry without changes. If stuck, something must change.

## Subagent Roles

- **Implementer** — receives full task text + context, implements the change
- **Spec compliance reviewer** — verifies implementation matches the plan/spec
- **Code quality reviewer** — checks code quality, patterns, edge cases

## Rules

- **Never** start on main/master without user consent
- **Never** skip either review stage (spec compliance THEN quality — order matters)
- **Never** dispatch parallel implementers without isolation rubric score ≥ 6 and integration checkpoint protocol active (see `references/parallel-dispatch-mode.md`)
- **Never** provide plan file path instead of full text
- **Never** proceed with unfixed review issues
- **Never** let self-review replace actual review (both needed)
- Answer subagent questions completely before letting them proceed
- If reviewer finds issues → implementer fixes → reviewer re-reviews → repeat until approved

## Integration

| Skill | Role |
|-------|------|
| `superpowers:using-git-worktrees` | Set up isolated workspace (REQUIRED) |
| `superpowers:plan-and-execute` | Creates the plan this executes |
| `superpowers:finishing-a-development-branch` | After all tasks complete |
| `superpowers:executing-plans` | Alternative: parallel session execution |

## Example: Dispatch Prompt

```text
Implement task 3: "Add retry logic to API client."
Files: src/api/client.ts (main), test/api/client.test.ts (tests).
Constraints: max 3 retries, exponential backoff, no new dependencies.
Reply DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.
```

## Example

```bash
# Launch sub-agent for independent task
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill code-review-battery
# Pass context inline — sub-agents have NO conversation context
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Subagent given plan file path instead of full text | Re-dispatch with complete task text inline |
| Skipped spec compliance review, went straight to quality | Go back — spec compliance THEN quality, order matters |
| Parallel implementers caused merge conflicts | Re-serialize: fall back to sequential. If isolation score was ≥ 6, file a re-serialization event (SD-11) and tighten rubric for this codebase |
