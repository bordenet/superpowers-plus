---
name: report-templates
description: Standardized report templates for [product]-investigator output
type: reference
---

# Report Templates

## Template Selection

| User Request | Template |
|-------------|----------|
| "What happened on call {callId}" | 1: Single Call Investigation |
| "How is dealer {lskinid} doing" | 2: Dealer Health Check |
| "Why did call {callId} fail" | 3: Error Investigation |
| "Show me calls for {lskinid} this week" | 4: Bulk/Trend Analysis |
| "Check xtime/PBS/Motive for {lskinid}" | 5: Integration Deep Dive |
| "Show me trends for {lskinid} over 30 days" | 6: Dealership Trend Report |

> **If no template fits the user's request**, don't force one. Use the templates as a starting point and adapt the output to match what the user actually asked for. Skip sections that aren't relevant, add sections that are. The templates are guardrails, not handcuffs.

## Shared Sections

These sections appear across multiple templates. Use them as building blocks.

### Call Summary Block

| Field | Value |
|-------|-------|
| Call ID | {call_id} |
| CM Call ID | {cm_call_id} |
| Dealer (lskinid) | {lskinid} — {dealer_name} |
| Agent Type | {scheduler/receptionist/acquisition} |
| Start | {start_time} (ET) |
| End | {end_time} (ET) |
| Duration | {duration}s ({Xm Ys}) |
| Language | {language} |
| Caller | {caller_phone_number} |
| Classification | {call_classification} |

### Dealer Config Block

| Field | Value |
|-------|-------|
| lskinid | {lskinid} — {name} |
| Timezone | {time_zone} |
| DMS Type | {dms_type} |
| Scheduler Type | {scheduler_type} |
| Scheduler Active | {yes/no} |
| Receptionist Active | {yes/no} |
| Test Account | {yes/no} |

### Errors Block

| Time (ET) | Source | Level | Message |
|-----------|--------|-------|---------|
| {combined from agent Q2 + telephony T2 + integration errors} |

---

## Template 1: Single Call Investigation

**Use when:** User provides a callId and wants to know what happened.

**Sections (in order):**
1. Call Summary Block
2. Dealer Config Block
3. Outcome — scheduler or receptionist depending on agent_type
4. Services Booked (opcodes) — skip if none
5. Call Timeline — telephony lifecycle + agent key decisions, chronological
6. Errors Block — skip if none
7. Latency — time to first audio, avg turn, avg pipeline

| Field | Value |
|-------|-------|
| Outcome | {outcome} |
| Customer Type | {new/returning} |
| Service Complexity | {simple/medium/complex} |
| Transportation | {waiter/shuttle/loaner/rideshare/none} |
| Time Until First Available | {X} days |
| Transfer Reason | {if transferred} |
| Abandoned Reason | {if abandoned} |

### Receptionist Outcome

| Field | Value |
|-------|-------|
| Transferred To | {first_extension_name} ({first_extension_phone_number}) |
| Pickup Duration | {first_pickup_duration}s |
| Response | {answered/voicemail/no_answer} |
| [[warm-transfer]] | {summary} |
| Transferred to Scheduler | {yes/no} |

### Services Booked

| Code | Description | Price | Duration |
|------|-------------|-------|----------|
| {rows from call_opcodes — skip section if empty} |

### Call Timeline

| Time (ET) | Source | Event |
|-----------|--------|-------|
| {telephony T3 lifecycle + agent-api key decisions + integration calls, merged chronologically} |

### Latency

| Metric | Value |
|--------|-------|
| Time to first audio | {ttfa}ms |
| Avg turn latency | {avg}ms |
| Avg pipeline latency | {avg}ms |

---

## Template 2: Dealer Health Check

**Use when:** User provides an lskinid and wants a general status.

**Sections (in order):**
1. Dealer Config Block
2. Active Products — scheduler/receptionist/acquisition with active status
3. Last 7 Days Performance — call count, booking rate, abandonment, transfers
4. Top Abandonment Reasons — skip if none
5. Integration Health — last sync, polling status, recent errors

### Active Products

| Product | Active | Last Config Update |
|---------|--------|-------------------|
| Scheduler | {yes/no} | {updated_at} |
| Receptionist | {yes/no} | {updated_at} |
| Acquisition | {yes/no} | {updated_at} |

### Last 7 Days Performance

| Metric | Value |
|--------|-------|
| Total Calls | {count} |
| Booking Rate | {X}% |
| Abandonment Rate | {X}% |
| Transfer Rate | {X}% |
| Avg Duration | {X}s |
| Avg Time to First Available | {X} days |

### Top Abandonment Reasons

| Reason | Count | % |
|--------|-------|---|
| {from performance-analytics — skip if no abandonments} |

### Integration Health

| Check | Status |
|-------|--------|
| Last successful data sync | {timestamp} |
| Polling active | {yes/no} |
| Recent integration errors (24h) | {count} |

---

## Template 3: Error Investigation

**Use when:** User asks why a call failed or what went wrong.

