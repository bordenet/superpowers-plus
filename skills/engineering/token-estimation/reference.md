# Token Estimation — Extended Reference

> Companion to `skill.md`. Contains the detailed formulas, calibration tables, and confidence band rules. Linked from skill.md sections.

---

## Superpowers Quality Gate Overhead

When a task includes superpowers quality gates (PHR, cr-battery), add overhead **on top of** the calibration table estimate. These gates are themselves agentic workloads. Two additive mechanisms apply — apply both:

**Mechanism 1 — Category-up:** When any MR will go through the full quality gate workflow (PHR + cr-battery), **advance the implementation estimate one calibration category** as a baseline overhead. This covers a typical 1–2 PHR rounds + one cr-battery run.

Example: Small feature (50–300k implementation) + full quality gates → report as Medium (250–700k total) [med].

**Mechanism 2 — PHR iteration risk additive:** If the deliverable is novel or structurally complex (new skill, new policy document, new estimation system), add explicit overhead for the expected PHR cycle count on top of the category-up estimate:

| Gate | Overhead per invocation | Applies when |
|------|------------------------|--------------|
| **PHR (progressive-harsh-review)** | +150–500k per round | Any new or significantly revised skill/doc |
| **cr-battery (code-review-battery)** | +200–600k per invocation | Any MR going through full gate workflow |
| **Both gates on one MR** | +500k–1.5M total | Baseline; see PHR iteration risk below |

**PHR iteration risk:** for novel or structurally complex deliverables, budget for PHR round overhead using a **default prior** before flagging [low]:
- **New or significantly restructured skill/doc:** default prior = 3 rounds → add ~450k–1.5M overhead [med]
- **Minor revision to existing skill:** default prior = 1 round → add ~150–500k overhead [med]
- **Unknown iteration count:** add 750k–5M overhead [low]

Apply the default prior to produce a [med] estimate before falling back to the full [low] range.

The category-up and additive overhead are not double-counted — apply both: category-up handles the baseline gate cost, additive handles high-iteration risk.

**Output:** when quality gate overhead is material (>50% of the implementation estimate), report it separately:

```
**Implementation estimate:** ~X–Yk [confidence]
**Quality gate overhead:** ~A–Bk (M–N PHR rounds + 1 cr-battery) [low if iteration count unknown]
**Total estimate:** ~C–Dk [confidence]
```

---

## Overlap Zone Tiebreakers

> **⚠️ Before applying any bullet below, apply the two multi-way ordering rules first:**
>
> **Order rule A — 50k–100k zone (Investigation ∩ Surgical ∩ Small):** (1) Apply Investigation ∩ Surgical first. (2) If result = Surgical, then apply Surgical ∩ Small. (3) If result = Investigation, then apply Investigation ∩ Small — only the "new capability" and "scope undefined" branches apply.
>
> **Order rule B — 300k zone (Small ∩ Medium ∩ Multi-service):** (1) Apply Small ∩ Medium first. (2) If result = Medium, then apply Medium ∩ Multi-service. (3) If result = Small, Multi-service tiebreaker does not apply.

- **(30k–100k) Investigation ∩ Surgical:** apply Investigation if the primary deliverable is a finding or recommendation; apply Surgical if a code/config change is the primary deliverable. Two deliverables are **co-primary** when the task explicitly requests both (e.g., "investigate AND fix") — if investigation is merely a necessary step toward a single deliverable (the fix), treat the fix as primary. For co-primary tasks: (a) if the fix is Surgical-sized → apply Surgical [med] to reflect investigation overhead; (b) if the fix requires multiple files or tests → apply Small (50–300k) [med].
- **(50k–150k) Investigation ∩ Small:** apply Small if the finding drives a new capability; apply Investigation [med] if the investigation is bounded and the deliverable is a finding or report with no associated code change; apply Investigation [low] if the fix scope is undefined.
- **(50k–100k) Surgical ∩ Small:** apply Surgical if the change touches one file and has no test surface; apply Small if tests must be written or multiple files change.
- **(250k–300k) Small ∩ Medium:** apply Medium if tests are required or the feature has an API contract; apply Small with confidence [low] otherwise.
- **(300k–700k) Medium ∩ Multi-service:** apply Multi-service if the change crosses a service boundary; apply Medium with confidence [low] if it does not.
- **(1M–2M) Multi-service ∩ Architectural:** apply Architectural if the change introduces a new abstraction layer or requires a migration; apply Multi-service with confidence [low] if it does not.
- **(exactly 4M) Architectural ∩ Full System Redesign boundary:** apply Full System Redesign — the 4M+ formula convention takes precedence. **Lower bound = 4M** (the category boundary); the 4M+ formula sets only the upper bound.

