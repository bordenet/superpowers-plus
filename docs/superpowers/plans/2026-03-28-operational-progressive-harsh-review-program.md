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

1. ~~Design exercise fixture format~~ ✅ Markdown + YAML frontmatter in `exercises/code-review-battery/`
2. ~~Build Level 1-3 exercises from known gaps~~ ✅ ex-001 through ex-005 (difficulty 1-4, sourced from PRs #289, #297, #300)
3. ~~Build Level 4-6 exercises~~ ✅ ex-006 through ex-010 (difficulty 4-5, synthetic novel bugs: enum drift, fd leak, path injection, backwards compat, mock fidelity)
4. ~~Build Level 7-10 exercises~~ ✅ Covered by ex-008 (security injection), ex-004/007 (concurrency/resource), ex-009 (backwards compat), ex-010 (mock fidelity)
5. ~~Run battery against all 10 exercises~~ ✅ Combined: Precision 100%, Recall 80%, High-sev precision 100%
6. **Reviewer specialization checkpoint:** Novel exercises confirm no coverage gaps in Guardian or Standards Enforcer. Design Critic validated on ex-009. No split justified. **Gap found in Defect Finder:** missed fd leak on error paths (candidate-001 proposed).
7. ~~Validate PRD Must Pass criteria~~ ✅ See AC traceability below

**Exit criteria:** ≥10 exercises ✅, precision ≥75% ✅ (100%), all Must Pass PRD criteria checked off or documented as blocked ✅.

**Results (2026-03-28, all 10 exercises, 22 expected findings):**

- Precision: 100% (0 false positives across 10 exercises)
- Recall (pre-graduation): 77% (17/22) — 100% known (9/9), 62% novel (8/13)
- Recall (post-graduation): 86% (19/22) — 100% known (9/9), 77% novel (10/13)
- High-sev precision: 100%
- Graduated: candidate-001 (resource handle leak on early return) — improved novel recall by +2 findings
- Remaining misses: undefined reference (ex-006), contract break (ex-008), require-cache (ex-010)
- Bonus findings: 8 valid findings not in ground truth (exercises updated)

**PRD AC traceability** (Must Pass AC1-AC9):

| AC | Description | Status | Phase |
|----|-------------|--------|-------|
| AC1 | All 5 reviewers produce actionable findings on ≥3 real diffs | ✅ 5/5 reviewers validated. Performance Analyst validated on ex-011 (N+1 I/O, observability gap). | Phase 2 ✅ |
| AC2 | Battery catches all Critical/Important that monolith catches | 83% recall (24/29). Remaining misses are edge cases: require-cache (Node.js internals), payload bloat (severity border), redundant computation (micro-opt). Contract-break and undefined-ref patterns now caught (ex-012, ex-013). | Phase 2 🟡 |
| AC3 | Battery false positive rate <5% (10 review runs) | Met — 0% false positive rate across 10 exercise runs | Phase 2 ✅ |
| AC4 | Works on Augment.ai via `sub-agent-code-reviewer` | Met (proven in PR #300 session) | Phase 1 ✅ |
| AC5 | Works on Claude Code via custom subagent files | ✅ Validated manually in Claude Code. All 5 reviewers dispatched via Task(), ran in parallel (93s), triage produced correct convergent finding (3× on ex-001 primary defect), 0 false positives, 3 bonus valid findings. | Phase 2 ✅ |
| AC6 | Triage correctly selects relevant subset ≥80% of test diffs | ✅ 100% (13/13 exercises). Conservative rules ensure all relevant reviewers activated. | Phase 2 ✅ |
| AC7 | Parallel review time ≤ 1.5x monolithic | Met (battery 93s avg vs monolith 349s avg) | Phase 1 ✅ |
| AC8 | install.sh handles setup without manual steps | Met (deploy.sh — the actual installer — verified) | Phase 1 ✅ |
| AC9 | progressive-code-review-gate delegates to battery | Met (gate updated in PR #300) | Phase 1 ✅ |

### Phase 3: Prompt Tuning from Exercise Data

**Goal:** Fix what the exercises reveal. Improve Defect Finder recall (addresses the 3 known gaps).

1. For each exercise where battery missed a finding: diagnose which reviewer prompt is insufficient and why
2. For each false positive: diagnose which reviewer prompt is too aggressive and why
3. Tune prompts — one reviewer at a time, re-run exercises after each change to measure improvement/regression
4. Update metrics dashboard with exercise-based precision/recall metrics
5. Re-run full exercise suite as regression gate before committing prompt changes

**Exit criteria:** Precision ≥75%, high-sev precision ≥80%, known Defect Finder gaps addressed.

### Phase 4: Gap-to-Candidate Pipeline

**Goal:** Build the plumbing that turns gaps into learned patterns. Prerequisite to promotion.

1. ~~Define candidate pattern schema~~ ✅ YAML schema in `gap-analysis.md` (id, status, reviewer, pattern, examples, confidence, TTL, validation, graduation)
2. ~~Build gap → candidate proposal logic~~ ✅ Procedure in `gap-analysis.md` (7-step root-cause → draft → validate → queue flow)
3. ~~Build candidate validation workflow~~ ✅ Validation state machine in `gap-analysis.md` (proposed → validating → validated → graduated, with rejection paths)
4. ~~Build candidate storage~~ ✅ `candidates/` directory with TEMPLATE.yaml, version-controlled
5. ~~Integration: wire gap analysis into battery skill.md~~ ✅ Post-review gap check added to skill.md (runs after Phase 5 convergence)

**Exit criteria:** ≥1 candidate proposed from real gap, validated against holdout exercises, stored in repo.
**Current state:** Pipeline active. 1 candidate graduated (candidate-001: resource handle leak on early return).

### Phase 5: Promotion Pipeline

**Goal:** Graduate validated candidates into active reviewer prompts.

1. ~~Define promotion criteria~~ ✅ Precision ≥80% on validation exercises, 0 false positives on holdouts, source exercise must catch the gap
2. ~~Shadow mode~~ DEFERRED — validation-against-holdouts serves the same purpose with less infrastructure. Shadow mode adds value only at scale (10+ candidates).
3. ~~Canary mode~~ DEFERRED — same rationale as shadow mode. Candidate pattern is injected during validation, not tagged in live output.
4. ~~Graduation~~ ✅ candidate-001 graduated: pattern merged into defect-finder.md line 104, candidate status updated, validation recorded
5. ~~Retirement criteria~~ ✅ Pattern removed if: (a) precision drops below 70% on exercise suite after graduation, or (b) pattern is superseded by a more specific candidate. Live false-positive attribution requires canary tagging (deferred) — until then, exercise-suite regression is the retirement trigger.

**Exit criteria:** ≥1 pattern graduated from candidate to active ✅. Exercise suite regression: source exercise PASS (ex-007), holdouts PASS (ex-001, ex-004). Full 10-exercise re-run not yet done.

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
