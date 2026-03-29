# Forked Debugging Superpower: Architecture Design

> **Status:** Draft · **Author:** Matt Bordenet · **Date:** 2026-03-29
> **Branch:** `feat/forked-debugging-superpower`

## 1. Problem Statement

Debugging complex distributed systems — especially telephony + LLM-integrated architectures — is hard because failures cross service boundaries, depend on timing, involve nondeterministic components, and leave incomplete evidence. A single debugging agent often gets stuck in one hypothesis path, missing parallel possibilities that a structured team would explore.

**The question is not "should we use multiple agents?" but "when does forking investigation work actually improve root-cause discovery, and when does it create noise, cost, and false confidence?"**

## 2. Research Foundation

This design is grounded in published research, not intuition. Key findings that constrain our architecture:

### 2.1 Multi-Agent Scaling Laws (Kim et al., Google Research + MIT, 2025)

180 controlled experiments across 4 benchmarks, 3 LLM families, 5 architectures. Critical findings:

| Finding | Implication for Design |
|---------|----------------------|
| **Centralized orchestration** outperforms independent agents on structured tasks (+80.9%) | Use conductor pattern, not peer swarm |
| **Independent agents amplify errors 17.2×**; centralized contains to 4.4× | Never fork without orchestrator validation |
| **Optimal team size: 3–4 agents** under fixed compute budgets | Hard-cap investigator count |
| Turn count grows **superlinearly** with agent count (T ∝ n^1.724) | Budget awareness is non-optional |
| **Capability saturation**: beyond ~45% single-agent accuracy, more agents → negative returns | Fork only when single-agent is insufficient |
| Tool-heavy tasks suffer **33% efficiency penalty** from coordination (β=-0.330, p<0.001) | Minimize inter-agent tool contention |

### 2.2 Multi-Agent Debugging (AgentRx, Microsoft Research, 2026; TraceCoder, ICSE 2026)

- AgentRx: Not all agents in a system are equally culpable. **Systematic attribution** of fault to specific agent + step enables targeted remediation.
- TraceCoder: Execution traces + causal analysis + multi-agent repair outperforms single-pass debugging.

### 2.3 Evidence Adjudication (Yang et al., 2026)

- **Majority voting fails** under correlated errors (agents trained on similar data converge on same wrong answer).
- **Reasoning trees + localized auditing** outperform voting by 3–5% absolute accuracy.
- Adjudicator must be trained to prefer **minority-correct** over majority-wrong reasoning.

### 2.4 Checkpoint/Replay Semantics (Zheng et al., 2026)

- Fork vs replay must be explicitly distinguished.
- Irreversible operations (API calls, DB writes) require **idempotency keys**.
- Temperature alone ≠ determinism; must also control seed, context length, tool ordering.

### 2.5 SRE Incident Response (Google SRE, 2020; Resolve.ai, 2026)

- Human incident teams use **Incident Command System**: IC delegates to specialists, minimal crosstalk.
- **Mitigation first, root cause second.** Generic mitigations (rollback, drain, quota increase) reduce MTTR.
- Formalize structure immediately. Unstructured parallel investigation wastes hours.

## 3. Architecture: Conductor-Led Bounded Investigation

### 3.1 Design Alternatives Considered

| Alternative | Description | Rejection Reason |
|-------------|-------------|-----------------|
| **A. Peer Swarm** | All investigators communicate freely | Error amplification 17.2×; consensus drift; cost explosion |
| **B. Static Pipeline** | Fixed sequence of investigators | Can't adapt to incident type; wastes time on irrelevant domains |
| **C. Conductor-Led Bounded (selected)** | Orchestrator assigns work, validates evidence, synthesizes | Best error containment (4.4×); adapts dynamically; bounded cost |

