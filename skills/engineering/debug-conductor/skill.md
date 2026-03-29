---
name: debug-conductor
source: superpowers-plus
description: >
  PREVIEW — Conductor-led bounded investigation for complex distributed system incidents.
  Decides whether to stay serial or fork into parallel investigator branches.
  Produces structured incident packets, not chat transcripts.
  NOTE: Incident-packet persistence tooling is not yet implemented; this skill
  defines the protocol and evidence contracts but cannot persist packets end-to-end.
triggers:
  - "investigate distributed"
  - "debug across services"
  - "cross-service failure"
  - "incident investigation"
  - "forked debugging"
  - "parallel investigation"
  - "complex incident"
anti_triggers:
  - "simple bug"
  - "single file fix"
  - "write tests"
  - "implement feature"
coordination:
  group: engineering
  order: 2
  requires: ["systematic-debugging"]
  enables: ["investigation-state", "failure-autopsy"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  produces: [incident-packet, root-cause-verdict, investigation-evidence]
  consumes: [incident-description, system-context, investigation-state]
  capabilities: [orchestrates-investigation, parallel-hypothesis-testing]
  priority: 3
  optional: false
  requires_all: false
---

# Debug Conductor

> **Research basis:** Kim et al. (2025) — centralized orchestration contains errors to 4.4× vs 17.2× for independent agents. Optimal team: 3–4 investigators. Fork only when single-agent is insufficient.

## When to Use

- Complex incident crossing service boundaries
- Debugging stalled after `systematic-debugging` + `think-twice`
- Multiple plausible hypothesis domains (telephony, LLM, state, infra)
- Production impact requiring faster resolution than serial investigation

## When NOT to Use

- Single service, clear error message → use `systematic-debugging`
- First investigation attempt (always start serial)
- Budget exhausted (>80% consumed — see `fork-readiness-rubric.md`)

## The Conductor Protocol

### Phase 1: Incident Triage

1. **Receive incident description** from user or escalation from `systematic-debugging`
2. **Extract structured context:**
   - Affected systems and services
   - Timeline (when detected, any mitigation in place)
   - Available evidence (logs, traces, metrics, user reports)
   - Recent changes (deployments, config, code)
3. **Classify hypothesis domains:**
   - Timeline / trace gaps
   - Telephony call flow
   - LLM / prompt behavior
   - State consistency
   - Infrastructure / config / deployment
4. **Initialize incident packet** (see `references/incident-packet-schema.md`)

### Phase 2: Fork Decision

Apply the **Fork-Readiness Rubric** (see `skills/_shared/fork-readiness-rubric.md`).

| Score | Decision |
|-------|----------|
| < 6 | **SERIAL** — continue with `systematic-debugging` |
| ≥ 6, anti-fork signal present | **SERIAL** — log why fork was blocked |
| ≥ 6, no anti-fork signals | **FORK** — proceed to Phase 3 |

**Record the rubric score and rationale in the incident packet.**

**Operator checkpoint:** Before forking, present the rubric score, proposed investigator mix, and estimated budget to the user.

| Response | Action |
|----------|--------|
| **Approve** (yes, go, LGTM) | Proceed to Phase 3 |
| **Redirect** (change investigators, adjust hypotheses) | Apply user's adjustments, re-present for approval |
| **Reject** (no, don't fork, stay serial) | Fall back to serial `systematic-debugging` |
| **Conditional** ("yes but limit to 2 branches") | Apply constraints, proceed |
| **Explain more** ("why these investigators?") | Provide rationale, re-present; do NOT auto-proceed |
| **Off-topic / unclear** | Clarify once: "Should I proceed with forked investigation?" If still unclear → single-agent fallback |
| **Echo** (repeats the plan back) | Treat as approval |
| **No response / silence** | Stay serial (`systematic-debugging`); log that fork was available but not approved |

### Phase 3: Investigator Assignment (Fork Path)

1. **Select investigators** based on classified domains (max 4):
   - Timeline & Trace Investigator — always included if trace data available
   - Domain-specific investigator(s) — telephony, LLM, state, infra
   - Reproduction & Experiment — only if hypothesis is testable
2. **Scope each mandate:**
   - Specific hypothesis to investigate
   - Allowed tools (constrained to domain)
   - Token budget (25% of remaining per branch)
   - Wall-clock limit (5 minutes per branch)
   - **Required output:** both supporting AND disconfirming evidence
3. **Dispatch investigators as parallel sub-agents**
   - Each investigator gets: incident context + scoped mandate + evidence schema
   - Investigators do NOT communicate with each other (centralized only)

### Phase 4: Evidence Collection & Validation

As investigators return evidence:

1. **Validate** — is the evidence properly structured? Does it include confidence?
2. **Detect duplicates** — Jaccard similarity > 0.7 between branch evidence → merge
3. **Monitor budgets** — kill branches exceeding limits
4. **Check confidence** — kill branches with < 0.3 confidence after first evidence
5. **Update incident packet** in real-time

### Phase 5: Adjudication

When all investigators complete (or budget exhausted), **dispatch `evidence-adjudicator`**:

1. Pass all branch evidence packets to `evidence-adjudicator`
2. Adjudicator builds reasoning tree, weighs evidence strength, detects contradictions
3. Adjudicator produces `RootCauseVerdict` with confidence score and alternative causes
4. Conductor receives verdict and proceeds to Phase 6

> **Ownership:** The conductor orchestrates; `evidence-adjudicator` synthesizes. The conductor MUST NOT perform adjudication itself.

### Phase 6: Resolution

1. **Write adjudicator verdict** to `incidentPacket.adjudication`
2. **Update `incidentPacket.budget`** with final token/time usage per branch
3. **If confidence ≥ 0.8:** Present root cause + recommended next steps
4. **If confidence 0.5–0.8:** Present ranked hypotheses, recommend targeted experiments
5. **If confidence < 0.5:** Escalate to user with what we know and what we don't
6. **Write resolution actions** to `incidentPacket.nextSteps`
7. **Always:** Invoke `failure-autopsy` for post-resolution learning
8. **Always:** Update `investigation-state` with final verdict
9. **Always:** Log to TODO ledger any deferred follow-ups

## Bounded Forking Constraints

| Constraint | Value | Action at Limit |
|-----------|-------|----------------|
| Max concurrent investigators | 4 | Queue additional; explain to user |
| Max total branches | 6 | Stop branching; dispatch `evidence-adjudicator` with current branches |
| Per-branch token budget | 25% of total | Kill branch |
| Per-branch wall-clock | 5 minutes | Kill branch |
| Min confidence to continue | 0.3 | Kill branch |
| Duplicate threshold | Jaccard > 0.7 | Merge branches |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| All investigators find nothing | All branches < 0.3 confidence | Escalate to user; suggest new evidence sources |
| Investigators agree on wrong cause | High confidence but contradicted by reproduction | Require reproduction before accepting verdict |
| Cost explosion | Budget > 80% with no verdict | Stop forking; dispatch `evidence-adjudicator` with partial findings |
| Conductor bottleneck | Queued evidence > 3 items unprocessed | Process evidence in batch; simplify validation |
| Circular investigation | Same hypothesis re-investigated | Track hypothesis IDs; reject duplicates |
| Adjudicator failure | `evidence-adjudicator` times out or returns malformed verdict | Retry once; if still failed, escalate with partial ranked evidence and mark adjudication as degraded |

## Companion Skills

- **systematic-debugging** — serial investigation (always try first)
- **investigation-state** — evidence persistence across sessions
- **think-twice** — escalation signal (fork trigger)
- **adversarial-search** — embedded in adjudicator Step 5b (disconfirmation pass)
- **failure-autopsy** — post-resolution learning
- **thinking-orchestrator** — hub router (routes here when fork-ready)
