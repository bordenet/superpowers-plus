# Operational Progressive Harsh Review Program

> **Created:** 2026-03-28
> **Source:** Perplexity.ai prompt, adapted for superpowers-plus code-review-battery
> **Status:** EXECUTING — Phase 1 complete, Phase 2 deferred

## Overview

Production-grade program to sharpen the code-review-battery through progressive exercises,
quantitative metrics, durable checks, and a promotion pipeline. This document drives execution;
the wiki dashboard tracks metrics.

## Key Deltas from Current Battery

The Perplexity plan introduced several concepts beyond the original battery; some are now adopted and others remain future work:

| Concept | Current State | Target State |
|---------|--------------|--------------|
| **Finding format** | Markdown (Severity/File:Line/Issue/Why/Fix) | Extended markdown: +Regressions Risked, +Durable Check (JSON deferred) ✅ |
| **Scoring rubric** | Qualitative (battery caught X, missed Y) | Live metrics (durable rate, convergent count, unresolved critical) + offline (precision ≥75%, high-sev ≥80%, R2 yield ≤20%) ✅ |
| **Durable checks** | Not tracked | Every Implement finding proposes a lint/test/semgrep/invariant ✅ |
| **Promotion pipeline** | Not implemented | Shadow → Canary → Full promotion for new patterns — planned for Phase 4 |
| **Exercise catalog** | Ad-hoc (real PRs) | 10-level progressive exercises — planned for Phase 3 |
| **Convergence logic** | Manual | Phase 5 auto-stop: unresolved-critical=0 + <20% new yield + durable≥50% ✅ |
| **Reviewer names** | Guardian, Standards Enforcer | KEPT AS-IS — split deferred, current coverage sufficient ✅ |
| **Regression analysis** | Not tracked | Every fix assessed for Regressions Risked ✅ |
| **Tightening** | Not implemented | Suppress Minor findings when total >10 ✅ |
| **Callee trace** | Not implemented | Full function body default; compression fallback (must read full impl first) ✅ |
| **Escalation context** | Implicit | Phase 4 re-dispatch must re-attach diff + source context ✅ |

## Execution Plan

### Phase 1: Structural Integration (implement into battery) ✅ COMPLETE
1. ~~Add callee implementation trace (TODO 20260328-16)~~ ✅ DONE
2. ~~Integrate finding schema~~ ✅ Extended markdown with Regressions Risked + Durable Check (JSON deferred)
3. ~~Add durable_check field~~ ✅ Added to all 6 reviewer prompts
4. ~~Add regressions_risked field~~ ✅ Added to all 6 reviewer prompts
5. ~~Update skill.md Phase 3 aggregation with scoring rubric~~ ✅ Live + offline metric split
6. ~~Add convergence logic~~ ✅ Phase 5 with stop/continue/escalate-to-human
7. ~~Add tightening rule~~ ✅ Suppress Minor when total >10 (battery-reviewed: fixed subjective trigger + threshold)

### Phase 2: Reviewer Specialization
7. Evaluate Security Guardian split (from current Guardian)
8. Evaluate Test Guardian split (from current Standards Enforcer)
9. Update triage table if new reviewers added

### Phase 3: Exercise Catalog & Validation
10. Build exercise catalog (Levels 1-10) as test fixtures
11. Run battery against Level 1-5 exercises, measure metrics
12. Tune reviewer prompts based on exercise results

### Phase 4: Promotion Pipeline
13. Implement shadow mode for candidate patterns
14. Add canary mode infrastructure
15. Define promotion criteria

## Design Decisions

### What to adopt vs defer

**ADOPTED** (high value, low cost):
- ✅ Extended finding schema (Regressions Risked, Durable Check) — kept markdown, deferred JSON
- ✅ Scoring rubric — split into live metrics (per-pass) and offline metrics (wiki dashboard)
- ✅ Convergence logic — Phase 5 with 3-pass cap
- ✅ Tightening rule — suppress Minor when >10 total findings
- ✅ Callee implementation trace — full body default, compression fallback
- ✅ Escalation context re-attachment — Phase 4 requires diff + source inline

**DEFERRED** (evaluated, not implementing now):
- Reviewer split (Security Guardian, Test Guardian) — DEFERRED: current Guardian already covers security + blast radius + backwards compat effectively. Standards Enforcer already has test revert-safety, mock fidelity, paired boundary tests. Split when evidence shows insufficient coverage in either area.
- Full exercise catalog — useful but large effort, defer to Phase 3
- Promotion pipeline — needs infrastructure we don't have

**DEFER** (premature optimization):
- Shadow/canary mode — we don't have enough historical PRs yet
- Automated exercise generation — manual exercises first

### Finding format: JSON vs Markdown

The Perplexity plan mandates JSON. Our battery uses markdown. Trade-off:
- JSON: machine-parseable, enables automated scoring, but harder for sub-agents to produce reliably
- Markdown: human-readable, proven in our battery, but no automated metrics

**Decision:** Extend markdown format with structured fields (durable_check, regressions_risked)
rather than switching to pure JSON. Add JSON as optional `--json` output mode later.

## Metrics Dashboard

Tracked in Outline wiki (internal dashboard — see wiki for live data).

## References

- [Perplexity source prompt](./2026-03-28-operational-progressive-harsh-review-program.md) (this file)
- [Battery DESIGN.md](../../../skills/engineering/code-review-battery/DESIGN.md)
- Reproducibility analysis (see TODO 20260328-16 handoff file)
