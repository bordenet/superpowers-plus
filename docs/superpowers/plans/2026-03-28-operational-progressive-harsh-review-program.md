# Operational Progressive Harsh Review Program

> **Created:** 2026-03-28
> **Source:** Perplexity.ai prompt, adapted for superpowers-plus code-review-battery
> **Status:** EXECUTING — Phase 1 (structural integration)

## Overview

Production-grade program to sharpen the code-review-battery through progressive exercises,
quantitative metrics, durable checks, and a promotion pipeline. This document drives execution;
the wiki dashboard tracks metrics.

## Key Deltas from Current Battery

The Perplexity plan introduces several concepts not yet in our battery:

| Concept | Current State | Target State |
|---------|--------------|--------------|
| **Finding format** | Markdown (Severity/File:Line/Issue/Why/Fix) | Structured JSON schema with evidence, regressions_risked, durable_check |
| **Scoring rubric** | Qualitative (battery caught X, missed Y) | Quantitative (precision ≥90%, detection ≥80%, gap rate ≤20%) |
| **Durable checks** | Not tracked | Every accepted finding proposes a lint/test/semgrep/invariant |
| **Promotion pipeline** | Not implemented | Shadow → Canary → Full promotion for new patterns |
| **Exercise catalog** | Ad-hoc (real PRs) | 10-level progressive exercises with expected findings |
| **Convergence logic** | Manual | Auto-stop when metrics meet thresholds + <20% new yield |
| **Reviewer names** | Guardian, Standards Enforcer | Security Guardian, Test Guardian (split from current) |
| **Regression analysis** | Not tracked | Every fix assessed for regressions_risked |

## Execution Plan

### Phase 1: Structural Integration (implement into battery)
1. ~~Add callee implementation trace (TODO 20260328-16)~~ ✅ DONE
2. Integrate JSON finding schema into reviewer output formats
3. Add durable_check field requirement to reviewer prompts
4. Add regression_risked field to reviewer output
5. Update skill.md Phase 3 aggregation with scoring rubric
6. Add convergence logic to Phase 4 escalation

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

**ADOPT NOW** (high value, low cost):
- JSON finding schema additions (durable_check, regressions_risked)
- Scoring rubric in aggregation phase
- Convergence logic

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

Tracked in Outline wiki: Code Review Battery — Performance Dashboard
Document ID: 66eec34c-5590-4f4f-a370-b4d134cd174e

## References

- [Perplexity source prompt](./2026-03-28-operational-progressive-harsh-review-program.md) (this file)
- [Battery DESIGN.md](../../../skills/engineering/code-review-battery/DESIGN.md)
- Reproducibility analysis (see TODO 20260328-16 handoff file)
