---
name: plan-quality-gates
source: superpowers-plus
triggers: ["write plan", "create plan", "design plan", "roadmap", "implementation plan", "phased plan", "write roadmap", "project plan"]
description: Use when writing plans, roadmaps, or phased work to enforce quality gates — prevents fabricated timelines, ensures dependency ordering, and requires exit criteria.
summary: "Use when: writing plans or roadmaps. Prevents fabricated timelines."
coordination:
  group: writing
  order: 2
  requires: []
  enables: ['plan-and-execute']
  escalates_to: []
  internal: false
---

# Plan Quality Gates

> **Last Updated:** 2026-03-20
> **Fires alongside:** `superpowers:writing-plans` — this skill is ADDITIVE, not a replacement. Also relevant during brainstorming when plan/roadmap topics arise (load manually if needed).
> **See also:** [detecting-ai-slop reference](../detecting-ai-slop/reference.md) § Fabricated Calendar Timelines

## Purpose

Enforce quality constraints on plans at creation time. The upstream `writing-plans` skill handles plan structure. This skill prevents specific failure modes (fabricated timelines, missing exit criteria) that other skills do not guard against.

**Announce at start:** "Using plan-quality-gates to enforce timeline and exit-criteria discipline."

---

## ⛔ Rule 1: No Fabricated Timelines

**NEVER assign calendar periods to plan phases without actual capacity data.**

You have zero information about:
- Team size or availability
- Sprint velocity or cadence
- Competing priorities or deadlines
- Holidays, PTO, or external dependencies
- How long any specific task actually takes

Therefore you CANNOT write any of the following:

| Forbidden Pattern | Example |
|-------------------|---------|
| Phase + calendar period | "Phase 2: Foundation (Weeks 1-2)" |
| Sprint numbering | "Sprint 1: schema extraction" |
| Quarter/month targets | "Target: Q3 2026" |
| Week-numbered milestones | "By Week 3, we should have..." |
| Aggregate duration | "Timeline: 4-6 weeks" |
| Day estimates for phases | "Phase 1 (Days 1-3)" |

**If the user provides capacity data** (team size, sprint length, velocity), you MAY use it. Otherwise, any calendar-based phasing is fabrication.

### What to Use Instead

**Dependency ordering + exit criteria.** Each phase states:
1. What it depends on (preconditions)
2. What "done" means (exit criterion)

### ❌ WRONG (actual incident, 2026-03-20)

```
Phase 1: Discovery (Week 1)
Phase 2: Foundation (Weeks 1-2)
Phase 3: Validation (Weeks 3-4)
Phase 4: Optimization (Week 5)
```

### ✅ RIGHT

```
Phase 1: Build schema knowledge base
  Depends on: nothing
  Exit: ≥9 table docs with business semantics committed

Phase 2: Wire named connections
  Depends on: Phase 1 (need schema understanding to choose connection names)
  Exit: config-service reads from named connections, tests pass

Phase 3: Validate data flow
  Depends on: Phase 2
  Exit: integration test confirms read path works end-to-end

Phase 4: Cut over production queries
  Depends on: Phase 3
  Exit: old connection strings removed, monitoring confirms no regressions
```

---

## ⛔ Rule 2: No Empty Duration Estimates

**If you don't know how long something takes, say "unknown" — don't invent numbers.**

| Forbidden | Acceptable |
|-----------|------------|
| "This should take 2-3 days" | "Duration: unknown without team input" |
| "Estimate: 1 sprint" | "Estimate: requires sizing by the team" |
| "Quick win — 1 hour" | "Likely small scope — team to confirm" |

**Exception:** If the user explicitly asks for rough estimates and accepts they're guesses, you MAY provide them with a clear disclaimer: "⚠️ These are rough guesses, not commitments."

---

## ✅ Rule 3: Dependency Ordering

Every phase in a plan MUST state its dependencies explicitly:
- `Depends on: nothing` (can start immediately)
- `Depends on: Phase N` (sequential dependency)
- `Depends on: Phase N + external approval` (blocked dependency)

If two phases have no dependency relationship, note they can run in parallel.

---

## ✅ Rule 4: Exit Criteria

Every phase or task MUST have a concrete "done means" statement:
- ❌ "Complete the migration" (vague)
- ✅ "Exit: all queries use named connections, zero references to legacy connection strings in codebase"

Exit criteria must be **verifiable** — someone can check whether they're true without asking the author what they meant.

---

## Self-Check

Before finalizing any plan, verify:

- [ ] Zero calendar-based phase labels (Weeks, Sprints, Months, Quarters)
- [ ] Zero fabricated duration estimates
- [ ] Every phase has explicit `Depends on:` statement
- [ ] Every phase has explicit `Exit:` criterion
- [ ] Exit criteria are verifiable (not "complete X" — what does complete mean?)

If any check fails, fix the plan before presenting it.

---

## Scoring (for `detecting-ai-slop` integration)

These patterns in plan output indicate this skill was not followed:

| Pattern | Score | Severity |
|---------|-------|----------|
| Phase + calendar period | +8 | Fabrication |
| Duration estimate without basis | +5 | Fabrication |
| Missing exit criteria | +3 | Incomplete |
| Missing dependency statement | +3 | Incomplete |

## When to Use

- When writing plans, roadmaps, or any phased work
- Automatically co-activated with `writing-plans` skill
- When reviewing existing plans for quality and completeness
