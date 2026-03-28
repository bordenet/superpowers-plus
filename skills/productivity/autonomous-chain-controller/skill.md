---
name: autonomous-chain-controller
source: superpowers-plus
triggers:
  - "build"
  - "implement"
  - "create feature"
  - "fix and ship"
  - "end to end"
  - "full workflow"
anti_triggers:
  - "build the matrix"
  - "build a table"
  - "simple one-liner"
description: >
  Meta-orchestrator that auto-detects required skill chain, executes with
  quality gates between steps, and auto-retries on failures. User says
  "build X" — this handles brainstorming through verification.
summary: "Use when: multi-step task. Skip when: single focused action."
coordination:
  group: orchestration
  order: 1
  requires: []
  enables: [brainstorming, design-triad, plan-and-execute, test-driven-development]
  escalates_to: [think-twice, failure-autopsy]
  internal: false
---

# Autonomous Chain Controller

> **Wrong skill?** Single action -> invoke directly. Planning only -> plan-and-execute.

**Announce at start:** "I am using the **autonomous-chain-controller** to orchestrate the full workflow."

## When to Use

- User gives vague task ("build X", "implement Y", "fix and ship Z")
- Task requires 3+ skills in sequence
- Full feature development lifecycle
- Multi-step refactoring

## Scope Exclusions

- Single-skill tasks -> invoke directly
- Planning without execution -> plan-and-execute
- Already mid-chain -> continue current

---

## Chain Protocol

### Phase 1: Classify

Task: [request]
Complexity: LOW (1-2) | MEDIUM (3-5) | HIGH (6+)
Chain: [ordered skill list]

### Phase 2: Select Chain

| Task Type | Chain |
|-----------|-------|
| New feature | brainstorming -> design-triad -> plan-and-execute -> TDD -> review -> verify |
| Bug fix | systematic-debugging -> TDD -> review -> verify |
| Refactor | blast-radius-check -> plan -> TDD -> review -> verify |
| Content | brainstorming -> plan -> harsh-review -> verify |
| Investigation | adversarial-search -> investigation-state -> autopsy |

### Phase 3: Execute with Gates

Between EVERY skill:
- [ ] Previous output correct?
- [ ] TODOs logged? (todo-guardian)
- [ ] No regressions? (measurement-integrity)
- [ ] Correct branch?

Gate failure: retry < 2 -> retry / retry >= 2 -> think-twice / retry >= 3 -> HALT

### Phase 4: Completion

All skills done + gates passed + verification + TODO sweep.

---

## Failure Detectors

| Detector | Signal | Action |
|----------|--------|--------|
| Premature completion | Remaining skills | Block -> resume |
| TODO amnesia | Unlogged items | Pause -> extract -> resume |
| Branch drift | Wrong branch | HALT -> fix -> resume |
| Gate cascade | 3x same failure | HALT -> autopsy -> escalate |
| Scope creep | >8 skills | Split into sub-chains |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Wrong chain | Output mismatch | Re-analyze, new chain |
| Chain too long | >8 skills | Split into 2 sub-chains |
| Missing skill | Reference missing | Skip + log TODO |
| Retry loop | Repeated failure | think-twice, then escalate |

## Companion Skills

- **plan-and-execute**: Planning within chain
- **brainstorming**: Options at chain start
- **design-triad**: Design selection
- **verification-before-completion**: Final gate
- **todo-guardian**: Between-gate enforcement
- **quantitative-decision-gate**: Branch-point decisions
- **failure-autopsy**: Chain failure post-mortem
