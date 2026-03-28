---
name: verification-before-completion
source: superpowers-plus
overrides: superpowers/verification-before-completion
# Override rationale: Adds auto-fire triggers table (explicit list of phrases that
# MUST trigger this skill), adds PR creation verification pattern, adds incident
# history tracking, and refines rationalization prevention. obra's version lacks
# the "Shipped! before PR exists" anti-pattern and trigger-phrase gate.
triggers: ["work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "claiming completion", "expressing satisfaction"]
anti_triggers: ["not done yet", "almost done", "when done", "once done", "until done"]
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs. CRITICAL - this skill must fire BEFORE saying "Shipped!", "Done!", "Complete!", or any success expression. Evidence before assertions always. If code was changed, dispatch sub-agent-code-reviewer before claiming done (self-review is not review). For multi-step or TODO-backed sessions, run TODO maintenance before the claim.
summary: "Use when: about to claim work is done. Skip when: still actively working. Code changes require code reviewer dispatch."
coordination:
  group: completion-gate
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Verification Before Completion

> **Wrong skill?** Pre-commit checks → `pre-commit-gate`. Output inspection → `output-verification`. Code review → `progressive-code-review-gate`.

## Companion Skills

- **pre-commit-gate**: Pre-commit checks · **output-verification**: Output inspection · **holistic-repo-verification**: Repo health
- **completeness-check**: Quick scope · **exhaustive-audit-validation**: Deep audit · **adversarial-search**: Bias prevention
- **todo-guardian**: TODO enforcement · **measurement-integrity**: Metric validation
## When to Use

- Before saying "Done!", "Shipped!", "Fixed!", "Passing!", or any completion claim
- Before creating or merging a PR
- Before closing a ticket or marking a task complete
- After fixing a bug — verify the fix AND verify no regressions
- At session end for any multi-step or TODO-backed work, before the final completion claim

## Core Principle

Evidence before claims, always. Violating the letter = violating the spirit.

**Pre-checks:** Generated output → `output-verification` first. Bulk edit/audit → `exhaustive-audit-validation` first.

**Auto-fire:** MUST fire BEFORE "Shipped!", "Done!", "Fixed!", "Ready for review", "All tests pass", or ANY satisfaction expression. Evidence comes FIRST, expression AFTER.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. SHOW: Include the command output in your response (evidence requirement — see below)
5. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
6. CODE REVIEW GATE: If you made code changes, dispatch sub-agent-code-reviewer
   BEFORE claiming "Done" or "Fixed". Self-review is not review.
   See "Code Review Gate" section below.
7. HOUSEKEEPING: If the work spanned multiple steps or used TODO.md, run:
   `~/.codex/superpowers-plus/tools/todo-maintenance.sh`
   Read the summary and resolve any stale-plan/archive surprises before proceeding.
8. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## 🚨 Evidence Requirements (NON-NEGOTIABLE)

**No completion claim without visible tool output.** Saying "tests pass" without showing
the command output in your response is fabrication. Show the command invocation, exit code,
and summary line. For large output, show the decisive lines — but the tool call itself
MUST be visible.

| Claim | Required evidence (visible in response) | NOT evidence |
|-------|----------------------------------------|--------------|
| "Tests pass" | Test runner output: pass/fail counts + exit code 0 | "I ran the tests" |
| "Lint clean" | Linter output: 0 errors + exit code 0 | "No lint issues" |
| "Build succeeds" | Build output: exit code 0 | "Builds fine" |
| "PR created" | API response: PR number, state=open | "Pushed the branch" |
| "Code reviewed" | `sub-agent-code-reviewer` dispatch + findings | "I reviewed the code" |
| "Fixed!" | Test output showing the specific failure now passes | "Should work now" |

## Code Review Gate

Code changes → MUST get independent review. Self-review is not review.

Methods (priority order): 1) `sub-agent-code-reviewer` 2) File protocol via `code-review` skill 3) Human reviewer.

**Tests verify what you thought of. Code review catches what you didn't.**

## Red Flags

"Should/probably/seems to" · satisfaction before evidence · push without PR verification · trusting agent reports · skipping TODO maintenance at session end.

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Push succeeded" | Push ≠ PR created |

## Incident History

| Date | Violation | Impact |
|------|-----------|--------|
| 2026-03-13 | "Shipped! 🚀" after push, before PR verified | Trust erosion |
| 2026-03-23 | "Fixed" without code reviewer dispatch | State leak shipped |

## Example

```bash
npm test 2>&1 | tail -5  # Show actual results
echo "Exit code: $?"      # Prove success
# Evidence FIRST, then claim
```

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Done without evidence | Paste command output + exit code |
| Happy-path only | List edge cases: null, empty, auth, timeout |
| "Compiles" ≠ "works" | Show test output for changed behavior |
| Skipped output-verification | Run output-verification FIRST, then this |
