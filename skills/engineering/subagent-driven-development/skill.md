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
  requires: ["writing-plans"]
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

**Why:** Fresh subagent per task = isolated context, no pollution. You construct exactly what they need. **Narration:** between tool calls, one short line max — the ledger and tool results carry the record. **Continuous execution:** Do not pause to check in between tasks. The only reasons to stop: BLOCKED you cannot resolve, genuine ambiguity, cost signal from your human partner, or all tasks complete.

## When to Use

- Executing implementation plans with independent tasks in the current session
- User says "execute plan with subagents" or "implement plan with subagents"
- NOT for: writing the plan (`writing-plans`), parallel session execution (`executing-plans`)

### Parallel Dispatch Mode

For tasks with sufficient isolation (different files, independent interfaces), the Execution Conductor can dispatch implementers in parallel. See `references/parallel-dispatch-mode.md` for full protocol.

**Activation:** Fan-out eligibility rubric score ≥ 6 per task pair (file overlap, interface coupling, test isolation, data model coupling). **Cost cap:** 2.5× serial. **Default:** Sequential.

## Process (per task)

1. **Read plan** — note Global Constraints, create TodoWrite for all tasks
2. **Check this plan's ledger** — mandatory, before any dispatch: `scripts/sdd-workspace PLAN_FILE` prints the workspace; `cat "<workspace>/progress.md" 2>/dev/null || echo "(no ledger — all tasks pending)"`. If the first line names your plan file, `Task <N>: complete` lines are DONE — resume at the first task without one; a task whose last line is a fix round is mid-loop, resume there. If the first line names a *different* plan file — or it's the stray legacy path `.superpowers/sdd/progress.md` — it isn't yours: leave it in place and start fresh (see Durable Progress below for why this check exists, not just the slug).
3. **Run `scripts/task-brief PLAN_FILE N`** — extracts task text to file; record current HEAD as BASE_SHA (verify: `git log BASE_SHA..HEAD --oneline` should show zero commits — you haven't started yet)
4. **Dispatch implementer** using `implementer-prompt.md` with brief path + report path + context
5. **Handle status** — DONE → generate review package | DONE_WITH_CONCERNS → assess → review | NEEDS_CONTEXT → provide and re-dispatch | BLOCKED → see below
6. **Run `scripts/review-package PLAN_FILE BASE_SHA HEAD`** — writes diff file; verify `git log BASE_SHA..HEAD --oneline` shows only this task's commits; dispatch task reviewer using `task-reviewer-prompt.md` with diff path
7. **Review issues?** → enter the fix loop below (Critical/Important, or a confirmed ⚠️ gap) | remaining ⚠️ items → resolve yourself (you hold cross-task context)
8. **Mark complete** → append to progress ledger → next task
9. **After all tasks** — invoke `superpowers:unified-commit-gate` via `/sp-push`; when gate clears, `git push`. Sentinel required; docs-only exclusion: see unified-commit-gate Push Mode.
10. **After push** — invoke `superpowers:requesting-code-review` for final whole-branch review
11. **Finish** — invoke `superpowers:finishing-a-development-branch`

## Pre-Flight Plan Review

Before dispatching Task 1, scan the plan for conflicts:
- Tasks that contradict each other or the plan's Global Constraints
- Anything the plan mandates that the review rubric treats as a defect

Present all findings as **one batched question** to your human partner before execution begins. If the scan is clean, proceed without comment.

## File Handoffs

Everything pasted into a dispatch stays in your context for the rest of the session. Use files:

- **Task brief:** `scripts/task-brief PLAN_FILE N` → path for implementer
- **Report file:** `task-N-report.md` alongside the brief → implementer writes full report here; you read it before review dispatch
- **Review package:** `scripts/review-package PLAN_FILE BASE_SHA HEAD` → path for reviewer (never enters your context)
- **Dispatch content:** (1) where this task fits, (2) brief file path (implementer reads all task requirements from it — do not summarize inline), (3) interfaces from earlier tasks, (4) report path + contract. No pasted task history from prior tasks.

## Durable Progress

Conversation memory does not survive compaction. Track progress in a ledger file:

- **At start (mandatory, before any dispatch):** run `scripts/sdd-workspace PLAN_FILE` — it prints this plan's directory. Then check for this plan's ledger at `<workspace>/progress.md`. If its first line names your plan file, tasks with a `Task <N>: complete` line are DONE — do not re-dispatch them; resume at the first task without one. A task whose last line is a fix round is mid-loop: resume the loop at the next round. A ledger whose first line names a different plan file — or a stray ledger at the old flat path `.superpowers/sdd/progress.md` — is another plan's progress: leave it in place and start your own, fresh.
- **Ledger identity:** create the ledger with its identity as the first line: `# SDD ledger — plan: <plan file path>`.
- **On each task completion:** append `Task N: complete (commits <base7>..<head7>, review clean)`
- **After compaction:** trust ledger + `git log` over your own recollection

The workspace is plan-scoped: `.superpowers/sdd/<plan-basename>/` (not `.git/sdd/` — Claude Code agents cannot write to `.git/`), where `<plan-basename>` is derived from the plan file's basename alone. Two different plan files that happen to share a basename (e.g. two different `PLAN.md` files in different directories) resolve to the *same* slug directory — `scripts/sdd-workspace` does not disambiguate by full path, so the collision is real, not hypothetical. What actually prevents cross-plan contamination in that case is the ledger-identity check above: it runs before any dispatch and refuses to treat a ledger naming a different plan file as your own, so a follow-up plan run in the same working tree can share a workspace directory with a prior plan without ever reading or overwriting that prior plan's ledger. Once the final whole-branch review is clean, delete this plan's workspace (`rm -rf <workspace>`) — git history is the durable record from that point on; don't touch sibling plan directories.

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
- Enter the fix loop below for Critical and Important; record Minor in the ledger for the final review
- If a finding is labeled plan-mandated, present it to the human — do not dismiss or fix without asking

## Fix Loop (Review Findings)

A fix round is one fix dispatch + one scoped re-review (`re-review-prompt.md`, diff from `scripts/review-package PLAN_FILE FIX_BASE HEAD`). Five rounds max per task — this is a circuit breaker, not a target to reach.

**Rounds 1-3 — resume the original implementer.** Send it the open findings verbatim. Its context is intact: it knows the task, the code, and its own choices. If your harness cannot send another message to a live subagent, dispatch a fresh implementer carrying the brief path, the report-file path, and the findings — the report file is the persistent memory either way.

**Rounds 4-5 — dispatch a fresh implementer on a more capable model** (per Model Selection), with the brief path, the report-file path, the open findings, and this framing: "A prior implementer attempted this task [N] times; you own it now. Read the report file for what was tried." A loop that survives three resumes usually means the implementer cannot see its own problem — fresh eyes and a capability bump in one move.

| Round | Who fixes it | Model |
|-------|--------------|-------|
| 1–3 | Resume the original implementer (mechanism above) | Same as original |
| 4–5 | Fresh implementer (framing above) | One tier more capable |
| After round 5, still open | **STOP dispatching.** Adjudicate each open finding yourself | — |

Adjudication at the cap:
- **Reviewer is wrong / contestable** → park it in the ledger with a ruling (`Task N: parked — <finding> — ruling: <why the code stands>`)
- **Real but nothing downstream depends on it** → park it the same way, ruling says "real, deferred"
- **Real and load-bearing** (a later task builds on it, or it reveals a plan defect) → `Task N: BLOCKED — <reason>`, escalate to your human partner with the finding, the plan text it collides with, and the fix history

Never adjudicate before round 5 to end a loop early — that's pre-judging with a different name. Every ledger entry from a fix round or adjudication is mandatory; a silent discard is forbidden.

## Rules

- **Never** start on main/master without user consent
- **Never** skip task review (both spec compliance AND quality in one pass)
- **Never** dispatch parallel implementers without isolation rubric score ≥ 6 (see `references/parallel-dispatch-mode.md`)
- **Never** provide plan file path to implementer instead of brief file path
- **Never** dispatch task reviewer without BRIEF_FILE, DIFF_FILE, and REPORT_FILE — partial dispatch produces partial verdicts
- **Never** dispatch a re-review without FINDINGS, DIFF_FILE, BRIEF_FILE, and REPORT_FILE — the re-reviewer cannot verdict findings it never saw, inspect a diff it doesn't have, recover the task's context, or confirm the fix report's covering-test evidence
- **Never** proceed with unfixed Critical/Important review issues
- **Never** let self-review replace actual review (both needed)
- **Never** re-dispatch a task the progress ledger marks complete
- **Never** fresh-dispatch a fix in rounds 1-3 of the fix loop — resume the original implementer
- **Never** let a fix loop run past round 5 without adjudicating and reporting to your human partner
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
- [re-review-prompt.md](re-review-prompt.md) — dispatch scoped re-review after a fix round (verifies fixes only, doesn't re-read the whole task)
- Final review: use `superpowers:requesting-code-review`'s `code-reviewer.md`

**Minimal dispatch example** (full template in `implementer-prompt.md`):

```
Implement task 3: "Add retry logic to API client."
Brief: .superpowers/sdd/<plan-basename>/task-3-brief.md — read it; it contains all requirements.
Report: .superpowers/sdd/<plan-basename>/task-3-report.md — write your full report here.
Reply DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED.
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Pasted task text inline instead of using task-brief | Dispatch with `scripts/task-brief` path |
| Skipped review or dispatched without diff file | Generate `scripts/review-package`, re-dispatch reviewer |
| Progress lost after compaction | Check ledger at `scripts/sdd-workspace PLAN_FILE`'s `progress.md` and `git log` |
| Ledger says task complete but `git log` shows no commits | Implementer may have reported DONE without committing — re-dispatch that task |
| Artifacts written to `.git/sdd/` | Use `scripts/sdd-workspace PLAN_FILE` — it writes to `.superpowers/sdd/<plan-basename>/` |
| Parallel implementers caused merge conflicts | Never dispatch parallel implementers — sequential only |
| Fix loop still open after round 5 | Circuit breaker tripped — stop dispatching, adjudicate each finding yourself, escalate load-bearing ones to your human partner |
| Fresh implementer dispatched in fix rounds 1-3 | Resume the original implementer instead — it already has task context |
| Follow-up plan reading a prior plan's ledger | Can happen — two plan files with the same basename share a slug directory. The ledger-identity check (Durable Progress) is the actual guard: if the ledger's first line names a different plan file, it isn't yours — leave it and start fresh |
