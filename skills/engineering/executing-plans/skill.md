---
name: executing-plans
disable-model-invocation: true
source: superpowers-plus
# 2026-10: obra/superpowers 7.0.1 parity (native execution: shared SDD
# workspace + ledger, rulings, completion contract, one final review),
# condensed. Scripts task-start/task-done are obra's plus a not-a-repo
# guard, %q command rendering, and no duplicate ledger lines.
triggers: ["execute this plan", "implement the plan", "execute plan file", "carry out this plan", "run the plan"]
anti_triggers: ["write a plan", "create a plan", "plan this out"]
description: Use when executing an approved written plan natively in the current session with required verification and review
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

Execute the plan yourself, task by task, in this session: no per-task
implementer or reviewer subagent, one fresh-context review of the whole
branch at the end. The brief is the spec, the ledger is your memory, TDD is
the per-task gate, the final reviewer is the second pair of eyes.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## When to Use

- A written plan exists (`writing-plans`), the user reviewed that saved plan
  and authorized execution, and chose native execution — or no subagent tool
  exists (never fabricate a dispatch). Approval of an unseen scope is not
  approval of an unseen plan.
- Prefer `subagent-driven-development` when the user wants a review gate per
  task, or the plan is long enough that late tasks would run on a compacted
  context. Native runs well on a mid-tier session model; tell the user so.

## Operating Rules

- **Continuous:** do not pause to check in between tasks. Narrate at most one
  short line between tool calls; bookkeeping rides in the same call as work.
- **Rulings, not stalls:** decide conflicts, ambiguities, and plan defects.
  The spec is the binding authority, the plan its argument. Ledger each as
  `Task <N>: Ruling: <what you decided> — <why> — <cost if wrong>`. A
  deviation without a ledgered ruling is a decision made in secret.
- **Only four things stop you:** an irreversible or destructive operation; a
  security-sensitive action; a side effect outside this worktree that norms
  say to ask about (merge, push to a shared branch, publish); a plan so
  broken every path is a guess.
- **Context hygiene:** redirect long output to a workspace file and read its
  tail; read a task's brief, not the whole plan.
- **Before any `git commit`:** run `unified-commit-gate` (all applicable
  gates), even mid-plan.

## Setup

Run every command from the target repo's root. Script paths below
(`scripts/…`, `../subagent-driven-development/…`) are relative to this
skill's installed directory — `~/.claude/skills/executing-plans` or
`~/.codex/skills/executing-plans` — so prefix them with it.

1. Isolated workspace via `using-git-worktrees`; never implement on
   main/master without explicit consent.
2. Workspace and ledger are shared with `subagent-driven-development` so
   executors can swap mid-plan: run
   `bash ../subagent-driven-development/scripts/sdd-workspace PLAN_FILE`
   (prints `<repo>/.superpowers/sdd/<plan-basename>/`). Another plan's
   directory is never yours.
3. Ledger `<workspace>/progress.md`, first line
   `# SDD ledger — plan: <plan file path>`. If it names your plan, every
   `Task <N>: complete` line is DONE — resume at the first task without one;
   after compaction trust the ledger and `git log` over recollection. A
   ledger naming another plan: leave it, start your own. `git clean -fdx`
   destroys it; recover from `git log`.
4. Read the plan once (Global Constraints) and its Spec if named; no
   reachable spec → ledger note, rulings provisional. One todo per task.
5. Load `test-driven-development` now; it governs every step.
6. **Pre-flight scan:** for each task consuming what an earlier task produces
   (Interfaces blocks), one ledger row: both tasks, produced vs consumed,
   finding, ruling. Nothing shared → `Pre-flight: no shared interfaces`.

## The Task Loop

1. **Take:** `bash scripts/task-start PLAN_FILE N` prints the brief path and
   BASE. Read the brief every time — memory is a summary, the brief has the
   exact values. Mark the todo in_progress.
2. **Work the steps** in their RED-GREEN order. Watching the test fail is a
   step; a test that passes before the implementation exists is a finding
   about the test. Compare every `Expected:` line to real output:
   matches → next; code wrong → `systematic-debugging`, never patch the
   symptom; plan wrong → smallest spec-satisfying change, ledgered ruling.
   Commit as the plan says; BASE, never `HEAD~1`, cuts the review range.
3. **Completion contract** (`verification-before-completion` governs the
   claim), with evidence from this session: every named test exists and ran;
   the final run passed; every `Expected:` was compared; every deviation has a
   `Ruling:` line. Anything missing → the task is not complete.
4. **Complete:** `bash scripts/task-done PLAN_FILE N BASE -- <test command>`
   runs the brief's whole-task tests and, only on success, appends
   `Task <N>: complete (commits <base>..<head>, tests: <cmd> → <result>)`.
   A failing run records nothing. Mark the todo complete; next task.

## Final Review

1. `bash ../subagent-driven-development/scripts/review-package PLAN_FILE
   MERGE_BASE HEAD` (MERGE_BASE = `git merge-base <base-branch> HEAD`).
2. **With a subagent tool:** dispatch one reviewer on the most capable model
   (set the model explicitly) with `requesting-code-review`'s
   `code-reviewer.md`, the package, plan and spec paths, the plan's Review
   Focus verbatim, and a pointer to the ledger's `Ruling:` lines. Never
   replace it with your own read of the diff. **Without one:** perform that
   review yourself as a separate pass, ledger
   `Final review: self-review (no subagent tool)`, and say so — the user
   decides whether that suffices before merge.
3. **Re-grade by effect** (what a reasonable user gets if it ships), not by
   whether the spec named the input. Each "Declined to judge" item becomes a
   ledgered `Final: Ruling:`.
4. **Critical/Important → ONE fix pass**, each fix: reproducing test RED →
   GREEN, then the whole suite green; ledger
   `Final: fixed <finding> — <test> RED→GREEN, suite <N>/<N>`. No re-review
   dispatch. Not fixing is a `Final: Ruling:`. **Minor →**
   `Final: minor (deferred): <one-liner>`, never fixed, never a ruling.

## Finish

Final message lists every `Ruling:` line under "Rulings I made" (in order,
with cost if wrong) and every deferred minor under "Deferred minors" —
exhaustive; it is the only place those decisions reach the user. When the
review is clean and fixes are committed, delete this plan's workspace
directory (siblings belong to other plans). Before pushing, run
`unified-commit-gate` (`/sp-push`) once per branch push; a valid
`.code-review-cleared` sentinel must exist for HEAD. Then follow
`finishing-a-development-branch`.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I remember what Task N says" | You remember a summary. Read the brief. |
| "The plan's code is right, skip watching the test fail" | A test you never saw fail proves nothing. |
| "I'll run the full suite at the end" | Per-step runs show which step broke it; the end-of-task run is the contract. |
| "The plan is wrong, I'll just do the right thing" | Do it and ledger the ruling. |
| "I'll write ledger lines after a few tasks" | Compaction doesn't wait. One line per task, same call as the commit. |
| "Let me check in before the next task" | Only the four stops stop you. |
| "I read my own diff; the final reviewer is redundant" | Same author, same blind spots. It is the only fresh context this run buys. |
| "The reviewer said Minor, so it's Minor" | The label graded the spec's silence. Re-grade by effect. |
| "The fix is obvious, no failing test needed" | The failing test is the only proof the finding was real and is gone. |
