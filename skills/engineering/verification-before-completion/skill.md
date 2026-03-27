---
name: verification-before-completion
source: superpowers-plus
overrides: superpowers/verification-before-completion
# Override rationale: Adds auto-fire triggers table (explicit list of phrases that
# MUST trigger this skill), adds PR creation verification pattern, adds incident
# history tracking, and refines rationalization prevention. obra's version lacks
# the "Shipped! before PR exists" anti-pattern and trigger-phrase gate.
triggers: ["work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "claiming completion", "expressing satisfaction"]
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

## When to Use

- Before saying "Done!", "Shipped!", "Fixed!", "Passing!", or any completion claim
- Before creating or merging a PR
- Before closing a ticket or marking a task complete
- After fixing a bug — verify the fix AND verify no regressions
- At session end for any multi-step or TODO-backed work, before the final completion claim

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## Completion-Gate Coordination

**BEFORE running this skill's gate function, check:**

| Task Type | Action |
|-----------|--------|
| Bulk edit, audit, or refactoring | Invoke `exhaustive-audit-validation` FIRST, then return here |
| Single fix, feature, or bug fix | Continue directly with this skill |

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## ⚠️ AUTO-FIRE TRIGGERS

**This skill MUST fire BEFORE you say any of these:**

| Trigger Phrase | Required Action |
|----------------|-----------------|
| "Shipped!" / "🚀" | Verify PR/commit exists first |
| "Done!" / "Complete!" | Verify task requirements met first |
| "Fixed!" / "Working!" | Verify test/build passes first |
| "Ready for review" | Verify CI passes first |
| "All tests pass" | Show test output first |
| "Build succeeds" | Show build output first |
| ANY satisfaction expression | Run verification command first |

**The satisfaction expression comes AFTER the evidence, never before.**

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. CODE REVIEW GATE: If you made code changes, dispatch sub-agent-code-reviewer
   BEFORE claiming "Done" or "Fixed". Self-review is not review.
   See "Code Review Gate" section below.
6. HOUSEKEEPING: If the work spanned multiple steps or used TODO.md, run:
   `~/.codex/superpowers-plus/tools/todo-maintenance.sh`
   Read the summary and resolve any stale-plan/archive surprises before proceeding.
7. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Code Review Gate

**If you made code changes, you MUST get independent code review before claiming completion.**

Self-review is not review. The implementer cannot objectively evaluate their own work —
the same blind spots that caused the bug will cause the review to miss the same class of issues.

| Condition | Action |
|-----------|--------|
| Made code changes (any `.ts`, `.js`, `.py`, etc.) | Get independent review (see methods below) |
| Documentation-only changes | Skip code review (still verify links/content) |
| Config-only changes (env, yaml) | Skip code review unless security-relevant |
| Reviewer found issues | Fix issues, re-review |
| Reviewer approved | Proceed to completion claim |

### How to Get Review

Use the first method available to you, in priority order:

1. **Sub-agent** (if your tool supports it): Dispatch `sub-agent-code-reviewer` with the diff, file list, and specific review questions. Load `superpowers:requesting-code-review` for the dispatch template.
2. **File protocol** (works with any AI agent): Load the `code-review` skill and use Mode 1 (Generate Request) to write a structured request to `~/.codex/superpowers-review/active/{scope}/request.md`. Tell the user to hand off to a separate agent session for review.
3. **Human reviewer**: If no agent-based review is available, tell the user: "This needs code review before I can call it done. Please review or assign a reviewer."

**The reviewer should load `providing-code-review` for the review checklist.** Do not assume they will do this automatically — include the instruction in your review request.

### Incident History

| Date | Violation | Impact |
|------|-----------|--------|
| 2026-03-23 | Implemented bug fix, self-reviewed, claimed "Done" without dispatching code reviewer | Reviewer later found state leak across resets — a real bug shipped without review |

### Why This Gate Exists

The 2026-03-23 incident proved the gap: the implementer ran tests (1,636 passed), self-reviewed the code,
and claimed completion. A code reviewer dispatched after-the-fact immediately found a state leak the
implementer missed. The same cognitive blind spot that allowed the bug to be written prevented it from
being caught in self-review.

**This is not optional.** Tests verify behavior you thought of. Code review catches behavior you didn't think of.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| PR created | API response showing PR exists | `git push` succeeded |
| Shipped | PR merged confirmation | PR created |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", "🚀", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- **Saying "Shipped!" after git push but before verifying PR was created**
- Finishing a multi-step session without running TODO maintenance

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Push succeeded" | Push ≠ PR created |
| "Agent said success" | Verify independently |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**PR Creation:**
```
✅ [Create PR] [API returns: state=open, number=17] "PR #17 created"
❌ "Shipped!" after git push (PR creation is separate step)
```

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

## Incident History

| Date | Violation | Impact |
|------|-----------|--------|
| 2026-03-13 | Said "Shipped! 🚀" after git push before verifying PR created | Trust erosion, required post-hoc verification |
| 2026-03-23 | Claimed "Fixed" without dispatching code reviewer | State leak caught only after user forced review |

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