**Sections (in order):**
1. Call Summary Block
2. Error Timeline — all errors/warnings chronological across all services
3. Root Cause Analysis — per-layer status summary
4. Conversation Flow — key moments from transcription if relevant

### Error Timeline

| Time (ET) | Source | Level | Message | Detail |
|-----------|--------|-------|---------|--------|
| {all errors/warnings from agent, telephony, integration — chronological} |

### Root Cause Analysis

| Layer | Status |
|-------|--------|
| Telephony (SIP/audio) | {ok/error — one-line summary} |
| Agent (AI decisions) | {ok/error — one-line summary} |
| Integration (DMS/scheduler API) | {ok/error — one-line summary} |
| Config (dealer setup) | {ok/error — one-line summary} |

### Conversation Flow

| Time | Speaker | What Happened |
|------|---------|--------------|
| {key moments from transcription — only include if relevant to the error} |

---

## Template 4: Bulk/Trend Analysis

**Use when:** User asks for multiple calls over a date range.

**Sections (in order):**
1. Query Parameters — dealer, date range, agent type
2. Summary — totals and percentages
3. Breakdown by Outcome
4. Breakdown by Abandonment Reason — skip if none
5. Daily Trend

### Query Parameters

| Filter | Value |
|--------|-------|
| Dealer | {lskinid} — {name} |
| Date Range | {start} to {end} |
| Agent Type | {scheduler/receptionist/all} |

### Summary

| Metric | Value |
|--------|-------|
| Total Calls | {count} |
| Successful | {count} ({%}) |
| Abandoned | {count} ({%}) |
| Transferred | {count} ({%}) |

### Breakdown by Outcome

| Outcome | Count | % |
|---------|-------|---|
| {from reporting-service} |

### Breakdown by Abandonment Reason

| Reason | Count | % |
|--------|-------|---|
| {skip section if no abandonments} |

### Daily Trend

| Date | Calls | Booked | Abandoned | Transferred |
|------|-------|--------|-----------|-------------|
| {per-day rows} |

---

## Template 5: Integration Deep Dive

**Use when:** User asks about a specific integration (xTime, PBS, Motive, Authenticom, CDK).

**Sections (in order):**
1. Dealer Config Block
2. Integration Config — DMS/scheduler codes, polling status
3. Recent API Activity (last 24h)
4. Data Sync Health — vehicle services, appointment times, make/model
5. Errors (last 24h)
6. Polling Health

### Integration Config

| Setting | Value |
|---------|-------|
| DMS code | {from config.dms} |
| Scheduler code | {from config.scheduler} |
| Polling enabled | {yes/no} |
| Last config update | {updated_at} |

### Recent API Activity

| Time (ET) | Direction | Endpoint | Status | Latency |
|-----------|-----------|----------|--------|---------|
| {from integration-platform CloudWatch} |

### Data Sync Health

| Check | Status | Last Success |
|-------|--------|-------------|
| Vehicle services | {ok/stale/error} | {timestamp} |
| Appointment times | {ok/stale/error} | {timestamp} |
| Make/model data | {ok/stale/error} | {timestamp} |
| Transportation options | {configured/missing} | — |

### Errors (last 24h)

| Time | Message | Count |
|------|---------|-------|
| {grouped by message} |

### Polling Health

| Metric | Value |
|--------|-------|
| Last poll | {timestamp} |
| Poll interval | {expected vs actual} |
| Consecutive failures | {count} |


---

## Template 6: Dealership Trend Report

**Use when:** User asks for week-over-week trends or "is this dealer getting better/worse."

**Sections (in order):**
1. Dealer Config Block
2. Weekly Trend — calls, booked, booking %, abandoned, abandon %
3. Outcome Distribution (period total)
4. Top Abandonment Reasons with trend direction
5. Service Complexity Breakdown
6. Avg Time to First Available per week
7. Latency Trend per week
8. Integration Reliability per week

### Weekly Trend

| Week | Calls | Booked | Booking % | Abandoned | Abandon % | Transferred | Avg Duration |
|------|-------|--------|-----------|-----------|-----------|-------------|-------------|
| {per-week rows} |

### Outcome Distribution

| Outcome | Count | % |
|---------|-------|---|
| {period total} |

### Top Abandonment Reasons

| Reason | Count | % | Trend |
|--------|-------|---|-------|
| {with week-over-week direction: ↑ ↓ →} |

### Service Complexity Breakdown

| Complexity | Count | Booking Rate |
|------------|-------|-------------|
| Simple | {n} | {%} |
| Medium | {n} | {%} |
| Complex | {n} | {%} |

### Avg Time to First Available

| Week | Avg Days | Min | Max |
|------|----------|-----|-----|
| {per-week} |

### Latency Trend

| Week | Avg Turn (ms) | P95 Turn (ms) | Avg Pipeline (ms) |
|------|--------------|---------------|-------------------|
| {per-week} |

### Integration Reliability

| Week | API Calls | Errors | Error Rate |
|------|-----------|--------|-----------|
| {per-week} |
