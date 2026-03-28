---
name: feature-development
source: superpowers-plus
triggers: ["start feature", "new feature", "feature development workflow",
           "build a feature", "implement feature", "feature from scratch",
           "full development workflow", "code change", "make changes",
           "fix this", "add this", "modify code", "refactor this",
           "write code", "update the code"]
anti_triggers: ["fix bug", "debug", "small change", "quick fix", "update docs"]
description: "DEFAULT WORKFLOW for ANY code change. Orchestrates the full rigorous development lifecycle: brainstorming → think-twice → design-triad → progressive-harsh-review → plan-and-execute → progressive-harsh-review → commit. This fires AUTOMATICALLY for code changes unless the user explicitly opts out. Sequences existing skills so no phase is skipped."
summary: "Default for ALL code changes. Opt out only if user says 'skip the full workflow' or 'just do it quickly'. Brainstorm → think-twice → design → review → plan → implement → review → ship."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: ["brainstorming", "think-twice", "design-triad",
            "progressive-code-review-gate", "plan-and-execute",
            "requirements-validation", "todo-management",
            "output-verification", "verification-before-completion"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [feature-request, user-story, requirement, code-change, bug-fix, refactor]
  produces: [implementation, tested-feature, completed-feature]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 5
---

# Feature Development

> **Wrong skill?** Bug fix → `systematic-debugging`. Design comparison → `design-triad`. Pre-commit checks → `pre-commit-gate`. Workflow

> **Purpose:** Orchestrate the full rigorous development lifecycle so no phase is skipped.
> **Pattern:** This skill SEQUENCES existing skills — it does not replace them.
> **Scope:** This is the DEFAULT workflow for ANY code change. Opt out ONLY if the user explicitly says to skip it.

**Announce at start:** "I'm using the **feature-development** skill to orchestrate this workflow."

## When to Use — DEFAULT for Code Changes

- **Any code change** — features, bug fixes, refactors, skill edits, config changes
- This fires AUTOMATICALLY. You do not need the user to say "use the full workflow."
- If you are about to write, edit, or generate code, this skill applies.

## Opt-Out Conditions

- User explicitly says "skip the workflow", "just do it", "quick fix only"
- Pure documentation-only changes (no code files touched)
- Reading/exploring code with no intent to change it

---

## The Workflow

```
Phase 1: BRAINSTORM → Phase 2: FRESH PERSPECTIVE → Phase 3: DESIGN →
Phase 4: HARSH REVIEW → Phase 5: PLAN & EXECUTE → Phase 6: HARSH REVIEW →
Phase 7: SHIP
```

Each phase has an **exit gate** — you cannot proceed until the gate passes.

---

### Phase 1: Brainstorming

**Invoke:** `brainstorming`

1. Explore the user's intent, requirements, and constraints
2. Gather codebase context — read existing code, understand patterns
3. Surface assumptions, edge cases, and scope boundaries
4. **Exit gate:** Clear understanding of what needs to change and why.

---

### Phase 2: Fresh Perspective

**Invoke:** `think-twice`

1. Dispatch a sub-agent with zero prior context to review the problem
2. The sub-agent should identify gaps, blind spots, and alternative framings
3. Integrate fresh insights back into the plan
4. **Exit gate:** Fresh perspective reviewed, no unaddressed blind spots.

---

### Phase 3: Design

**Invoke:** `design-triad`

1. Generate ≥3 genuinely distinct design options
2. Build comparison matrix (≤5 criteria)
3. Evaluate options against requirements from Phase 1
4. Select winning design with documented rationale
5. **Exit gate:** Design selected, trade-offs documented, edge cases addressed.

---

### Phase 4: Harsh Review (Design)

**Invoke:** `progressive-code-review-gate`

1. Red-team the selected design via hostile sub-agent reviewer
2. Reviewer should find issues the designer is blind to
3. Fix all BLOCKER and MAJOR findings before proceeding
4. **Exit gate:** All BLOCKER/MAJOR findings resolved. MINOR findings tracked.

---

### Phase 5: Plan & Execute

**Invoke:** `plan-and-execute`

1. Break the design into ordered implementation phases with success criteria
2. **Enroll each phase as a TODO** via `todo-management` / `todo-crud.sh`, then mirror to MCP tasks
3. Execute each phase, running tests after each
4. For each phase: implement → test → self-review via `adversarial-search`
5. Run `output-verification` after generating any artifact
6. **Exit gate:** All phases complete, all tests pass, no regressions.

---

### Phase 6: Harsh Review (Implementation)

**Invoke:** `progressive-code-review-gate`

1. Red-team the FULL implementation via hostile sub-agent reviewer
2. Reviewer reads ALL changed files, runs quality gates, checks for regressions
3. Fix all BLOCKER and MAJOR findings
4. Re-review after fixes (minimum 2 review rounds total)
5. **Exit gate:** Two review rounds passed, all findings resolved.

---

### Phase 7: Ship

1. Run `output-verification` — read back all generated files
2. Run `verification-before-completion` — evidence before assertions
3. Run all validation tools (harsh-review, trigger-validator, tests)
4. Commit, push, create PR, merge (with user approval at each step)
5. **Exit gate:** All checks pass, PR merged, synced to all remotes.

---

## Phase Skip Prevention

**You MUST NOT skip phases.** Common temptations and why they fail:

| Temptation | Why It Fails |
|-----------|-------------|
| "I already know the approach" | Think-twice exists because you have blind spots you can't see |
| "Only one design option" | `design-triad` rejects this — ≥3 options always |
| "The design is obviously right" | Harsh review #1 exists because designers are blind to their own flaws |
| "The code works, why review again?" | Harsh review #2 catches implementation bugs the author can't see |
| "Too small for this workflow" | The 2026-03-27 incident was "just a small PDF export script" |

**Opt-out is user-initiated ONLY.** The agent never decides to skip the workflow. If the user says "just do it" or "skip the full workflow," follow their instruction. Otherwise, run all phases.

---

## Integration Map

| Phase | Skill Invoked | Purpose |
|-------|--------------|---------|
| Brainstorm | `brainstorming` | Explore intent, gather context, surface assumptions |
| Fresh Perspective | `think-twice` | Sub-agent catches blind spots |
| Design | `design-triad` | ≥3 options, comparison, selection |
| Harsh Review (Design) | `progressive-code-review-gate` | Red-team the design |
| Plan & Execute | `plan-and-execute` + `adversarial-search` | Structured implementation with self-review |
| Harsh Review (Impl) | `progressive-code-review-gate` | Red-team the implementation (min 2 rounds) |
| Ship | `output-verification`, `verification-before-completion` | Inspect output, verify completion, merge |

## Incident History

| Date | What Happened | Impact |
|------|---------------|--------|
| 2026-03-27 | Agent skipped brainstorming, think-twice, and harsh review. Created a new skill file, immediately presented a confabulated summary without reading the file back. README table ordering was wrong. Router stems were wrong for the actual stemmer. Thinking-orchestrator routing was overcorrected. Required 2 full hostile review rounds to catch all issues. | Every issue found by hostile reviewers could have been caught if the full workflow had been followed from the start. |

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Phase skipping (most common) | Every phase has an exit gate. No phase can be skipped without user opt-out. |
| Rushing through brainstorming in <2 exchanges | Brainstorming should explore ≥3 approaches with real trade-offs |
| Skipping harsh review after implementation | Phase 6 is mandatory. Fixes from review need their own review. |
| Not persisting phase state via TODO | Each phase must be enrolled as a TODO before starting |
