# TODO: subagent-driven-development Hierarchical Execution Orchestrator

> **Epic:** Merge-risk-aware selective parallelism for subagent-driven-development
> **Priority:** P2 — Second priority (highest risk, highest reward when correct)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29 · **Status:** ✅ ALL ITEMS COMPLETE

## P1 — Critical Path

- [x] **SD-01: Orchestration architecture** ✅ → `references/parallel-dispatch-mode.md` (Execution Conductor with strategy announcement)
- [x] **SD-02: Task isolation analysis** ✅ → `references/isolation-analyzer.md` (4-signal rubric, pair scoring, dependency graph)
- [x] **SD-03: Merge-risk scoring** ✅ → `references/isolation-analyzer.md` §"Merge-Risk Escalation" (risk = 1 - score/8, >0.5 → serial)
- [x] **SD-04: Task packet schema** ✅ → `references/parallel-dispatch-mode.md` §"Enhanced Task Packets" + `multi-agent-skill-strategy.md` §3.2
- [x] **SD-05: Integration checkpoint** ✅ → `references/integration-checkpoint.md` (5-step protocol: file, interface, test, review, log)

## P2 — Important

- [x] **SD-06: Duplicate-effort detection** ✅ → `skills/_shared/multi-agent-quality-standards.md` §6 (file overlap → dup/conflict/compatible classification)
- [x] **SD-07: Conflict handling** ✅ → `skills/_shared/multi-agent-quality-standards.md` §7 (5 conflict types with detection + resolution)
- [x] **SD-08: Review gate integration** ✅ → `skills/_shared/multi-agent-quality-standards.md` §8 (per-branch + post-integration, cost-aware skip)
- [x] **SD-09: Observability / dispatch logs** ✅ → `references/isolation-analyzer.md` §"Report" + `references/integration-checkpoint.md` §"Dispatch Log Entry" + `skills/_shared/multi-agent-quality-standards.md` §5
- [x] **SD-10: Subagent result schema** ✅ → `multi-agent-skill-strategy.md` §3.3 Common Result Schema

## P3 — Intentionally Deferred

- [~] **SD-11: Dynamic re-serialization** — DEFERRED. Start with static isolation analysis; dynamic detection is complex and risky.
- [~] **SD-12: Branch budgets** — DEFERRED. Current per-task scoping + 25% budget cap from activation rubric is sufficient.
- [~] **SD-13: Rollback protocol** — DEFERRED. Git stash/branch mechanics are tricky; manual intervention acceptable for now.
- [~] **SD-14: Metric collection** — DEFERRED. Instrumentation spec (§5) covers logging; aggregation/dashboards are post-validation.
- [~] **SD-15: "Stop and ask" threshold** — DEFERRED. Conservative serial default for ambiguous cases (score 4–5) is the safe starting point.

## Open Questions

- **OQ-SD-01:** Should the Integration Checker be a separate agent or a scripted step (git diff analysis + test run)? Agent can reason about semantic conflicts; script is cheaper and deterministic.
- **OQ-SD-02:** How to handle shared test fixtures? Two branches may both add to the same test file. File-level isolation analysis misses this.
- **OQ-SD-03:** What's the maximum number of parallel implementer branches? Research says 3–4 optimal. But implementers also trigger review loops (2 agents each), so total agent count could be 3×3=9.

## Experiments

| ID | Scenario | Expected | Measures |
|----|----------|----------|----------|
| SD-1 | 3 independent file changes | Parallel wins on latency | Time, correctness, merge pain |
| SD-2 | Feature with shared types | Close call | Integration issues, review burden |
| SD-3 | Tightly coupled refactor | Serial wins | Merge conflicts, rework cost |
