# Debugging Fork-Readiness Rubric

> **Purpose:** Decide whether to stay serial or fork into parallel investigation branches.
> **Default:** Serial. Forking is an escalation, not a starting position.
> **Reference:** See `skills/engineering/debug-conductor/` for the forked debugging implementation.

## Scoring (0–2 per signal, fork if total ≥ 6)

| Signal | 0 | 1 | 2 |
|--------|---|---|---|
| **Multiple domains** | Single domain (e.g., just code) | 2 plausible domains | 3+ domains (network + code + config) |
| **Investigation stalled** | Making progress | Slowed; 1 dead end | think-twice invoked; 2+ dead ends |
| **Cross-service** | Single service | 2 services | 3+ services in failure path |
| **Time pressure** | No production impact | Degraded but tolerable | Revenue/customer impact ongoing |
| **Multiple causes** | Single clear hypothesis | 2 plausible hypotheses | Evidence supports 3+ partial causes |

**Total ≥ 6 → fork.** Total < 6 → stay serial.

## Anti-Fork Signals (any one blocks forking)

| Signal | Rationale |
|--------|-----------|
| Clear error message → single root cause | Forking adds overhead with no benefit |
| Budget exhausted (>80% tokens consumed) | Can't afford parallel branches |
| Fewer than 2 hypothesis domains identified | 1 fork = serial with extra coordination cost |
| Previous fork on similar incident produced duplicates | Evidence of ineffective forking pattern |

## Post-Fork Constraints

| Constraint | Value | Enforcement |
|-----------|-------|-------------|
| Max concurrent investigators | 4 | Conductor hard limit |
| Max total branches | 6 | Conductor hard limit |
| Per-branch token budget | 25% of total | Kill branch at limit |
| Per-branch wall-clock limit | 5 minutes | Kill branch at limit |
| Min confidence to continue | 0.3 after first evidence | Kill if below threshold |
| Duplicate detection threshold | Jaccard >0.7 | Merge or kill overlap |
| Mandatory disconfirming evidence | 1 per branch | Branch incomplete without it |

## Decision Flow

```text
Incident arrives
  │
  ├─ Single service + clear error? → SERIAL (systematic-debugging)
  │
  ├─ Score rubric
  │   ├─ Score < 6 → SERIAL (systematic-debugging + think-twice if stalled)
  │   ├─ Score ≥ 6 + anti-fork signal → SERIAL (log why fork was blocked)
  │   └─ Score ≥ 6 + no anti-fork → FORK (debug-conductor)
  │
  └─ During investigation:
      ├─ Branch confidence < 0.3 → KILL branch
      ├─ Branch overlap > 0.7 → MERGE branches
      ├─ Budget > 80% consumed → STOP forking, synthesize what we have
      └─ Root cause ≥ 0.8 confidence → RESOLVE
```

## Examples

### Fork: Cross-service telephony + LLM failure

- Multiple domains: 2 (telephony signaling + LLM tool selection)
- Stalled: 1 (initial triage inconclusive)
- Cross-service: 2 (telephony gateway + LLM orchestrator + call router)
- Time pressure: 2 (calls dropping in production)
- Multiple causes: 1 (could be timeout OR tool failure)
- **Total: 8 → FORK**

### Stay serial: Single service config error

- Multiple domains: 0 (just config)
- Stalled: 0 (not started yet)
- Cross-service: 0 (single service)
- Time pressure: 1 (degraded but not critical)
- Multiple causes: 0 (error message points to config key)
- **Total: 1 → SERIAL**
