# Multi-Agent Activation Rubric

> **Purpose:** Shared decision framework for all multi-agent-capable skills.
> **Default:** Single-agent. Multi-agent is escalation, not starting point.
> **Score:** 0–2 per signal. Activate multi-agent if total ≥ 5.

## Scoring

| Signal | 0 | 1 | 2 |
|--------|---|---|---|
| **Task decomposability** | Atomic (one thing) | 2–3 independent aspects | 4+ independent aspects |
| **Perspective diversity value** | Single perspective sufficient | 2 perspectives would help | Multi-dimensional problem |
| **Output comparability** | Hard to compare outputs | Partially comparable | Side-by-side natural |
| **Single-agent quality risk** | Confident it handles it | Moderate tunnel-vision risk | High risk of missed perspectives |
| **Cost justification** | Low-value task | Moderate value | High-value (gates other work) |

**Total ≥ 5 → multi-agent eligible** (skill-specific criteria may also apply).

## Anti-Activation Signals (any blocks multi-agent)

| Signal | Rationale |
|--------|-----------|
| Quick fix or small change | Overhead exceeds benefit |
| Tight coupling requiring sequential processing | Parallelism causes merge pain |
| Budget remaining < 30% | Can't afford parallel branches |
| User explicitly requests single-agent | Respect user intent |
| Previous multi-agent attempt produced duplicates | Evidence of ineffective forking |

## Skill-Specific Overrides

Each skill may add criteria that raise or lower the threshold:

### writing-plans
- **Raises score:** Task crosses team/domain boundaries (+1), significant rollback cost (+1)
- **Lowers score:** Task is internal-only with one stakeholder (-1)

### subagent-driven-development
- **Additional gate:** Fan-out eligibility rubric score ≥ 6 (file/interface/test/model isolation)
- **Merge-risk > 0.5 blocks parallelism** regardless of activation score

### brainstorming
- **Raises score:** Broad/ambiguous prompt (+1), architectural impact (+1)
- **Lowers score:** Known solution exists (-1), time-sensitive task (-1)

## Post-Activation Constraints

| Constraint | Value |
|-----------|-------|
| Max parallel branches | 4 |
| Max total cost vs single-agent | 2.5× |
| Per-branch token budget | 25% of total |
| Kill threshold | < 0.3 confidence |
| Max wall-clock per branch | 5 minutes |

## Decision Flow

```
Task arrives at multi-agent-capable skill
  │
  ├─ Anti-activation signal? → SINGLE-AGENT
  │
  ├─ Score activation rubric
  │   ├─ Score < 5 → SINGLE-AGENT
  │   ├─ Score ≥ 5 → check skill-specific criteria
  │   │   ├─ Skill criteria met → MULTI-AGENT
  │   │   └─ Skill criteria not met → SINGLE-AGENT (log why)
  │   └─ Score ≥ 5 + ambiguous → ask user
  │
  └─ During execution:
      ├─ Branch confidence < 0.3 → KILL branch
      ├─ Budget > 80% consumed → synthesize what we have
      └─ All branches complete → synthesize
```

## When NOT to Use Multi-Agent (explicit list)

1. Task is a bug fix with known root cause
2. Task is a simple refactor (rename, move, extract)
3. Task has a single correct answer (not judgment-dependent)
4. User said "just do it" or "quick"
5. Task is tightly coupled with ordering dependencies
6. Previous multi-agent run on similar task showed no improvement
