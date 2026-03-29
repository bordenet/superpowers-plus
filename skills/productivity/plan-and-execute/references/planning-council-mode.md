# Planning Council Mode

> **Purpose:** Multi-agent planning for complex, multi-dimensional tasks.
> **Activation:** Multi-agent activation rubric score ≥ 5 + task-specific criteria.
> **Default:** Single-agent planning (existing Phase B behavior). Council is escalation.
> **Cost cap:** 2.0× single-agent tokens.

## When Planning Council Activates

During Phase B (Devise the Plan), before writing the plan:

1. Apply `skills/_shared/multi-agent-activation-rubric.md`
2. Check task-specific criteria:
   - Task involves ≥3 components/services → +1
   - Task crosses team/domain boundaries → +1
   - Significant rollback cost if plan is wrong → +1
   - Single stakeholder, internal-only → -1
3. Score ≥ 5 → announce council mode and proceed
4. Score < 5 → single-agent Phase B (standard behavior)

## Council Protocol

### Step 1: Announce

"I'm using the **planning council** — dispatching role-specific planners to cover architecture, risks, testing, and rollout independently before merging into a coherent plan."

### Step 2: Prepare Common Plan Packet

All council members receive identical context:

```
TASK: [full challenge description from Phase A]
CONSTRAINTS: [user-specified constraints]
SUCCESS CRITERIA: [from Phase A clarification]
RELEVANT CONTEXT: [codebase/system context gathered in Phase A]
```

### Step 3: Select and Dispatch Roles (3–5 from pool)

| Role | Select When | Output |
|------|------------|--------|
| **Requirements Clarifier** | Always | Ambiguities, missing requirements, unstated assumptions |
| **Architecture Planner** | Always | Component decomposition, interfaces, sequencing |
| **Risk / Failure-Mode Planner** | Production system or high-stakes | Risks with likelihood/impact, mitigations, rollback |
| **Test & Verification Planner** | Testable components exist | Test cases, acceptance criteria, verification order |
| **Rollout / Migration Planner** | Deployment, data migration, backward compat needed | Rollout steps, feature flags, migration plan |

**Always include:** Requirements Clarifier + Architecture Planner.
**Select 1–3 others** based on task characteristics.

Each role receives the common plan packet plus a scoped mandate:

```
YOUR ROLE: [Role Name]
YOUR MANDATE: [Specific section to produce]
PRODUCE:
1. Your section of the plan (structured, concrete)
2. Assumptions you're making
3. Risks you see (from your perspective)
4. Missing information you need
5. Your confidence score (0.0–1.0)
6. Objection: what's the weakest part of your section?

BUDGET: [max 25% of total tokens]
DO NOT: Write sections outside your mandate.
```

### Step 4: Synthesis

The Synthesis Planner (conductor) merges all role outputs:

1. **Assemble sections** in natural plan order:
   Requirements → Architecture → Risk → Testing → Rollout
2. **Cross-reference:**
   - Architecture decisions align with risk mitigations?
   - Test plan covers architectural components?
   - Rollout plan accounts for identified risks?
3. **Resolve conflicts:**
   - Architecture says monolith; Rollout says microservices → surface as tradeoff
   - Risk says "don't use X"; Architecture assumes X → require resolution
4. **Merge overlapping content:**
   - Multiple roles identify same risk → merge, note consensus
   - Multiple roles propose same component → merge, strengthen
5. **Produce coherent plan** formatted as standard Phase B output

### Step 5: Quality Check

Before exiting Phase B:
- Plan reads as if written by one author (no "lens voice" leaking)
- All sections internally consistent
- No contradictions between architecture and testing plans
- Risks have corresponding mitigations in other sections
- Length ≤ 2× what single-agent would produce

### Step 6: Proceed to Phase C (Stress-Test)

The merged plan enters standard Phase C stress-testing (brainstorming + think-twice + harsh review). This is unchanged — the council improves Phase B input quality, not the overall workflow.

## Synthesis Output Format

```markdown
## Plan: [Title]

### Requirements & Scope
[From Requirements Clarifier, validated against Architecture Planner output]

### Architecture & Sequencing
[From Architecture Planner]
- Components: [list with interfaces]
- Dependencies: [dependency graph]
- Sequencing: [phase order]

### Risk Assessment
[From Risk Planner, cross-referenced with architecture decisions]
| Risk | Likelihood | Impact | Mitigation | Covered By |
|------|-----------|--------|------------|------------|

### Verification Plan
[From Test Planner, aligned with architecture components]

### Rollout Strategy
[From Rollout Planner, if applicable]

### Unresolved Tradeoffs
[Conflicts between council members that need human decision]

### Council Metadata
- Roles activated: [list]
- Conflicts resolved: N
- Unresolved tradeoffs: M
- Cost: [tokens] ([ratio]× single-agent)
```

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Roles produce overlapping sections | >50% content overlap | Merge and note; tighten mandates for next time |
| Architecture and Risk contradict | Explicit conflict in synthesis | Surface as unresolved tradeoff; require user decision |
| Plan is bloated (>2× single-agent) | Word count check | Synthesizer must cut; distill to essentials |
| Council cost exceeds 2.0× | Token tracking | Stop dispatching; synthesize with what's available |
| Synthesis loses critical detail | Phase C stress-test catches it | Phase C functions as safety net (unchanged) |
