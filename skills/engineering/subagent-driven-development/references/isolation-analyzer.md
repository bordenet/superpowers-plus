# Task Isolation Analyzer

> **Purpose:** Score whether two tasks can safely run in parallel or must be serialized.
> **Used by:** Execution Conductor in `subagent-driven-development` before dispatching.

## Fan-Out Eligibility Rubric (Per Task Pair)

Score each pair of tasks 0–2 per signal. **Pair score ≥ 6 → parallel eligible.**

| Signal | 0 (Serial) | 1 (Maybe) | 2 (Parallel) |
|--------|------------|-----------|---------------|
| **File overlap** | Same files modified | Adjacent files (same directory) | Completely separate file trees |
| **Interface coupling** | Shared function signatures or APIs | Shared types/structs only | Independent interfaces |
| **Test isolation** | Shared test fixtures or test helpers | Partially overlapping test files | Completely separate test files |
| **Data model coupling** | Same DB tables or models | Related models (foreign key relationship) | Separate data domains |

## Analysis Protocol

### Step 1: Extract Task File Footprints

For each task in the plan:

1. Identify expected files to modify (from plan phase details)
2. Identify expected files to read (imports, dependencies)
3. Identify test files affected

### Step 2: Score Each Task Pair

For every pair (Task A, Task B):

```text
file_overlap = score_file_overlap(A.modifies, B.modifies)
interface_coupling = score_interface_coupling(A.interfaces, B.interfaces)
test_isolation = score_test_isolation(A.tests, B.tests)
data_coupling = score_data_coupling(A.models, B.models)

pair_score = file_overlap + interface_coupling + test_isolation + data_coupling
merge_risk = 1 - (pair_score / 8)
```

### Step 3: Build Dependency Graph

```markdown
If pair_score >= 6 AND merge_risk <= 0.5:
  → Edge: "parallel eligible"
If pair_score < 6 OR merge_risk > 0.5:
  → Edge: "must serialize"
```

### Step 4: Identify Parallel Groups

Tasks connected only by "parallel eligible" edges → parallelizable group.
Any "must serialize" edge → those tasks run sequentially.

### Step 5: Report

```json
{
  "taskCount": 5,
  "pairScores": [
    { "taskA": "task-1", "taskB": "task-2", "score": 7, "mergeRisk": 0.13, "verdict": "parallel" },
    { "taskA": "task-1", "taskB": "task-3", "score": 4, "mergeRisk": 0.50, "verdict": "serial" }
  ],
  "parallelGroups": [["task-1", "task-2"], ["task-4", "task-5"]],
  "serialChains": [["task-1", "task-3"]],
  "recommendation": "Dispatch tasks 1+2 in parallel, then task 3 serially, then tasks 4+5 in parallel"
}
```

## Scoring Details

### File Overlap Scoring

```markdown
shared_files = A.modifies ∩ B.modifies
If |shared_files| > 0: score = 0
If same_directory(A.modifies, B.modifies) but no shared files: score = 1
If completely_separate_trees(A.modifies, B.modifies): score = 2
```

### Interface Coupling Scoring

```bash
shared_signatures = functions/methods that A exports AND B calls (or vice versa)
If |shared_signatures| > 0: score = 0
shared_types = types/structs used by both A and B
If |shared_types| > 0 and |shared_signatures| == 0: score = 1
If no shared types or signatures: score = 2
```

### Test Isolation Scoring

```markdown
shared_test_files = A.test_files ∩ B.test_files
shared_fixtures = A.fixtures ∩ B.fixtures
If |shared_test_files| > 0 or |shared_fixtures| > 0: score = 0
If adjacent_test_dirs but no shared files: score = 1
If completely_separate_test_files: score = 2
```

### Data Model Coupling Scoring

```markdown
shared_tables = A.tables ∩ B.tables
related_tables = tables with FK relationships between A.tables and B.tables
If |shared_tables| > 0: score = 0
If |related_tables| > 0: score = 1
If no table overlap or FK relationship: score = 2
```

## Conservative Defaults

When analysis is uncertain:

- Unknown file overlap → assume 0 (serial)
- Dynamic imports or reflection → assume 0 (serial)
- Shared test utilities (e.g., `testutil/`) → assume 0 (serial)
- Database migrations → always serial (ordering matters)

## Merge-Risk Escalation

| Risk Score | Action |
|-----------|--------|
| 0.0–0.25 | Parallel with confidence |
| 0.25–0.50 | Parallel with integration checkpoint |
| 0.50–0.75 | Serial recommended (flag to user if they want to override) |
| 0.75–1.0 | Serial required (no override) |
