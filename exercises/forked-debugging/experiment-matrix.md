# Forked Debugging Experiment Matrix

> **Purpose:** Structured comparison of debugging modes across realistic scenarios.
> **Branch:** `feat/forked-debugging-superpower`

## Conditions

| ID | Condition | Description | Agent Count |
|----|-----------|-------------|-------------|
| A | Single-Agent | `systematic-debugging` + `think-twice` (current baseline) | 1 |
| B | Naive Multi-Agent | 3 independent investigators, no conductor, majority vote | 3 |
| C | Conductor-Led | Debug conductor + scoped investigators + adjudicator | 2–4 |

## Scenarios

| ID | Name | Domain | Difficulty | Key Challenge |
|----|------|--------|-----------|---------------|
| S1 | Telephony event sequencing | Telephony + state | Medium | Events arrive out of order; call state machine diverges |
| S2 | Timeout / retry amplification | Distributed | High | One slow service cascades timeouts across 4 services |
| S3 | LLM tool-selection regression | LLM behavior | Medium | Prompt change causes wrong tool selection in 20% of calls |
| S4 | State desync across services | State + distributed | High | Replication lag causes stale read in critical path |
| S5 | Intermittent prod-only incident | Heisenbug | Very High | Load-dependent race condition with incomplete evidence |

## Experiment Grid (15 cells)

| | S1 | S2 | S3 | S4 | S5 |
|---|---|---|---|---|---|
| **A (Single)** | A-S1 | A-S2 | A-S3 | A-S4 | A-S5 |
| **B (Naive)** | B-S1 | B-S2 | B-S3 | B-S4 | B-S5 |
| **C (Conductor)** | C-S1 | C-S2 | C-S3 | C-S4 | C-S5 |

## Metrics per Cell

| Metric | Type | Collection |
|--------|------|-----------|
| Time to first hypothesis (≥0.3 conf) | seconds | Timestamp diff |
| Time to validated root cause (≥0.8 conf) | seconds | Timestamp diff |
| Wrong hypotheses pursued | count | Branch verdicts = "rejected" |
| Evidence quality | 0.0–1.0 | Avg confidence across evidence items |
| Duplicate work | 0.0–1.0 | Jaccard overlap between branches |
| Operator readability | 1–5 | Human rating of incident packet |
| Token cost | count | Sum across all agents |
| Actionability | boolean | Did diagnosis produce concrete fix? |

## Scenario Fixtures

Each scenario includes:
1. **Incident description** — what the user reports
2. **System context** — services, dependencies, recent changes
3. **Available evidence** — logs, traces, metrics (pre-seeded)
4. **Hidden root cause** — ground truth for scoring
5. **Red herrings** — plausible but incorrect evidence

### S1: Telephony Event Sequencing Bug

**Incident:** "Calls are dropping after ~3 seconds. Caller hears ringing, then silence."

**System context:**
- Telephony gateway (SIP) → Call router → LLM orchestrator → Agent handler
- Recent deployment: call router v2.3.1 (2 hours ago)
- SIP INVITE timeout: 3000ms (configurable)

**Available evidence:**
- SIP traces: INVITE sent, 100 Trying received, 180 Ringing received, then timeout
- Call router logs: "Event received: call_connected" AFTER "Event received: call_disconnected"
- Metrics: Call setup latency p99 jumped from 1.2s to 3.8s after deployment

**Root cause:** Call router v2.3.1 introduced async event processing that delivers events out of order under load. The `call_disconnected` event from a previous call is processed before `call_connected` for the current call, causing the state machine to immediately transition to disconnected.

**Red herrings:**
- SIP timeout is 3000ms (looks like timeout issue, but timeout is effect not cause)
- Network latency increased 50ms (within normal variance)

### S3: LLM Tool-Selection Regression

**Incident:** "Agent is sending emails instead of making phone calls. Started yesterday."

**System context:**
- LLM orchestrator uses tool_use with 12 available tools
- Prompt template last updated: yesterday at 14:00
- Tools: `make_call`, `send_email`, `lookup_contact`, `schedule_callback`, ...

**Available evidence:**
- Agent trace: 20% of "call customer" requests invoke `send_email` instead of `make_call`
- Prompt diff: Tool description for `make_call` changed from "Initiate an outbound phone call" to "Reach out to a contact" (ambiguous with `send_email`)
- Token usage: Context window at 85% capacity on affected conversations
- Error rate: No errors logged (tool calls succeed — they just pick wrong tool)

**Root cause:** Prompt template update made `make_call` description ambiguous. Under high context load (>80% window), LLM defaults to `send_email` because its description is more specific ("Send an email message to...").

**Red herrings:**
- Context window at 85% (contributes but isn't root cause alone)
- No errors logged (silent failure — looks like everything works)

## Execution Protocol

1. **Randomize order** — don't always run A first (learning effect)
2. **Fresh agent context** per cell (no cross-contamination)
3. **Same evidence set** across conditions for same scenario
4. **Record full traces** for post-hoc analysis
5. **Human scorer** rates readability after all 15 cells complete
6. **3 runs per cell** for statistical stability (total: 45 runs)

## Success Criteria

Conductor-led (C) should demonstrate before being recommended:
- ≥20% faster time to validated root cause on S2, S4, S5 (complex scenarios)
- ≤2× token cost vs single-agent (A)
- Higher or equal evidence quality
- Higher actionability rate
- No scenario where C is strictly worse than A on all metrics
