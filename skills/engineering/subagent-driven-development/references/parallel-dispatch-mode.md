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

1. Build a dependency graph from pair scores
2. Identify parallelizable groups (tasks with no serial dependencies between them)
3. Announce dispatch strategy before executing

## Parallel Dispatch Protocol

### Step 1: Announce Strategy

"I'm using **parallel dispatch** for tasks [A, B, C] because they modify independent files/services. Tasks [D, E] will run serially because they share interfaces."

### Step 2: Enhanced Task Packets

Each parallel implementer receives the standard task packet PLUS:

```text
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

## Dynamic Re-Serialization (SD-11)

During parallel execution, the conductor may dynamically convert parallel branches to serial:

**Runtime re-serialization triggers** (while branches are still executing):

1. Branch reports `NEEDS_COORDINATION` for a file owned by another active branch

> **Only `NEEDS_COORDINATION` is a runtime trigger.** It is detectable during execution because the branch itself reports it when it discovers it needs to modify a file outside its assignment.

**Post-completion conflict triggers** (after branches finish, at integration checkpoint):

- Interface mismatches detected via type checking → handled by **Rollback Protocol (SD-13)**
- Semantic conflicts detected by integration checkpoint → handled by **Rollback Protocol (SD-13)**

**Runtime protocol:**

1. **Pause** the conflicting pair (not all branches)
2. **Re-score** the paused pair using the isolation rubric with updated file ownership data
3. If new score < 6 → **serialize**: complete branch A first, then restart branch B with branch A's output as context
4. If new score ≥ 6 → **resume parallel** with updated file boundaries communicated to both branches
5. Log re-serialization event with reason, affected branches, and time cost

**Guardrails:**

- Maximum 2 runtime re-serializations per dispatch. On the 3rd trigger, fall back to fully serial for all remaining work.
- Re-serialization adds overhead. If cumulative re-serialization time > 50% of parallel time saved, switch to fully serial and note "parallelism not effective for this task."
- Budget enforcement (80% warn, 100% kill) is handled by **Branch Budgets (SD-12)**, not re-serialization.

## Branch Budgets (SD-12)

Per-branch token budgets prevent runaway parallel branches from consuming the session:

**Budget allocation:**

- Total parallel budget = 2.5× single-agent estimate (unchanged cost cap)
- Per-branch budget = `total_parallel_budget / active_branch_count`
- Maximum 4 branches (per conductor limits), so minimum per-branch is 25% of total

**Enforcement:**

1. Each branch receives its budget in the task packet
2. At 80% of branch budget: warn branch ("80% budget used — wrap up or request extension")
3. At 100% of branch budget: **hard kill** — branch must produce whatever partial result it has
4. Killed branches are logged with partial results and `status: "budget_exceeded"`

**Reallocation:** If a branch completes under budget, its remainder is redistributed equally to active branches. This incentivizes efficient branches without penalizing complex ones.

**Extension protocol:** A branch can request a one-time 25% extension by reporting `NEEDS_EXTENSION` with justification. The conductor grants only if total budget allows and no other branch is starving.

## Rollback Protocol (SD-13)

When parallel integration fails, the conductor can roll back branch work:

> **Ownership:** The integration checkpoint (see `integration-checkpoint.md`) detects conflicts and presents choices to the user. This rollback protocol defines the **recovery actions** available once a conflict decision is made. The user (not the conductor) decides whether to rollback.

**Rollback triggers** (all require user confirmation):

1. Integration checkpoint finds irreconcilable semantic conflicts and user chooses rollback
2. Integrated test suite fails and failure can't be attributed to a single branch
3. User explicitly rejects the integrated result

**Rollback levels:**

| Level | Action | When |
|-------|--------|------|
| **Branch rollback** | Discard one branch's changes; keep others | Single branch caused regression |
| **Pair rollback** | Discard both conflicting branches; re-execute serially | Semantic conflict between exactly 2 branches |
| **Full rollback** | Discard all parallel work; re-execute entire plan serially | >2 branches in conflict or integration fundamentally broken |

**Protocol:**

1. Identify failure scope (single branch, pair, or full)
2. `git stash` or `git branch -D` the affected work (preserve in reflog for forensics)
3. Re-execute affected tasks serially, providing the failure as context: "Previous parallel attempt failed because [reason]. Avoid [specific pattern]."
4. Log rollback event with: affected branches, failure reason, recovery strategy, time cost

**Limitation:** Rollback is manual — the conductor instructs the user or executing agent on git operations. Automated git manipulation is out of scope for safety.

## Metric Collection (SD-14)

Structured metrics for evaluating parallel dispatch effectiveness:

**Per-dispatch metrics** extend the shared instrumentation schema (`multi-agent-quality-standards.md` §5). The shared fields (`skill`, `mode`, `activationRubricScore`, etc.) are required; these are additional fields for parallel dispatch:

```json
{
  "skill": "subagent-driven-development",
  "mode": "multi-agent",
  "activationRubricScore": 7,
  "activationDecision": "multi-agent",
  "rolesActivated": ["taskA", "taskB", "taskC"],
  "rolesSkipped": ["taskD"],
  "skipReason": "Tight coupling with taskA; serialized",
  "perBranch": [
    { "role": "taskA", "tokensUsed": 1200, "wallClockSec": 15, "confidence": 0.9 },
    { "role": "taskB", "tokensUsed": 900, "wallClockSec": 12, "confidence": 0.85 }
  ],
  "synthesis": {
    "duplicatesDetected": 0,
    "conflictsResolved": 0,
    "unresolvedTradeoffs": 0,
    "outputQualityScore": 8,
    "tokensUsed": 200,
    "wallClockSec": 3
  },
  "totalTokens": 4700,
  "costRatio": 1.34,
  "fallbackTriggered": false,
  "timestamp": "ISO-8601",
  "dispatchExtension": {
    "strategy": "parallel",
    "parallelGroups": [["taskA", "taskB"], ["taskC"]],
    "serialTasks": ["taskD"],
    "isolationAnalysisMs": 200,
    "integrationCheckpointMs": 5000,
    "reSerializations": 0,
    "rollbacks": 0,
    "testPassRate": 1.0
  }
}
```

**Aggregation:** After 5+ dispatches, the conductor can compute:

- Average cost ratio (parallel vs serial)
- Re-serialization frequency (high → isolation analysis needs tuning)
- Rollback frequency (high → parallelism threshold should be raised)
- Time savings (wall-clock parallel vs estimated serial)

**Dashboard:** No dashboard exists yet. Metrics are logged inline and can be extracted by searching dispatch logs. A future aggregation tool could consume these JSON entries.

## "Stop and Ask" Threshold (SD-15)

For isolation score 5 (the only ambiguous score), the conductor asks the user instead of guessing:

> **Alignment with isolation-analyzer:** Score ≥ 6 AND merge risk ≤ 0.5 → parallel. Score < 5 → serial (per isolation-analyzer Step 3). Score = 5 is the ambiguous zone where the analyzer says "must serialize" but the task may be parallelizable with checkpoints.

**Protocol:**

1. Isolation score ≥ 6 AND merge risk ≤ 0.5 → auto-parallel (no prompt)
2. Isolation score ≤ 4 → auto-serial (no prompt)
3. Isolation score = 5 → **stop and ask**:

```text
These tasks have moderate coupling (isolation score: 5/8, merge risk: {risk}):
- Task A: modifies {files_A}
- Task B: modifies {files_B}
- Overlap: {shared_files_or_interfaces} ({N} shared files)
- Estimated time: parallel ~{X}min, serial ~{Y}min

