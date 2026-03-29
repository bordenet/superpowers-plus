---
name: reporting-service
parent: cari-investigator
description: Reporting DB queries for call/session data — single call drill-down, opcodes, RO value, warm transfers, repeat callers, acquisition sessions.
---

# Reporting Service Sub-Skill

> **Database:** `reporting-prod` on same RDS instance as config DB (use same credentials, override dbname)
> **Tables:** calls, scheduler_calls, receptionist_calls, call_opcodes, acquisition_sessions
> **Credentials:** Same `cari-readonly-rds-production` secret — see `references/aws-credentials.md`
> **Guardrails:** Follow `references/aws-query-guardrails.md` — read-only, 30s timeout, EXPLAIN before execute

## Purpose

This sub-skill handles individual call investigation, JSONB deep dives, and data that performance-analytics.md does NOT cover: single call drill-down, opcode/RO value analysis, warm transfer interaction logs, transfer history chains, repeat caller detection, language distribution, and acquisition session lookups.

## Before Running

1. Confirm what the user wants to investigate (see Query Index below)
2. Confirm parameters: call_id, cm_call_id, lskinid, date range as needed
3. Run query against reporting-<env> database
4. Present: raw table output + numerical summary (counts and percentages only)
5. For JSONB queries: format the JSON readably, highlight key fields
6. Ask: "What stands out? Want to drill into anything?"

## Query Index

| # | Query | Parameters | Use When User Asks... |
|---|-------|------------|----------------------|
| 1 | Single Call Drill-Down (Scheduler) | call_id or cm_call_id | "Show me everything about this call" |
| 2 | Single Call Drill-Down (Receptionist) | call_id or cm_call_id | "What happened on this receptionist call?" |
| 3 | OpCode / RO Value by Dealer | lskinid, date range | "What services are being booked? What's the RO value?" |
| 4 | Top OpCodes Platform-Wide | date range | "What are the most common services across all dealers?" |
| 5 | Warm Transfer Interaction Log | call_id | "Show me the warm transfer sequence for this call" |
| 6 | Warm Transfer Stats by Dealer | lskinid, date range | "How are warm transfers performing for this dealer?" |
| 7 | Transfer History Chain | call_id | "Show me every transfer attempt for this call" |
| 8 | Repeat Callers | lskinid, date range | "Which callers called multiple times?" |
| 9 | Language Distribution | lskinid (optional), date range | "What languages are callers using?" |
| 10 | Acquisition Session Lookup | lskinid or smr_lead_id | "Show me SellMyRide sessions for this dealer" |
| 11 | Containment Rate | lskinid, date range | "What's the containment rate for this dealer?" |
| 12 | Call Lookup by Phone Number | caller_phone_number | "Find all calls from this phone number" |

---

## Query 1: Single Call Drill-Down (Scheduler)

Pulls everything for one call: call record, scheduler details, opcodes, and full context.

```sql
SELECT
  c.call_id, c.cm_call_id, c.lskinid, c.agent_type,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  TO_CHAR(c.end_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS end_time_et,
  c.duration, c.language, c.caller_phone_number,
  c.call_classification, c.message_status,
  c.llm_reviewed, c.llm_review_timestamp,
  c.transcription,
  sc.outcome, sc.addon, sc.customer_type,
  sc.transfer_reason, sc.abandoned_reason,
  sc.service_complexity, sc.transportation_type,
  sc.time_until_first_available,
  sc.call_context
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.call_id = :call_id   -- OR: c.cm_call_id = :cm_call_id
  AND c.agent_type = 'scheduler';
```

Then fetch opcodes separately:

```sql
SELECT code, description, price, duration
FROM call_opcodes
WHERE call_id = :call_id
ORDER BY price DESC;
```

## Query 2: Single Call Drill-Down (Receptionist)

```sql
SELECT
  c.call_id, c.cm_call_id, c.lskinid, c.agent_type,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  TO_CHAR(c.end_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS end_time_et,
  c.duration, c.language, c.caller_phone_number,
  c.call_classification, c.message_status,
  c.llm_reviewed, c.llm_review_timestamp,
  c.transcription,
  rc.first_extension_name, rc.first_extension_response,
  rc.first_pickup_duration, rc.first_time_to_transfer,
  rc.second_extension_name, rc.second_extension_response,
  rc.second_pickup_duration, rc.second_time_to_transfer,
  rc.name_status, rc.transferred_to_scheduler,
  rc.start_time AS receptionist_start,
  rc.end_time AS receptionist_end,
  rc.duration AS receptionist_duration,
  rc.transcript AS receptionist_transcript,
  rc.warm_transfer_log,
  rc.transfer_history,
  rc.call_context
FROM calls c
LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.call_id = :call_id   -- OR: c.cm_call_id = :cm_call_id
  AND c.agent_type = 'receptionist';
```

## Query 3: OpCode / RO Value by Dealer

