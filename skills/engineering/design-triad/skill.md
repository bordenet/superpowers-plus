---
name: design-triad
source: superpowers-plus
triggers: ["three design options", "compare design approaches", "design comparison matrix", "evaluate design alternatives", "red team the design", "harsh design review", "generate design options", "design triad"]
description: Use when selecting a design approach for a feature or significant change. Enforces generation of 3+ distinct options, structured comparison, harsh review (red teaming), and edge-case brainstorming before committing to a design. NOT for brainstorming (idea exploration) or writing plans (execution).
---

# Design Triad

> **Core principle:** Never commit to a design without considering at least three alternatives and surviving a harsh review.

**Announce at start:** "I'm using the **design-triad** skill to evaluate design options."

**NOT for:** Initial idea exploration (`brainstorming`), execution planning (`writing-plans`), bug fixing (`systematic-debugging`).
**IS for:** Any decision where the wrong design choice would cost significant rework.

## Preflight

Before generating design options, confirm:
1. **Requirements validated** — use `requirements-validation` to test for falsifiability, measurability, and contradictions.
2. **Architecture assessed** — use `engineering-rigor` (Architecture Testing section) to validate scalability, maintainability, and pattern fit.

If neither has been done, complete them first or explicitly acknowledge the risk of designing without validated inputs.

## The Process (5 Steps)

| Step | Type | What Happens | Gate |
|------|------|-------------|------|
| 1. GENERATE | Diverge | Produce ≥3 genuinely distinct design options | ≥3 options, each implementable |
| 2. COMPARE | Analyze | Structured comparison matrix across 5 criteria | Matrix complete, recommendation stated |
| 3. HARSH REVIEW | Converge | Red-team the selected design — invoke `adversarial-search` mindset | All weaknesses documented |
| 4. EDGE CASES | Diverge | Final brainstorm targeting gaps found in Step 3 | Edge cases cataloged |
| 5. ITERATE | Loop | Fix issues → re-review until no new material issues OR 3 iterations (then escalate) | Converged or escalated |

## Step 1: Generate Options

Produce **minimum THREE** options. Each must be:
- **Genuinely different** — not superficial variations (different data model, different decomposition, different integration pattern)
- **Implementable** — within current constraints, not fantasy
- **Summarized** — approach, key trade-off, risk profile (3-5 sentences each)

⛔ **HARD GATE:** If you can only think of one approach, invoke `think-twice` for a fresh perspective before proceeding. Two straw men and one real option is a violation.

## Step 2: Compare

Build a comparison matrix:

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Complexity | | | |
| Testability | | | |
| Maintainability | | | |
| Risk | | | |
| Fit with existing patterns | | | |

State your recommendation with explicit rationale. If only one option is viable, the matrix documents WHY the others don't work — that documentation has value.

## Step 3: Harsh Review (Red Team)

For the selected design, answer ALL of these:
1. What's the weakest assumption?
2. What failure mode hasn't been considered?
3. What would a hostile code reviewer attack?
4. What edge case would break this in production?
5. What happens if the adjacent system changes?

**REQUIRED:** Invoke `adversarial-search` principles — search for the WRONG thing, not confirmation of the RIGHT thing.

## Step 4: Edge Cases

One more divergent brainstorm targeting ONLY the gaps surfaced in Step 3. Not a full re-design — focused on:
- Failure modes that need handling
- Boundary conditions that need tests
- Integration points that need defensive code

## Step 5: Iterate

`harsh-review → fix → harsh-review` loop:
- **Exit when:** No new material issues found in a review round
- **Escalate when:** 3 iterations completed without convergence — summarize blockers, escalate to human
- **Do NOT:** Continue beyond 3 iterations — diminishing returns

## Output

Design document with:
1. Selected approach (with rationale)
2. Rejected alternatives (with WHY they were rejected)
3. Edge-case catalog from Step 4
4. Harsh review findings and resolutions

## Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "There's only one way to do this" | You haven't thought hard enough. Invoke `think-twice`. |
| "The other options are obviously wrong" | Document WHY in the matrix. That's the point. |
| "This is too simple for 3 options" | Simple designs have unexamined assumptions. |
| "Harsh review found nothing" | You didn't look hard enough. Answer all 5 questions. |
| "We don't have time for alternatives" | Rework from a bad design costs more than 15 minutes of comparison. |
