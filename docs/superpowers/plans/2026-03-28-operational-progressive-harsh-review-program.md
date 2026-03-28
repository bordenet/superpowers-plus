# Operational Progressive Harsh Review Program

> **Created:** 2026-03-28
> **Source:** Perplexity.ai prompt, adapted for superpowers-plus code-review-battery
> **Status:** EXECUTING — Phase 1 complete, Phases 2-5 replanned from evidence (2026-03-28)
> **Last Replanned:** 2026-03-28 — original Phases 2-4 discarded; replaced with evidence-driven sequence

## Overview

Production-grade program to sharpen the code-review-battery through progressive exercises,
quantitative metrics, durable checks, and a promotion pipeline. This document drives execution;
a private metrics dashboard tracks quantitative results.

## Key Deltas from Current Battery

The Perplexity plan introduced several concepts beyond the original battery; some are now adopted and others remain future work:

| Concept | Current State | Target State |
|---------|--------------|--------------|
| **Finding format** | Markdown (Severity/File:Line/Issue/Why/Fix) | Extended markdown: +Regressions Risked, +Durable Check (JSON deferred) ✅ |
| **Scoring rubric** | Qualitative (battery caught X, missed Y) | Live metrics (durable rate, convergent count, unresolved critical) + offline (precision ≥75%, high-sev ≥80%, R2 yield ≤20%) ✅ |
| **Durable checks** | Not tracked | Every Implement finding proposes a lint/test/semgrep/invariant ✅ |
| **Promotion pipeline** | Not implemented | Shadow → Canary → Full promotion — planned for Phase 5 |
| **Exercise catalog** | Ad-hoc (real PRs) | Structured exercises as test fixtures — Phase 2 |
| **Convergence logic** | Manual | Phase 5 auto-stop: unresolved-critical=0 + <20% new yield + durable≥50% ✅ |
| **Reviewer names** | Guardian, Standards Enforcer | KEPT AS-IS — no evidence of coverage gaps ✅ |
| **Regression analysis** | Not tracked | Every fix assessed for Regressions Risked ✅ |
| **Tightening** | Not implemented | Suppress Minor findings when total >10 ✅ |
| **Callee trace** | Not implemented | Full function body default; compression fallback (must read full impl first) ✅ |
| **Escalation context** | Implicit | Phase 4 re-dispatch must re-attach diff + source context ✅ |
| **Gap-to-candidate pipeline** | Not implemented | Automated gap → candidate pattern flow — Phase 4 |

## Evidence That Drove the Replan

The original Phases 2-4 were written before we had operational data. After the PR #300
workstream, the evidence contradicts the original ordering:

| Original Phase | Evidence Against | Decision |
|---|---|---|
| Phase 2: Split Guardian / Standards Enforcer | Based on internal gap-analysis logs: all 3 logged gaps are primarily Defect Finder misses (one straddles Defect Finder + Standards Enforcer). No strong empirical signal that a full reviewer split is justified. | **Demoted to checkpoint** within Phase 2 validation — split only if exercises reveal gaps |
| Phase 3: 10-level exercise catalog | No test fixtures exist. Multiple PRD Must Pass criteria unchecked (see AC traceability below). Cannot tune what we cannot measure. | **Promoted to Phase 2** — measurement infra is prerequisite to everything else |
| Phase 4: Shadow/canary promotion pipeline | Learning system has 0 patterns, 0 candidates, 0 graduates. Building promotion infra for an empty pipeline is waste. | **Moved to Phase 5** — build after gap-to-candidate pipeline produces candidates |

**Principle: measure first → fix what's broken → then build infrastructure for what's working.**

## Execution Plan

### Phase 1: Structural Integration ✅ COMPLETE
1. ~~Add callee implementation trace~~ ✅
2. ~~Integrate extended finding schema~~ ✅
3. ~~Add durable_check + regressions_risked fields~~ ✅ (all 6 reviewers)
4. ~~Scoring rubric~~ ✅ (live + offline metric split)
5. ~~Convergence logic~~ ✅ (Phase 5 with 3-pass cap)
6. ~~Tightening rule~~ ✅ (suppress Minor when >10)
7. ~~v2.5 simplification~~ ✅ (1,854→674 lines)

### Phase 2: Exercise Catalog & Validation
**Goal:** Build measurement infrastructure. Validate PRD acceptance criteria. Produce data.

