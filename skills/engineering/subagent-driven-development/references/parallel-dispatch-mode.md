# Parallel Dispatch Mode

> **Purpose:** Merge-risk-aware selective parallelism for subagent-driven-development.
> **Activation:** Fan-out eligibility rubric score ≥ 6 (task pair isolation analysis).
> **Default:** Sequential dispatch (existing behavior). Parallelism is opt-in per task pair.
> **Cost cap:** 2.5× single-agent tokens.

## When Parallel Dispatch Activates

Before dispatching implementer subagents, the Execution Conductor:

1. Extracts task list from the plan
2. For each pair of tasks, scores fan-out eligibility:

| Signal | 0 (Serial) | 1 (Maybe) | 2 (Parallel) |
|--------|------------|-----------|---------------|
| **File overlap** | Same files | Adjacent files (same dir) | Completely separate files |
| **Interface coupling** | Shared interfaces/APIs | Shared types only | Independent interfaces |
| **Test isolation** | Shared test fixtures | Partial overlap | Independent test files |
| **Data model coupling** | Same DB tables/models | Related models (FK) | Separate data domains |

**Pair score ≥ 6 → parallel eligible.** Score < 6 → serialize this pair.

**Merge-risk score:** `risk = 1 - (isolation_score / 8)`. Risk > 0.5 → force serial.

3. Build a dependency graph from pair scores
4. Identify parallelizable groups (tasks with no serial dependencies between them)
5. Announce dispatch strategy before executing

## Parallel Dispatch Protocol

### Step 1: Announce Strategy

"I'm using **parallel dispatch** for tasks [A, B, C] because they modify independent files/services. Tasks [D, E] will run serially because they share interfaces."

### Step 2: Enhanced Task Packets

Each parallel implementer receives the standard task packet PLUS:

```
PARALLEL CONTEXT:
- Other tasks running in parallel: [list with brief descriptions]
- Files you MUST NOT modify: [files owned by other branches]
- Interfaces you MUST NOT change: [shared interfaces]
- If you need to modify a shared file: STOP and report NEEDS_COORDINATION

INTEGRATION CONTRACT:
- Your expected outputs: [files, exports, test results]
- Integration checkpoint will verify: [what will be checked]
```

### Step 3: Monitor for Coordination Signals

During parallel execution, watch for:
- `NEEDS_COORDINATION` — branch discovered shared dependency → pause, re-analyze
- `NEEDS_CONTEXT` from branch about another branch's work → provide carefully, don't cross-contaminate
- `BLOCKED` on shared resource → serialize the blocked pair

### Step 4: Integration Checkpoint

After all parallel branches complete:

1. **File conflict check:** Did any branches modify the same files?
   - No conflicts → proceed to review
   - Trivial conflicts (imports, adjacent lines) → auto-merge
   - Semantic conflicts (different implementations of same function) → escalate to user

2. **Interface consistency:** Do outputs from branch A work as inputs to branch B?
   - Type check, import resolution, API compatibility

3. **Test integration:** Run ALL tests (not just per-branch tests)
   - All pass → proceed to review
   - Failures → identify which branch caused regression → fix serially

4. **Review:** Apply standard spec compliance + quality review to INTEGRATED result
   - Review gatekeeper sees the merged output, not individual branches

## Dispatch Decision Log

```json
{
  "decision": "parallel-dispatch",
  "tasks": [
    { "id": "task-A", "files": ["src/auth/"], "isolation_scores": { "task-B": 7, "task-C": 8 } },
    { "id": "task-B", "files": ["src/email/"], "isolation_scores": { "task-A": 7, "task-C": 6 } },
    { "id": "task-C", "files": ["tests/integration/"], "isolation_scores": { "task-A": 8, "task-B": 6 } }
  ],
  "parallel_groups": [["task-A", "task-B", "task-C"]],
  "serial_pairs": [],
  "rationale": "All pairs score ≥ 6; independent file domains"
}
```

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Parallel branches modify same file | Integration checkpoint git diff | Serialize conflicting pair; re-execute one branch |
| Interface mismatch between branches | Type check / import resolution | Fix in integration; charge to the branch that diverged |
| Test regression from integration | Test run after merge | Identify regressor; fix serially |
| Branch reports NEEDS_COORDINATION | Status code from implementer | Pause parallel; re-analyze dependency; serialize if needed |
| Cost exceeds 2.5× | Token tracking | No more parallel branches; finish remaining work serially |

## When NOT to Parallelize

Even if fan-out score ≥ 6:
- Total task count < 3 (parallelism overhead not worth it for 2 tasks)
- Previous parallel attempt on this codebase caused integration failures
- User requests serial execution
- Budget remaining < 40%
- Tasks involve database migrations (ordering matters)
