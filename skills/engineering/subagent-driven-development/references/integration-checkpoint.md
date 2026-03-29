# Integration Checkpoint Protocol

> **Purpose:** Verify parallel branches don't conflict after completion, before committing.
> **Executor:** Execution Conductor after all parallel implementers return.

## Checkpoint Steps

### 1. File Conflict Check

```javascript
For each file modified by any branch:
  If modified by >1 branch:
    diff = compute_diff(branchA.file, branchB.file)
    classify(diff):
      - "trivial": different sections of file (imports, adjacent functions) → auto-merge
      - "semantic": different implementations of same function → ESCALATE
      - "structural": conflicting structural changes (moved vs modified) → ESCALATE
```

| Conflict Type | Action |
|--------------|--------|
| No conflicts | Proceed to step 2 |
| Trivial only | Auto-merge; note in dispatch log |
| Semantic | Present both versions to user; ask which to keep |
| Structural | Serialize the conflicting pair; re-execute one branch |

### 2. Interface Consistency Check

Verify outputs from branch A can be consumed by branch B and vice versa:

```javascript
For each shared interface:
  Check: do exported function signatures match expectations?
  Check: do type definitions agree?
  Check: do import paths resolve?
```

| Result | Action |
|--------|--------|
| All interfaces consistent | Proceed to step 3 |
| Type mismatch | Fix in the branch that deviated from the plan |
| Missing export | Add the missing export; charge to the branch that should have produced it |

### 3. Test Integration

Run ALL tests — not just per-branch tests:

```text
1. Run unit tests for all modified packages
2. Run integration tests that cross branch boundaries
3. Run any existing end-to-end tests
```

| Result | Action |
|--------|--------|
| All tests pass | Proceed to review |
| Unit test failure in branch A's code | Fix in branch A (does not affect other branches) |
| Integration test failure | Identify which branch caused the regression; fix serially |
| Flaky test (passes on retry) | Note as flaky; do not block on it |

### 4. Review Gate

Apply standard spec compliance + quality review to the INTEGRATED result:

- Reviewer sees the merged output, not individual branches
- Review covers: code correctness, style, test quality, documentation
- Review does NOT re-evaluate the dispatch decision (that's the conductor's job)

### 5. Dispatch Log Entry

```json
{
  "checkpoint": "integration",
  "timestamp": "ISO-8601",
  "branches": ["task-1", "task-2"],
  "fileConflicts": { "trivial": 1, "semantic": 0, "structural": 0 },
  "interfaceChecks": { "passed": 3, "failed": 0 },
  "testResults": { "total": 47, "passed": 47, "failed": 0, "flaky": 1 },
  "reviewResult": "approved",
  "totalCheckpointDurationSeconds": 45
}
```

## Failure Recovery

| Failure | Recovery |
|---------|----------|
| Semantic file conflict | Pause. Present diffs to user. Accept their choice. |
| Interface mismatch | Identify deviant branch. Fix. Re-run integration tests. |
| Test regression | Identify regressor branch. Fix serially. Re-run all tests. |
| Multiple cascading failures | Abandon parallel result. Re-execute all tasks serially. Log failure. |
| Checkpoint cost exceeds 20% of total budget | Skip detailed review; do quick smoke test only. |

## When to Skip Checkpoint

- Only 1 branch completed (nothing to integrate)
- Branches modified zero overlapping files AND have no shared interfaces (pure isolation)
- User explicitly requests fast mode (at their own risk)