8. ~~Design exercise fixture format~~ ✅ Markdown + YAML frontmatter in `exercises/code-review-battery/`
9. ~~Build Level 1-3 exercises from known gaps~~ ✅ ex-001 through ex-005 (difficulty 1-4, sourced from PRs #289, #297, #300)
10. Build Level 4-6 exercises from real PRs with unknown bugs (not yet caught by battery)
11. Build Level 7-10 exercises targeting under-tested dimensions (security injection, concurrency, backwards compat, mock fidelity)
12. ~~Run battery against exercises 1-5~~ ✅ Precision 100%, Recall 100%, 0 false positives, 4 bonus findings
13. **Reviewer specialization checkpoint:** Exercises 1-5 show no coverage gaps in Guardian or Standards Enforcer. Both caught convergent findings correctly. No split justified. Will re-evaluate after Level 4-10 exercises.
14. Validate unchecked PRD Must Pass criteria with exercise results (see AC traceability below)

**Exit criteria:** ≥10 exercises, precision ≥75%, all Must Pass PRD criteria checked off or documented as blocked.

**Partial results (2026-03-28, exercises 1-5 only):**
- Precision: 100% (0 false positives across 5 exercises, 9 expected findings, 4 bonus valid findings)
- Recall: 100% (all 9 expected findings caught)
- Caveat: all exercises use known bugs from training data. Need Level 4-10 exercises with novel bugs for true evaluation.

**PRD AC traceability** (Must Pass AC1-AC9):

| AC | Description | Status | Phase |
|----|-------------|--------|-------|
| AC1 | All 5 reviewers produce actionable findings on ≥3 real diffs | Partial — 3 reviewers (defect-finder, guardian, standards-enforcer) validated on 5 exercises. Design-critic and perf-analyst not yet exercised. | Phase 2 🟡 |
| AC2 | Battery catches all Critical/Important that monolith catches | Met on exercises 1-5 (100% recall on Important+ findings) | Phase 2 ✅ |
| AC3 | Battery false positive rate <5% (10 review runs) | Met on exercises 1-5 (0% false positive rate, 5 runs) — need 5 more runs | Phase 2 🟡 |
| AC4 | Works on Augment.ai via `sub-agent-code-reviewer` | Met (proven in PR #300 session) | Phase 1 ✅ |
| AC5 | Works on Claude Code via custom subagent files | Unchecked — not yet tested | Phase 2 (manual test) |
| AC6 | Triage correctly selects relevant subset ≥80% of test diffs | Unchecked | Phase 2 (exercises) |
| AC7 | Parallel review time ≤ 1.5x monolithic | Met (battery 93s avg vs monolith 349s avg) | Phase 1 ✅ |
| AC8 | install.sh handles setup without manual steps | Met (deploy.sh — the actual installer — verified) | Phase 1 ✅ |
| AC9 | progressive-code-review-gate delegates to battery | Met (gate updated in PR #300) | Phase 1 ✅ |

### Phase 3: Prompt Tuning from Exercise Data
**Goal:** Fix what the exercises reveal. Improve Defect Finder recall (addresses the 3 known gaps).

15. For each exercise where battery missed a finding: diagnose which reviewer prompt is insufficient and why
16. For each false positive: diagnose which reviewer prompt is too aggressive and why
17. Tune prompts — one reviewer at a time, re-run exercises after each change to measure improvement/regression
18. Update metrics dashboard with exercise-based precision/recall metrics
19. Re-run full exercise suite as regression gate before committing prompt changes

**Exit criteria:** Precision ≥75%, high-sev precision ≥80%, known Defect Finder gaps addressed.

### Phase 4: Gap-to-Candidate Pipeline
**Goal:** Build the plumbing that turns gaps into learned patterns. Prerequisite to promotion.

20. Define candidate pattern schema (pattern, reviewer, source gap, TTL, confidence, validation status)
21. Build gap → candidate proposal logic (when battery misses a finding that monolith catches, auto-propose a candidate)
22. Build candidate validation workflow (re-run candidate against holdout exercises — does it catch the gap without introducing false positives?)
23. Build candidate storage (file-based, in repo — no external infrastructure)
24. Integration: wire gap analysis into battery Phase 3 aggregation so candidates are proposed automatically

**Exit criteria:** ≥1 candidate proposed from real gap, validated against holdout exercises, stored in repo.

### Phase 5: Promotion Pipeline
**Goal:** Graduate validated candidates into active reviewer prompts. Only build when Phase 4 produces candidates.

25. Define promotion criteria (precision threshold, stability window, no regressions on exercise suite)
26. Implement shadow mode: candidate runs alongside baseline, findings compared but not surfaced
27. Implement canary mode: candidate findings surfaced with `[CANDIDATE]` tag, user validates
28. Implement graduation: candidate pattern merged into reviewer prompt, exercise suite updated
29. Implement retirement: pattern removed if precision drops below threshold after graduation

**Exit criteria:** ≥1 pattern graduated from candidate to active. Exercise suite validates no regression.

## Design Decisions

### What to adopt vs defer

**ADOPTED** (high value, low cost):
- ✅ Extended finding schema (Regressions Risked, Durable Check) — kept markdown, deferred JSON
- ✅ Scoring rubric — split into live metrics (per-pass) and offline metrics (tracked externally)
- ✅ Convergence logic — Phase 5 with 3-pass cap
- ✅ Tightening rule — suppress Minor when >10 total findings
- ✅ Callee implementation trace — full body default, compression fallback
- ✅ Escalation context re-attachment — Phase 4 requires diff + source inline

**RESOLVED by evidence** (2026-03-28):
- Reviewer split (Security Guardian, Test Guardian) — based on internal gap-analysis logs, all 3 logged gaps are primarily Defect Finder misses (one straddles Defect Finder + Standards Enforcer). No strong signal for a full split. Checkpoint in Phase 2 will re-evaluate with exercise data. Split only if exercises produce evidence of coverage gaps.

**REORDERED by evidence** (2026-03-28):
- Exercise catalog — promoted from Phase 3 to Phase 2 (can't tune without measurement)
- Promotion pipeline — moved from Phase 4 to Phase 5 (can't promote without candidates)
- Gap-to-candidate pipeline — inserted as new Phase 4 (prerequisite to promotion)

### Finding format: JSON vs Markdown

The Perplexity plan mandates JSON. Our battery uses markdown. Trade-off:
- JSON: machine-parseable, enables automated scoring, but harder for sub-agents to produce reliably
- Markdown: human-readable, proven in our battery, but no automated metrics

**Decision:** Extend markdown format with structured fields (durable_check, regressions_risked)
rather than switching to pure JSON. Add JSON as optional `--json` output mode later.

## Metrics Dashboard

Tracked in a private metrics dashboard.

## References

- [Perplexity source prompt](./2026-03-28-operational-progressive-harsh-review-program.md) (this file)
- [Battery DESIGN.md](../../../skills/engineering/code-review-battery/DESIGN.md)
- Reproducibility analysis (see TODO 20260328-16 handoff file)