I can:
  (a) Run them in parallel with integration checkpoints (faster by ~{delta}min, risk: integration conflict)
  (b) Run them serially (safer, no conflict risk)

My recommendation: {serial|parallel} because {reason}.
Which do you prefer?
```

**Response handling:**

| User Response | Action |
|---------------|--------|
| "a", "parallel", "go parallel" | Proceed parallel with checkpoints |
| "b", "serial", "go serial" | Proceed serial |
| "your call", "you decide", "whichever" | Use conductor's recommendation |
| "explain more", "why?", "what's the overlap?" | Provide detail on shared files/interfaces, then re-ask |
| "parallel if tests pass first" (conditional) | Run tests first; if pass → parallel, else serial |
| Unrecognizable / off-topic | Clarify once: "I need to know: parallel (a) or serial (b)?" |
| No response / silence | Default to serial (conservative) |

**Learning:** After the user's choice and the outcome, log: `{ score, mergeRisk, userChoice, outcome: "success|conflict" }`. Over time, this data can calibrate whether score=5 should default to parallel or serial.

**Skip mode:** User can set `PARALLEL_DISPATCH_MODE=auto` to skip all prompts and use the conductor's recommendation. Default is `ask` for score 5.

## When NOT to Parallelize

Even if fan-out score ≥ 6:

- Total task count < 3 (parallelism overhead not worth it for 2 tasks)
- Previous parallel attempt on this codebase caused integration failures
- User requests serial execution
- Budget remaining < 30% (see `multi-agent-activation-rubric.md` for canonical threshold)
- Tasks involve database migrations (ordering matters)
