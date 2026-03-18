---
name: domain-design
source: superpowers-plus
triggers: ["design a new skill domain", "plan a skill family", "what skills should we build for", "domain design for", "design a domain", "new superpowers domain", "skill family design", "plan skills for"]
description: Use when designing a new superpowers skill family from scratch — orchestrates the full research → brainstorm → harsh review → prioritize → document cycle. Produces a prioritized skill roster, architecture decision, infrastructure map, and blocker list. Does NOT build skills.
---

# Domain Design Orchestrator

> **Purpose:** Guide a structured domain design process for a new superpowers skill family.
> **Origin:** Codified from the Call Review Domain design (21-step, 10-phase methodology, March 2026).
> **Output:** Prioritized skill roster, architecture decision, infrastructure map, wiki design doc + tracking page.

**Announce at start:** "I'm using the **domain-design** skill to structure this domain design exercise."

## ⛔ TODO.md Persistence — MANDATORY (Before Phase 1)

This is a 10-phase workflow. Per `todo-enforcement.always.md` and AGENTS.md, ANY task with 3+ steps MUST use the `todo-management` skill with TODO.md as PRIMARY persistence. MCP `add_tasks`/`update_tasks` are SUPPLEMENTARY ONLY.

### Preflight (run ONCE at workflow start)

```bash
# 1. Load the todo-management skill
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill todo-management

# 2. Resolve TODO.md path
~/.codex/superpowers-plus/tools/todo-preflight.sh --create-if-missing
# Use the TODO_PATH from output for ALL subsequent operations
```

### Persist ALL 10 phases to TODO.md BEFORE starting Phase 1

Acquire lock → write → release lock → mirror to MCP.

```bash
~/.codex/superpowers-plus/tools/todo-lock.sh acquire
# Write the following to TODO.md under ## P1 - Today:
```

```markdown
- [ ] [YYYYMMDD-NN] Phase 1: SCOPE — Define domain boundary #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 2: RESEARCH — Explore each system with real queries #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 3: SYNTHESIZE — Compile infrastructure map #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 4: BRAINSTORM R1 — Generate candidates by persona #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 5: HARSH REVIEW R1 — Value filter, kill/merge #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 6: BRAINSTORM R2 — Map candidates to infrastructure #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 7: HARSH REVIEW R2 — Feasibility gate (real queries) #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 8: BRAINSTORM R3 — Prioritize and architect #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 9: HARSH REVIEW R3 — YAGNI and scope check #plan-domain-{name} #engineering
- [ ] [YYYYMMDD-NN] Phase 10: DOCUMENT — Wiki design doc + tracking page #plan-domain-{name} #engineering
```

```bash
~/.codex/superpowers-plus/tools/todo-lock.sh release
```

Then mirror to MCP: create parent task "Plan: Domain Design — {name}", add 10 children.

### Phase Completion Protocol

As each phase completes:

1. **TODO.md first:** Acquire lock → mark `[x]` → add completion note → release lock
2. **MCP second:** `update_tasks` to mark COMPLETE
3. **Wiki third:** Update tracking page status table

### Cross-Session Recovery

If the agent starts a new session mid-workflow:

1. Run preflight to resolve `TODO_PATH`
2. Filter `#plan-domain-{name}` — incomplete tasks show exactly where to resume
3. Fetch wiki tracking page for human-readable context
4. Resume from the first incomplete phase

**Do NOT rely on MCP state for recovery.** MCP tasks are lost on context compaction. TODO.md is the source of truth.

## Overview

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

### Phase 1: SCOPE

Define the domain boundary and trace the system landscape.

1. Name the domain (e.g., "Call Review", "Billing", "Provisioning")
2. Identify the user-facing action this domain serves
3. Trace backwards from that action to enumerate ALL systems that touch it
4. Create a tracking page (wiki) with a phase-by-phase status table — update throughout

**Output:** Domain name, boundary statement, list of systems to research.

### Phase 2: RESEARCH (repeat per system)

For each system identified in Phase 1:

1. Read wiki documentation, README files, runbooks
2. Explore database schemas (if applicable) — run `DESCRIBE TABLE` or equivalent
3. **Run real queries against prod/dev** — do NOT trust documentation alone
4. Document: what data is accessible, what's denied, what's not connected
5. Note schema discrepancies between docs and reality

**Output:** System Landscape table. Per-system: data sources, access status, key tables/APIs.

**Gate:** Do not proceed to Phase 3 until every system in the scope list has been researched.

### Phase 3: SYNTHESIZE

1. Compile all research into a structured summary
2. Create Infrastructure Mapping table:
   - **Connected:** working queries verified
   - **Permission Denied:** specific tables/endpoints that failed
   - **Not Connected:** services with no MCP/API integration
3. Identify gaps and conflicts between documentation and reality

**Output:** Infrastructure map, gap list, compiled research summary.

### Phase 4: BRAINSTORM R1 — Generate Candidates

*Invoke `brainstorming`-style divergent thinking.*

1. Define 3-5 personas who interact with this domain (e.g., Support, Engineering, QA, Ops, Product)
2. For each persona: generate 2+ skill ideas answering questions they actually ask
3. For each candidate: name, one-sentence description, primary data source

**Output:** Candidate roster (expect 10-15 candidates).

### Phase 5: HARSH REVIEW R1 — Value Filter

*Invoke `adversarial-search`-style convergent review.*

