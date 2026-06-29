---
name: token-estimation
source: superpowers-plus
augment_menu: false
triggers:
  - what would it cost in tokens
  - how much effort in tokens
  - AI effort estimate
  - token estimate for
  - how long will this take for an AI agent
  - how much work is this for an AI agent
  - /sp-estimate
  - estimate this for an AI
  - token range for
anti_triggers:
  - context window remaining
  - how many tokens left
  - token count of this file
  - data science comparison
  - comparing datasets for analysis
  - how long for the team
  - human effort estimate
  - how many engineers
  - sprint planning
  - story point planning
  - human team estimate
description: "Translates implementation effort questions into token-range estimates with confidence bands when an AI agent is doing the work. REQUIRED UNIT CONVENTION: bans day/week/sprint/story-point output. Token ranges are pre-flight planning references only. Triggered by explicit AI-effort estimation phrasing — NOT by generic 'estimate this' or 'scope this' alone."
summary: "Use when: estimating AI agent implementation effort or comparing design options by cost. NEVER output day/week/sprint estimates."
coordination:
  group: thinking
  order: 0
  requires: []
  enables: [debate]
  escalates_to: []
  internal: false
composition:
  consumes: [challenge]
  produces: [token-range-estimate]
  capabilities: [estimates-effort]
  priority: 1
---

# Token Estimation

> **Why this exists:** When an AI agent does the implementation, calendar time is irrelevant — the agent does not have sick days, sprint commitments, or context-switching overhead. The real cost signal is tokens consumed.
>
> **Scope statement:** This skill estimates AI agent implementation cost in tokens. It does NOT apply to human engineering effort, human sprint velocity, or incident response timelines. If the user is asking how many engineers to hire or how long a human team will take: "This skill estimates AI token cost, not human effort. For human staffing questions, consult your engineering manager or use story-point estimation methods."

**Announce at start:** "Using **token-estimation** to scope effort."

## Quick-Start (common case)

For the most common invocation — user asks "how big is this feature?" on a familiar, single-service codebase with a Sonnet-class model:
1. Assign the scope category from the Calibration Table.
2. Default to `[med]` confidence unless a [low]-trigger fires.
3. Output the estimate block (see Output Format).
4. Add cost-translation callout if total >100k tokens.

All other cases (unfamiliar codebase, non-Sonnet, multi-session, 4M+, quality gates, batch) follow the full procedure below.

---

## Pre-Output Check (REQUIRED before each estimate)

Before producing any estimate, verify:
1. This is an AI agent implementation task — not a human staffing or human sprint estimate (see Scope Statement).
2. There is enough information to assign a scope category. If not, say so explicitly.
3. If the output will be >100k tokens: add a cost-translation callout after the estimate (see Output Format).

---

## The One Hard Rule

**NEVER output estimates in days, weeks, sprints, hours, or story points.**

If someone uses a time-based phrase, translate it into scope category and look up the token range in the Calibration Table below. Do not hard-code token values here — the table is the single source of truth.

| Banned phrase | Scope category to look up |
|---------------|--------------------------|
| "2-3 days" | Small feature / CLI subcommand |
| "1-2 weeks" | Medium feature with tests |
| "1 sprint" | Multi-service change |
| "quick win" / "this is small" | Surgical fix / config patch |
| "3 story points" | Small feature / CLI subcommand |
| "4-hour task" / "2-hour fix" | Surgical fix / config patch |

If you have no basis for an estimate, say so: **"Token range: unknown — insufficient information to scope."**
Never substitute vagueness with a false number.

If the user provides a time constraint ("we need this before Friday") — acknowledge the constraint, then still state the token range. Time constraints and implementation cost are independent dimensions. Do not convert one to the other.

---

## Calibration Table

