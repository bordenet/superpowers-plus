---
name: verification-before-completion
source: superpowers-plus
triggers: ["work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "ready for review", "claiming completion", "expressing satisfaction"]
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs. CRITICAL - this skill must fire BEFORE saying "Shipped!", "Done!", "Complete!", or any success expression. Evidence before assertions always.
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

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
5. ONLY THEN: Make the claim

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
