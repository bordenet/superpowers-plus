# Multi-Agent Skill Execution Strategy

> **Status:** Draft · **Author:** Matt Bordenet · **Date:** 2026-03-29
> **Branch:** `feat/multi-agent-skill-upgrades`
> **Related:** `docs/superpowers/specs/2026-03-29-forked-debugging-design.md` (forked debugging)

## 1. Executive Summary

This document defines the architecture for multi-agent execution across three skills: **plan-and-execute (formerly writing-plans)**, **subagent-driven-development**, and **brainstorming**. The goal is disciplined parallelism — not "spawn many agents" — grounded in the same research principles as the forked debugging initiative.

**Core thesis:** These three skills are the strongest non-debugging candidates because they are naturally decomposable, benefit from diverse perspectives, and can be centrally synthesized without tight serialization.

### Ranked Target Skills

| Rank | Skill | Why Multi-Agent | Risk Level |
|------|-------|----------------|------------|
| 1 | **plan-and-execute** | Independent planners can propose decompositions, risks, tests in parallel; outputs are comparable side-by-side before implementation | Low — plans are cheap to compare |
| 2 | **subagent-driven-development** | Already near multi-agent; needs better orchestration, parallel dispatch for isolated tasks, merge-risk awareness | Medium — code merges can fail |
| 3 | **brainstorming** | Viewpoint diversity improves idea quality; low-risk since output is ideas, not code | Low — ideas are cheap to generate |

## 2. Research Foundation

### Key Constraints (from Kim et al. 2025, applied to non-debugging contexts)

1. **Centralized orchestration always wins** — synthesis layer required; no peer-to-peer
2. **Optimal team: 3–4 agents** — beyond this, coordination overhead exceeds gains
3. **Turn count scales superlinearly** (T ∝ n^1.724) — budget awareness mandatory
4. **Capability saturation** — if single-agent performance >45%, more agents may hurt
5. **Tool-heavy tasks penalized 33%** — minimize tool contention across agents

### Design Principles (non-negotiable across all three skills)

| Principle | Application |
|-----------|------------|
| **Single-agent is default** | Multi-agent is escalation, not starting point |
| **Bounded fan-out** | Max 4 parallel branches per skill invocation |
| **Central synthesis required** | No skill produces N competing outputs; always one merged result |
| **Budget-aware** | Total cost increase ≤ 2.5× single-agent for same quality |
| **Operator-readable** | Final output must be cleaner than single-agent, not noisier |
| **Evidence-driven activation** | Rubric decides; never fork "just because we can" |

## 3. Shared Architecture

### 3.1 Multi-Agent Activation Rubric

Shared across all three skills. Score 0–2 per signal; total = 5 → borderline (ask user); total ≥ 6 → multi-agent eligible.

| Signal | 0 | 1 | 2 |
|--------|---|---|---|
| **Task decomposability** | Atomic task | 2–3 independent aspects | 4+ independent aspects |
| **Perspective diversity value** | Single perspective sufficient | 2 perspectives would help | Problem is multi-dimensional |
| **Output comparability** | Hard to compare outputs | Partially comparable | Side-by-side comparison natural |
| **Single-agent quality risk** | Confident single-agent handles it | Moderate risk of tunnel vision | High risk of missed perspectives |
| **Cost justification** | Low-value task | Moderate value | High-value (gates downstream work) |

**Anti-activation signals** (any blocks multi-agent):

- Task is a quick fix or small change
- Tight coupling requires sequential processing
- Budget remaining < 30%
- User explicitly requests single-agent

### 3.2 Common Task Packet Schema

> **Canonical source:** `skills/_shared/multi-agent-task-packet-schema.md`

Every multi-agent dispatch uses the task packet schema. See the shared file for the full JSON schema, field notes, and required/optional field documentation.

### 3.3 Common Result Schema

> **Canonical source:** `skills/_shared/multi-agent-result-schema.md`

Every branch produces a result conforming to the shared result schema. Key fields: `branchId`, `status`, `confidence` (0.0–1.0), `objections` (self-identified weakness), and resource usage metrics.

