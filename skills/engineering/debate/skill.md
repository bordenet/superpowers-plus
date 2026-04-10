---
name: debate
source: superpowers-plus
aliases: [thunderdome, design-triad]
triggers:
  - debate the options
  - compare approaches
  - comparison matrix
  - evaluate alternatives
  - red team the decision
  - harsh decision review
  - generate options and compare
  - design decision needed
  - choosing implementation approach
  - decision options with adversarial review
  - structured decision making
anti_triggers:
  - implement this design
  - code review
  - already decided on the approach
  - continue implementing
  - just writing tests
description: "Use when selecting an approach for a feature, decision, or significant change. Enforces generation of 3+ distinct options, structured comparison, harsh review, and edge-case brainstorming before committing. Self-assessment trigger: invoke before committing to any architecture or significant decision (see When to Use in skill body). NOT for brainstorming (idea exploration) or writing plans (execution)."
summary: "Use when: choosing between approaches, OR about to commit to an architecture/decision (self-fire). Skip when: decision already made and implementation has started."
coordination:
  group: thinking
  order: 1
  requires: []
  enables: []
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [challenge, goal]
  produces: [decision-options, decision-record]
  capabilities: [evaluates-options, generates-options]
  priority: 5
---

# Debate

> **Wrong skill?** Brainstorming many ideas → `brainstorming`. Requirements validation → `requirements-validation`. Feature workflow → `feature-development`.
>
> **Core principle:** Never commit to a decision without considering at least three alternatives and surviving a harsh review.

**Announce at start:** "I'm using the **debate** skill to evaluate decision options."

## Companion Skills

- **brainstorming**: Generating design options before evaluation
- **requirements-validation**: Validating requirements before design
- **plan-and-execute**: Implementing the chosen design
- **innovation**: 10x ideas before evaluation
- **feature-development**: Full feature workflow (uses this skill)
- **fallback-planning**: Evaluating fallback alternatives
- **quantitative-decision-gate**: Quantitative option scoring

## When to Use

**Intent-based (self-fire — first gate in the quality chain):**
- **About to commit to an approach before any code is written** — even without explicit user request
- Any time you are about to choose between architectural patterns, data models, or integration approaches
- Even if there is only a 1% chance the decision is non-trivial, run this first

**Explicit request:**
- User asks to compare approaches or generate options

**NOT for:**
- Initial idea exploration before a design exists → `brainstorming`
- Execution planning after design is decided → `plan-and-execute`
- Bug fixing → `systematic-debugging`

## Preflight

⛔ **HARD GATE: Do not stall here.** Choose your route within 30 seconds, then proceed to Step 1. Pick ONE:

1. **Requirements and architecture are known** — state the key requirement and the architectural constraint in one sentence each, then proceed to Step 1.
2. **Requirements or architecture need investigation** — pause debate, investigate separately (ask clarifying questions, review docs, check constraints), summarize findings in one sentence each, then proceed to Step 1. If investigation reveals inputs are fundamentally unclear or contradictory, escalate to the user — do not proceed with unresolved inputs on high-stakes decisions. Do NOT invoke other design/architecture skills from within this preflight — that creates recursive loops.
3. **This is a low-stakes, reversible decision** (no architecture change, no external interface change, no irreversible cost) — state: "Low-stakes decision, proceeding without formal validation." Then proceed to Step 1.

Stalling at preflight (loading skills without executing them, deliberating about whether to validate, or cycling back to re-decide) is **the single most common failure mode** of this skill. If you've spent more than 30 seconds choosing your route, you are stalling. Pick an option and move to Step 1.

## The Process (5 Steps)

| Step | Type | What Happens | Gate |
|------|------|-------------|------|
| 1. GENERATE | Diverge | Produce ≥3 genuinely distinct design options | ≥3 options, each implementable |
| 2. COMPARE | Analyze | Structured comparison matrix across 5 criteria | Matrix complete, recommendation stated |
| 3. HARSH REVIEW | Converge | Red-team via **separated reviewer** (sub-agent or explicit role switch) | All weaknesses documented by non-author |
| 4. EDGE CASES | Diverge | Final brainstorm targeting gaps found in Step 3 | Edge cases cataloged |
| 5. ITERATE | Loop | Fix → verify fixes landed → re-review (min 2 rounds) | Converged or escalated |

## Step 1: Generate Options

Produce **minimum THREE** options. Each must be:

- **Genuinely different** — not superficial variations (different data model, different decomposition, different integration pattern)
- **Implementable** — within current constraints, not fantasy
- **Compact** — max 3 bullet points per option: approach, key trade-off, risk profile

⛔ **HARD GATE:** If you can only think of one approach, invoke `think-twice` for a fresh perspective before proceeding. Two straw men and one real option is a violation.

