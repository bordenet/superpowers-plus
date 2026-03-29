# Multi-Agent Quality Standards

> **Purpose:** Shared quality rubrics, readability rules, fallback behavior, instrumentation specs,
> and "NOT to use" criteria across all multi-agent-capable skills.

## 1. Plan Quality Rubric (plan-and-execute council output)

Score each dimension 0–2. **Minimum passing score: 7/10.**

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| **Completeness** | Missing sections (no risk or test plan) | All sections present but thin | All sections substantive with cross-references |
| **Coherence** | Contradictions between sections | Minor inconsistencies | Internally consistent; architecture matches tests matches risks |
| **Coverage** | Risks don't map to architecture; tests don't cover components | Partial mapping | Every component has risk assessment AND test strategy |
| **Actionability** | Vague next steps ("implement the thing") | Some concrete tasks, some vague | Every phase has deliverables, exit criteria, and owner |
| **Readability** | Wall of text; no structure | Structured but verbose | Scannable; each section ≤1 page; clear headers |

**If score < 7:** Synthesis failed. Fall back to single-agent and note failure.

## 2. Readability Requirements (all multi-agent output)

| Rule | Threshold | Enforcement |
|------|-----------|------------|
| Total output length | ≤ 2× single-agent equivalent | Synthesis must cut if exceeded |
| Per-idea description | ≤ 3 sentences + 1 tradeoff bullet | Lens/role mandates enforce this |
| Section headers | Required every 5–10 lines | Template enforces structure |
| Metadata section | Required at end of every multi-agent output | Shows lenses/roles, costs, conflicts |
| No "lens voice" leaking | Output reads as one author | Synthesis quality check |

## 3. Fallback Behavior

When multi-agent mode cannot complete successfully:

| Trigger | Fallback | User Message |
|---------|----------|-------------|
| Activation score = 5 (borderline) | Ask user: "This task is borderline — use multi-agent or stay single?" | Transparent choice |
| Sub-agent unavailable | Single-agent mode | "Multi-agent mode unavailable; proceeding with single-agent." |
| All branches < 0.3 confidence | Kill all branches; single-agent retry | "Multi-agent branches produced low-confidence results. Retrying single-agent." |
| Budget exceeded before synthesis | Synthesize available outputs | "Budget limit reached. Synthesizing partial results from N of M branches." |
| Synthesis produces score < 7 | Discard synthesis; present best single branch | "Synthesis quality below threshold. Presenting strongest individual branch." |
| Merge conflict in parallel dispatch | Serialize conflicting pair; retry | "Parallel branches conflicted. Re-executing serially." |

**Non-negotiable:** User is NEVER left in a broken state. Every failure mode has a recovery path.

## 4. Novelty Scoring (brainstorming ensemble)

Score each idea 0–3 on novelty:

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | **Obvious** — any single-agent would suggest this | "Add a loading spinner" |
| 1 | **Standard** — common solution, but worth including | "Use feature flags for rollout" |
| 2 | **Insightful** — non-obvious but well-reasoned | "Existing webhook infra can replace custom notification system" |
| 3 | **Novel** — surprising, challenges assumptions | "Don't build this at all; the problem resolves with existing tooling" |

**Ranking boost:** novelty × 0.5 added to feasibility × impact score.
**Novelty bias guard:** Ideas scoring novelty=3 but feasibility=L are flagged as "interesting but risky," not ranked #1.

## 5. Instrumentation Spec (all multi-agent skills)

Every multi-agent invocation MUST log:

```json
{
  "skill": "brainstorming | plan-and-execute | subagent-driven-development",
  "mode": "single-agent | multi-agent",
  "activationRubricScore": 7,
  "activationDecision": "multi-agent",
  "rolesActivated": ["product", "architecture", "reliability", "contrarian"],
  "rolesSkipped": ["security"],
  "skipReason": "Not relevant — internal tool, no external data exposure",
  "perBranch": [
    { "role": "product", "tokensUsed": 1200, "wallClockSec": 15, "confidence": 0.8 },
    { "role": "architecture", "tokensUsed": 1500, "wallClockSec": 20, "confidence": 0.75 }
  ],
  "synthesis": {
    "duplicatesDetected": 2,
    "conflictsResolved": 1,
    "unresolvedTradeoffs": 0,
    "outputQualityScore": 8,
    "tokensUsed": 800,
    "wallClockSec": 10
  },
  "totalTokens": 4700,
  "costRatio": 1.4,
  "fallbackTriggered": false,
  "timestamp": "ISO-8601"
}
```

## 6. Duplicate-Effort Detection (subagent-driven-dev parallel dispatch)

Before committing parallel branch outputs:

```markdown
For each pair of completed branches (A, B):
  file_overlap = files_modified(A) ∩ files_modified(B)
  If |file_overlap| > 0:
    For each shared file:
      diff_A = changes_by_A(file)
      diff_B = changes_by_B(file)
      If diff_A ≈ diff_B (>80% line overlap):
        → DUPLICATE: keep branch with more tests, discard other
      If diff_A conflicts with diff_B:
        → CONFLICT: escalate to integration checkpoint
      If diff_A and diff_B touch different sections:
        → COMPATIBLE: auto-merge
```

## 7. Conflict Handling (subagent-driven-dev parallel dispatch)

| Conflict Type | Detection | Resolution |
|--------------|-----------|-----------|
| **Import conflicts** | Same file, different imports added | Auto-merge: combine import lists |
| **Adjacent changes** | Same file, different functions modified | Auto-merge: no semantic conflict |
| **Semantic conflict** | Same function modified differently | Escalate: present both to user |
| **Test conflict** | Same test file, different assertions | Escalate: likely indicates interface mismatch |
| **Type mismatch** | Branch A expects type X, branch B produces type Y | Fix: align to planned interface; charge to deviant branch |

## 8. Review Gate Integration (subagent-driven-dev parallel dispatch)

Apply `progressive-code-review-gate` at TWO points:

1. **Per-branch review** (before integration): Each branch passes quality review independently
2. **Post-integration review** (after merge): Integrated result passes review as a whole

**Cost management:** If branch count × review cost exceeds 30% of total budget, do post-integration review only and skip per-branch review. Document the skip in dispatch log.

## 9. "NOT to Use" Criteria (explicit, all skills)

Multi-agent MUST NOT activate when:

| Criterion | Applies To | Rationale |
|-----------|-----------|-----------|
| Task is a bug fix with known root cause | All | Single path; no perspective diversity needed |
| Task is a simple refactor (rename, move, extract) | All | Tightly coupled; parallelism causes merge pain |
| Task has a single correct answer | All | No judgment diversity value |
| User says "just do it" or "quick" | All | Speed > quality exploration |
| Task is tightly coupled with ordering dependencies | subagent-driven-dev | Parallelism would cause integration hell |
| Previous multi-agent run on similar task showed no improvement | All | Evidence says it doesn't help |
| Budget remaining < 30% | All | Can't afford parallel branches |
| Task is time-sensitive | brainstorming | Over-brainstorming wastes time |
| Task has a known solution | brainstorming | No ideation value |