### 3.4 Common Synthesis Schema

> **Canonical source:** `skills/_shared/multi-agent-synthesis-schema.md`

The synthesis layer merges branch results using the shared synthesis schema. Key fields: `conflictsResolved`, `unresolved` tradeoffs, `overallConfidence`, and `humanEscalationNeeded`.

### 3.5 Duplicate-Output Detection

| Strategy | When Used | Threshold |
|----------|-----------|-----------|
| **Structural overlap** | Compare plan section headings, task lists | >70% heading overlap → merge |
| **Semantic similarity** | Compare key claims/recommendations | Embedding cosine >0.85 → merge |
| **Contradiction detection** | Compare assertions across branches | Conflicting claims → escalate to synthesis |

### 3.6 Confidence Scoring Model

Confidence is **role-specific** but follows a shared calibration:

| Score | Meaning |
|-------|---------|
| 0.9–1.0 | High certainty: clear evidence, minimal assumptions |
| 0.7–0.9 | Moderate: well-reasoned but some assumptions |
| 0.5–0.7 | Mixed: reasonable but missing information |
| 0.3–0.5 | Low: speculative, needs validation |
| <0.3 | Insufficient: branch should be killed or reconsidered |

**Calibration note:** These scores are starting guesses. They will be refined through Wave 4 experiments.

## 4. Skill-Specific Designs

### 4.1 plan-and-execute: Multi-Agent Planning Council

**Design Alternatives Considered:**

| Alternative | Description | Verdict |
|-------------|-------------|---------|
| **A. Sequential Planning Lenses** | Single agent writes plan, then passes to risk reviewer, then to test planner, etc. in sequence | ❌ Rejected: Sequential ≈ single-agent with more overhead; doesn't gain parallelism benefit |
| **B. Competing Full Plans** | 3 agents each write a complete plan independently, then merge | ❌ Rejected: Maximum redundancy; 3× cost for incremental quality gain; synthesis of 3 full plans is harder than merging aspects |
| **C. Role-Scoped Parallel Aspects (Selected)** | Each agent owns ONE aspect of the plan (architecture, risk, testing, rollout) and writes that section; synthesis layer merges into coherent plan | ✅ Selected: Minimizes duplication, maximizes perspective diversity, natural merge points at section boundaries |

**Planning Council Roles:**

| Role | Mandate | Output |
|------|---------|--------|
| **Requirements Clarifier** | Identify ambiguities, missing requirements, unstated assumptions | `{ requirements[], assumptions[], questions[], missingContext[] }` |
| **Architecture Planner** | Decompose task into components, define interfaces, propose sequencing | `{ components[], interfaces[], dependencies[], sequencing[] }` |
| **Risk / Failure-Mode Planner** | Identify what can go wrong, propose mitigations, rate likelihood/impact | `{ risks[{description, likelihood, impact, mitigation}], rollbackPlan }` |
| **Test & Verification Planner** | Define how to verify each component works, acceptance criteria | `{ testCases[], integrationTests[], acceptanceCriteria[], verificationOrder }` |
| **Rollout / Migration Planner** | Plan deployment, feature flags, data migration, backward compatibility | `{ rolloutSteps[], featureFlags[], migrationPlan, backwardCompatibility }` |
| **Synthesis Planner** | Merge all sections, resolve conflicts, produce coherent plan | `{ mergedPlan, conflicts[], unresolved[], readinessAssessment }` |

**Activation criteria (specific to plan-and-execute):**

- Multi-agent activation rubric score ≥ 6 (score = 5 → ask user)
- Task involves ≥3 components/services
- Task has significant rollback cost if plan is wrong
- Task crosses team/domain boundaries

**Synthesis strategy:** Section-merge with conflict detection. The Synthesis Planner receives ALL role outputs and produces one coherent plan.

### 4.2 subagent-driven-development: Hierarchical Execution Orchestrator

**Design Alternatives Considered:**

