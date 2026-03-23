---
name: verification-before-completion
source: superpowers-plus
overrides: superpowers/verification-before-completion
# Override rationale: Adds auto-fire triggers table (explicit list of phrases that
# MUST trigger this skill), adds PR creation verification pattern, adds incident
# history tracking, and refines rationalization prevention. obra's version lacks
# the "Shipped! before PR exists" anti-pattern and trigger-phrase gate.
triggers: ["work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "ready for review", "claiming completion", "expressing satisfaction"]
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs. CRITICAL - this skill must fire BEFORE saying "Shipped!", "Done!", "Complete!", or any success expression. Evidence before assertions always; for multi-step or TODO-backed sessions, run TODO maintenance before the claim.
summary: "Use when: about to claim work is done. Skip when: still actively working."
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
5. HOUSEKEEPING: If the work spanned multiple steps or used TODO.md, run:
   `~/.codex/superpowers-plus/tools/todo-maintenance.sh`
   Read the summary and resolve any stale-plan/archive surprises before proceeding.
6. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

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

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
