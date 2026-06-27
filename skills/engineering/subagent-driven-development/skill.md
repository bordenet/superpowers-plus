---
name: subagent-driven-development
source: superpowers-plus
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

Execute plan by dispatching a fresh implementer subagent per task, a task review (spec compliance + code quality) after each, and a broad whole-branch review at the end.

**Why:** Fresh subagent per task = isolated context, no pollution. You construct exactly what they need. **Narration:** between tool calls, one short line max — the ledger and tool results carry the record. **Continuous execution:** Do not pause to check in between tasks. The only reasons to stop: BLOCKED you cannot resolve, genuine ambiguity, or all tasks complete.

## When to Use

- Executing implementation plans with independent tasks in the current session
- User says "execute plan with subagents" or "implement plan with subagents"
- NOT for: writing the plan (`writing-plans`), parallel session execution (`executing-plans`)

### Parallel Dispatch Mode

For tasks with sufficient isolation (different files, independent interfaces), the Execution Conductor can dispatch implementers in parallel. See `references/parallel-dispatch-mode.md` for full protocol.

**Activation:** Fan-out eligibility rubric score ≥ 6 per task pair (file overlap, interface coupling, test isolation, data model coupling). **Cost cap:** 2.5× serial. **Default:** Sequential.

## Process (per task)

1. **Read plan** — note Global Constraints, create TodoWrite for all tasks
2. **Run `scripts/task-brief PLAN N`** — extracts task text to file; record current HEAD as BASE_SHA
3. **Dispatch implementer** using `implementer-prompt.md` with brief path + report path + context
4. **Handle status** — DONE → generate review package | DONE_WITH_CONCERNS → assess → review | NEEDS_CONTEXT → provide and re-dispatch | BLOCKED → see below
5. **Run `scripts/review-package BASE_SHA HEAD`** — writes diff file; dispatch task reviewer using `task-reviewer-prompt.md` with diff path
6. **Review issues?** → dispatch fix subagent for Critical/Important → re-review | ⚠️ items → resolve yourself (you hold cross-task context)
7. **Mark complete** → append to progress ledger → next task
8. **After all tasks** — dispatch final code reviewer using `requesting-code-review/code-reviewer.md`
9. **Finish** — invoke `superpowers:finishing-a-development-branch`

## Pre-Flight Plan Review

Before dispatching Task 1, scan the plan for conflicts:
- Tasks that contradict each other or the plan's Global Constraints
- Anything the plan mandates that the review rubric treats as a defect

Present all findings as **one batched question** to your human partner before execution begins. If the scan is clean, proceed without comment.

## File Handoffs

Everything pasted into a dispatch stays in your context for the rest of the session. Use files:

- **Task brief:** `scripts/task-brief PLAN N` → path for implementer
- **Report file:** `task-N-report.md` alongside the brief → implementer writes full report here; you read it before review dispatch
- **Review package:** `scripts/review-package BASE HEAD` → path for reviewer (never enters your context)
- **Dispatch content:** (1) where this task fits, (2) brief path as "requirements, exact values verbatim", (3) interfaces from earlier tasks, (4) report path + contract. No pasted task history from prior tasks.

## Durable Progress

Conversation memory does not survive compaction. Track progress in a ledger file:

- **At start:** `cat "$(git rev-parse --show-toplevel)/.superpowers/sdd/progress.md"` — tasks listed as complete are DONE, do not re-dispatch
- **On each task completion:** append `Task N: complete (commits <base7>..<head7>, review clean)`
- **After compaction:** trust ledger + `git log` over your own recollection

The workspace lives at `.superpowers/sdd/` (not `.git/sdd/` — Claude Code agents cannot write to `.git/`). `scripts/sdd-workspace` creates and returns the path.

## Model Selection

Always specify model explicitly — omitting it inherits the session's most expensive model.

**Turn count beats token price.** Cheap models take 2-3× the turns on multi-step work, often costing more overall. Use mid-tier as the floor for reviewers and prose-description implementers.

| Role | Model tier | Signal |
|------|-----------|--------|
| Mechanical implementer (1-2 files, complete spec = transcription) | Cheapest | Complete code in plan |
| Integration implementer (multi-file, judgment needed) | Standard | Cross-file coordination |
| Architecture/design | Most capable | Broad understanding required |
| Reviewer (small diff) | Standard | Scale to diff size and risk |
| Reviewer (subtle/concurrency change) | Most capable | Risk warrants it |
| Final whole-branch review | Most capable | Always |

## Handling BLOCKED Status

1. Context problem → provide more context, re-dispatch same model
2. Reasoning limit → re-dispatch with more capable model
3. Task too large → break into smaller pieces
4. Plan is wrong → escalate to human
5. **Same error 3+ times** → invoke `think-twice` for fresh perspective before re-dispatch

Never force retry without changes. If stuck, something must change.

## Constructing Reviewer Prompts

- Do not add open-ended directives ("check all uses") without a concrete task-specific reason
- Do not ask a reviewer to re-run tests the implementer already ran on the same code
- Do not pre-judge findings — never write "do not flag", "at most Minor", or "the plan chose" in a dispatch prompt
- The `[GLOBAL_CONSTRAINTS]` block is the reviewer's attention lens — copy binding requirements verbatim from the plan; do not include process rules (they're in the template)
- Dispatch fix subagents for Critical and Important; record Minor in the ledger for the final review
- If a finding is labeled plan-mandated, present it to the human — do not dismiss or fix without asking

## Rules

- **Never** start on main/master without user consent
- **Never** skip task review (both spec compliance AND quality in one pass)
- **Never** dispatch parallel implementers without isolation rubric score ≥ 6 (see `references/parallel-dispatch-mode.md`)
- **Never** provide plan file path to implementer instead of brief file path
- **Never** dispatch task reviewer without a diff file (`scripts/review-package BASE HEAD`)
- **Never** proceed with unfixed Critical/Important review issues
- **Never** let self-review replace actual review (both needed)
- **Never** re-dispatch a task the progress ledger marks complete
- Answer subagent questions completely before letting them proceed

## Integration

| Skill | Role |
|-------|------|
| `superpowers:using-git-worktrees` | Set up isolated workspace (REQUIRED) |
| `superpowers:writing-plans` | Creates the plan this executes |
| `superpowers:requesting-code-review` | Final whole-branch code review |
| `superpowers:finishing-a-development-branch` | After all tasks complete |
| `superpowers:executing-plans` | Alternative: parallel session execution |

## Prompt Templates

- [implementer-prompt.md](implementer-prompt.md) — dispatch implementer subagent
- [task-reviewer-prompt.md](task-reviewer-prompt.md) — dispatch task reviewer (spec + quality)
- Final review: use `superpowers:requesting-code-review`'s `code-reviewer.md`

## Failure Modes

| Failure | Fix |
|---------|-----|
| Pasted task text inline instead of using task-brief | Dispatch with `scripts/task-brief` path |
| Skipped review or dispatched without diff file | Generate `scripts/review-package`, re-dispatch reviewer |
| Progress lost after compaction | Check ledger at `.superpowers/sdd/progress.md` and `git log` |
| Artifacts written to `.git/sdd/` | Use `scripts/sdd-workspace` — it writes to `.superpowers/sdd/` |
| Parallel implementers caused merge conflicts | Never dispatch parallel implementers — sequential only |