| Alternative | Description | Verdict |
|-------------|-------------|---------|
| **A. Pure Sequential (Status Quo)** | One implementer at a time, spec review, quality review | ❌ Rejected as sole mode: Correct for coupled tasks, but misses parallelism for isolated changes |
| **B. Naive Parallel Fan-Out** | Dispatch all implementers simultaneously | ❌ Rejected: No merge-risk assessment; integration failures are expensive |
| **C. Merge-Risk-Aware Selective Parallelism (Selected)** | Analyze task dependencies; parallelize only isolated workstreams; serialize coupled work | ✅ Selected: Gets parallelism gains where safe; protects against merge pain |

**New Roles (extending existing 3-role pattern):**

| Role | Mandate | When Used |
|------|---------|-----------|
| **Execution Conductor** | Analyze task graph, assess parallelizability, dispatch | Always (replaces implicit sequential dispatch) |
| **Task Isolation Analyzer** | Score merge risk between task pairs | Before parallel dispatch |
| **Implementer Subagent** | Execute scoped task (unchanged from current) | Always |
| **Integration Checker** | Verify parallel branches don't conflict after completion | After parallel branch completion |
| **Review Gatekeeper** | Spec compliance + quality review (unchanged) | Always |

**Fan-Out Eligibility Rubric:**

| Signal | 0 (Serial) | 1 (Maybe) | 2 (Parallel) |
|--------|------------|-----------|---------------|
| File overlap | Same files | Adjacent files | Completely separate files |
| Interface coupling | Shared interfaces | Shared types | Independent interfaces |
| Test isolation | Shared test fixtures | Partial overlap | Independent tests |
| Data model coupling | Same tables/models | Related models | Separate models |

**Score ≥ 6 → parallel eligible.** Score < 6 → stay serial.

**Merge-Risk Score:** `risk = 1 - (isolation_score / 8)`. If risk > 0.5 → serial.

### 4.3 brainstorming: Multi-Perspective Ensemble

**Design Alternatives Considered:**

| Alternative | Description | Verdict |
|-------------|-------------|---------|
| **A. Random Perspective Sampling** | Each agent brainstorms freely with no role constraint | ❌ Rejected: Produces redundant lists; no perspective diversity guarantee |
| **B. Debate Format** | Agents argue for/against proposals | ❌ Rejected: Premature convergence; debates narrow rather than expand possibility space. **Exception:** BS-13 adds a single-round *contradiction clarification* pass (not a debate) — it surfaces hidden assumptions without convergence pressure. See `ensemble-mode.md` §"Cross-Lens Contradiction Clarification." |
| **C. Role-Based Ideation with Synthesis (Selected)** | Each agent wears a specific "lens"; synthesizer clusters and ranks | ✅ Selected: Guaranteed diversity; structured output; natural handoff to planning |

**Brainstorming Ensemble Lenses:**

| Lens | Perspective | Key Question |
|------|-----------|-------------|
| **Product / User Value** | What do users need? What creates the most value? | "What's the highest-impact thing we could build?" |
| **Architecture** | How should this be built? What patterns apply? | "What architecture gives us the most flexibility?" |
| **Reliability / Ops** | What will break? How will we know? How will we fix it? | "What's the 2am page scenario?" |
| **Security / Abuse** | How can this be misused? What data is exposed? | "How would a malicious actor exploit this?" |
| **Simplicity / DX** | Is this too complex? Can we do less? | "What's the simplest thing that could work?" |
| **Contrarian / Skeptic** | What if the premise is wrong? What are we not seeing? | "Why might we NOT want to build this at all?" |

**Note:** Not all lenses activate every time. The activation rubric selects 3–4 relevant lenses per brainstorm.

**Synthesizer responsibilities:**

- Cluster similar ideas (semantic grouping, not lexical)
- Remove true duplicates
- Rank options by feasibility × impact
- Identify recurring concerns across lenses
- Separate "high-upside but risky" ideas
- Produce planning-ready handoff (directly consumable by plan-and-execute)

## 5. Cross-Cutting Concerns

