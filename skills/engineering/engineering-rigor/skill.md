---
name: engineering-rigor
source: superpowers-plus
triggers: ["engineering rigor", "implement this feature", "add a new field", "before marking done", "which verification skill", "what gate should I use", "which quality check"]
description: Hub skill for engineering rigor. Points to pre-commit-gate, blast-radius-check, output-verification, code-review-battery, and providing-code-review.
summary: "Use when: need hub for pre-commit, blast-radius, output-verification, code review battery, or code review skills."
coordination:
  group: engineering
  order: 0
  requires: []
  enables: ["pre-commit-gate", "blast-radius-check", "output-verification", "field-rename-verification"]
  escalates_to: []
  internal: false
---

# Engineering Rigor

> **Source:** `superpowers-plus`

> **Wrong skill?** This is a hub/dispatcher. Use the dispatch table below to find the right sub-skill.

This is the **hub skill** for engineering rigor. For operational guidance, use the specific skill that matches your current task:

## Operational Skills (Use These)

| Skill | When to Use | Trigger |
|-------|-------------|---------|
| `output-verification` | Before describing/approving generated output | "verify output", "check pdf", "ready to share" |
| `pre-commit-gate` | Before committing code | "before commit", "git commit" |
| `blast-radius-check` | Before modifying existing code | "refactor", "modify existing", "fix bug" |
| `code-review-battery` | When deep parallel review needed | "battery review", "parallel review", "run the battery" |
| `providing-code-review` | When reviewing others' PRs | "review this PR", "code review" |
| `receiving-code-review` | When handling PR feedback | "received code review", "PR feedback" |

**TypeScript/testing skills (in overlay repo — install via `spc:` prefix):**

| Skill | When to Use | Trigger |
|-------|-------------|---------|
| `typescript-project-conventions` | Import order, file splits | "import order wrong", "file too long" |
| `typescript-strict-mode` | Strict TS errors | "noExplicitAny error", "strictNullChecks" |
| `cognitive-complexity-refactoring` | Complex functions | "cognitive complexity too high", "too many nested ifs" |
| `vitest-testing-patterns` | Mock/test issues | "vi.mock not working", "test is flaky" |

**All skills fire automatically on their triggers.** You don't need to remember to load them.

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

## Dispatch Table

```
Am I describing generated output? → output-verification
Am I about to commit?            → pre-commit-gate
Am I modifying existing code?    → blast-radius-check
Am I reviewing someone's PR?     → providing-code-review
Do I need deep parallel review?  → code-review-battery
General philosophy refresh?      → You're here (engineering-rigor)
```

## Architecture Testing (Pre-Implementation Gate)

Before writing feature code, validate the architectural approach:

| Question | Red Flag |
|----------|----------|
| Does it scale to 10x current load/complexity? | "It works for now" |
| Can a new engineer understand the boundaries? | Requires tribal knowledge to navigate |
| Follows existing patterns or introduces new? | New pattern without documented justification |
| What breaks if the adjacent system changes? | Tight coupling without interface boundaries |

If any question surfaces a red flag, address it BEFORE implementation. Use `design-triad` for structured design evaluation.

## Companion Skills

- `output-verification` — Hard gate: no claims about output without inspection
- `code-review-battery` — Parallel specialized review with 5 focused agents
- `design-triad` — Structured design evaluation with 3+ options
- `requirements-validation` — Validate requirements before design
- `field-rename-verification` — Specific focus on field renames
- `verification-before-completion` — General completion checklist

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Handling request inline instead of dispatching | This is a router. Dispatch to the right sub-skill, don't DIY. |
| Wrong skill selected from dispatch table | Check skill descriptions. When in doubt, load both and compare. |
| Skipping output-verification before claiming done | output-verification fires BEFORE verification-before-completion |
