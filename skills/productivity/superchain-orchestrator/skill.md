---
name: superchain-orchestrator
source: superpowers-plus
triggers: ["build this", "implement this", "create this", "make this work",
           "full chain", "superchain", "autonomous workflow",
           "do this end to end", "handle this completely"]
anti_triggers: ["just do it", "skip the workflow", "quick fix only", "no process"]
description: "Auto-detects task phase and chains skills autonomously: brainstorming → think-twice → design-triad → plan-and-execute → progressive-harsh-review → ship. User says 'build X' and the full chain engages without explicit skill names. Wraps feature-development with automatic phase detection and TODO enrollment."
summary: "Use when: user wants autonomous end-to-end execution. Detects phase, chains skills, ships."
coordination:
  group: productivity
  order: 0
  requires: []
  enables: ["brainstorming", "think-twice", "design-triad", "plan-and-execute",
            "progressive-harsh-review", "feature-development", "todo-management"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [task, goal, requirement, feature-request]
  produces: [implementation, tested-feature, completed-feature]
  capabilities: [orchestrates-workflow, auto-detects-phase, chains-skills]
  priority: 10
---

# Superchain Orchestrator

> **Purpose:** Autonomous end-to-end skill chaining. User says "build X" → full chain fires.
> **Pattern:** Phase detection → skill dispatch → quality gate → iterate → ship.

**Announce at start:** "I'm using the **superchain-orchestrator** to handle this end-to-end."

## When to Use

- User wants something built, implemented, or created without specifying process
- Any task that would benefit from the full brainstorm → design → plan → implement → review chain
- When you detect a multi-step task that isn't explicitly requesting a specific workflow

## When NOT to Use

- User says "skip the workflow", "just do it", or "quick fix only"
- Pure investigation/debugging (use `systematic-debugging` → `investigation-state`)
- Single-line changes or trivial edits
- Code review tasks (use `providing-code-review`)

## Phase Detection

Automatically detect the current phase based on context:

| Signal | Detected Phase | Chain From |
|--------|---------------|------------|
| No design exists, vague request | **Brainstorm** | Start of chain |
| Design exists but no plan | **Plan** | Skip brainstorm |
| Plan exists, TODOs enrolled | **Execute** | Skip brainstorm + plan |
| Implementation done, needs review | **Review** | Skip to review |
| Review passed, ready to ship | **Ship** | Skip to ship |

## The Chain

```
BRAINSTORM → FRESH PERSPECTIVE → DESIGN → HARSH REVIEW (design) →
PLAN → TODO ENROLLMENT → EXECUTE (per phase) → HARSH REVIEW (impl) → SHIP
```

### Phase 1: Brainstorm
**Invoke:** `brainstorming`
Explore intent, gather context, surface assumptions. Exit: clear understanding.

### Phase 2: Fresh Perspective
**Invoke:** `think-twice`
Sub-agent with zero context reviews the problem. Exit: blind spots addressed.

### Phase 3: Design
**Invoke:** `design-triad`
≥3 options, comparison matrix, selection with rationale. Exit: design selected.

### Phase 4: Harsh Review (Design)
**Invoke:** `progressive-harsh-review`
Three-persona adversarial review of the design. Score ≥6 to proceed.

### Phase 5: Plan
**Invoke:** `plan-and-execute` (Phase A-D only)
Break into phases, stress-test, enroll as TODOs. Exit: all phases in TODO.md.

### Phase 6: Execute
**Invoke:** `plan-and-execute` (Phase E)
Execute each TODO with retros between phases. Use `test-driven-development` for code.

### Phase 7: Harsh Review (Implementation)
**Invoke:** `progressive-harsh-review`
Three-persona review of ALL deliverables. Score ≥6 to proceed.

### Phase 8: Ship
**Invoke:** `verification-before-completion` + `pre-commit-gate`
Evidence-based completion. Commit, push, PR, merge (with user approval at each step).

## Skip Rules

| User Says | Skip To |
|-----------|---------|
| "I already know what to build" | Phase 3 (Design) |
| "Design is decided, just plan it" | Phase 5 (Plan) |
| "Plan exists, execute it" | Phase 6 (Execute) |
| "Code is done, review it" | Phase 7 (Review) |
| "skip the workflow" / "just do it" | Disable orchestrator entirely |

## Quality Gates

Every phase transition requires its gate to pass:
- Brainstorm → Design: clear requirements documented
- Design → Plan: design scored ≥6 by harsh review
- Plan → Execute: all phases enrolled as TODOs
- Execute → Ship: implementation scored ≥6 by harsh review
- Ship: all verification-before-completion checks pass

## Failure Modes

| Failure | Fix |
|---------|-----|
| Skipped brainstorm because task "seemed simple" | Simple tasks have unexamined assumptions — brainstorm anyway |
| Design harsh review scored <6 but proceeded anyway | REJECT means redesign. No exceptions. Chain to design-triad. |
| Executed without TODO enrollment | Go back to Phase 5 — TODOs enable session recovery |
| Implementation review scored <6 | Fix issues, re-review (min 2 rounds) |
| User said "just build it" and agent ran full chain | Respect anti_triggers — "just do it" = skip orchestrator |
