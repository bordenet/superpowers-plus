# Planning Council Mode

> **Purpose:** Multi-agent planning for complex, multi-dimensional tasks.
> **Activation:** Multi-agent activation rubric score ≥ 6 (score = 5 → ask user) + task-specific criteria.
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
3. Score ≥ 6 → announce council mode and proceed
4. Score = 5 → ask user: "This task is borderline — use planning council or single-agent?"
5. Score < 5 → single-agent Phase B (standard behavior)

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

## Dynamic Role Selection (WP-11)

Instead of manually selecting 3–5 roles, the conductor auto-selects based on task signals:

| Task Signal | Roles Auto-Selected | Rationale |
|-------------|---------------------|-----------|
| ≥3 components mentioned | Architecture + Requirements (always) | Multi-component coordination |
| "production", "deploy", SLA-bound | + Risk/Failure-Mode + Rollout/Migration | Operational safety |
| "migration", "backward compat" | + Rollout/Migration | Data/API transition |
| Testable acceptance criteria exist | + Test/Verification | Quality gatekeeping |
| Internal tool, single service | Requirements + Architecture only (min) | Minimal overhead |

**Rules:**
1. Requirements Clarifier + Architecture Planner always included (unchanged)
2. Auto-selection produces candidates; conductor prunes if >5 roles selected
3. Prune by lowest task relevance, keeping roles whose domain is explicitly mentioned
4. Log selected/pruned roles with reasoning in Council Metadata

**Override:** User can explicitly request or exclude specific roles.

## Iterative Refinement (WP-12)

After synthesis (Step 4), the conductor evaluates whether a refinement round improves the plan:

**Refinement triggers** (ALL must be true):
1. Synthesis produced ≥2 unresolved tradeoffs
2. Plan quality score (per `multi-agent-quality-standards.md` §1) is exactly 7/10 (borderline pass)
3. Budget remaining ≥ 30%

> **Note:** If quality score < 7, the shared standard (§3) requires fallback — not refinement. Refinement is only for **borderline-passing** plans (score = 7) that have unresolved tradeoffs worth addressing.

**Refinement protocol:**
1. Only roles involved in unresolved tradeoffs are re-dispatched (not all roles)
2. Each re-dispatched role receives: the synthesized plan + the specific unresolved tradeoffs
3. Prompt: "Given the merged plan and these unresolved tradeoffs, revise ONLY your section to address the conflicts. Do not rewrite other sections."
4. Synthesizer re-merges, focusing on tradeoff resolution
5. Maximum: 1 refinement round. If tradeoffs persist, surface to user as "Council could not resolve"
6. If post-refinement score drops below 7 → fall back per shared standard §3

**Cost guard:** Refinement round cannot exceed 40% of the initial council cost.

## Plan Versioning (WP-13)

Track plan evolution across council rounds for auditability and rollback:

**Version format** (extends shared instrumentation schema — `multi-agent-quality-standards.md` §5):
```json
{
  "version": 1,
  "timestamp": "ISO-8601",
  "rolesDispatched": ["Requirements", "Architecture", "Risk"],
  "unresolvedTradeoffs": 2,
  "outputQualityScore": 7,
  "planHash": "sha256 of plan text",
  "deltaFromPrevious": null,
  "planText": "full plan text for this version"
}
```

**Rules:**
1. Version 1 = initial synthesis output
2. Version 2 = after refinement round (if triggered)
3. Each version records: roles dispatched, tradeoff count, quality score, **full plan text**, plan hash
4. `deltaFromPrevious` summarizes what changed (sections modified, tradeoffs resolved)
5. Version history is appended to Council Metadata in the output
6. If user requests a previous version, the conductor can reference the stored `planText` for comparison or rollback

**Retention:** Version history (including full plan text per version) lives in the plan output metadata. Maximum 2 versions stored (initial + 1 refinement). No external persistence required.

## Operator Visibility (WP-15)

Real-time progress reporting during council execution:

**Progress events** (emitted to user as the council runs):
1. `COUNCIL_START` — "Planning council activated with roles: [list]"
2. `ROLE_DISPATCHED` — "Dispatching [Role Name]..." (per role)
3. `ROLE_COMPLETE` — "[Role Name] complete (confidence: X, assumptions: N)"
4. `CONFLICT_DETECTED` — "Conflict between [Role A] and [Role B]: [summary]"
5. `SYNTHESIS_START` — "Merging role outputs..."
6. `REFINEMENT_TRIGGERED` — "Borderline pass (score = 7) with unresolved tradeoffs; running refinement round..."
7. `COUNCIL_COMPLETE` — "Plan complete. Roles: N, Conflicts resolved: M, Unresolved: K, Cost: X×"

**Format:** Each event is a single-line status message (no code blocks, no tables). Events appear inline as the council runs, giving the user real-time awareness without requiring interaction.

**Quiet mode:** If the user has signaled preference for minimal output (e.g., "just give me the plan"), suppress events 2–5 and emit only START/COMPLETE.

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Roles produce overlapping sections | >50% content overlap | Merge and note; tighten mandates for next time |
| Architecture and Risk contradict | Explicit conflict in synthesis | Surface as unresolved tradeoff; require user decision |
| Plan is bloated (>2× single-agent) | Word count check | Synthesizer must cut; distill to essentials |
| Council cost exceeds 2.0× | Token tracking | Stop dispatching; synthesize with what's available |
| Synthesis loses critical detail | Phase C stress-test catches it | Phase C functions as safety net (unchanged) |
| Refinement round doesn't improve score | Quality score unchanged after round 2 | Accept plan; note "council exhausted" in metadata |
