---
name: telephony-service
parent: cari-investigator
description: ECS CloudWatch queries for telephony — call lifecycle, SIP events, websocket/audio streaming, transfer sequences, turn latency, call cost.
---

# Telephony Service (ECS) — Investigation Skill

Use this when the investigation is about **call transport / carrier / websocket / audio streaming / orchestrator init / transfers**.
This complements:
- `agent-api.md` (agent decisioning / tool calls)
- `reporting-service.md` (DB outcomes)

<EXTREMELY_IMPORTANT>
**Always ask which environment to investigate (prod vs dev vs staging). Never default.**
</EXTREMELY_IMPORTANT>

## Environments

| Environment | AWS Profile | CloudWatch Log Group |
|-------------|-------------|----------------------|
| Production | `telephony-prod` | `/ecs/cari-telephony-production` |
| Dev | `telephony-dev` | `/ecs/cari-telephony-dev` |
| Staging | `telephony-dev` | `/ecs/cari-telephony-staging` |

## Inputs

You can investigate using any identifier you have:
- `callId` (UUID — usually matches reporting-service + agent-api)
- `callControlId` (carrier call control id, often `v3:...`)

Telephony logs are structured JSON (see `telephony-service/src/utils/logger.ts`). Common fields:
- `level` (INFO/WARN/ERROR/DEBUG), `message`, `timestamp`, `service` ("telephony-service")
- `callId` (always present — required by `telephonyLogger`)
- `callControlId` (Telnyx carrier ID, often `v3:...`)
- `lskinid` (dealer ID, top-level JSON field — use `fields lskinid` not `parse`), `agentType` (scheduler/receptionist/acquisition)
- `audioCodec`, `incomingIpAddress`, `customerPhone` (logged at init)
- Hangup events include: `hangupCause`, `hangupSource`, `callQuality` (MOS, jitter, packet loss)
- Cost events include: `durationSeconds`, `cost`, `costBreakdown`

## Query Templates (CloudWatch Logs Insights)

### T0 — Find correlation IDs (when you only have a partial ID)
Use this to discover the paired UUID ↔ `v3:` id.

```sql
parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| filter @message like /<<ID_FRAGMENT>>/
| display @timestamp, callId, msg
| sort @timestamp desc
| limit 50
```

### T1 — Full timeline for one call

```sql
fields lskinid
| parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| parse @message '"callControlId":"*"' as callControlId
| filter callId = '<<CALL_ID>>' or callControlId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/
| display @timestamp, level, msg, callId, callControlId, lskinid
| sort @timestamp asc
| limit 500
```

### T2 — WARN/ERROR triage for one call

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| parse @message '"callControlId":"*"' as callControlId
| filter (callId = '<<CALL_ID>>' or callControlId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/)
  and (level = 'ERROR' or level = 'WARN')
| display @timestamp, level, msg, callId
| sort @timestamp asc
| limit 200
```

### T3 — Milestones only (fast skim)

```sql
parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| parse @message '"callControlId":"*"' as callControlId
| filter (callId = '<<CALL_ID>>' or callControlId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/)
  and (msg like /Call initiated|Call answered|Audio streaming started|Media streaming|CallOrchestrator fully initialized|Starting call flow|Starting outbound|Blind transfer executed|Warm transfer succeeded|Complete transfer sequence failed|Account is inactive|Streaming failed|Call rejected|Call hangup|Call cost|Call ended|Call cleanup/)
| display @timestamp, msg
| sort @timestamp asc
| limit 200
```

### T4 — Correlation IDs + quick stats (recommended)
Extract key identifiers (UUID vs `v3:`), dealer, and basic counts.

```sql
fields lskinid
| parse @message '"callId":"*"' as callId
| parse @message '"callControlId":"*"' as callControlId
| parse @message '"level":"*"' as level
| filter callId = '<<CALL_ID>>' or callControlId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/
| stats
    min(@timestamp) as firstSeen,
    max(@timestamp) as lastSeen,
    count() as lines,
    sum(if(level = 'WARN', 1, 0)) as warns,
    sum(if(level = 'ERROR', 1, 0)) as errors,
  by callId, callControlId, lskinid
| sort lines desc
| limit 20
```

### T5 — Top repeated messages (noise vs signal)
Useful when one warning dominates (e.g., duplicate WebSocket messages).

```sql
parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| parse @message '"callControlId":"*"' as callControlId
| filter callId = '<<CALL_ID>>' or callControlId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/
| stats count() as cnt by msg
| sort cnt desc
| limit 20
```

### T6 — Turn Latency & Pipeline Metrics (single call)

Extracts per-turn latency data logged by `CallMetricsTracker`. Each turn emits:
- `turnLatencyMs`: end-to-end (user stops speaking → AI audio starts), includes STT + VAD + LLM + TTS
- `pipelineLatencyMs`: computational only (STT + LLM + TTS, excludes VAD wait)
- `vadWaitMs`: time spent in voice activity detection / turn-end confirmation

Also captures one-time call-level timing (**⚠️ logged at DEBUG level — may not be available in production**):
- `timeToFirstAudioOutputMs`: call start → AI speaks for the first time
- `timeToCustomerReadyMs`: call start → greeting complete, STT listening
- `timeToFirstInteractionMs`: call start → first user speech or DTMF

Always available (INFO level):
- `Latency metrics measured`: per-turn turnLatencyMs, vadWaitMs, pipelineLatencyMs
- `Agent API timing`: first message latency and context/history round-trip

```sql
parse @message '"message":"*"' as msg
| parse @message '"callId":"*"' as callId
| parse @message '"turnLatencyMs":*,' as turnLatency
| parse @message '"pipelineLatencyMs":*}' as pipelineLatency
| parse @message '"vadWaitMs":*,' as vadWait
| parse @message '"timeToFirstAudioOutputMs":*}' as ttFirstAudio
| parse @message '"timeToCustomerReadyMs":*}' as ttCustomerReady
| parse @message '"timeToFirstInteractionMs":*}' as ttFirstInteraction
| filter (callId = '<<CALL_ID>>' or @message like /<<CALL_ID>>/)
  and (msg like /Latency metrics measured|First audio output tracked|Customer ready to speak tracked|First user interaction tracked|Agent API timing/)
| display @timestamp, msg, turnLatency, pipelineLatency, vadWait, ttFirstAudio, ttCustomerReady, ttFirstInteraction
| sort @timestamp asc
| limit 200
```

**Interpreting the results:**
- `turnLatencyMs` > 2000ms = noticeable delay for the caller
- `pipelineLatencyMs` isolates compute time from VAD wait (useful for diagnosing slow LLM vs slow STT)
- `timeToFirstAudioOutputMs` > 3000ms = caller hears silence before AI greeting (bad UX)
- Agent API timing lines show `First Message = Xms` (time to first TTS chunk) and `Context/History = Yms` (full round-trip)

## Output: Summarized Call Report (required)

When this skill is used, return a short report (in chat) in this format:

```markdown
## Telephony-Service Call Report
- **Environment:** <prod|dev|staging>
- **Input identifier:** <callId or callControlId>
- **Correlation IDs:** callId=<uuid>, callControlId=<v3:...>
- **Dealer:** lskinid=<id>, agentType=<scheduler|receptionist|acquisition>
- **Log window:** <start..end searched> | firstSeen=<ts> | lastSeen=<ts>
- **Total log lines:** <N> | Warnings: <N> | Errors: <N>

### Lifecycle (milestones)
| Milestone | Timestamp | Notes |
|-----------|-----------|-------|
| Call initiated | | inbound/outbound, audioCodec |
| Call answered | | streaming mode |
| Audio streaming started | | |
| Orchestrator initialized | | agentType, config fetched |
| Call flow started | | |
| Transfer (if any) | | blind/warm, target, success/fail |
| Call hangup | | hangupCause, hangupSource |
| Call cleanup | | |
| Call cost | | durationSeconds, cost |

### Latency Summary (from T6 query)
| Metric | Value | Assessment |
|--------|-------|------------|
| Time to first audio (greeting) | <ms> or N/A (DEBUG only) | < 3000ms = good |
| Time to customer ready | <ms> or N/A (DEBUG only) | |
| Time to first interaction | <ms> or N/A (DEBUG only) | |
| Avg turn latency | <ms> | < 2000ms = good |
| Avg pipeline latency | <ms> | |
| Avg VAD wait | <ms> | |
| Agent API first message | <ms> | |
| Agent API context/history | <ms> | |

### Call Quality (from hangup event, if present)
- MOS: <value>, Jitter: <value>ms, Packet Loss: <value>%

### Errors / Warnings
| Timestamp | Level | Message |
|-----------|-------|---------|
| <ts> | WARN/ERROR | <message> |

### Notes / Likely Root Cause
- 1–2 bullet points based on earliest ERROR/WARN and where the lifecycle stopped.

### Next Steps (cross-correlation)
- Run `agent-api.md` Query 1/1b with the same callId to see agent decisioning + conversation.
- Run `reporting-service.md` Query 1 to see the final recorded outcome in the DB.
```

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present the CloudWatch log timeline in chronological order
2. Highlight SIP errors, websocket failures, and call lifecycle anomalies
3. For transfer sequences, show: initiator, target extension, ringback duration, outcome
4. Do NOT interpret call quality — present what happened, let the user assess
5. After presenting, ask: "What stands out? Want to drill into any specific part?"
