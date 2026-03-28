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

| Exercise | Difficulty | Precision | Recall | High-sev Precision | Notes |
|----------|-----------|-----------|--------|-------------------|-------|
| ex-001   | 3 | 100% | 100% | 100% | Convergent finding caught by both Defect Finder and Guardian |
| ex-002   | 1 | 100% | 100% | 100% | Both newline and triggers-sync issues caught |
| ex-003   | 2 | 100% | 100% | 100% | Regression correctly identified |
| ex-004   | 4 | 100% | 100% | 100% | All 3 expected + 1 bonus (PID liveness check) |
| ex-005   | 3 | 100% | 100% | 100% | All 2 expected + 3 bonus (circular ordering, ambiguity, terminology) |
| **Total** | — | **100%** | **100%** | **100%** | 0 false positives, 0 misses, 4 bonus findings |

**Caveat:** All exercises are derived from known bugs that the battery previously caught. Perfect scores are expected on this training set. True evaluation requires exercises with unknown bugs (not yet authored).

## Exit Criteria (from operational plan)

- Precision ≥ 75%
- High-severity precision ≥ 80%
- All known Defect Finder gaps addressed

## Files

| Exercise | Difficulty | Primary Reviewer | Bug Type |
|----------|-----------|-----------------|----------|
| [ex-001](./ex-001-stage-exclusion-gap.md) | 3 | defect-finder + guardian | Incomplete fix across parallel code paths |
| [ex-002](./ex-002-missing-newlines.md) | 1 | standards-enforcer | Standards violation (trailing newline) |
| [ex-003](./ex-003-callee-trace-regression.md) | 2 | defect-finder | Context truncation regression |
| [ex-004](./ex-004-lock-atomicity.md) | 4 | defect-finder + guardian | Race condition + security (lock forgery) |
| [ex-005](./ex-005-convergence-underspec.md) | 3 | standards-enforcer + defect-finder | Under-specified algorithm edge case |
