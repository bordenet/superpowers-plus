---
name: feature-development
source: superpowers-plus
triggers: ["start feature", "new feature", "feature development workflow",
           "build a feature", "implement feature", "feature from scratch",
           "full development workflow"]
description: Orchestrates the full feature development lifecycle from requirements through completion. Sequences existing skills (requirements-validation, design-triad, todo-management, completeness-check) so no phase is skipped.
summary: "Use when: starting a new feature that needs requirements, design, implementation, and testing."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: ["requirements-validation", "design-triad", "todo-management",
            "completeness-check", "verification-before-completion"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [feature-request, user-story, requirement]
  produces: [implementation, tested-feature, completed-feature]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 5
---

# Feature Development Workflow

> **Purpose:** Orchestrate the full feature development lifecycle so no phase is skipped.
> **Pattern:** This skill SEQUENCES existing skills — it does not replace them.

**Announce at start:** "I'm using the **feature-development** skill to orchestrate this workflow."

## When to Use

- Starting a new feature from requirements
- Building a feature that needs design decisions
- Any multi-phase development work (not bug fixes — use `investigation-state` for those)

## When NOT to Use

- Quick bug fixes (use `investigation-state`)
- Pure refactors (use `design-triad` directly)
- Documentation-only changes

---

## The Workflow

```
Phase 1: REQUIREMENTS → Phase 2: DESIGN → Phase 3: PLAN →
Phase 4: IMPLEMENT → Phase 5: VERIFY → Phase 6: COMPLETE
```

Each phase has an **exit gate** — you cannot proceed until the gate passes.

---

### Phase 1: Requirements Gathering

**Invoke:** `requirements-validation`

1. Capture what the user wants built
2. Write requirements as testable statements
3. Run falsifiability, measurability, and independence tests
4. Resolve contradictions (surface, don't suppress)
5. **Exit gate:** All requirements pass validation. No unresolved contradictions.

---

### Phase 2: Design

**Invoke:** `design-triad`

1. Generate ≥3 genuinely distinct design options
2. Build comparison matrix (≤5 criteria)
3. Evaluate options against requirements from Phase 1
4. Run harsh red-team review (min 2 rounds)
5. Select winning design with documented rationale
6. **Exit gate:** Design selected, review passed, edge cases addressed.

---

### Phase 3: Plan

**Invoke:** `todo-management`

1. Break the selected design into implementation phases
2. Each phase becomes a TODO with:
   - **Purpose:** Why this phase exists
   - **Trinity:** WHY / WHAT / HOW
   - **Success Criteria:** Binary done/not-done
3. Tag all TODOs with `#plan-<feature-name>`
4. Order phases by dependency (not calendar)
5. For each phase, identify a fallback approach
6. **Pre-phase improvement pass:** Before starting each phase, identify ≥2 improvements to the upcoming TODO
7. **Exit gate:** All phases written to TODO.md with success criteria.

---

### Phase 4: Implement

For each phase from the plan:

1. **Pre-flight:** Re-read the TODO, check for stale assumptions
2. **Implement:** Write code, following existing conventions
3. **Test:** Write tests that exercise the success criteria
4. **Self-review:** Run `adversarial-search` — search for what could be WRONG
5. **Prepare commit:** Stage changes, verify pre-commit gates pass (commit only with user approval)
6. **Mark TODO complete** with progress note
7. **Exit gate:** Tests pass, TODO marked complete, no regressions.

---

### Phase 5: Verify

**Invoke:** `completeness-check` then `verification-before-completion`

1. Run completeness audit (18 detection categories)
2. Score must be ≥90 — this is a **policy choice** stricter than the default ≥70; adjust per team norms
3. Run verification-before-completion checks
4. **Exit gate:** Completeness score meets threshold, no blocking findings.

---

### Phase 6: Complete

1. Update README/docs if the feature is user-facing
2. Prepare PR description linking to plan TODOs (create PR only with user approval)
3. Run all validation tools (harsh-review, trigger-validator, tests)
4. **Exit gate:** All checks pass, PR ready for user to create/merge.

---

## Phase Skip Prevention

**You MUST NOT skip phases.** Common temptations and why they fail:

| Temptation | Why It Fails |
|-----------|-------------|
| "Requirements are obvious" | Untested assumptions surface during implementation |
| "Only one design option" | `design-triad` rejects this — ≥3 options always |
| "Too small for a plan" | If it has 3+ steps, it needs a plan |
| "Tests aren't needed" | Success criteria must be verifiable |
| "Completeness check is overkill" | It catches what you forgot |

**Exception:** For truly trivial features (single file, <20 lines), skip Phase 2 (Design) and Phase 3 (Plan). State the exception explicitly.

---

## Resuming a Feature

If a feature was started in a previous session:

1. Check TODO.md for `#plan-<feature-name>` items
2. Identify the last completed phase
3. Resume from the next incomplete phase
4. Do NOT restart from Phase 1

---

## Integration Map

| Phase | Skill Invoked | Purpose |
|-------|--------------|---------|
| Requirements | `requirements-validation` | Testable, non-contradictory requirements |
| Design | `design-triad` | ≥3 options, harsh review, selection |
| Plan | `todo-management` | WHY/WHAT/HOW TODOs with success criteria |
| Implement | `adversarial-search` | Self-review after each phase |
| Verify | `completeness-check`, `verification-before-completion` | Audit + final gate |
| Complete | (none — user-driven) | PR creation, merge |

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Skipped requirements, design failed | Requirements surface constraints that inform design |
| Skipped design, rework during implementation | Design-triad prevents single-option tunnel vision |
| No plan, lost track of phases | TODO.md with #plan tags enables session resumption |
| Skipped verification, shipped incomplete | completeness-check catches what you forgot |
