# Planning Council — Synthesis Protocol

> **Purpose:** Merge role outputs into a single coherent plan.
> **Executor:** The conductor agent after all council members return.

## Input

You receive 3–5 role outputs (JSON), each containing a scoped section plus assumptions, risks, missing info, and self-critique.

## Synthesis Steps

### 1. Assemble in Natural Order

Arrange sections: Requirements → Architecture → Risk → Testing → Rollout.
Skip any role that was not activated.

### 2. Cross-Reference Validation

Check for consistency BETWEEN sections:

| Check | Source A | Source B | Pass If |
|-------|---------|---------|---------|
| Architecture covers requirements | Requirements | Architecture | Every requirement maps to ≥1 component |
| Tests cover architecture | Architecture | Testing | Every component has ≥1 test strategy |
| Risks address architecture decisions | Architecture | Risk | High-impact architectural decisions have risk entries |
| Rollout handles risks | Risk | Rollout | High-likelihood risks have rollout mitigations |
| Requirements match test acceptance criteria | Requirements | Testing | Each requirement has ≥1 acceptance criterion |

Log each check: pass, partial, or fail. Failed checks → unresolved tradeoff.

### 3. Resolve Conflicts

Types of conflict between roles:

| Conflict Type | Example | Resolution |
|--------------|---------|-----------|
| **Factual disagreement** | Architecture says 3 components; Risk says the 3rd is unnecessary | Evaluate: is the 3rd component risk-mitigating or risk-creating? |
| **Priority disagreement** | Architecture sequences A→B→C; Testing says test C first | Prefer testing priority (catch errors early), adjust architecture |
| **Scope disagreement** | Requirements includes X; Rollout says X needs separate migration | Surface as tradeoff: include X in this plan or defer? |
| **Unresolvable** | Architecture wants monolith; Rollout wants microservices | Surface explicitly: human must decide |

For each resolved conflict: record what was decided and why.
For each unresolved conflict: present both options with tradeoffs.

### 4. Merge Overlapping Content

- Multiple roles identify same risk → merge, note consensus (stronger signal)
- Multiple roles reference same component → merge descriptions, keep strongest
- Remove duplicate assumptions (keep unique ones from each role)

### 5. Aggregate Missing Information

Combine all `missingInformation` fields. Deduplicate. Classify:
- **Blocking:** Plan cannot proceed without this → flag for human input
- **Important:** Plan is weaker without this but can proceed → note as caveat
- **Nice-to-have:** Would improve plan but not critical → defer

### 6. Produce Merged Plan

```markdown
## Plan: [Title]

### 1. Requirements & Scope
[From Requirements Clarifier, validated against Architecture section]
- **In scope:** [list]
- **Out of scope:** [list]
- **Ambiguities resolved:** [decisions made]
- **Ambiguities remaining:** [need human input]

### 2. Architecture & Sequencing
[From Architecture Planner]
- **Components:** [list with 1-sentence purposes]
- **Dependencies:** [graph or ordered list]
- **Implementation sequence:** [phase order]
- **Reused patterns:** [existing code to leverage]

### 3. Risk Assessment
[From Risk Planner, cross-referenced with architecture]
| Risk | L | I | Mitigation | Covered In |
|------|---|---|-----------|-----------|
[Risks with cross-references to which plan section addresses them]

### 4. Verification Plan
[From Test Planner, aligned with architecture components]
- **Unit tests:** [per component]
- **Integration tests:** [per boundary]
- **Acceptance criteria:** [concrete, checkable]
- **Edge cases:** [specific scenarios]

### 5. Rollout Strategy
[From Rollout Planner, if applicable]
- **Steps:** [ordered]
- **Feature flags:** [list with lifecycle]
- **Migration:** [if applicable]
- **Monitoring:** [success metrics + rollback triggers]

### 6. Unresolved Tradeoffs
[Conflicts between council members requiring human decision]
- **Tradeoff:** [description]
  - Option A: [from Role X] — [pro/con]
  - Option B: [from Role Y] — [pro/con]
  - **Recommendation:** [if one is clearly better] or **Needs decision**

### 7. Missing Information
- **Blocking:** [must resolve before proceeding]
- **Important:** [plan is weaker without]

### Council Metadata
- Roles activated: [list with confidence scores]
- Cross-reference checks: [N passed, M partial, K failed]
- Conflicts resolved: N
- Unresolved tradeoffs: M
- Token cost: [total] ([ratio]× single-agent estimate)
```

## Quality Checks

1. **Reads as one author** — no "the Architecture Planner suggested..." phrasing
2. **Length ≤ 2×** single-agent plan for same task
3. **All cross-references valid** — risks map to components, tests map to requirements
4. **No orphaned sections** — every section connects to at least one other
5. **Actionable** — a developer could start implementing Phase 1 from this plan

## Failure Recovery

| Problem | Action |
|---------|--------|
| Council cost exceeds 2.0× | Synthesize with available outputs; skip missing roles |
| All roles low confidence (<0.5) | Fall back to single-agent planning; note council was unhelpful |
| Synthesis produces bloated output | Cut to top 3 phases + critical risks only |
| Unresolvable conflicts dominate | Escalate to user with ranked options instead of a plan |