### 5.1 Budget Management

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Max cost increase vs single-agent | 2.5× | Arbitrary but conservative; tighten based on experiments |
| Per-branch token budget | 25% of total | Same as forked debugging; prevents branch dominance |
| Kill threshold | < 0.3 confidence after first output | Same as forked debugging |
| Max wall-clock per branch | 5 minutes | Prevents runaway branches |

### 5.2 Human Escalation Rules

Escalate to user when:

- Synthesis finds unresolvable conflicts (2+ branches contradict with similar confidence)
- Activation rubric is borderline (score = 5, ambiguous signals)
- Budget exceeded without convergence
- Branch outputs are all low-confidence (< 0.5)

### 5.3 Integration with Existing Skills

| Existing Skill | How It's Used |
|---------------|--------------|
| `thinking-orchestrator` | Gains routing rule: complex planning → plan-and-execute multi-agent mode |
| `autonomous-chain-controller` | Gains chain type: "multi-agent-planning" |
| `design-triad` | Used within plan-and-execute for architecture decisions; NOT itself multi-agent |
| `progressive-code-review-gate` | Applied to each code batch from parallel subagent branches |
| `adversarial-search` | Embedded in brainstorming Contrarian lens |
| `plan-and-execute` | Consumes multi-agent plan-and-execute output as its plan source |

### 5.4 Replayability

All orchestration decisions logged in structured format:

```json
{
  "decision": "activate-multi-agent",
  "skill": "plan-and-execute",
  "rubricScore": 7,
  "rubricDetails": { "decomposability": 2, "diversity": 2, "comparability": 1, "qualityRisk": 1, "costJustification": 1 },
  "selectedRoles": ["requirements", "architecture", "risk", "testing"],
  "rejectedRoles": ["rollout"],
  "rejectedReason": "Task has no deployment component",
  "timestamp": "ISO-8601"
}
```

## 6. Experiment Plan

### Conditions

| ID | Condition | Description |
|----|-----------|-------------|
| A | Single-Agent | Current behavior (no multi-agent) |
| B | Multi-Agent | Skill-specific multi-agent mode |

### Scenarios per Skill

**plan-and-execute:**

| ID | Scenario | Expected Winner |
|----|----------|----------------|
| WP-1 | Simple utility function | A (single-agent) — over-engineering risk |
| WP-2 | Medium feature with 3 components | B (close call) — diversity may help risks |
| WP-3 | Large cross-service feature with migration | B (clear win) — too many aspects for one agent |

**subagent-driven-development:**

| ID | Scenario | Expected Winner |
|----|----------|----------------|
| SD-1 | Independent file changes (3 files, no overlap) | B — parallelism directly reduces latency |
| SD-2 | Moderately coupled feature (shared types) | A or B (close) — merge risk is real |
| SD-3 | Tightly coupled refactor | A — parallelism would cause merge hell |

**brainstorming:**

| ID | Scenario | Expected Winner |
|----|----------|----------------|
| BS-1 | Vague feature request ("improve onboarding") | B — viewpoint diversity adds value |
| BS-2 | Architecture redesign | B — multi-dimensional problem |
| BS-3 | Simple UI change | A — over-brainstorming wastes time |

### Metrics

| Metric | How Measured |
|--------|-------------|
| Output quality | Human rating 1–5 (completeness, coherence, actionability) |
| Missing risks caught | Count of risks in multi-agent output absent from single-agent |
| Duplicate content | % of content duplicated across branches |
| Cost (tokens) | Total tokens consumed |
| Time (wall-clock) | End-to-end completion time |
| Downstream success | For plans: did execution succeed without major replanning? |

## 7. Implementation Waves

### Wave 1 ✅

- [x] Repo inventory and existing capability audit
- [x] Shared architecture document
- [x] TODO documents per skill → `todo-brainstorming.md`, `todo-writing-plans.md`, `todo-subagent-driven-development.md`
- [x] Multi-agent activation rubric (shared) → `skills/_shared/multi-agent-activation-rubric.md`

### Wave 2 ✅

- [x] Design alternatives per skill (3 each, select 1, reject 2 with reasons) → §4.1–4.3 above
- [x] Harsh review of all designs → §8.1 findings addressed