**Review dimension: User Value**
- Does this answer a question someone actually asks weekly?
- Does this duplicate an existing tool or UI?
- Can narrow candidates be merged into broader, more useful skills?

**Actions:** Kill duplicates. Merge narrow skills. Challenge every survivor.
**Expected attrition:** 30-50%.
**Output:** Surviving candidates with rationale for each kill/merge.

### Phase 6: BRAINSTORM R2 — Infrastructure Mapping

For each surviving candidate:

1. Map to specific tables, APIs, connections, or services
2. Classify: **INTEGRATE** (tooling exists) / **BUILD** (new integration needed) / **BLOCKED** (access denied)
3. Write the actual query or API call skeleton

**Output:** Infrastructure-mapped roster with classification per skill.

### Phase 7: HARSH REVIEW R2 — Feasibility Gate ⛔ HARD GATE

This is the single most valuable phase. It catches showstoppers before any building happens.

1. **For EVERY data source referenced by any candidate:** run a real query/request
2. Record result: ✅ works / ❌ permission denied / ⚠️ not connected
3. Re-tier candidates based on actual results (not documentation)
4. **File issue tickets (Linear/Jira/GitHub) for ALL discovered blockers IMMEDIATELY**
5. Update the tracking page with blocker status

**Output:** Reality-checked roster, filed blocker tickets, updated infrastructure map.
**Gate:** Any candidate whose ONLY data source is ❌ or ⚠️ is automatically P1+ (not P0).

### Phase 8: BRAINSTORM R3 — Prioritize & Architect

1. Assign tiers:
   - **P0:** Zero external dependencies, verified accessible, build now
   - **P1:** High value but blocked on filed tickets
   - **P2:** Deferred (novel infrastructure, lower frequency use)
   - **P3:** Parked (multiple blockers, uncertain payoff)
2. Choose architecture pattern (examine precedent in existing skills):
   - Independent Skills (most common — standalone skill.md files)
   - Shared Library (extract common patterns into `_shared/`)
   - Router (central dispatcher — rarely justified)
3. Design the walking skeleton: simplest P0 skill that proves the full pattern
4. **Skill file size constraint:** Each designed skill MUST target ≤250 lines for its `skill.md`. If the design implies a skill that would exceed this (complex multi-mode queries, extensive output formatting), plan a multi-file structure: `skill.md` (core) + `examples.md` + `references/*.md`. Record this in the design doc.

**Output:** Tiered skill list, architecture decision with rationale, walking skeleton design.

### Phase 9: HARSH REVIEW R3 — YAGNI & Scope

*Final adversarial review before documentation.*

- Is the walking skeleton truly minimal? Can it be simpler?
- Are there shared abstractions being designed before 2+ skills need them? (YAGNI violation)
- Is the architecture decision justified by existing precedent?
- Does the P0 set represent genuine quick wins, or are there hidden dependencies?

**Output:** Final approved scope. Any YAGNI violations corrected.

### Phase 10: DOCUMENT

*Invoke `wiki-orchestrator` for each page.*

Create three wiki artifacts:

1. **Design Document** — Full domain specification:
   - Purpose & vision, system landscape, tiered skill list
   - Architecture decision, infrastructure map, gap analysis
   - Contribution guide ("how to add a skill")
   - Info box emphasizing community extensibility

2. **Tracking Page** — Phase-by-phase status table (update from Phase 1 draft):
   - Every phase as a row with status, key output
   - "What's Blocked" section with filed ticket links
   - Key findings, decisions made, open questions

3. **Handoff brief** — What shipped (nothing yet — this is design only), what's P0, what's blocked, who needs to act.

**Output:** Published wiki pages. Domain is designed and ready for implementation.

**Terminal state:** Hand off to `writing-plans` for P0 implementation planning, or to `domain-build` (if available) for the build/deploy/document cycle.

## ⛔ Post-Design Documentation Sync — HARD GATE

Before reporting "design complete," verify ALL downstream documentation is current:

- [ ] **Wiki design document** — Published with all 9 sections (purpose, landscape, skills, infrastructure, architecture, gap analysis, roadmap, open questions, sources)
- [ ] **Wiki tracking page** — All 10 phases have rows with status and key output
- [ ] **Blocker tickets** — Every discovered blocker has a filed ticket (Linear/Jira/GitHub) and the ticket link appears in both the design doc and tracking page
- [ ] **Skill count references** — If any wiki page or README states a total skill count, note that it will change after build phase (do not update yet — skills aren't built)

**If the `domain-design` skill file itself was modified during this exercise** (e.g., adding a new hard principle discovered during the design), you MUST also:

- [ ] Deploy superpowers-plus: `cd ~/GitHub/Personal/superpowers-plus && ./install.sh --verbose`
- [ ] Verify: `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep domain-design`
- [ ] Commit and push to GitHub (with user permission)

**Do not report "design complete" with any unchecked item above.**

## Scaling & Proof

The 10-phase structure is domain-agnostic — only research targets, personas, and infrastructure connections change per domain. The architecture pattern choice and blocker ticket system may also vary.

**Proof:** The Call Review Domain (March 2026) executed this exact process: 5 systems researched, 12 candidates generated, 75% attrition, 3 P0 shipped, Phase 7 caught internal-service-prod permission denials that blocked 4 skills. See [Tracking Page](https://wiki.int.example-org.net/doc/call-review-domain-design-workflow-tracking-HD5xgXNPoI).
