---
id: ex-005
title: "Phase 5 convergence logic under-specified for pass 1"
difficulty: 3
source_commit: fe0f71e
source_pr: 300
tags: [underspecification, edge-case, algorithm, convergence]
expected_reviewers: [standards-enforcer, defect-finder]
---

## Context

Phase 5 convergence logic was added to auto-stop the review loop when metrics indicate diminishing returns. The logic evaluates three criteria: unresolved critical = 0, last 2 passes produced <20% new high-severity findings, and durable check rate ≥ 50%.

The problem: this logic is evaluated after "each synthesis pass" but doesn't define what happens on pass 1. On pass 1, there are no "last 2 passes" to compare, making the <20% criterion undefined. An agent could interpret this as "condition met" (vacuously true) and stop after a single pass.

## Diff

```diff
diff --git a/skills/engineering/code-review-battery/skill.md b/skills/engineering/code-review-battery/skill.md
--- a/skills/engineering/code-review-battery/skill.md
+++ b/skills/engineering/code-review-battery/skill.md
@@ -149,6 +149,18 @@ Skip escalation if: user requested `--round1-only`, all Round 1 clean, or diff <

 ### Phase 5: Convergence (multi-round reviews only)

-After each review round, manually decide whether to continue or stop.
+After each synthesis pass, evaluate stop criteria. **Escalation takes precedence** — if a trigger fires, run escalation before evaluating convergence.
+
+**STOP** when ALL of:
+- Unresolved Critical count = 0
+- Last 2 passes produced <20% new high-severity findings
+- Durable check rate >= 50% (findings with proposed durable checks / total Implement findings)
+
+**ESCALATE TO HUMAN** if:
+- 3 passes completed and criteria still not met
+- Unresolved Critical persists across 2 passes
+
+**Live metrics** (report after each pass):
+- Unresolved Critical count, new high-sev yield %, durable check rate %
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** defect-finder or standards-enforcer
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** Pass 1 behavior is undefined. "Last 2 passes produced <20% new high-severity findings" has no defined value on pass 1 (there is no prior pass to compare against). An agent could treat this as vacuously true and stop after a single pass, defeating the purpose of multi-round review.
- **Category:** underspecification, edge-case
- **Fix:** Add: "Only evaluate convergence starting at pass 2. After pass 1, stop if no escalation trigger fired; otherwise continue."

### Finding 2

- **Severity:** Minor
- **Reviewer:** standards-enforcer
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** The <20% formula doesn't specify what happens when the prior pass had zero high-severity findings (0/0 is undefined). Should specify: "If prior pass had 0 high-sev findings and current pass has 0, criterion is met."
- **Category:** edge-case, division-by-zero

### Finding 3 (Bonus — discovered by battery)

- **Severity:** Important
- **Reviewer:** standards-enforcer or defect-finder
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** Circular ordering: "Escalation takes precedence — run escalation before evaluating convergence" but escalation trigger "3 passes completed and criteria still not met" requires evaluating convergence first. The spec is self-contradictory.
- **Category:** circular-dependency, spec-contradiction
- **Fix:** Define explicit evaluation order: compute metrics → check escalation → check stop → continue.

### Finding 4 (Bonus — discovered by battery)

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** "Unresolved Critical persists across 2 passes" is ambiguous — does it mean the same finding stays open, or any critical is present in 2 consecutive passes?
- **Category:** ambiguity, identity-vs-count

### Finding 5 (Bonus — discovered by battery)

- **Severity:** Minor
- **Reviewer:** standards-enforcer
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** Terminology inconsistency: section header says "review round" but body uses "synthesis pass" and "passes" interchangeably.
- **Category:** terminology-drift

## Anti-Findings

- Don't flag the 3-pass cap as too low (it's appropriate for the current battery size)
- Don't flag the 50% durable check rate as too low (it's a starting threshold)
- Don't suggest removing convergence logic entirely (it solves a real problem)