### Wave 3 ✅

- [x] Shared primitives (task packet, result schema, synthesis schema) → §3.2–3.4 above
- [x] plan-and-execute multi-agent prototype (first target) → `plan-and-execute/references/planning-council-mode.md`
- [x] Progressive harsh review → 10+ rounds, final score 8.6/10

### Wave 4 ✅

- [x] subagent-driven-development parallel dispatch → `references/parallel-dispatch-mode.md`, `isolation-analyzer.md`
- [x] brainstorming ensemble prototype → `references/ensemble-mode.md`, `lens-mandates.md`
- [x] Experiment fixtures and harness → `exercises/multi-agent-skills/fixtures/` (9 fixtures), `exercises/forked-debugging/` (5 fixtures + harness)

### Wave 5 — In Progress

- [ ] Run comparative experiments (harness built, execution pending integration testing)
- [x] Final recommendations → `docs/superpowers/specs/2026-03-29-forked-debugging-design.md`
- [x] Documentation and limitations → §8 "Honest Caveats" + all TODO docs updated

## 8. Honest Caveats

1. **Activation rubric is untested.** The ≥5 threshold is a guess. Experiments must validate.
2. **Synthesis is the hard part.** Merging N outputs into 1 coherent result is where quality lives or dies. Prototype synthesis early.
3. **Cost increase may not be worth it** for many tasks. Single-agent planning is already quite good. We must prove multi-agent is meaningfully better, not just different.
4. **Role definitions are speculative.** The lens taxonomy for brainstorming and planning council roles are designed from first principles, not empirically validated.
5. **Parallel subagent dispatch is the riskiest.** File conflicts, interface mismatches, and integration failures are expensive. The isolation analyzer must be conservative.

### 8.1 Harsh Review Findings (Round 1, 2026-03-29)

**Finding 1: Strawman alternatives.** The rejected designs (naive fan-out, competing full plans, random brainstorming) are weak. Stronger baselines to add:

- **Single-agent draft + parallel critics** (write once, critique in parallel — cheaper coordination)
- **2 competing full plans + judge** (less coordination, stronger synthesis forcing function)
- **Serial plan with adversarial review** (no multi-agent overhead, reuses existing harsh review)
**Action:** These are now acknowledged as serious alternatives to test experimentally alongside the selected designs.

**Finding 2: Activation rubric signals are subjective and correlated.** "Task decomposability" and "perspective diversity" tend to score together. Need observable predicates.
**Action:** Revised rubric should use measurable features (service count, file count, stakeholder count) alongside judgment-based signals. Deferred to Wave 3 prototype iteration.

**Finding 3: Experiment plan favors multi-agent.** "Missing risks caught" structurally advantages multi-agent unless normalized for false positives and noise.
**Action:** Add metric: "false risk rate" (risks in multi-agent output that are irrelevant or noise). Add near-threshold scenario per skill (where it's genuinely unclear which mode wins).

**Finding 4: Per-skill cost caps needed.** 2.5× is too generous.
**Action:** Set per-skill caps:

- brainstorming: 1.5× (ideas are cheap; if you need 2.5× to brainstorm better, something's wrong)
- plan-and-execute: 2.0× (plan sections have genuine independent work)
- subagent-driven-development: 2.5× (code execution has legitimate parallelism value)

**Finding 5: Synthesis weaknesses are skill-specific.**

- plan-and-execute: sections co-determine each other (architecture shapes risk shapes testing)
- subagent-driven-development: integration checker is too late; prevention > repair
- brainstorming: clustering washes out contrarian ideas
**Action:** Add explicit synthesis failure modes to each skill's TODO doc.

## 9. Recommendation: Ship Order

1. **Brainstorming ensemble first** — lowest risk (output is ideas, not code), easiest to evaluate, fastest to prototype
2. **Plan-and-execute council second** — medium risk (output is plans, not code), high impact (better plans → better execution)
3. **Subagent-driven-development parallelism third** — highest risk (code merges), highest value when it works, needs most infrastructure

This order maximizes learning velocity: each skill's lessons inform the next.