## Step 2: Compare

Build a comparison matrix. **Constraint: max 5 words per cell.**

| Criterion | Option A | Option B | Option C |
|-----------|----------|----------|----------|
| Complexity | | | |
| Testability | | | |
| Maintainability | | | |
| Risk | | | |
| Fit with existing patterns | | | |

State your recommendation with explicit rationale (2-3 sentences). If only one option is viable, the matrix documents WHY the others don't work — that documentation has value.

⛔ **HARD GATE: Recommendation ≠ Completion.** Stating a recommendation here is Step 2 of 5. You MUST proceed to Step 3 (Harsh Review), Step 4 (Edge Cases), and Step 5 (Iterate) before claiming the design decision is made. Stopping at a recommendation without adversarial review is a violation — it is the single most common failure mode of this skill.

## Step 3: Harsh Review (Red Team)

⛔ **HARD GATE: Author ≠ Reviewer.** You MUST NOT red-team your own design in the same thinking pass that produced it. Use ONE of:

- **Sub-agent** (preferred): Dispatch a sub-agent with role "hostile reviewer" and full context of the design
- **Explicit role switch**: Complete the design, then start a new section with: *"I am now reviewing this as a hostile critic. My job is to find what's WRONG."*

Self-review in the same pass that wrote the design is **a violation** — it produces theater, not adversarial pressure.

For the selected design, the reviewer answers ALL of these (**max 1 sentence per answer**):

1. What's the weakest assumption?
2. What failure mode hasn't been considered?
3. What would a hostile code reviewer attack?
4. What edge case would break this in production?
5. What happens if the adjacent system changes?
6. **Cross-reference check:** Do the design's concrete details (file paths, integration points, claimed behaviors) actually work within the project's real directory structure, existing conventions, and stated constraints?

**REQUIRED:** Invoke `adversarial-search` principles — search for the WRONG thing, not confirmation of the RIGHT thing.

## Step 4: Edge Cases

One more divergent brainstorm targeting ONLY the gaps surfaced in Step 3. **Cap: 10 edge cases max.** Not a full re-design — focused on:

- Failure modes that need handling
- Boundary conditions that need tests
- Integration points that need defensive code

## Step 5: Iterate

`harsh-review → fix → verify → re-review` loop:

⛔ **HARD GATE: Minimum 2 full review rounds.** Round 1 = the initial harsh review (Step 3). Round 2 = re-review after fixes. You may NOT declare convergence without completing Round 2. Declaring "converged" after only Step 3 is a violation.

Each round has THREE phases:

1. **Fix:** Address issues found in the previous review
2. **Verify fixes landed:** Cross-reference each resolution against the actual artifact (spec, code, design doc). Confirm the fix appears in the output, not just in a resolution table. Claimed-but-not-implemented fixes are the #1 failure mode.
3. **Re-review:** Run harsh review again (Step 3 questions) on the UPDATED artifact

- **Exit when:** Round 2+ finds no new material issues
- **Escalate when:** 3 rounds completed without convergence — summarize blockers, escalate to human
- **Do NOT:** Continue beyond 3 rounds — diminishing returns
- **Delta-only:** Each round documents ONLY what changed since the previous round, not the full design

## Output

Design document with:

1. Selected approach (with rationale)
2. Rejected alternatives (with WHY they were rejected)
3. Edge-case catalog from Step 4
4. Harsh review findings and resolutions

## Example: Comparison Matrix Output

```markdown
| Criterion | A: Event-driven | B: Polling | C: Hybrid |
|-----------|----------------|------------|-----------|
| Complexity | Medium, new infra | Low, cron job | High, both paths |
| Testability | Hard, async | Easy, sync | Medium |
| Maintainability | Good, decoupled | Good, simple | Poor, two systems |
| Risk | Message loss | Stale data | Complexity debt |
| Fit with patterns | Matches existing | New pattern | Mixed |
```

## Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "There's only one way to do this" | You haven't thought hard enough. Invoke `think-twice`. |
| "The other options are obviously wrong" | Document WHY in the matrix. That's the point. |
| "This is too simple for 3 options" | Simple designs have unexamined assumptions. |
| "Harsh review found nothing" | You didn't look hard enough. Answer all 6 questions. |
| "We don't have time for alternatives" | Rework from a bad design costs more than 15 minutes of comparison. |
| "Converged after Step 3" | That's Round 1. You need Round 2 minimum. Fix, verify, re-review. |
| "I produced a recommendation" | That's Step 2 of 5. Steps 3-5 are mandatory. Recommendations without harsh review are theater. |
| "I reviewed my own design and it's solid" | Author ≠ Reviewer. Use a sub-agent or explicit role switch. |
| "I documented the resolution" | Did you verify it actually landed in the artifact? Check. |
