# Debate reference

## Preflight routing

Do not stall here. Check `docs/superpowers/specs/` for an existing spec instead of reconstructing compacted reasoning.

⛔ **HARD GATE: Do not stall here.** Choose the route within 30 seconds, then proceed to Step 1.

- Skip brainstorming only when the decision is both low-stakes and reversible. Otherwise, if no spec exists, run `brainstorming` once.
- If brainstorming produces at least three approaches, its nested debate supplies the decision record; do not run a duplicate outer debate.
- If brainstorming produces its normal two approaches, treat the human-reviewed spec as the input and continue here.

Then choose one route:

1. Requirements and architecture are known: state the key requirement and architectural constraint in one sentence each.
2. Either needs investigation: pause, inspect the relevant evidence, summarize each finding in one sentence, and return. Do not invoke design skills recursively during this investigation. Escalate contradictory or unresolved high-stakes inputs to `thinking-orchestrator`.
3. The decision is low-stakes and reversible: state that fact and proceed without formal validation.

### Step 2: Generate options

Produce at least three genuinely distinct, implementable options with no more than three bullets each: approach, key trade-off, and risk profile.

⛔ **HARD GATE:** If only one approach emerges, invoke `think-twice`; do not pad the set with straw men.

## Comparison protocol

### Step 3: Compare

Give each option no more than three bullets: approach, key trade-off, and risk profile. Compare Complexity, Testability, Maintainability, Risk, Fit with existing patterns, and Reversibility. Keep matrix cells to five words or fewer.

If one option is the only viable choice, the matrix must still explain why the other competent proposals lose. Recommendation is Step 3 of 6, not permission to skip adversarial review.

⛔ **HARD GATE: Recommendation is not completion.** Continue through hostile review, edge cases, and iteration.

## Hostile review protocol

### Step 4: Harsh review

⛔ **HARD GATE: Author and reviewer must differ.**

Dispatch a fresh sub-agent when available (Claude Code: `Task()`/Agent tool with a hostile-reviewer prompt carrying the full design context; other platforms: see `using-superpowers`'s Platform Adaptation section for the equivalent dispatch mechanism); otherwise make an explicit role switch after finishing the design ("You are now the hostile reviewer. Discard the author's reasoning; start fresh from the artifact text alone."). For the reviewer's lens, reuse the relevant `progressive-harsh-review` persona name (`JuniorDevNitpicker`, `SeniorArchCritic`, or `OpsRealist`) rather than redefining personas here. This is a persona reference only: do not invoke that skill from debate.

The reviewer answers each question in one sentence:

1. What is the weakest assumption?
2. Which failure mode is missing?
3. What would a hostile code reviewer attack?
4. Which production edge case breaks this?
5. What happens when an adjacent system changes?
6. Do the paths, integration points, conventions, and constraints match the actual project?
7. Is every rejected option one a competent engineer would propose? If not, replace it once and rerun comparison; the next review becomes round one.
8. Was status quo, deferment, or a time-boxed spike priced as the comparison anchor?

**REQUIRED:** Invoke `adversarial-search` principles -- search for the WRONG thing, not confirmation of the RIGHT thing. An option that loses on merit stays documented; do not regenerate it merely because it lost.

### Step 5: Probe edge cases

List at most ten failure modes, boundaries, tests, or defensive integration points surfaced by hostile review.

### Step 6: Iterate

⛔ **HARD GATE: Complete at least two full review rounds.** Run review, fix, verify the fix in the artifact, and re-review by continuing the same reviewer on the delta (a fresh reviewer needs the complete prior findings, not a summary); stop after three rounds and escalate to `thinking-orchestrator` if the design has not converged.

## Output and example

The decision record contains six short parts: Decision, Options considered, Rejected and why, Edge-case catalog, Review findings and resolutions, and Open risks.

Example matrix:

| Criterion | Event-driven | Polling | Hybrid |
|---|---|---|---|
| Complexity | Medium, new infra | Low, cron job | High, two paths |
| Testability | Hard, asynchronous | Easy, synchronous | Medium |
| Maintainability | Good, decoupled | Good, simple | Poor, dual paths |
| Risk | Message loss | Stale data | Complexity debt |
| Existing-pattern fit | Matches existing | New pattern | Mixed |
| Reversibility | Hard, persisted | Easy, stateless | Hard, mixed |

## Companion skills

- `brainstorming`: generate ideas before evaluation.
- `requirements-validation`: validate unclear requirements.
- `think-twice`: produce a missing alternative.
- `plan-and-execute`: implement the chosen design.
- `innovation`: seek a larger option set before evaluation.
- `fallback-planning`: compare fallback paths.
