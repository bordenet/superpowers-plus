---
name: autonomous-chain-controller
source: superpowers-plus
disable-model-invocation: true
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
description: "Meta-orchestrator that auto-detects required skill chain, admits actions against phase acceptance, and stops unchanged failures. User says \"build X\" — this handles brainstorming through verification."
summary: "Use when: multi-step task. Skip when: single focused action."
coordination:
  group: orchestration
  order: 1
  requires: []
  enables: [brainstorming, debate, plan-and-execute, test-driven-development]
  escalates_to: [think-twice, failure-autopsy]
  internal: false
composition:
  consumes: [goal, phased-plan]
  produces: [todo-items, implementation]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 3
---

# Autonomous Chain Controller

> **Wrong skill?** Single action -> invoke directly. Planning only -> plan-and-execute.

**Announce at start:** "I am using the **autonomous-chain-controller** to orchestrate the full workflow."

## Execution control

An independent execution controller owns phase acceptance and may STOP scope
expansion. This role is separate from implementation and code review; use a
fresh agent for a drift exception or disputed acceptance, not every action.
Routine decisions use the deterministic `tools/execution-admission.py` gate.

Before a managed edit, check or review, register the active phase, its open
acceptance criterion, exact patch paths or check argv/selector, and proof inputs
in the private execution-control registry. Invoke admission with the actual
request before execution. Missing ownership, stale prerequisite fingerprints,
unrelated selectors and successor work before predecessor acceptance STOP.
Close criteria only against their required evidence. Reuse unchanged proof.
The ledger records costs and exceptions; it cannot substitute for admission.
Unsupported host boundaries remain UNENFORCED in the support matrix.

## When to Use

- User gives vague task ("build X", "implement Y", "fix and ship Z")
- Task requires 3+ skills in sequence
- Full feature development lifecycle
- Multi-step refactoring

### Example

```bash
# Example: Chain selection for "build login page"
echo "Task: build login page"
echo "Complexity: MEDIUM (5 skills)"
echo "Chain: brainstorming -> debate -> plan-and-execute -> TDD -> verify"
echo "Gate 1: brainstorming output has >=3 options? YES"
echo "Gate 2: debate scored all options? YES"
echo "Gate 3: plan has phases? YES -> continue"
```

## Chain Protocol

### Phase 1: Classify

Task: [request]
Complexity: LOW (1-2) | MEDIUM (3-5) | HIGH (6+)
Chain: [ordered skill list]

### Phase 2: Select Chain

| Task Type | Chain |
|-----------|-------|
| New feature | brainstorming -> debate -> plan-and-execute -> TDD -> review -> verify |
| Bug fix | systematic-debugging -> TDD -> review -> verify |
| Distributed incident | debug-conductor -> (investigators forked) -> evidence-adjudicator -> failure-autopsy |
| Refactor | blast-radius-check -> plan -> TDD -> review -> verify |
| Content | brainstorming -> plan -> harsh-review -> verify |
| Investigation | adversarial-search -> investigation-state -> autopsy |

### Phase 3: Execute with Gates

Before every managed action, run action admission against the active phase
and its open acceptance criterion. Check actual patch paths or exact check
argv; a TODO count or the next skill in a chain is insufficient evidence.
Before every automated review or test/check pass, obtain the native snapshot-
bound REUSE, WAIT, RUN_MINIMAL, REVIEW_REQUIRED or STOP strategy decision.

A failed or interrupted unchanged attempt STOPs. Preserve evidence and diagnose
the owning gap; retry only changed inputs or an explicitly authorized bounded
diagnostic. Do not restart prior clean skills. Accept predecessor criteria from
verified evidence before admitting the next phase.

### Phase 4: Completion

All skills done + gates passed + verification + TODO sweep.

---

## Failure Detectors

| Detector | Signal | Action |
|----------|--------|--------|
| Premature completion | Remaining skills | Block -> resume |
| TODO amnesia | Unlogged items | Pause -> extract -> resume |
| Branch drift | Wrong branch | HALT -> fix -> resume |
| Gate failure | Unchanged failed inputs | STOP before another attempt; diagnose owning gap |
| Scope creep | >8 skills | Split into sub-chains |

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Skipped gate | Missing admission or evidence | STOP; run only missing required coverage |
| Wrong chain selected | Output mismatches task | Re-classify, new chain |
| Premature completion | Skills remaining | Block until all complete |
| Scope creep | >8 skills in chain | Split into sub-chains |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Wrong chain | Output mismatch | Re-analyze, new chain |
| Chain too long | >8 skills | Split into 2 sub-chains |
| Missing skill | Reference missing | Skip + log TODO |
| Retry loop | Unchanged attempt proposed | Refuse before execution; independent controller resolves exception |

## Companion Skills

- **plan-and-execute**: Planning within chain
- **brainstorming**: Options at chain start
- **debate**: Design selection
- **verification-before-completion**: Final gate
- **todo-guardian**: Between-gate enforcement
- **quantitative-decision-gate**: Branch-point decisions
- **failure-autopsy**: Chain failure post-mortem
