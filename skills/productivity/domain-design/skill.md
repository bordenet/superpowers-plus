---
name: domain-design
source: superpowers-plus
triggers: ["design a new skill domain", "plan a skill family", "what skills should we build for", "domain design for", "design a domain", "new superpowers domain", "skill family design", "plan skills for"]
description: Use when designing a new superpowers skill family from scratch — orchestrates the full research → brainstorm → harsh review → prioritize → document cycle. Produces a prioritized skill roster, architecture decision, infrastructure map, and blocker list. Does NOT build skills.
summary: "Use when: designing a new skill family from scratch. Skip when: building skills (use domain-build)."
coordination:
  group: productivity
  order: 2
  requires: []
  enables: ["skill-authoring", "brainstorming", "design-triad"]
  escalates_to: []
  internal: false
---

# Domain Design Orchestrator

> **Purpose:** Guide a structured domain design process for a new superpowers skill family.
> **Origin:** Codified from the Call Review Domain design (21-step, 10-phase methodology, March 2026).
> **Output:** Prioritized skill roster, architecture decision, infrastructure map, wiki design doc + tracking page.

> **Wrong skill?** Writing individual skills → `skill-authoring`. Feature design → `design-triad`. Brainstorming ideas → `brainstorming`.

## When to Use

- Designing a brand-new superpowers skill family from scratch
- Planning which skills should exist for a new domain (e.g., "call review," "recruiting")
- Running a structured brainstorm → prioritize → document cycle for skill architecture
- Evaluating whether an existing domain needs restructuring or new sub-skills

**Announce at start:** "I'm using the **domain-design** skill to structure this domain design exercise."

## Preflight

This is a 10-phase workflow. Per `todo-enforcement.always.md`, persist all 10 phases to TODO.md with `#plan-domain-{name}` tags BEFORE starting Phase 1. Mirror to MCP as supplementary.

## Scope

Orchestrates the full cycle of designing a new skill domain (3+ related skills). Composes `brainstorming`, `adversarial-search`, `innovation`, and `wiki-orchestrator` into a 10-phase process. **Not for** single-skill design (use `brainstorming` + `skill-authoring`) or implementation (use `writing-plans` or `domain-build`).

## Hard Principles

| # | Principle | Why |
|---|-----------|-----|
| 1 | **Research before brainstorming** | Prevents designing skills around inaccessible data |
| 2 | **Documentation lies — verify with real queries** | Wiki said tables existed; SELECT was denied |
| 3 | **Every brainstorm gets a harsh review** | 3 rounds × 2 = 6 phases of diverge/converge |
| 4 | **P0 means zero external dependencies** | If it needs a DBA ticket, it's P1 at best |
| 5 | **Walking skeleton first** | Prove the full pattern before building more |
| 6 | **Kill aggressively** | 75% attrition is normal and healthy |
| 7 | **File blocker tickets immediately** | Don't wait until build phase to discover blocks |

## The Process (10 Phases)

Three rounds of diverge (brainstorm) → converge (harsh review), bookended by research and documentation.

| Phase | Type | What Happens | Gate |
|-------|------|-------------|------|
| 1. SCOPE | Setup | Name domain, trace system landscape, create wiki tracking page | — |
| 2. RESEARCH | Discovery | Per system: read docs, explore schemas, **run real queries** (don't trust docs) | All systems researched |
| 3. SYNTHESIZE | Analysis | Infrastructure map: Connected / Permission Denied / Not Connected | — |
| 4. BRAINSTORM R1 | Diverge | 3-5 personas × 2+ skill ideas each → candidate roster (10-15) | — |
| 5. HARSH REVIEW R1 | Converge | Value filter: kill duplicates, merge narrow skills. 30-50% attrition. | — |
| 6. BRAINSTORM R2 | Diverge | Map survivors to tables/APIs. Classify: INTEGRATE / BUILD / BLOCKED | — |
| 7. HARSH REVIEW R2 | Converge | **⛔ HARD GATE:** Run real queries for EVERY data source. File blocker tickets immediately. | All sources verified |
| 8. BRAINSTORM R3 | Diverge | Tier (P0-P3), choose architecture, design walking skeleton. Skills ≤250 lines. | — |
| 9. HARSH REVIEW R3 | Converge | YAGNI check, scope check, walking skeleton minimality | — |
| 10. DOCUMENT | Output | Wiki: design doc + tracking page + handoff brief via `wiki-orchestrator` | — |

**P0 = zero external dependencies, verified accessible.** P1+ = blocked on filed tickets.

## Post-Design Gate

Before reporting "design complete": wiki design doc published, tracking page updated, all blocker tickets filed with links in both docs.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Design produces too many skills (scope creep) | Enforce P0-only delivery — defer P1+ to backlog |
| Missing infrastructure requirements (tools, APIs) | Infrastructure map is mandatory output — blockers stop design |
| Design never converges after harsh review | Cap at 3 review rounds — escalate to user for tiebreak |

```bash
# Example: design a new skill domain
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill domain-design
```