### 3.2 Core Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                    Debug Conductor                       │
│  (Incident Orchestrator / Decision Authority)            │
│                                                         │
│  Responsibilities:                                      │
│  • Triage incoming incident                             │
│  • Decide: serial vs. fork                              │
│  • Assign investigators with scoped mandates            │
│  • Validate evidence (not just collect it)              │
│  • Detect duplicate work across branches                │
│  • Dispatch evidence-adjudicator for synthesis           │
│  • Enforce budget/time/branch limits                    │
│  • Produce structured incident artifact                 │
└───────┬──────────┬──────────┬──────────┬───────────────┘
        │          │          │          │
        ▼          ▼          ▼          ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │Timeline │ │Telephony│ │ LLM/    │ │ State   │
   │& Trace  │ │  Flow   │ │ Prompt  │ │Coherency│
   │Investig.│ │Investig.│ │Investig.│ │Investig.│
   └─────────┘ └─────────┘ └─────────┘ └─────────┘
        │          │          │          │
        ▼          ▼          ▼          ▼
   ┌──────────────────────────────────────────────┐
   │          Evidence Adjudicator                 │
   │  (Root Cause Synthesizer)                     │
   │  • Builds reasoning tree from all branches    │
   │  • Identifies critical divergence points      │
   │  • Prefers evidence strength over vote count  │
   │  • Requires both supporting AND disconfirming │
   └──────────────────────────────────────────────┘
