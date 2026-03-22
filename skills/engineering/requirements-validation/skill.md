---
name: requirements-validation
source: superpowers-plus
triggers: ["validate requirements", "requirements review", "are these requirements valid", "contradictory requirements", "conflicting requirements", "requirements testing", "testable requirements", "requirements falsifiability", "check requirements for contradictions"]
description: Use when validating feature requirements before design or implementation. Tests each requirement for falsifiability, measurability, and independence. Detects contradictions and guides resolution without resolving silently.
---

# Requirements Validation

> **Core principle:** Every requirement must be testable. Contradictions must be surfaced, not silently resolved.

**Announce at start:** "I'm using the **requirements-validation** skill to validate these requirements."

## Input Contract

Before running the three tests, normalize requirements into a numbered list:
- **Format:** `R1: [requirement text]`, `R2: [requirement text]`, etc.
- If the input is prose, extract discrete requirements and number them.
- If the input is already numbered, preserve the numbering.
- Each `R#` must be a single, atomic requirement (split compound requirements).

## The Three Tests

For EACH numbered requirement, apply all three:

### 1. Falsifiability Test
**Question:** Can you write a test that would FAIL if this requirement isn't met?

| Result | Action |
|--------|--------|
| Yes — concrete test exists | ✅ Requirement passes |
| No — too vague to test | ❌ Rewrite to be specific. "Improve performance" → "Response time < 200ms at p95" |
| Partially — some aspects testable | ⚠️ Split into testable and non-testable parts |

### 2. Measurability Test
**Question:** Is "done" a binary state (yes/no), not a gradient?

| Result | Action |
|--------|--------|
| Binary — clear done/not-done | ✅ Passes |
| Gradient — "better", "improved", "enhanced" | ❌ Add a threshold. "Better error handling" → "All error paths return structured error with code, message, and recovery hint" |

### 3. Independence Test
**Question:** Does this requirement conflict with any other requirement in the set?

| Result | Action |
|--------|--------|
| Independent — no conflicts | ✅ Passes |
| Conflicts detected | ❌ Trigger contradiction resolution (below) |

## Contradiction Resolution

⛔ **HARD GATE:** Do NOT resolve contradictions silently. The stakeholder decides.

When two requirements conflict:

1. **State both requirements verbatim.**
2. **State the contradiction explicitly:** "R3 requires X, but R7 requires Y. These cannot both be true because [reason]."
3. **Propose resolution options:**
   - Option A: Prioritize R3 (drop R7 or modify it)
   - Option B: Prioritize R7 (drop R3 or modify it)
   - Option C: Split into phases (R3 in v1, R7 in v2)
   - Option D: Merge into a new requirement that satisfies both constraints
4. **Record the decision:**
   - **Decision owner:** [name or role]
   - **Chosen option:** A / B / C / D
   - **Rationale:** [1 sentence]
5. **Do NOT proceed until recorded.** Unresolved contradictions block Phase 2.

## Output Format

```markdown
## Requirements Validation Report

### Passed
- R1: [requirement] — Falsifiable ✅ Measurable ✅ Independent ✅
- R2: [requirement] — Falsifiable ✅ Measurable ✅ Independent ✅

### Failed (Needs Revision)
- R3: [requirement] — Measurability ❌ (gradient language: "improve")
  - Suggested revision: [specific, measurable version]

### Contradictions Found
- R4 vs R6: [description of conflict]
  - Resolution options: A / B / C / D
  - Stakeholder decision: PENDING
```

## Common Failure Patterns

| Pattern | Example | Fix |
|---------|---------|-----|
| Gradient language | "Improve the UX" | Add threshold: "Task completion time < 30s" |
| Compound requirements | "Fast AND flexible AND secure" | Split into 3 independent requirements |
| Implementation as requirement | "Use Redis for caching" | Restate as need: "Cache layer with <10ms reads" |
| Negative-only | "Don't break existing behavior" | State positive: "All existing tests pass" |
