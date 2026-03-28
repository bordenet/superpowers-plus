# Code Review Battery — Product Requirements Document

> **Status**: Shipped (Phase 1e)
> **Author**: Matt Bordenet + AI
> **Created**: 2026-03-27
> **Shipped**: 2026-03-27
> **Confidence**: 92/100 (post-validation V1-V8, 8 review runs)

## Problem Statement

The current code review system in the superpowers framework has three critical limitations:

### 1. Monolithic Review Agent
A single reviewer agent (`code-reviewer.md`) attempts to evaluate ALL review dimensions simultaneously — correctness, security, design, performance, testing, and more. This leads to:
- Shallow coverage across many dimensions rather than deep analysis in any one
- Inconsistent focus (the reviewer gravitates toward whichever issue it notices first)
- No parallelism — review time scales linearly with diff size

### 2. Platform Portability
The battery uses `sub-agent-code-reviewer` (Augment) or `subagent()`/`Task()` (Claude Code) for dispatch. Each platform needs shell/tool access for reviewers to run `git diff` and read source files. Future platforms need equivalent sub-agent dispatch with workspace access.

### 3. Installation
Skill files are auto-deployed via `install.sh` and skill discovery. No additional platform-specific setup required beyond having sub-agent dispatch available.

## Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | Replace monolithic review with parallel specialized reviewers | ≥5 focused review dimensions run concurrently |
| G2 | Achieve cross-platform portability | Works identically on Augment.ai AND Claude Code |
| G3 | Zero manual setup | `install.sh` provides full review capability |
| G4 | Reduce false positives | <5% of findings are noise (vs current ~15-20%) |
| G5 | Maintain or improve review quality | Battery catches ≥ monolithic issues on same diff |
| G6 | Triage gating | Only relevant reviewers fire per diff, reducing cost |

## Scope

### In Scope (Phase 1: Review Battery)
- 5 specialized reviewer agents with focused prompts
- Triage coordinator that selects relevant reviewers per diff
- Platform-agnostic dispatch (Augment + Claude Code)
- Integration with existing `progressive-code-review-gate` skill
- Aggregation of multi-reviewer output into unified report
- 16 review dimensions covered across the 5 agents

### Out of Scope (Phase 2: Debugging Parallelization)
> **⚠️ FUTURE SCOPE — DO NOT FORGET**
>
> Phase 2 will extend the parallel dispatch pattern to `systematic-debugging`:
> - Dispatch parallel investigation agents (data flow tracer, recent changes analyzer, error message interpreter)
> - Useful for multi-component failures where root cause is unclear
> - Must preserve the "one hypothesis at a time" discipline from the existing skill
> - The battery pattern from Phase 1 provides the dispatch infrastructure
>
> **Entry point**: `~/.agents/skills/systematic-debugging/SKILL.md`
> **Trigger**: After Phase 1 battery is validated and stable

### Out of Scope (Not Planned)
- Accessibility review (too domain-specific; optional add-on for UI projects)
- Internationalization review (too domain-specific; optional add-on)
- CI/CD integration (future, after battery is proven locally)

## The 5 Reviewer Agents

### Agent 1: Defect Finder
**Mental Model**: *"What inputs, states, or conditions break this code?"*
**Dimensions**: Correctness, Edge Cases, Error Handling, Concurrency
**Triage**: Always-on (highest ROI)

### Agent 2: Design Critic
**Mental Model**: *"Is this code well-structured for humans to understand, extend, and test?"*
**Dimensions**: Factoring/Composition, Complexity Reduction, Testability, API Design
**Triage**: Conditional — when diff adds/modifies classes, functions, or public APIs

### Agent 3: Guardian
**Mental Model**: *"What damage can this change cause beyond the diff?"*
**Dimensions**: Security, Blast Radius, Dependencies/Config, Backwards Compatibility
**Triage**: Always-on (prevents production incidents)

### Agent 4: Standards Enforcer
**Mental Model**: *"Does this code meet the team's and project's documented expectations?"*
**Dimensions**: Language Standards/Style, Spec Compliance, Documentation Drift, Test Quality
**Triage**: Always-on (conformance checking)

### Agent 5: Performance Analyst
**Mental Model**: *"Will this code behave well under production load?"*
**Dimensions**: Performance, Observability/Logging
**Triage**: Conditional — when diff touches DB, loops, caching, or >500 LOC changed

## Dimension Coverage Matrix

| # | Dimension | Agent | Always-On? |
|---|-----------|-------|------------|
| 1 | Correctness | Defect Finder | ✅ |
| 2 | Error Handling | Defect Finder | ✅ |
| 3 | Concurrency | Defect Finder | ✅ |
| 4 | Edge Cases | Defect Finder | ✅ |
| 5 | Factoring & Composition | Design Critic | Conditional |
| 6 | Complexity Reduction | Design Critic | Conditional |
| 7 | API Design | Design Critic | Conditional |
| 8 | Testability | Design Critic | Conditional |
| 9 | Language Standards & Style | Standards Enforcer | ✅ |
| 10 | Spec Compliance | Standards Enforcer | ✅ |
| 11 | Security | Guardian | ✅ |
| 12 | Blast Radius | Guardian | ✅ |
| 13 | Test Quality | Standards Enforcer | ✅ |
| 14 | Documentation Drift | Standards Enforcer | ✅ |
| 15 | Performance | Performance Analyst | Conditional |
| 16 | Dependencies & Configuration | Guardian | ✅ |
| + | Backwards Compatibility | Guardian | ✅ |
| + | Observability/Logging | Performance Analyst | Conditional |