```

### 3.3 The Fork Decision: When to Parallelize

The conductor does NOT always fork. Serial debugging is the default. Forking is an escalation.

**Fork-Readiness Rubric** (score each 0–2, fork if total ≥ 6):

| Signal | Score | Example |
|--------|-------|---------|
| Multiple plausible domains involved | 0–2 | "Could be network, could be config, could be code" |
| Single-agent investigation stalled (think-twice already invoked) | 0–2 | Same hypothesis tested 2+ times |
| Incident crosses service boundaries | 0–2 | Failure spans 3+ services |
| Time pressure (production impact ongoing) | 0–2 | Revenue-affecting, customer-visible |
| Evidence suggests multiple contributing causes | 0–2 | Partial evidence for 2+ hypotheses |

**Anti-fork signals** (any one blocks forking):

- Single service, single component, clear error message → stay serial
- Budget exhausted (>80% consumed — see `fork-readiness-rubric.md`)
- Fewer than 2 distinct hypothesis domains identified
- Previous fork attempt produced duplicate findings

### 3.4 Bounded Forking Constraints

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Max concurrent investigators | 4 | Research: 3–4 optimal; beyond this, coordination overhead > gains |
| Max investigation branches | 6 | Prevent combinatorial explosion |
| Per-branch token budget | 25% of total | Forces prioritization; no single branch dominates |
| Per-branch time limit | 5 minutes wall-clock | Prevents runaway investigations |
| Confidence threshold to continue | ≥0.3 after first evidence | Kill low-confidence branches early |
| Duplicate work detection | Jaccard similarity >0.7 on evidence | Merge or kill overlapping branches |
| Mandatory disconfirming evidence | 1 per completed branch (killed branches exempt — see killed-branch contract in evidence-schema.md) | Prevents confirmation bias |

## 4. Investigator Role Definitions

Each investigator is a sub-agent with a scoped mandate, constrained tools, and a structured evidence output.

### 4.1 Debug Conductor (Incident Orchestrator)

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Incident description, system context, available tools, budget constraints |
| **Allowed tools** | All tools (read-only); investigation-crud.sh; todo-crud.sh; sub-agent dispatch |
| **Output** | `IncidentPacket` (see §5) |
| **Confidence** | Aggregated from investigators; weighted by evidence quality |
| **Stop** | Root cause identified ≥0.8 confidence; budget exhausted; time limit; user override |
| **Escalation** | All branches <0.3 confidence; contradictory high-confidence findings; scope exceeds investigators |
| **Handoff** | N/A — receives evidence, does not produce it directly |

**Decision loop:** Receive incident → classify domain(s) → apply fork rubric → operator checkpoint (approve/redirect/reject) → assign investigators → validate evidence → detect duplicates → dispatch `evidence-adjudicator` → write verdict to incident packet → produce artifact.

### 4.2 Timeline & Trace Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Incident timeframe, affected services, trace/correlation IDs |
| **Allowed tools** | Distributed tracing, log search, git log, deployment history, metrics |
| **Output** | `TimelineEvidence { events[], gaps[], correlations[] }` |
| **Confidence** | Trace completeness (% of request path covered) |
| **Stop** | Complete timeline; or 3 evidence items; or time limit |
| **Escalation** | Trace gaps >30% of path; conflicting timestamps across services |
| **Handoff** | Annotated timeline with suspicious intervals |

### 4.3 Telephony Flow Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Call IDs, expected vs actual behavior, call flow description |
| **Allowed tools** | SIP trace parser, call state validator, codec analyzer, RTP metrics |
| **Output** | `TelephonyEvidence { callFlow[], anomalies[], timingIssues[] }` |
| **Confidence** | Call-flow coverage × anomaly specificity |
| **Stop** | State divergence point identified; codec mismatch confirmed; or time limit |
| **Escalation** | One-way audio with no signaling anomaly; timing below measurement resolution |
| **Handoff** | Specific state transition where behavior diverged |

### 4.4 Prompt / LLM Behavior Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Agent trace, tool invocation logs, prompt versions, expected behavior |
| **Allowed tools** | Trace replay, tool schema validator, prompt diff, context window audit |
| **Output** | `LLMEvidence { toolCalls[], promptDiffs[], contextUsage, parsingFailures[] }` |
| **Confidence** | Tool call success rate × prompt version match × context headroom |
| **Stop** | Tool selection failure identified; prompt regression confirmed; or time limit |
| **Escalation** | Silent failure (tool returned error but agent continued); nondeterministic reproduction |
| **Handoff** | Specific tool call or prompt change that caused behavior shift |

### 4.5 State Consistency Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Affected data entities, service boundaries, consistency expectations |
| **Allowed tools** | DB queries (read-only), cache inspection, event stream audit, replication lag monitor |
| **Output** | `StateEvidence { inconsistencies[], replicationLag, eventOrdering[], staleReads[] }` |
| **Confidence** | Cross-source agreement (how many sources confirm the inconsistency) |
| **Stop** | Inconsistency source identified; or 3 comparison checks; or time limit |
| **Escalation** | Multiple inconsistencies with no common cause; data corruption suspected |
| **Handoff** | Specific data entity + timestamp where state diverged |

### 4.6 Infra / Config / Deployment Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Deployment timeline, config versions, infrastructure topology |
| **Allowed tools** | Git log, CI/CD history, config diff, resource metrics, health checks |
| **Output** | `InfraEvidence { deployments[], configChanges[], resourceMetrics[], healthStatus[] }` |
| **Confidence** | Temporal correlation (deployment timing vs incident onset) |
| **Stop** | Config or deployment change correlated with incident; or resource exhaustion confirmed; or time limit |
| **Escalation** | No deployment changes in window; resource metrics nominal |
| **Handoff** | Specific deployment or config change correlated with incident |

### 4.7 Reproduction & Experiment Investigator

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | Hypothesis to test, reproduction steps, expected outcome |
| **Allowed tools** | Test runner, environment setup, load generator, scenario scripts |
| **Output** | `ExperimentEvidence { hypothesis, steps[], outcome, reproduced: bool, confidence }` |
| **Confidence** | Reproduction success rate across N attempts |
| **Stop** | Hypothesis confirmed or rejected with ≥3 attempts; or time limit |
| **Escalation** | Intermittent reproduction (<50% success rate); environment mismatch |
| **Handoff** | Confirmed or rejected hypothesis with reproduction recipe |

### 4.8 Evidence Adjudicator (Root Cause Synthesizer)

| Attribute | Definition |
|-----------|-----------|
| **Inputs** | All evidence from all investigators, reasoning tree |
| **Allowed tools** | Evidence comparison, timeline correlation, contradiction detection |
| **Output** | `RootCauseVerdict { cause, confidence, supportingEvidence[], disconfirmingEvidence[], alternativeCauses[] }` |
| **Confidence** | Evidence convergence × source diversity × disconfirming evidence handled |
| **Stop** | Single root cause ≥0.8 confidence; or ranked causes with explicit gaps |
| **Escalation** | Contradictory high-confidence evidence; no hypothesis >0.5 confidence |
| **Handoff** | Final root cause verdict with full evidence chain |

**Adjudication algorithm:**

1. Build reasoning tree from all branches (per AgentAuditor research)
2. Identify Critical Divergence Points (CDPs) — where investigators disagree
3. At each CDP: evaluate evidence strength, not investigator count
4. Require both supporting AND disconfirming evidence for final verdict
5. Produce ranked list of causes with explicit confidence and gaps

## 5. Structured Incident Packet (Evidence Schema)

Every investigation produces a machine-readable incident packet, not a chat transcript.

```json
{
  "id": "uuid-v4",
  "created": "ISO-8601",
  "updated": "ISO-8601",
  "status": "active | resolved | escalated | abandoned",
  "incident": {
    "description": "Free text description of the problem",
    "severity": "P1 | P2 | P3 | P4",
    "affectedSystems": ["service-a", "telephony-gateway", "llm-orchestrator"],
    "timeline": {
      "detected": "ISO-8601",
      "mitigated": "ISO-8601 | null",
      "resolved": "ISO-8601 | null"
    }
  },
  "forkDecision": {
    "rubricScore": 7,
    "rubricDetails": { "multipleDomains": 2, "stalled": 1, "crossService": 2, "timePressure": 2, "multipleCauses": 0 },
    "decision": "fork",
    "rationale": "Cross-service telephony + LLM issue with ongoing production impact"
  },
  "branches": [
    {
      "id": "branch-uuid",
      "investigator": "telephony-flow",
      "hypothesis": "SIP INVITE timeout causing call drops",
      "status": "completed",
      "evidence": {
        "supporting": [
          { "source": "sip-trace", "finding": "INVITE response delayed >3s", "timestamp": "ISO-8601", "confidence": 0.85 }
        ],
        "disconfirming": [
          { "source": "metrics", "finding": "Network latency nominal at incident time", "timestamp": "ISO-8601", "confidence": 0.7 }
        ]
      },
      "verdict": "partial-cause",
      "tokensUsed": 4200,
      "wallClockSeconds": 45
    }
  ],
  "adjudication": {
    "rootCause": "Combined: SIP timeout (3s threshold) + LLM tool-selection delay (2.5s) exceeded call setup window",
    "confidence": 0.82,
    "divergencePoints": ["Was delay in network or application layer?"],
    "alternativeCauses": [
      { "cause": "Config change to timeout value", "confidence": 0.15, "reason": "No config changes in deployment window" }
    ]
  },
  "budget": {
    "totalTokens": 25000,
    "usedTokens": 18400,
    "branches": 3,
    "wallClockSeconds": 180
  },
  "nextSteps": ["Increase SIP INVITE timeout to 5s", "Add LLM response time monitoring"],
  "relatedInvestigations": [],
  "relatedTickets": []
}
```

## 6. Integration with Existing Superpowers

This design builds on — not replaces — the existing debugging triad:

| Existing Skill | Role in Forked Debugging |
|---------------|-------------------------|
| `systematic-debugging` | Phase 1 (serial) investigation; conductor invokes this first |
| `investigation-state` | Evidence persistence layer; extended with branch/fork metadata |
| `think-twice` | Escalation trigger; a stuck serial investigation is the primary fork signal |
| `thinking-orchestrator` | Hub router; gains new routing rule: debugging + fork-ready → conductor |
| `subagent-driven-development` | Dispatch pattern; investigators use same sub-agent dispatch |
| `autonomous-chain-controller` | Chain template: adds "distributed-debug" chain type |
| `adversarial-search` | Embedded in adjudicator; ensures disconfirming evidence |
| `failure-autopsy` | Post-resolution analysis; invoked after incident packet is closed |

**Composition metadata additions:**

```yaml
composition:
  produces: [incident-packet, root-cause-verdict, investigation-evidence]
  consumes: [incident-description, system-context, investigation-state]
  capabilities: [orchestrates-investigation, parallel-hypothesis-testing]