**These are order-of-magnitude priors calibrated against empirical agentic data.** Agent benchmark observations (2025–2026), including analyses of SWE-bench production runs and studies such as "How Do AI Agents Spend Your Money?" (Hamel Husain, 2024, https://hamel.dev/blog/posts/ai-agent-cost/) and Tokenomics research (Simon Willison, 2024, https://simonwillison.net/2024/Dec/26/tokenomics/), document **30× run-to-run variance for identical tasks** (internal calibration — verified against Sonnet-class production runs 2025–2026; re-verify against current benchmarks before revising table ranges) — the same code change can cost 30× more tokens depending on how many explore/fix/validate loops the agent executes. This 30× variance is the empirical foundation for the confidence band system: [high]/[med]/[low] ratings exist because cost is driven by loop count, not code complexity alone. The agent cannot read its own token counter in real-time — ranges are pre-flight planning references only.

"Token count" means total session tokens: input context + generated output + tool call payloads + tool response content fed back as context.

The 30× variance figure is a reported maximum from Hamel Husain's empirical runs, not the median across identical tasks — run-to-run median variance is typically lower but not documented in a single comparable study. Use the wide calibration ranges (not a single-number estimate) to incorporate this uncertainty. The SWE-bench production run reference above is non-specific to any single paper or dataset; treat it as supporting context for the direction of the claim rather than a precise citation.

These ranges assume a Sonnet-class model on a codebase that has been previously explored in this session. Adjust:
- **Unfamiliar codebase** (no prior exploration in this session AND no architecture doc loaded — AGENTS.md counts as an architecture doc for this purpose): default to the next category up.
- **Non-Sonnet model**: widen the upper bound by 50% (lower bound unchanged) *(internal calibration — estimated from observed token-per-output-token ratio differences between Sonnet-class and larger models on agentic tasks; re-verify before revising)*. If the model class is unknown, apply the non-Sonnet adjustment (upper bound +50%) as the conservative default.
- **Multi-session task**: estimate per-session (a session ends when the context window is compacted or a new conversation begins) and flag "session count: unknown."

  **Default:** flag multi-session estimates as **[low]** confidence minimum — [high] and [med] are not valid for multi-session tasks regardless of scope clarity.

  **Exceptions to the [low]-minimum (4M+ formula tiers take precedence):**
  - Full System Redesign (4M+ scope category) tasks — use 4M+ formula confidence tiers.
  - Architectural Overhaul tasks estimated on a non-Sonnet model — the non-Sonnet 50% widening pushes the upper bound to 6M (>4M floor), routing the task into the 4M+ formula regime; use 4M+ non-Sonnet formula confidence tiers.
  - **Any category + non-Sonnet adjustment + [low] confidence where the resulting upper bound exceeds 4M** → route to the 4M+ non-Sonnet formula. Use the category's adjusted lower bound (after category-up, before non-Sonnet) as the lower; the 4M+ non-Sonnet formula sets the upper. This applies to Multi-service and any other category that can cross the 4M threshold under non-Sonnet adjustment.

**Multi-session working priors:**

| | Architectural Overhaul | Full System Redesign |
|---|---|---|
| Session count (prior) | ≈8–20 sessions *(internal calibration — observed on agentic workflows 2025–2026; re-verify before revising)* | ≈20+ sessions *(internal calibration — same basis)* |
| Per-session cost (prior) | ≈75–500k tokens/session *(internal calibration — wide range reflects variation in task complexity per session)* | ≈100–500k tokens/session *(internal calibration — same basis)* |

Per-session range is wide because session boundaries depend on compaction triggers. The [low] confidence multiplier (5× width) applies to the **total** calibration-table estimate, not the per-session figure. Report both: "Per-session estimate: ~X–Yk; total estimate: ~A–B [low] (session count unknown)." The calibration table is the authoritative source for the total — per-session figures and session counts are independent heuristics; their product will not equal the table total. Report both without attempting to reconcile.

**Sonnet-class defined (for this skill):** Claude Sonnet 4, Sonnet 4.5, and Sonnet 4.6 (and equivalent-tier releases as they ship). Haiku-class = Haiku 4.5 and equivalent. Opus-class = Opus 4.6 and equivalent. Non-Sonnet = any model NOT in the Sonnet-class tier (includes Opus-class, Haiku-class, GPT-5-series, Gemini). The +50% non-Sonnet adjustment was calibrated against Opus-class runs; apply it to all non-Sonnet models in the absence of model-specific calibration data.

**Calibration vintage:** Sonnet-class, 2025–2026. Re-verify table ranges when a new major model class is deployed or when ≥6 months have elapsed since last verification.

| Scope category | Token range | Annotated examples |
|----------------|-------------|-------------------|
| Investigation / diagnosis | 30–150k | Log triage, diagnostic tool run, hypothesis test |
| Surgical fix / config patch | 10–100k | Single-file bug fix, env var addition, doc update |
| Small feature / CLI subcommand | 50–300k | New CLI subcommand, skill YAML file |
| Medium feature with tests | 250–700k | New skill with PHR gate, MCP tool + tests |
| Multi-service change | 300k–2M | Cross-repo refactor, dispatch layer |
| Architectural overhaul | 1M–4M | Connection registry + CLI + dispatch + migration (multi-session) |
| Full system redesign | 4M+ | New MCP server from scratch, major protocol change (multi-session) |

*Ranges calibrated against empirical agentic data (agent benchmark observations, 2025–2026; see "How Do AI Agents Spend Your Money?" https://hamel.dev/blog/posts/ai-agent-cost/ and SWE-bench production run analyses; internal calibration — re-verify against current benchmarks before revising table ranges). The 30× run-to-run variance documented for identical tasks is why ranges are wide and why confidence ratings are mandatory.*

**Prompt caching note (if your provider supports it):** Providers like Anthropic offer prompt caching that reduces the effective cost of re-reading large contexts (repeated files, long system prompts). Prompt caching does NOT reduce the token count — ranges above are measured in raw tokens regardless of caching. However, actual *cost in dollars* can be 50–90% lower for the cached portion. State explicitly when prompt caching applies: "Range: ~X–Yk tokens [med]. With prompt caching on the shared context (~Zk), dollar cost will be lower than the uncached equivalent."

**Parallel agent task cost:** When a task uses multiple parallel sub-agents (e.g., `dispatching-parallel-agents`), total tokens = sum of all sub-agent sessions independently. Parallel sub-agents do NOT share a token budget — each runs its own context. A 3-parallel-agent task at ~200k tokens each = ~600k total, not ~200k. Estimate each sub-agent separately and sum.

*(Calibration vintage stated above — see start of Calibration Table section. Re-verify when a new major model class deploys or ≥6 months elapsed.)*

---

### Superpowers Quality Gate Overhead

See **[reference.md](reference.md)** for quality gate overhead formulas, PHR iteration risk priors, and batch estimation detail.

---

### Overlap Zone Tiebreakers

See **[reference.md](reference.md)** for overlap zone tiebreaker rules, multi-way ordering rules, and 4M+ formula conventions.

---

## Confidence Bands

See **[reference.md](reference.md)** for confidence band definitions ([high]/[med]/[low]), escalation triggers, adjustment stacking order, and worked examples.

---

## Output Format

**Inside a `debate` or `plan-and-execute` comparison matrix:**

```
| Token cost | ~X–Yk tokens [high/med/low] |
```

**For single-task invocations (no material quality gate overhead):**

```
**Token estimate:** ~X–Yk tokens [high/med/low]
**Scope category:** <category from calibration table>
**Basis:** <1-sentence rationale — e.g., "single-service, precedent exists in codebase">
**Unknowns:** <what could expand the range, or "none identified">
```

**For tasks with material quality gate overhead (overhead >50% of implementation estimate):**

```
**Implementation estimate:** ~X–Yk [confidence]
**Quality gate overhead:** ~A–Bk (M–N PHR rounds + 1 cr-battery) [low if iteration count unknown]
**Total estimate:** ~C–Dk [confidence]
**Scope category:** <implementation scope category>
**Basis:** <1-sentence rationale>
**Unknowns:** <what could expand the range>
```

**For batch estimates (multiple tasks in one request):** produce one block per task, then a summary:

```
**[Task 1 name]:** ~X–Yk [confidence]
**[Task 2 name]:** ~A–Bk [confidence]
...
**Batch total (additive ceiling):** ~N–Mk [low] — ranges do not add linearly; use as planning ceiling, not sum
```

**Cost-translation callout (required when total estimate >100k tokens):**

Add this after the estimate block:
```
**Cost note (approximate, verify at vendor):** At Sonnet 4.6 pricing (~$3/MTok input, ~$15/MTok output as of 2026),
~X–Yk tokens ≈ $A–$B. Verify current pricing at anthropic.com/pricing before budget decisions.
If a lighter model (Sonnet 4, Haiku 4.5) is viable, cost may be materially lower — note the trade-off.
```
Token costs are approximations (input/output split unknown at estimation time). Treat as order-of-magnitude, not a billing forecast.

If a time constraint is given ("we need this by Friday"):
> "Noted. Estimated token cost: ~X–Yk [confidence]. Whether that fits your timeline depends on session throughput, which I cannot predict."

If the user then demands a day/week estimate anyway: "I cannot produce a reliable day estimate — token range is the appropriate unit here. If you need to schedule around this, use the token range to negotiate scope."

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Using token range as a precise commitment | Always show a range; never a single number |
| Skipping confidence rating | Confidence is required — uncertainty is data |
| Defaulting to "unknown" without attempting calibration | Use the calibration table; unknown = no relevant prior exists |
| Converting token estimate to days "for context" | Forbidden. Tokens and days are different units. Do not convert. |
| Parenthetical time gloss: "~300k tokens (roughly 2 days or 4 hours)" | Violation. Correct form: "~300k tokens [med]" — strip the gloss entirely. |
| 4M+ output missing the formula anchor annotation | All 4M+ outputs must include "(upper bound is a formula anchor, not a real ceiling.)" |
| User demands days after receiving token range | Decline. Provide the script from "Output Format" above. |
| Computing confidence width from original category range after adjustments | Use the range entering the confidence step (post category-up + post non-Sonnet), not the table's base width. |
| Applying [low]-minimum to a Full System Redesign task | The 4M+ formula tiers ([med] or [low]) take precedence — do not apply the multi-session [low]-minimum to FSR tasks. |
| Defaulting to [low] on all tasks to be "safe" | [low] is for specific listed triggers only — systematic over-use produces ranges so wide they provide no planning signal. |
| 4M+ non-Sonnet [low] output (70M tokens) with no cost translation | At this scale, add a mandatory annotation: "~4M–70M [low] — re-verify against current [model] pricing before using this range for budget decisions." Token counts at this scale have near-zero standalone planning utility. |
| Using "estimate this" or "scope these" triggers on non-estimation requests | These broad phrases have been removed from triggers to avoid false-positive activation on code review and data-scoping contexts. Require explicit invocation (`/sp-estimate` or user-specific estimation phrasing) for ambiguous cases. |
| Multi-service + Non-Sonnet + [low] producing an upper > 4M without FSR routing | Any post-stacking upper bound exceeding 4M routes to the 4M+ non-Sonnet formula. Apply the routing rule before reporting the estimate. |
