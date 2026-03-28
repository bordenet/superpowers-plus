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

## Scope Exclusions

- Single-step tasks (just do them)
- Pure bug fixes (use `investigation-state`)
- **Code features needing requirements + design phases** → use `feature-development` instead (it adds requirements-validation and design-triad phases that this skill omits)
- When a plan already exists and phases are already enrolled in TODO.md → use `todo-management` directly to resume execution

### Choosing Between `plan-and-execute` and `feature-development`

| Signal | Use This | Use `feature-development` |
|--------|----------|--------------------------|
| General-purpose challenge (process, research, docs) | ✅ | |
| Code feature needing formal requirements validation | | ✅ |
| Code feature needing design-triad (≥3 options) | | ✅ |
| Code or non-code work where you already know WHAT to build | ✅ | |
| Multi-phase work that needs stress-testing and retros | ✅ | |

---

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

**This phase is critical. Plans almost always have significant problems that surface here.**

Apply whichever combination of these tools makes sense to pressure-test the plan:

1. **Brainstorming** — Are there better approaches we haven't considered? Alternative phasing? Missing phases?
2. **Think-twice** — Dispatch a fresh sub-agent with zero context to review the plan. What did we miss?
3. **Harsh review** — Red-team the plan by answering these questions:
   - What's the weakest phase?
   - What dependency is wrong or missing?
   - What will fail first?
   - What assumption is untested?
   - What edge case breaks the whole plan?

Run **minimum 2 rounds** of stress-testing. Fix issues found, then re-review.

**If stress-testing reveals the plan is fundamentally broken** (the approach itself is wrong, not just needs tweaks — e.g., wrong decomposition, missing a critical phase, flawed sequencing), return to Phase B and replan. State clearly: "The plan needs to be reworked, not refined."

4. **Exit gate:** Plan has survived stress-testing. All issues that would change execution are resolved. User approves the final plan.

---

### Phase D: Phase Enrollment

1. **Name the project** — ask user for a project tag or generate one (kebab-case). Example: `#plan-auth-redesign`
2. **Enroll each phase as an autonomous TODO** via `todo-crud.sh`. "Autonomous" means: a fresh agent with no conversation history could pick up this TODO and execute it successfully. Each TODO must include:
   - **Purpose:** WHY this phase exists
   - **Trinity:** WHY / WHAT / HOW (with file paths, commands, concrete references — not vague gestures)
   - **Deliverables:** Concrete outputs (files, states, artifacts)
   - **Success Criteria:** Binary done/not-done, verifiable by command or inspection
   - **Quality Gate:** "Run progressive harsh review on deliverables before marking complete"
   - **Handoff State:** What the next phase needs to know (branch, last commit, partial work, gotchas)
3. Tag all TODOs with `#plan-<project-name>`
4. Order by dependency (not calendar)
5. Mirror to MCP task list via `add_tasks` with parent/child structure
6. **Exit gate:** All phases enrolled in TODO.md with full context. User confirms.

---

### Phase E: Execute (The Loop)

For each phase TODO, in order:

#### Step 1: Pre-Phase Retrospective

**Skip for the first phase.** For all subsequent phases:

Load `references/retrospective-template.md` and complete:

1. **What went well** in the last phase (keep doing)
2. **What didn't go well** (stop or change)
3. **What did progressive harsh review surface** that we didn't anticipate?
4. **Process improvement** — one concrete change to how we work
5. **Quality improvement** — one concrete change to what we check

**Persistence:** Summarize the retro's key findings (what changed, why) as a completion note via `todo-crud.sh complete --note "Retro: [1-3 sentence summary of findings and changes made to upcoming TODOs]"`. The full retro is in conversation context; the note captures enough for cross-session resumption.

#### Step 2: Improve Upcoming TODOs

Review EVERY remaining TODO in the `#plan-<project>` list:

1. Apply learnings from the retrospective
2. Drive **at minimum 2 substantive improvements across all remaining TODOs** (not 2 per TODO — distribute where they add real value). If a TODO genuinely needs no changes, state why and move on. Forced improvements become filler.
   - Sharpen success criteria based on what we learned
   - Add guards against failure modes we discovered
   - Improve the HOW based on what worked/didn't
   - Strengthen the quality gate based on harsh review findings
3. **Rewrite affected TODOs** via `todo-crud.sh` with improvements
4. **Harsh-review rewritten TODOs** before finalizing (are the improvements real? do they conflict with other phases?)

**Scaling note:** For projects with many remaining phases, focus improvement effort on the next 2-3 phases (highest impact). Scan later phases for applicability but don't force changes into distant phases that may themselves change.

#### Step 3: Execute the Phase

1. Re-read the TODO (it may have been improved by a prior retro)
2. Execute the work described in the TODO
3. Harsh-review all deliverables (same red-team questions as Phase C, applied to outputs not plans)
4. Verify success criteria are met
5. **Before committing:** Run the commit gate chain (gates 1–3 always, 4–5 when applicable): `pre-commit-gate` → `enforce-style-guide` → `progressive-code-review-gate` → `professional-language-audit` → `public-repo-ip-audit`. Your FIXES are new code — they need their own review.
6. Mark TODO complete via `todo-crud.sh` with completion notes

**If the phase fails** (deliverables don't meet criteria, blockers surface, harsh review finds critical issues): document what went wrong in the TODO note, run a retrospective immediately, and decide whether to retry the phase or trigger mid-execution replanning.

#### Step 4: Post-Phase Verification

1. Confirm deliverables exist and meet success criteria
2. Confirm handoff state is documented for the next phase
3. **Exit gate:** TODO marked complete, deliverables verified, handoff state captured

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