```

## 7. Implementation Waves

### Wave 1: Foundation (Current)

- [x] Inventory existing skills and orchestration hooks
- [x] Write design document
- [x] Create TODO ledger (`docs/plans/forked-debugging-TODO.md`)
- [x] Create fork-readiness rubric (`skills/_shared/fork-readiness-rubric.md`)
- [x] Define evidence JSON schema (`skills/_shared/evidence-schema.md`)
- [x] Create conductor skill skeleton (`skills/engineering/debug-conductor/`)
- [x] Create experiment matrix + fixtures S1, S3
- [x] Harsh review round 1 (findings addressed below)

### Wave 2: Conductor + Core Investigators

- [ ] Implement `debug-conductor` skill with decision loop
- [ ] Implement `timeline-trace-investigator` skill
- [ ] Implement `llm-behavior-investigator` skill
- [ ] Define incident packet schema in `_shared/`
- [ ] Add progressive harsh review checkpoints

### Wave 3: Fork Semantics + Experiment Infrastructure

- [ ] Add branch tracking to `investigation-state`
- [ ] Implement duplicate-work detection (Jaccard similarity)
- [ ] Create experiment fixture scenarios
- [ ] Add branch budget enforcement
- [ ] Create experiment harness script

### Wave 4: Full Investigator Set + Experiments

- [ ] Implement remaining investigators (telephony, state, infra, reproduction)
- [ ] Implement evidence adjudicator
- [ ] Run comparative experiments (single vs naive-multi vs conductor-led)
- [ ] Record failures, surprising results, cases where forking hurts
- [ ] Add confidence scoring calibration

### Wave 5: Refinement + Recommendation

- [ ] Refine architecture based on experiment evidence
- [ ] Produce final recommendation document
- [ ] Document limitations candidly
- [ ] Update existing skills with integration hooks
- [ ] Cleanup deferred TODO items

## 8. Experiment Plan

### 8.1 Experimental Conditions

| Condition | Description |
|-----------|-------------|
| **A. Single-Agent** | `systematic-debugging` + `think-twice` (current behavior) |
| **B. Naive Multi-Agent** | 3 independent investigators, no conductor, majority vote |
| **C. Conductor-Led** | Debug conductor + scoped investigators + adjudicator |

### 8.2 Scenarios

| # | Scenario | Domain | Difficulty |
|---|----------|--------|-----------|
| S1 | Telephony event sequencing bug | Telephony + state | Medium |
| S2 | Cross-service timeout / retry amplification | Distributed | High |
| S3 | LLM tool-selection regression | LLM behavior | Medium |
| S4 | State desynchronization across services | State + distributed | High |
| S5 | Intermittent production-only incident with incomplete evidence | Heisenbug | Very High |

### 8.3 Metrics

| Metric | How Measured |
|--------|-------------|
| Time to first plausible hypothesis | Wall-clock from incident start to first hypothesis with ≥0.3 confidence |
| Time to validated root cause | Wall-clock to root cause with ≥0.8 confidence |
| Wrong hypotheses pursued | Count of branches with verdict "rejected" |
| Evidence quality | Avg confidence across final evidence items |
| Duplicate work | Jaccard overlap between branch evidence sets |
| Operator readability | Subjective 1–5 rating of incident packet |
| Cost (tokens) | Total tokens consumed across all agents |
| Actionability | Binary: did the diagnosis lead to a concrete fix? |

## 9. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cost explosion from parallel agents | High | Medium | Hard budget caps per branch; kill low-confidence early |
| False confidence from agreeing agents | Medium | High | Mandatory disconfirming evidence; adjudicator audits reasoning, not votes |
| Duplicate investigation work | High | Low | Jaccard similarity detection; conductor merges overlapping branches |
| Conductor becomes bottleneck | Medium | Medium | Conductor only validates + routes; doesn't investigate |
| Nondeterministic reproduction | High | Medium | Seed pinning; cached tool outputs; explicit branch semantics |
| Over-engineering for simple bugs | Low | Medium | Fork-readiness rubric; serial is default |

## 9.5 Honest Caveats (Added After Harsh Review Round 1)

The following limitations were identified by adversarial review and are not yet resolved:

1. **Confidence scores are uncalibrated.** The 0.3 kill threshold and 0.8 accept threshold are starting guesses, not empirically justified. Calibration is deferred to Wave 4 experiments. **Risk:** The minority-correct branch may be killed early while verbose wrong branches survive.

2. **Jaccard similarity is too naive for semantic duplicate detection.** Lexically different evidence about the same root cause will not be detected. **Mitigation needed:** Semantic similarity or structured field matching in Wave 3.

3. **"Mandatory disconfirming evidence" may produce theater.** In sparse incidents, agents may manufacture low-value contradictions to satisfy the template. **Mitigation:** Allow explicit "no disconfirming evidence available" with justification, rather than forcing fabrication.

4. **Correlated false evidence is unhandled.** If investigators share a bad telemetry source, all branches independently confirm the same wrong cause. **Mitigation needed:** Source diversity scoring in adjudicator (Wave 4).

5. **Schema migration from investigation-state is non-trivial.** The current `investigation-crud.sh` supports linear hypotheses only. Branch-aware operations require a data model extension, not just a field addition. **Decision:** Incident packets are a NEW artifact type (not an extension of investigation-state) to avoid breaking existing tooling.

6. **Research transfer is unproven.** Kim et al.'s findings are about multi-agent reasoning tasks, not debugging specifically. The transfer to our domain must be validated empirically, not assumed.

7. **Fork-readiness rubric requires judgment.** Signals like "stalled" and "multiple plausible domains" are fuzzy. LLM agents may score inconsistently. **Mitigation:** Provide concrete examples for each score level (done in rubric doc).

## 10. Decision Rubric: When to Fork, When Not To

### Fork when ALL of

- Single-agent investigation has stalled or been escalated via `think-twice`
- ≥2 distinct hypothesis domains identified
- Incident crosses service boundaries
- Fork-readiness rubric score ≥6
- Budget permits (<80% consumed)

### Stay serial when ANY of

- Clear error message points to single root cause
- Single service, single component affected
- Budget >80% consumed
- Previous fork attempt on similar incident produced duplicate findings

### Never fork when

- Incident is resolved or mitigated
- User explicitly requests serial investigation
- Fewer than 2 investigators would be assigned (1 fork = serial with overhead)

## 11. Open Questions (Deferred to Experiments)

1. What confidence threshold best balances branch pruning vs. premature kill?
2. How should the adjudicator weight evidence from different investigator types?
3. Does the conductor benefit from seeing investigator evidence in real-time, or only at completion?
4. What's the minimum incident complexity where forking outperforms serial?
5. How do we calibrate confidence scores across different evidence types?
6. Should investigators be allowed to request additional investigators (dynamic forking)?
7. How does this integrate with real-time incident response (human-in-the-loop)?

## 12. References

1. Kim et al., "Towards a Science of Scaling Agent Systems," Google Research + MIT, Dec 2025
2. AgentRx, Microsoft Research, Mar 2026
3. Huang et al., "TraceCoder," ICSE 2026
4. Yang et al., "Auditing Multi-Agent Reasoning Trees," Feb 2026
5. Zheng et al., "Preventing Semantic Rollback in Agent Checkpoint-Restore," arXiv 2603.20625, Mar 2026
6. Google SRE, "Debugging Incidents in Distributed Systems," CACM 2020
7. Zhang et al., "AutoCodeRover," ISSTA 2024
8. Wang et al., "OpenHands/CodeAct," ICLR 2025