**4M+ formula convention (Sonnet-class baseline):** treat the upper bound as **10M tokens** (a formula anchor, not a real ceiling) *(internal calibration — chosen to produce planning-useful upper bounds for multi-session FSR tasks; re-verify against current FSR task actuals before revising)*. width = 10M − 4M = 6M.
- **[med]:** upper = 10M + 1×6M = 16M → output `~4M–16M [med]`.
- **[low]:** upper = 10M + 5×6M = 40M → output `~4M–40M [low]`.

**4M+ non-Sonnet variant:** upper anchor = 15M. width = 11M.
- **[med]:** upper = 26M → output `~4M–26M [med]`.
- **[low]:** upper = 70M → output `~4M–70M [low]`.

Annotate all 4M+ outputs with: "(upper bound is a formula anchor, not a real ceiling.)" If the resulting range spans >2 table categories, also add: "Range too wide for planning utility — consider decomposing the scope into independently estimable sub-tasks."

---

## Confidence Bands

State confidence with every estimate. **Default to [med] for tasks with zero or one bounded unknown; escalate to [low] only when a trigger fires** (see below).

A **bounded unknown** has an identifiable resolution path. A **foundational unknown** has no clear resolution path without executing the task.

- **[high]** — all four conditions hold: (1) scope is isolated, (2) API surface or data sources known, (3) no unknowns identified, (4) agent has a clear execution path with low explore-loop risk. **[high] is not available for Full System Redesign tasks, or if any category-up adjustment was applied, or if quality-gate overhead is material (>50% of implementation estimate).**
- **[med]** — zero or one bounded unknown exists. Extend the upper bound by the full **current** range width.
- **[low]** — flag explicitly; extend the upper bound by 5× the full **current** range width.

  Escalate from [med] to [low] when ANY of the following apply:
  - **(1) Foundational unknown:** API surface itself is unknown, OR multiple independent unknowns exist.
  - **(2a) New external integration:** task requires building or establishing a new integration with an external service whose error behavior has not been previously characterized.
  - **(2b) Open-ended exploratory framing:** task description includes "figure out," "find out why," "not sure how to," or similarly open-ended language AND the scope category is NOT Investigation.
  - **(2c) Prior loop history:** previous analogous tasks have required repeated explore/fix/validate cycles.
  - **(3) Multi-session task:** mandatory minimum for non-FSR tasks.

**Partial exploration adjustment:** fires when fewer than 5 source implementation files *(internal calibration — empirically chosen as the minimum read depth to reliably distinguish exploratory vs. known codebases; re-verify before revising)* (files containing runtime logic — `.ts`, `.js`, `.py`, `.go`, `.rs`, or equivalent; type-definition-only `.d.ts` files, config files, schema files, and test files do not count) have been read AND no architecture doc is loaded. Apply the next-category-up adjustment even if the codebase is not technically "unfamiliar."

**Category-up direction by scope:**

| Starting scope | Advance to |
|---|---|
| Investigation (150k upper) | **Small** (300k upper) — NOT Surgical (100k upper < 150k) |
| Surgical (100k upper) | **Investigation** (150k upper) |
| Small and above | Next row in the calibration table |

**Adjustment stacking order (apply in sequence):**
1. **Category-up** (unfamiliar codebase, partial exploration) — advance one category if applicable. Maximum one category-up total regardless of how many triggers apply — do not stack multiple category-up adjustments.
2. **Non-Sonnet** — widen the category-adjusted upper bound by 50% (lower bound unchanged). If the result crosses 4M, route to 4M+ formula (see 4M+ Formula convention).
3. **Confidence multiplier** ([med] or [low]) — applied to the model-adjusted range. If the result crosses 4M after multiplier, route to 4M+ formula.

**4M routing checkpoint:** If the upper bound exceeds 4M at any point after steps 1–3, route to 4M+ formula. Use the lower bound from the category as computed at step 2 (before confidence multiplier). The 4M+ formula replaces steps 3 for upper-bound calculation only.

**Exception for 4M+ (Full System Redesign):** use the 4M+ formula convention instead of steps 2–3.

Example (Small feature + unfamiliar codebase + Non-Sonnet + [low]):
Step 1: advance to Medium (250–700k). Step 2: Non-Sonnet → upper = 700k × 1.5 = 1,050k → range 250–1,050k. Step 3 pre-check: 1,050k < 4M → no FSR routing yet. [low] width = 800k → upper = 1,050k + 5×800k = 5,050k → **5,050k > 4M → route to 4M+ non-Sonnet formula**. Use lower from step 2 (250k); apply non-Sonnet [low] formula upper (70M) → output `~250k–70M [low] (upper bound is a formula anchor, not a real ceiling.) — flag as near-zero planning utility at this range; recommend scope decomposition.` *(4 categories)*.

**Wide-range flag:** if the lower bound and upper bound fall in categories separated by 2 or more table rows, annotate the estimate with: *"Range too wide for planning utility — consider reducing scope unknowns or narrowing the task before estimating."*
