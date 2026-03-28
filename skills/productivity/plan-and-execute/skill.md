---
name: plan-and-execute
source: superpowers-plus
triggers: ["plan and execute", "plan-and-execute", "challenge me", "give me a challenge",
           "here's a challenge", "devise a plan", "phased execution", "break into phases",
           "execute in phases", "plan then execute", "structured execution",
           "project plan with phases", "plan with retrospectives", "measure twice cut once",
           "stress-test the plan", "divide into phases", "autonomous phases", "phased TODO",
           "plan phases", "big project", "organize this work", "tackle this problem",
           "let's do this systematically", "multi-phase project", "plan out this", "plan the implementation", "execute implementation plan"]
anti_triggers: ["brainstorm", "design options", "what should we build"]
description: "General-purpose orchestrator for challenge → plan → stress-test → phased execution. Produces a plan, stress-tests it with brainstorming + think-twice + progressive harsh review, then enrolls each phase as an autonomous TODO with deliverables, success criteria, and built-in quality gates. Between phases, runs structured retrospectives that drive improvements into all upcoming TODOs before execution continues."
summary: "Use when: tackling any multi-phase challenge that benefits from structured planning, stress-testing, and continuous improvement during execution."
coordination:
  group: productivity
  order: 1
  requires: []
  enables: ["brainstorming", "think-twice", "todo-management", "plan-quality-gates"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [challenge, problem-statement, goal, project-brief]
  produces: [phased-plan, todo-items, retrospective-notes]
  capabilities: [orchestrates-workflow, sequences-skills, continuous-improvement]
  priority: 5
---

# Plan and Execute

> **Wrong skill?** Brainstorming ideas → `brainstorming`. Design comparison → `design-triad`. Feature workflow → `feature-development`.

> **Purpose:** Turn any challenge into a stress-tested, phased plan — then execute each phase as an autonomous TODO with built-in quality gates and continuous improvement between phases.
> **Pattern:** This skill ORCHESTRATES existing skills. It does not replace them.

**Announce at start:** "I'm using the **plan-and-execute** skill to orchestrate this work."

## When to Use

- Any multi-phase challenge (code, process, research, documentation, design)
- Work that benefits from structured planning before execution
- Projects where plan quality directly impacts outcome quality
- When the user says "let's plan this out" or "break this into phases"

## The Workflow

```
Phase A: CHALLENGE INTAKE → Phase B: PLAN → Phase C: STRESS-TEST →
Phase D: PHASE ENROLLMENT → Phase E: EXECUTE (retro → improve → do → review)
```

---

### Phase A: Challenge Intake

1. Receive the challenge from the user
2. Clarify scope, constraints, and success criteria
   - Ask clarifying questions one at a time (like `brainstorming`)
   - OR accept an autonomous mandate — either mode works
3. Restate the challenge back to confirm understanding
4. **Exit gate:** User confirms the challenge statement is accurate

---

### Phase B: Devise the Plan

1. Produce a plan that addresses the challenge
   - Interactive co-development OR autonomous drafting — match user's mode
2. Structure the plan as ordered phases with dependency relationships
3. Each phase must state: purpose, deliverables, and exit criteria
4. Apply `plan-quality-gates`: no fabricated timelines, dependency ordering, verifiable exit criteria
5. **Exit gate:** Plan exists with phases, dependencies, and exit criteria

---

### Phase C: Stress-Test the Plan

**Critical — plans almost always have problems that surface here.** Minimum 2 rounds.

Tools: **brainstorming** (better approaches?), **think-twice** (fresh-eyes review), **harsh review** (weakest phase? wrong dependency? untested assumption?).

If fundamentally broken → return to Phase B. Fix → "reworked, not refined."

**Exit gate:** Plan survived stress-testing. User approves.

---

### Phase D: Phase Enrollment

Name project (`#plan-<name>`). Enroll each phase as autonomous TODO via `todo-crud.sh`. Each TODO: Purpose, Trinity (WHY/WHAT/HOW with concrete paths), Deliverables, Success Criteria (binary), Quality Gate, Handoff State. Tag `#plan-*`, order by dependency. Mirror to MCP `add_tasks`.

**Exit gate:** All phases enrolled with full context. User confirms.

---

### Phase E: Execute (The Loop)

For each phase TODO, in order:

#### Step 1: Pre-Phase Retrospective (skip phase 1)

Load `references/retrospective-template.md`. Complete: what went well, what didn't, what harsh review surfaced, one process improvement, one quality improvement. Persist key findings via `todo-crud.sh complete --note "Retro: ..."`.

#### Step 2: Improve Upcoming TODOs

Apply retro learnings to remaining `#plan-*` TODOs. ≥2 substantive improvements across all remaining TODOs (not forced per-TODO). Focus on next 2-3 phases. Harsh-review rewritten TODOs.

#### Step 3: Execute the Phase

1. Re-read TODO → execute → harsh-review deliverables → verify criteria
2. **Commit gate chain:** `pre-commit-gate` → `enforce-style-guide` → `progressive-code-review-gate` → `professional-language-audit` → `public-repo-ip-audit`
3. Mark complete. **If phase fails:** document, immediate retro, decide retry vs replan.

#### Step 4: Post-Phase Verification

Confirm deliverables meet criteria + handoff state documented for next phase.

---

## Phase Skip Prevention

**You MUST NOT skip phases.** The stress-test phase (C) is where most value is created.

| Temptation | Why It Fails |
|-----------|-------------|
| "The plan is obvious" | Obvious plans have unexamined assumptions |
| "Stress-testing is overkill" | Plans almost always have significant problems found here |
| "Retrospectives slow us down" | They systematically improve every subsequent phase |
| "The TODOs are fine as-is" | Pre-execution improvement is the whole point |
| "Just one round of review" | Minimum 2 rounds. First round finds surface issues; second finds structural ones |

## Replanning & Resuming

See [`references/replanning-and-resuming.md`](references/replanning-and-resuming.md) for mid-execution replanning and session resumption procedures.

---

## Integration Map

See [`references/integration-map.md`](references/integration-map.md) for the full phase→skill mapping.

## Example

```bash
# Enroll plan TODOs after stress-testing
todo-crud.sh add --priority P2 --tag "#plan-auth-redesign" --title "Phase 1: Migrate OAuth provider"
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Stress-test skipped | Phase C is mandatory — minimum 2 review rounds |
| Shallow retros / cosmetic TODO improvements | Findings and changes must be concrete and substantive; persist via todo-crud.sh |
| Harsh review on deliverables skipped | Quality gate is embedded in every TODO and commit gate chain — not optional |
| Plan broken but execution continues | Mid-execution replanning: defer remaining TODOs, return to Phase B |

## Companion Skills

- **brainstorming**: Generating plan options · **design-triad**: Evaluating alternatives
- **feature-development**: Full feature workflow · **todo-management**: Task persistence
- **requirements-validation**: Validating plan inputs · **plan-quality-gates**: Exit criteria
- **innovation**: Creative problem-solving · **fallback-planning**: Contingency plans
- **subagent-driven-development**: Multi-agent task dispatch
- **autonomous-chain-controller**: Full workflow orchestration
