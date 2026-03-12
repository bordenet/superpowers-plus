---
name: engineering-rigor
source: superpowers-plus
triggers: ["engineering rigor", "implement this feature", "add a new field", "before creating PR", "before marking done"]
description: Hub skill for engineering rigor. Points to pre-commit-gate, blast-radius-check, and providing-code-review.
---

# Engineering Rigor

> **Source:** `superpowers-plus`

This is the **hub skill** for engineering rigor. For operational guidance, use the specific skill that matches your current task:

## Operational Skills (Use These)

| Skill | When to Use | Trigger |
|-------|-------------|---------|
| `pre-commit-gate` | Before committing code | "before commit", "git commit" |
| `blast-radius-check` | Before modifying existing code | "refactor", "modify existing", "fix bug" |
| `providing-code-review` | When reviewing others' PRs | "review this PR", "code review" |

**These skills fire automatically on their triggers.** You don't need to remember to load them.

---

## The Iron Law

```
BEFORE IMPLEMENTING: Trace the FULL data flow across ALL boundaries
DURING IMPLEMENTING: Verify data flows INTO and OUT OF each component
AFTER IMPLEMENTING: Cross-repo grep for EVERY new field/function name
```

## The Problem This Skill Family Solves

**Failure Patterns:**
1. Mechanical plan execution without verifying assumptions or tracing data flow
2. Rubber-stamp code reviews that don't apply the same rigor as your own work
3. Pushing code without running local checks, then debugging CI failures

**Example:** Implementing a new field but missing a router component that constructs an intermediate object. The field never reaches its destination because the data flow wasn't traced end-to-end.

**Root Cause:** "Blinders on" implementation — trusting the plan without tracing the actual data flow.

## Quick Reference: Which Skill?

```
Am I about to commit?           → pre-commit-gate
Am I modifying existing code?   → blast-radius-check
Am I reviewing someone's PR?    → providing-code-review
General philosophy refresh?     → You're here (engineering-rigor)
```

## Related Skills

- `field-rename-verification` — Specific focus on field renames
- `verification-before-completion` — General completion checklist
