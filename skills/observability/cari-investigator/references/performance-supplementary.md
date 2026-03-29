---
name: performance-supplementary
parent: performance-analytics
description: Supplementary performance queries 7-9 — hourly volume, transfer reasons, extension performance, and schema reference.
---

# Performance Analytics — Supplementary Queries (7-9)

> **Loaded from:** `performance-analytics.md` → this file for queries 7-9 and schema reference.
> **Queries 1-6 are in the main `performance-analytics.md` file.**

## Query 7: Hourly Volume Pattern

```sql
SELECT
  EXTRACT(HOUR FROM c.start_time AT TIME ZONE 'America/New_York') AS hour_et,
  c.agent_type,
  COUNT(*) AS total_calls,
  COUNT(*) FILTER (WHERE EXTRACT(DOW FROM c.start_time AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5) AS weekday_calls,
  COUNT(*) FILTER (WHERE EXTRACT(DOW FROM c.start_time AT TIME ZONE 'America/New_York') IN (0, 6)) AS weekend_calls,
  ROUND(COUNT(*)::numeric / COUNT(DISTINCT DATE(c.start_time AT TIME ZONE 'America/New_York')), 1) AS avg_calls_per_day
FROM calls c
WHERE c.start_time >= NOW() - (:days * INTERVAL '1 day')
  -- Optional: AND c.lskinid = :lskinid
GROUP BY EXTRACT(HOUR FROM c.start_time AT TIME ZONE 'America/New_York'), c.agent_type
ORDER BY hour_et, c.agent_type;
```

## Query 8: Transfer Reason Analysis

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  sc.transfer_reason,
  COUNT(*) AS transfer_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY DATE(c.start_time AT TIME ZONE 'America/New_York')), 1) AS pct_of_transfers
FROM calls c
JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.agent_type = 'scheduler'
  AND sc.outcome @> ARRAY['transfer']::text[]
  AND sc.transfer_reason IS NOT NULL
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
  -- Optional: AND c.lskinid = :lskinid
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York'), sc.transfer_reason
ORDER BY call_date DESC, transfer_count DESC;
```

## Query 9: Extension Performance

```sql
SELECT
  rc.first_extension_name AS extension_name,
  COUNT(*) AS total_attempts,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected') AS connected,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'timeout') AS timeout,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'declined') AS declined,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'caller_hung_up') AS caller_hung_up,
  ROUND(100.0 * COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected')
        / NULLIF(COUNT(*), 0), 1) AS success_rate_pct,
  ROUND(AVG(rc.first_pickup_duration)::numeric, 0) AS avg_pickup_sec,
  ROUND(AVG(rc.first_time_to_transfer)::numeric, 0) AS avg_time_to_transfer_sec
FROM calls c
JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.agent_type = 'receptionist'
  AND rc.first_extension_name IS NOT NULL
  AND rc.first_extension_response NOT IN ('blind_transfer', 'dtmf', 'not_attempted')
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
  -- Optional: AND c.lskinid = :lskinid
GROUP BY rc.first_extension_name
HAVING COUNT(*) >= 5
ORDER BY total_attempts DESC;
```

## Schema Reference (reporting-service columns used)

### calls table
call_id (PK, VARCHAR), cm_call_id (BIGINT), lskinid (INT), agent_type (scheduler/receptionist), start_time (TIMESTAMPTZ), end_time, duration (INT, seconds), transcription (TEXT), call_classification (silent/spam/general_inquiry/hangup/abandoned), message_status (left_message/etc), caller_phone_number, llm_reviewed (BOOLEAN), language

### scheduler_calls table (FK: call_id -> calls.call_id)
outcome (TEXT[]), customer_type, transfer_reason, abandoned_reason, service_complexity, transportation_type, time_until_first_available (NUMERIC, days), addon (TEXT[]), call_context (JSONB)

### receptionist_calls table (FK: call_id -> calls.call_id)
first_extension_name, first_extension_response (connected/timeout/declined/caller_hung_up/blind_transfer/dtmf/not_attempted), first_pickup_duration (NUMERIC, seconds), first_time_to_transfer (NUMERIC, seconds), second_extension_name, second_extension_response, second_pickup_duration, second_time_to_transfer, name_status, transferred_to_scheduler (BOOLEAN), [[warm-transfer]]_log (JSONB), call_context (JSONB)

## Presentation Rules

1. Present raw table output first
2. Follow with numerical summary: total counts and percentages only
3. Do NOT add qualitative labels (good, bad, struggling, healthy, needs attention)
4. Do NOT interpret what the numbers mean
5. After presenting, ask: "What stands out? Want to drill into anything specific?"
