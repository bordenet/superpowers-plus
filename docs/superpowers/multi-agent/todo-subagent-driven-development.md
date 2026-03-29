# TODO: subagent-driven-development Hierarchical Execution Orchestrator

> **Epic:** Merge-risk-aware selective parallelism for subagent-driven-development
> **Priority:** P2 — Second priority (highest risk, highest reward when correct)
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Updated:** 2026-03-29

## P1 — Critical Path

- [ ] **SD-01: Orchestration architecture** — Replace implicit sequential dispatch with Execution Conductor that analyzes task graph before dispatching. _Success:_ conductor explains dispatch strategy before executing. _Risk:_ overhead on simple sequential work.
- [ ] **SD-02: Task isolation analysis** — Implement fan-out eligibility rubric: score file overlap, interface coupling, test isolation, data model coupling. Score ≥ 6 → parallel eligible. _Success:_ correctly identifies SD-1 as parallel-safe and SD-3 as serial-only. _Risk:_ false positives cause merge pain.
- [ ] **SD-03: Merge-risk scoring** — `risk = 1 - (isolation_score / 8)`. Risk > 0.5 → force serial. Publish risk score in dispatch logs. _Success:_ no parallel dispatch with risk > 0.5. _Risk:_ too conservative blocks beneficial parallelism.
- [ ] **SD-04: Task packet schema** — Each parallel branch carries: exact scoped task, expected file paths, non-goals, acceptance criteria, test expectations, integration constraints, known dependencies, review requirements. _Depends on:_ shared task packet from multi-agent-skill-strategy.md.
- [ ] **SD-05: Integration checkpoint protocol** — After parallel branches complete, run Integration Checker to verify no file conflicts, interface mismatches, or test failures. _Success:_ catches integration issues before commit. _Risk:_ integration check is expensive if branches are large.

## P2 — Important

- [ ] **SD-06: Duplicate-effort detection** — Detect when parallel branches modify same files or produce similar changes. Alert conductor before commit. _Depends on:_ shared duplicate detection primitives.
- [ ] **SD-07: Conflict handling** — When parallel branches conflict: auto-merge trivially compatible changes; escalate genuinely conflicting changes to user. _Risk:_ auto-merge produces subtle bugs.
- [ ] **SD-08: Review gate integration** — Apply progressive-code-review-gate to EACH parallel branch independently before integration checkpoint. _Success:_ each branch individually passes review. _Risk:_ review overhead scales linearly with branch count.
- [ ] **SD-09: Observability / dispatch logs** — Log: which tasks were analyzed, isolation scores, dispatch decision (serial/parallel), per-branch timings, integration results. _Priority rises to P1 during prototyping._
- [ ] **SD-10: Subagent result schema** — Structured completion report from each implementer: files changed, tests added/modified, integration notes, concerns, status code. _Depends on:_ shared result schema.

## P3 — Deferred

- [ ] **SD-11: Dynamic re-serialization** — If a parallel branch discovers it needs a file owned by another branch, dynamically serialize those two branches. _Not now:_ complex; start with static analysis.
- [ ] **SD-12: Branch budgets** — Per-branch token limits to prevent one implementer from dominating. _Not now:_ current per-task dispatch already limits scope.
- [ ] **SD-13: Rollback protocol** — If integration checkpoint fails, revert parallel branches and re-execute serially. _Not now:_ git stash/branch mechanics make this tricky.
- [ ] **SD-14: Metric collection** — Track: parallelism ratio, merge pain incidents, time savings, review burden increase. _Not now:_ needs experiment infrastructure.
- [ ] **SD-15: "Stop and ask" threshold** — When isolation analysis is ambiguous (score 4–5), ask user instead of guessing. _Not now:_ start with conservative serial default for ambiguous cases.

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
