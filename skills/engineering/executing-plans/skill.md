---
name: executing-plans
source: superpowers-plus
triggers: ["execute this plan", "implement the plan", "execute plan file", "carry out this plan", "run the plan"]
anti_triggers: ["write a plan", "create a plan", "plan this out"]
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
summary: "Use when: executing a written implementation plan. Reviews and executes all tasks."
coordination:
  group: engineering
  order: 3
  requires: ["writing-plans"]
  enables: ["subagent-driven-development"]
  escalates_to: []
  internal: false
composition:
  consumes: [implementation-plan]
  produces: [code-changes, test-results]
  capabilities: [plan-execution, review-checkpoints, phased-delivery]
  priority: 7
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Augment Code, Claude Code, or Codex). If subagents are available, use superpowers:subagent-driven-development instead of this skill.

## When to Use

- You have a written implementation plan (e.g. from writing-plans skill) and are ready to execute it step by step
- You lack subagent support and must execute tasks sequentially in one session
- You need structured checkpoints and review gates between phases

**NOT when:** subagents are available — use subagent-driven-development instead for better quality and parallelism.

## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. **Before any `git commit` in this step:** invoke `superpowers:unified-commit-gate` (all applicable gates). Do NOT skip because you are mid-plan. Then continue with the plan's steps exactly as written (plan has bite-sized steps).
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
1. **Before pushing:** invoke `superpowers:unified-commit-gate` via `/sp-push`. A valid `.code-review-cleared` sentinel must exist for HEAD; if missing, run `code-review-battery` first. Run once per branch push, not per task.
2. Announce: "I'm using the finishing-a-development-branch skill to complete this work."
3. **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
4. Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks
