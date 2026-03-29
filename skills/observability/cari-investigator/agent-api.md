---
name: agent-api
parent: [product]-investigator
description: CloudWatch Insights queries for [Product] agent Lambda logs — agent decisions, model failover, tool calls, LLM errors, integration debug.
---

# Agent API Sub-Skill

> **Log Group:** `/aws/lambda/[product]-agent-lambda-production` (production) / `/aws/lambda/[product]-agent-lambda-staging` (staging) / `/aws/lambda/[product]-agent-lambda-dev` (dev)
> **Primary Key:** `callId` — every log entry includes this field
> **AWS Profile:** `telephony-prod` (production) / `telephony-dev` (dev/staging)

## Purpose

This sub-skill investigates agent decision-making by querying CloudWatch Logs for the agent-api Lambda. The agent-api is the core AI brain — it receives call context, runs LLM inference, executes tool calls (schedule, cancel, lookup, transfer), and interacts with DMS/scheduler integrations.

<EXTREMELY_IMPORTANT>
**When retrieving call logs, ALWAYS filter by `callId`.** Do NOT use `lskinid`, phone number, or any other identifier to query agent-api CloudWatch logs — those identifiers do not appear on every log line and will return incomplete results. The `callId` is the only field guaranteed on every agent log entry.

If you only have an lskinid or phone number, look up the callId first via `reporting-service.md` (Query 3: Multi-Call Search), then use that callId here.
</EXTREMELY_IMPORTANT>

## Before Running

1. Get the `callId` from the user (or look it up from reporting-service using cm_call_id, phone number, or lskinid)
2. Determine environment (default: production)
3. Run the appropriate CloudWatch Insights query
4. Present the timeline of agent decisions
5. Cross-reference with config-service if integration-specific debugging is needed

## Query Index

| # | Query | Parameters | Use When User Asks... |
|---|-------|------------|----------------------|
| 1 | Full Call Timeline | callId | "What happened on this call?" / "Show me the agent logs" |
| 1b | Conversation & Context Reconstruction | callId | "Show me the conversation" / "What did the agent say?" / "Walk me through the call" |
| 2 | Error Investigation | callId | "Why did this call fail?" / "What went wrong?" |
| 3 | Model Failover Check | callId or time range | "Did the model fail over?" / "LLM issues?" |
| 4 | Tool Call Trace | callId | "What tools did the agent use?" / "What did the agent do?" |
| 5 | Integration Debug | callId | "Why couldn't it book?" / "DMS/scheduler issue?" |
| 6 | Slot Unavailability | callId or lskinid | "Why was the slot unavailable?" |
| 7 | Token Usage | callId | "How many tokens did this call use?" |
| 8 | Bulk Error Scan | time range | "Any agent errors in the last hour?" |
| 9 | Latency Analysis | callId or time range | "Was this call slow?" / "Latency issues?" |

---

## Running CloudWatch Insights Queries

Use the AWS CLI to run queries. The agent should construct and execute these:

```bash
# Default: run AWS CLI from PATH. Keep using "$AWS_CMD" so it can be swapped to a full path (with spaces) if needed.
AWS_CMD=aws

"$AWS_CMD" logs start-query \
  --log-group-name "/aws/lambda/[product]-agent-lambda-production" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string '<QUERY>' \
  --profile telephony-prod

# Then fetch results:
"$AWS_CMD" logs get-query-results --query-id <QUERY_ID> --profile telephony-prod
```

> **macOS note:** `date -d` is GNU-only. On macOS use `date -v-1H +%s` instead. WSL/Linux works as shown.

On Windows (PowerShell) — `aws` is in PATH natively, no `$AWS_CMD` needed:

```powershell
$startTime = [int][double]::Parse((Get-Date (Get-Date).AddHours(-1).ToUniversalTime() -UFormat %s))
$endTime = [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s))

$queryId = aws logs start-query `
  --log-group-name "/aws/lambda/[product]-agent-lambda-production" `
  --start-time $startTime --end-time $endTime `
  --query-string '<QUERY>' `
  --profile telephony-prod | ConvertFrom-Json | Select-Object -ExpandProperty queryId

# Wait a few seconds, then:
$env:PYTHONIOENCODING='utf-8'
aws logs get-query-results --query-id $queryId --profile telephony-prod
```

> **Windows encoding note:** Agent logs contain Unicode characters. Set `$env:PYTHONIOENCODING='utf-8'` before running AWS CLI commands. When running via Node.js `execSync`, use `encoding: 'buffer'` and decode as UTF-8, plus set `PYTHONIOENCODING` in the child process env.

---

## Query 1: Full Call Timeline

Shows every log entry for a call in chronological order.

```
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter callId = ':callId'
| display @timestamp, level, msg
| sort @timestamp asc
| limit 200
```


## Query 1b: Conversation & Context Reconstruction

Extracts the full agent conversation and call state progression from "Agent API: Result" entries. Each Result entry contains:
- **`history`** — the full conversation up to that point (user messages, assistant messages, tool_calls, tool results)
- **`context`** — live call state snapshot including `state` (agent workflow stage), `callEvents`, dealership config, customer/vehicle data

```
parse @message '"message":"*"' as msg
| filter callId = ':callId' and @message like /Agent API: Result/
| display @timestamp, msg
| sort @timestamp asc
| limit 50
```

> **Note:** Query 1b results can still be large (conversation history in `msg`). Always save CloudWatch output to a temp file before parsing — never pipe directly to python/jq.

### How to Parse the Results

Each "Agent API: Result" log entry is JSON with these key fields:

| Field | What It Contains |
|-------|-----------------|
| `history` | JSON array of the OpenAI-format conversation (`role`, `content`, `tool_calls`, `tool_call_id`) |
| `context.state` | Current agent workflow state (e.g., `existing_vehicle`, `new_vehicle`, `customer_name`, `service_needs`, `transportation`, `scheduling`, `appointment_management`) |
| `context.callEvents` | Array of significant events (e.g., `["scheduledAppt"]`, `["declinedTimeOffering"]`) |
| `context.call.callingNumber` | Caller phone number |
| `context.dealership.name` | Dealership name |
| `context.dealership.lskinid` | Dealership ID (use to cross-reference config-service) |

### Reconstructing the Conversation

The **last Result entry's `history`** contains the complete conversation. To reconstruct the agent dialogue:

1. Parse the `history` JSON array from the **last** Result entry
2. Walk through entries by role:
   - `role: "user"` → what the caller said (speech-to-text)
   - `role: "assistant"` with `content` → what the agent said (TTS to caller)
   - `role: "assistant"` with `tool_calls` → LLM decided to call a tool (includes `tts_text` in args — what caller hears during tool execution)
   - `role: "tool"` → tool execution result (what the agent learned)
3. The `context.state` across successive Result entries shows the agent workflow progression

### State Progression Reference

| State | Meaning |
|-------|---------|
| `existing_vehicle` | Agent asking about previously serviced vehicle |
| `new_vehicle` | Collecting new vehicle info (year/make/model) |
| `customer_name` | Collecting caller name |
| `service_needs` | Collecting what service is needed |
| `transportation` | Asking about transportation preference |
| `scheduling` | Fetching available times and booking |
| `appointment_management` | Appointment booked/cancelled/rescheduled |

### Presenting Conversation Logs

Format as a readable dialogue with tool calls inline:

```
Turn 1 | Agent: "Welcome back Sharon, are you calling about the 2023 Honda Pilot?"
Turn 2 | Caller: "No"
Turn 3 | Agent: → switch_prompt(new_vehicle) | "No problem."
Turn 4 | Agent: "What year, make, and model?"
Turn 5 | Caller: "2024 Honda Accord"
Turn 6 | Agent: → collect_new_vehicle(Honda, ACCORD, 2024) | "Perfect."
...
```

Include `tts_text` from tool_calls arguments — that is what the caller actually hears while the tool executes.
Note state transitions and callEvents for investigation context.

---

## Query 2: Error Investigation

Shows only errors and warnings for a call.

```
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| parse @message '"error":"*"' as error
| filter callId = ':callId' and (level = 'ERROR' or level = 'WARN')
| display @timestamp, level, msg, error
| sort @timestamp asc
| limit 100
```

## Query 3: Model Failover Check

Checks if the LLM failed over to a backup model during a call.

```
parse @message '"message":"*"' as msg
| parse @message '"modelIndex":*,' as modelIndex
| parse @message '"error":"*"' as error
| filter callId = ':callId' and @message like /failed after.*retrying|empty response.*retrying|LLM response failed/
| display @timestamp, msg, modelIndex, error
| sort @timestamp asc
```

For bulk failover analysis across all calls in a time range:

```
parse @message '"message":"*"' as msg
| parse @message '"modelIndex":*,' as modelIndex
| filter @message like /failed after.*retrying with next model/
| stats count() as failovers by callId, modelIndex
| sort failovers desc
| limit 20
```

## Query 4: Tool Call Trace

Shows tool execution — what the agent decided to do and the results.

```
parse @message '"message":"*"' as msg
| filter callId = ':callId'
  and (@message like /Tool call|tool call|Critical Operation|schedule_appointment|cancel_appointment|reschedule_appointment|lookup_customer|get_appointment_times|perform_transfer|collect_/)
  and msg not like /Agent API: Result/
| display @timestamp, msg
| sort @timestamp asc
| limit 100
```

## Query 5: Integration Debug (DMS/Scheduler)

Shows integration-specific logs — DMS lookups, scheduler API calls, appointment posting.

```
parse @message '"message":"*"' as msg
| parse @message '"error":"*"' as error
| filter callId = ':callId'
  and (@message like /Xtime|xtime|Motive|motive|DMS|dms/)
  and msg not like /Agent API: Result/
| display @timestamp, msg, error
| sort @timestamp asc
| limit 100
```

## Query 6: Slot Unavailability

**Per-call** (preferred — use this first):

```
parse @message '"message":"*"' as msg
| filter callId = ':callId' and @message like /Slot|slot|unavailable|No appointments/
| display @timestamp, msg
| sort @timestamp asc
```

**Bulk scan** (exception to callId-only rule — for cross-call pattern detection):

```
parse @message '"message":"*"' as msg
| filter @message like /Slot no longer available|No appointments available|no availability/
| display @timestamp, callId, msg
| sort @timestamp desc
| limit 50
```

## Query 7: Token Usage

```
parse @message '"message":"*"' as msg
| filter callId = ':callId' and @message like /Token usage|token/
| display @timestamp, msg
| sort @timestamp asc
```

## Query 8: Bulk Error Scan

Find all agent errors in a time window (no callId needed).

```
parse @message '"message":"*"' as msg
| parse @message '"error":"*"' as error
| filter level = 'ERROR'
| stats count() as errors by callId, msg
| sort errors desc
| limit 20
```

## Query 9: Latency Analysis

```
parse @message '"message":"*"' as msg
| filter callId = ':callId'
  and @message like /latency|Latency|duration|Duration/
  and msg not like /Agent API: Result/
| display @timestamp, msg
| sort @timestamp asc
```

---

---

> **For integration routing tables, agent tools catalog, decision flow diagram, cross-reference guide, and investigation patterns → see `references/agent-api-reference.md`**

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present the CloudWatch log timeline in chronological order
2. Highlight errors and warnings
3. For tool calls, show: tool name, key parameters, result
4. For integration calls, show: which API, request summary, response summary
5. Do NOT interpret agent decisions — present what happened, let the user assess
6. After presenting, ask: "What stands out? Want to drill into any specific part?"
