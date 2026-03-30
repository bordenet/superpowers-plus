# Code Review Battery — Exercise Catalog

## Purpose

Structured exercises to measure battery precision and recall. Each exercise contains a real diff (input) and ground-truth findings (expected output). Running the battery against exercises produces quantitative metrics.

## Format

Each exercise is a standalone markdown file with YAML frontmatter:

```yaml
---
id: ex-NNN
title: Human-readable description
difficulty: 1-5  # 1=obvious, 5=subtle cross-file reasoning
source_commit: <sha>  # Commit that introduced the bug (or fixed it)
source_pr: <number>   # PR where the finding was documented
tags: [error-handling, installer, ...]
expected_reviewers: [defect-finder, guardian, ...]  # Who SHOULD catch this
---
```

Body contains:

1. **## Context** — Background needed to understand the diff
2. **## Diff** — The actual code change (fenced code block)
3. **## Expected Findings** — Ground-truth findings with severity, reviewer, file, issue
4. **## Anti-Findings** — Things the battery should NOT flag (false positive traps)

## Metrics

After running the battery against an exercise:

| Metric | Formula |
|--------|---------|
| **Precision** | true_positives / (true_positives + false_positives) |
| **Recall** | true_positives / (true_positives + false_negatives) |
| **High-sev precision** | Important+ true_positives / Important+ total_positives |
| **Severity accuracy** | findings with correct severity / total true_positives |

A finding is a **true positive** if it matches an Expected Finding on: file, issue category, and severity (±1 level).
A finding is a **false positive** if it doesn't match any Expected Finding AND is not a legitimate issue in the diff.
A **bonus finding** is a legitimate issue found by the battery that wasn't listed in Expected Findings (ground truth was incomplete). These count as true positives and the exercise should be updated.
A **false negative** is an Expected Finding not matched by any battery output.

## Running Exercises

### Manual (agent-driven)

1. Read the exercise file
2. Feed the diff to the battery (use `sub-agent-code-reviewer` per skill.md)
3. Collect battery output
4. Score against Expected Findings using the matching rules above
5. Record results in the scoring table below

### Scoring Results (2026-03-28, battery v2.5)

**Known-bug exercises (training data):**

| Exercise | Difficulty | Precision | Recall | High-sev Precision | Notes |
|----------|-----------|-----------|--------|-------------------|-------|
| ex-001   | 3 | 100% | 100% | 100% | Convergent finding caught by both Defect Finder and Guardian |
| ex-002   | 1 | 100% | 100% | 100% | Both newline and triggers-sync issues caught |
| ex-003   | 2 | 100% | 100% | 100% | Regression correctly identified |
| ex-004   | 4 | 100% | 100% | 100% | All 3 expected + 1 bonus (PID liveness check) |
| ex-005   | 3 | 100% | 100% | 100% | All 2 expected + 3 bonus (circular ordering, ambiguity, terminology) |

**Novel-bug exercises (unseen by battery):**

| Exercise | Difficulty | Precision | Recall | High-sev Precision | Notes |
|----------|-----------|-----------|--------|-------------------|-------|
| ex-006   | 5 | 100% | 50% | 100% | Caught validator gap; missed undefined reference (below confidence threshold) |
| ex-007   | 4 | 100% | 33%→100% | 100% | **GAP FIXED:** fd leak missed pre-graduation. After candidate-001 graduated into defect-finder.md, re-run caught all 3 expected findings + 2 bonus. |
| ex-008   | 5 | 100% | 67% | 100% | Caught path traversal + blast radius; missed contract break (null→throw) |
| ex-009   | 4 | 100% | 100% | 100% | Caught silent default change + NaN; bonus: value validation gap |
| ex-010   | 5 | 100% | 67% | 100% | Caught tautological mock + mock leak; missed require-cache isolation |
| ex-011   | 4 | 100% | 50% | 100% | **AC1 VALIDATED:** Performance Analyst caught N+1 I/O + observability gap. Defect Finder caught 2 bonus (missing error guard, duplicate handling). Missed: payload bloat, redundant word count. |
| ex-012   | 3 | 100% | 100% | 100% | **AC2 TARGETED:** Defect Finder caught undefined `batchDispatch` reference (the ex-006 miss class). |
| ex-013   | 4 | 100% | 50% | 100% | **AC2 TARGETED:** Defect Finder caught contract break (the ex-008 miss class). Missed: negative cache (Minor). |

**Aggregate:**

| Metric | Known (1-5, 9 expected) | Novel (6-10, 13 expected) | Targeted (11-13, 7 expected) | Combined (29 expected) |
|--------|-------------|-------------|-------------|----------|
| Precision | 100% | 100% | 100% | **100%** |
| Recall (post-graduation) | 100% (9/9) | 77% (10/13) | 71% (5/7) | **83% (24/29)** |
| High-sev Precision | 100% | 100% | 100% | **100%** |
| False positives | 0 | 0 | 0 | **0** |
| Bonus valid findings | 4 | 4 | 2 | **10** |

**Key insights:**

- Precision remains perfect (0 false positives across 13 exercises).
- **AC1 validated:** All 5 reviewers now produce actionable findings (Performance Analyst validated on ex-011).
- **AC2 progress:** Battery catches undefined-reference (ex-012) and contract-break (ex-013) patterns when given proper context. Original misses (ex-006, ex-008) were harder because context was implicit.
- Remaining structural misses: require-cache isolation (ex-010, Node.js-specific), payload bloat (ex-011, severity border), redundant computation (ex-011, micro-opt).

## Exit Criteria (from operational plan)

- Precision ≥ 75%
- High-severity precision ≥ 80%
- All known Defect Finder gaps addressed

## Files

| Exercise | Difficulty | Primary Reviewer | Bug Type | Source |
|----------|-----------|-----------------|----------|--------|
| [ex-001](./ex-001-stage-exclusion-gap.md) | 3 | defect-finder + guardian | Incomplete fix across parallel code paths | PR #300 |
| [ex-002](./ex-002-missing-newlines.md) | 1 | standards-enforcer | Standards violation (trailing newline) | PR #289 |
| [ex-003](./ex-003-callee-trace-regression.md) | 2 | defect-finder | Context truncation regression | PR #300 |
| [ex-004](./ex-004-lock-atomicity.md) | 4 | defect-finder + guardian | Race condition + security (lock forgery) | PR #297 |
| [ex-005](./ex-005-convergence-underspec.md) | 3 | standards-enforcer + defect-finder | Under-specified algorithm edge case | PR #300 |
| [ex-006](./ex-006-cross-file-enum-drift.md) | 5 | defect-finder + standards-enforcer | Incomplete change across consumers | Synthetic |
| [ex-007](./ex-007-fd-leak-on-error.md) | 4 | defect-finder + guardian | Resource leak on error paths | Synthetic |
| [ex-008](./ex-008-path-injection.md) | 5 | guardian + defect-finder | Path traversal + contract break | Synthetic |
| [ex-009](./ex-009-backwards-compat-break.md) | 4 | guardian + design-critic | Silent behavior change | Synthetic |
| [ex-010](./ex-010-mock-fidelity.md) | 5 | standards-enforcer + defect-finder | Tautological test + mock leak | Synthetic |
| [ex-011](./ex-011-n-plus-one-query.md) | 4 | performance-analyst + defect-finder | N+1 blocking I/O + unbounded payload | Synthetic |
| [ex-012](./ex-012-undefined-import.md) | 3 | defect-finder | Undefined function reference (ReferenceError) | Synthetic |
| [ex-013](./ex-013-return-contract-break.md) | 4 | defect-finder + guardian | Return contract change breaks callers | Synthetic |
