---
name: fallback-planning
source: superpowers-plus
triggers: ["fallback plan", "contingency plan", "plan B", "what if this fails", "backup approach", "risk mitigation", "fallback TODO", "alternative plan"]
description: Use when a primary implementation plan has identified risks that could invalidate the approach. Generates machine-agnostic fallback TODOs for the top 2-3 risks, each with enough context for a different agent to execute cold.
---

# Fallback Planning

> **Core principle:** A plan without fallbacks is a plan that restarts from scratch when things go wrong.

**Announce at start:** "I'm using the **fallback-planning** skill to generate contingency plans."

**Prereq:** A primary plan exists (via `writing-plans`) with identified risks (via `design-triad` harsh review).

## Process

1. **Extract risks** from the design document's harsh review and edge-case catalog.
2. **Rank by impact** — which risks, if they materialize, would require the most rework?
3. **Select top 2-3** — don't generate fallbacks for every conceivable risk. Focus on the ones that would actually derail the project.
4. **For each selected risk, generate a Fallback TODO.**

## Fallback TODO Format (Context-Aware Standard)

Each fallback TODO must be **machine-agnostic** — a different agent in a fresh session can execute it without clarifying questions.

```markdown
### Fallback: [Risk Name]

**Trigger:** If [specific condition that indicates the risk has materialized].

**Purpose:** [Why this fallback exists — what problem does it solve that the primary plan cannot?]

**The Trinity:**
- **WHY:** [Business/technical rationale for switching to this approach]
- **WHAT:** [Concrete deliverable — what does the fallback produce?]
- **HOW:** [Implementation approach — file paths, key decisions, integration points]

**Success Criteria:** [Binary done/not-done — verifiable by running a command or checking a state]

**Handoff State:** [Context for cold-start: branch name, which primary plan tasks completed, what artifacts exist, known gotchas from the primary attempt]

**Estimated Scope:** [Relative to primary plan — "similar effort" / "larger" / "smaller" — NOT calendar time]
```

## Quality Checks

Before persisting fallback TODOs:

- [ ] Each fallback has a clear TRIGGER condition (not "if things go wrong")
- [ ] Each fallback's HOW section includes file paths, not just concepts
- [ ] Success criteria are binary and verifiable
- [ ] Handoff state assumes the reader knows NOTHING about the primary plan's history
- [ ] No calendar-based estimates (per `plan-quality-gates`)

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "If anything goes wrong, start over" | Not a fallback — it's giving up | Identify the specific failure mode and the specific alternative |
| Fallback is the primary plan with minor tweaks | Not genuinely different — same risks apply | Each fallback must address the root cause of the identified risk |
| "We'll figure it out when we get there" | Defeats the purpose of pre-planning | Write the fallback now, when context is fresh |
| Fallback depends on tribal knowledge | Violates machine-agnostic requirement | All context in the Handoff State field |

## Persistence

Fallback TODOs are persisted alongside the primary plan:
- **In TODO.md:** Tagged with `#fallback-[risk-name]` under the primary plan's tag
- **In MCP tasks:** As child tasks of the primary plan's root task, marked NOT_STARTED
- **In design doc:** Referenced in the "Fallback Plan" section