## Design Rationale: Why These Groupings?

The groupings were determined through a structured process:

1. **Initial proposal**: 16 standalone dimensions identified from industry research
2. **Think-twice consultation**: Sub-agent proposed 6-agent grouping
3. **Harsh review**: Adversarial critique identified forced marriages (Test Quality ≠ Correctness, Blast Radius ≠ Error Handling, Spec Compliance ≠ Security)
4. **Refinement**: Regrouped by shared "mental model" — dimensions that require the same cognitive frame belong together

**Industry validation**:
- Anthropic's Claude Code Review uses 5 parallel specialized agents
- Qodo recommends "Specialist-Agent architecture" over generic suggestions
- Claude Code Agent Teams docs recommend 3-5 teammates as the optimal range
- Multiple senior engineer accounts validate the parallel reviewer pattern with specialized lenses

## Acceptance Criteria

### Must Pass (Phase 1 ship gate)
- [x] AC1: All 5 reviewer prompts produce actionable findings on ≥3 real diffs
- [x] AC2: Battery catches Critical/Important issues (missed 1 Minor-overrated-as-Critical; mitigated by Data Integrity sub-dimension)
- [x] AC3: Battery false positive rate <15% (measured: 12.5% across 8 runs; vs monolithic 41%)
- [x] AC4: Works on Augment via `sub-agent-code-reviewer` parallel dispatch (upgraded from `sub-agent-explore` after benchmarking showed quality gap)
- [ ] AC5: Works on Claude Code via `subagent()`/`Task()` — DEFERRED (no CC test env; dispatch instructions documented)
- [x] AC6: Triage coordinator correctly selects relevant subset on 100% of test diffs (4/4)
- [x] AC7: Total review time (parallel) ≤ 1.5x monolithic review time
- [x] AC8: `install.sh` auto-deploys battery via existing skill discovery
- [x] AC9: progressive-code-review-gate delegates to battery with verdict mapping

### Should Pass (quality bar)
- [x] AC10: Each reviewer's findings are non-overlapping (0% overlap observed)
- [x] AC11: Aggregated output follows Critical/Important/Minor format
- [x] AC12: Token cost ~1.5x monolithic (within 3x budget)

### Nice to Have
- [ ] AC13: Support for `--all` override to force all reviewers on any diff
- [ ] AC14: Support for `--only=<agent>` to run a single reviewer
- [ ] AC15: Reviewer-specific configuration per project

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Sub-agents produce conflicting findings | Medium | Medium | Coordinator aggregation with conflict resolution rules |
| False positive rate too high | Medium | High | Triage gating + confidence threshold in prompts |
| Token cost 5x+ monolithic | Medium | Medium | Triage gating reduces active reviewers; measure and optimize |
| Platform dispatch differences cause bugs | Low | High | Smoke test both platforms before implementation |
| Reviewer prompts too broad/shallow | Medium | High | Prototype and iterate before shipping |

## Migration Path

1. **Phase 0**: Stabilize existing repos, tag known-stable versions
2. **Phase 1a**: Build battery as NEW skill (`code-review-battery`)
3. **Phase 1b**: Manual invocation for experimentation
4. **Phase 1c**: Validate against acceptance criteria on 10+ real diffs
5. **Phase 1d**: Wire `progressive-code-review-gate` to delegate to battery
6. **Phase 1e**: Battery becomes default review path
7. **Phase 2**: Extend pattern to debugging parallelization (separate PRD)

## Validation Plan

| # | Experiment | Purpose | Status |
|---|-----------|---------|--------|
| V1 | Parallel dispatch smoke test (Augment) | Verify 5 simultaneous sub-agents | ✅ PASS — 5/5 parallel |
| V2 | Draft + test all reviewer prompts | Validate prompt quality | ✅ PASS — 3/3 accurate, 0 FP |
| V3 | Draft + test Triage Coordinator | Validate diff classification | ✅ PASS — correct 4/5 selection |
| V4 | Monolithic vs Battery comparison | Prove battery ≥ monolithic quality | ⚠️ MIXED — higher precision, lower recall. See DESIGN.md |
| V5 | Token cost measurement | Quantify cost tradeoff | ✅ EST — ~1.5x monolithic (within 3x threshold) |
| V6 | Claude Code subagent file test | Verify `subagent()`/`Task()` dispatch | ⬜ Deferred (need CC env; dispatch instructions documented in skill.md + coordinator.md) |

## Open Questions

1. **Aggregation format**: Flat list by severity, or grouped by reviewer?
2. **Reviewer model selection**: Should Performance Analyst use a more expensive model?
3. **Project-specific config**: How should per-project reviewer settings be stored?
4. **Incremental review**: Re-run only dimensions that found issues?