```sql
SELECT
  co.code, co.description,
  COUNT(*) AS times_booked,
  ROUND(AVG(co.price)::numeric, 2) AS avg_price,
  SUM(co.price) AS total_revenue,
  ROUND(AVG(co.duration)::numeric, 0) AS avg_duration_min
FROM call_opcodes co
JOIN calls c ON c.call_id = co.call_id
JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.lskinid = :lskinid
  AND sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY co.code, co.description
ORDER BY times_booked DESC;
```

**RO Value summary** (add to the same query session):

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  COUNT(DISTINCT c.call_id) AS scheduled_calls,
  ROUND(SUM(co.price)::numeric, 2) AS daily_ro_value,
  ROUND(AVG(co.price)::numeric, 2) AS avg_opcode_price,
  COUNT(co.code) AS total_opcodes
FROM calls c
JOIN scheduler_calls sc ON sc.call_id = c.call_id
JOIN call_opcodes co ON co.call_id = c.call_id
WHERE c.lskinid = :lskinid
  AND sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York')
ORDER BY call_date DESC;
```

## Query 4: Top OpCodes Platform-Wide

```sql
SELECT
  co.code, co.description,
  COUNT(*) AS times_booked,
  COUNT(DISTINCT c.lskinid) AS dealers_using,
  ROUND(AVG(co.price)::numeric, 2) AS avg_price,
  SUM(co.price) AS total_revenue
FROM call_opcodes co
JOIN calls c ON c.call_id = co.call_id
JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY co.code, co.description
ORDER BY times_booked DESC
LIMIT 25;
```

---

> **For Queries 5-12 (warm transfers, repeat callers, language, acquisition, containment, phone lookup) and schema reference → see `references/reporting-advanced-queries.md`**


## Transcript Analysis Patterns

When reviewing `transcription` JSONB for CX issues, look for these structural patterns:

| Pattern | How to Detect | What It Indicates |
|---------|--------------|-------------------|
| Comprehension loop | Same assistant question appears 2+ times with different wording | Cari misunderstood the caller; caller is repeating themselves |
| `[INTERRUPTED]` tag | Text contains `[INTERRUPTED]` in assistant content | Barge-in collision — Cari and caller spoke simultaneously (latency or sensitivity issue) |
| `[Internal Error]` | Assistant content starts with `[Internal Error]` | Tool call or transfer failed; Cari is recovering |
| Explicit human request | Caller says "representative", "somebody", "person", "talk to someone", "adviser" | Caller gave up on AI and wants a human |
| Empty assistant content | `{"role":"assistant","content":null}` followed by tool call | Normal — Cari is calling a tool before speaking |
| Repeat caller | Same `caller_phone_number` appears 2+ times in a time window | Failed first-contact resolution — customer had to call back |
| Ambiguous "yes" | Customer says "yes" to an either/or question | Cari may misinterpret which option was selected |

**Repeat caller detection query:**

```sql
SELECT caller_phone_number, COUNT(*) AS call_count,
       MIN(start_time) AS first_call, MAX(start_time) AS last_call
FROM calls
WHERE lskinid = :lskinid
  AND start_time >= :start AND start_time < :end
GROUP BY caller_phone_number
HAVING COUNT(*) >= 2
ORDER BY call_count DESC;
```

## Scheduler Transfer Reason Reference

Values found in `scheduler_calls.transfer_reason`:

| Value | Meaning | Cari Issue? |
|-------|---------|-------------|
| `NULL` | Successful booking (no transfer needed) | No |
| `requested_transfer` | Caller explicitly asked for a human | Maybe — could be preference or Cari failure |
| `declined_times` | Caller rejected all offered appointment times | No — availability issue |
| `agent_error` | Tool call or internal error forced transfer | **Yes** — always a bug |
| `pricing_question` | Caller asked about cost; Cari can't answer | **Yes** — feature gap |
| `recall` | Caller asking about a recall | No — expected routing to service |
| `warranty` | Warranty-related question | No — expected routing |
| `loaner_request` | Caller needs a loaner vehicle | No — expected routing |
| `parts_department` | Caller needs parts, not service scheduling | No — expected routing |
| `other` | Uncategorized transfer reason | Unknown — investigate individually |

**Baseline query (7-day breakdown for a dealer):**

```sql
SELECT COALESCE(sc.transfer_reason, '(scheduled)') AS reason,
       COUNT(*) AS count,
       ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER() * 100, 1) AS pct
FROM calls c
JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.lskinid = :lskinid AND c.agent_type = 'scheduler'
  AND c.start_time >= NOW() - INTERVAL '7 days'
GROUP BY sc.transfer_reason
ORDER BY count DESC;
```

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present raw table output first
2. Follow with numerical summary: total counts and percentages only
3. For JSONB data (warm_transfer_log, transfer_history): format as readable timeline
4. Do NOT add qualitative labels (good, bad, struggling, healthy, needs attention)
5. Do NOT interpret what the numbers mean
6. After presenting, ask: "What stands out? Want to drill into anything specific?"
