---
name: performance-analytics
parent: cari-investigator
description: Aggregate performance queries — booking rates, call volumes, containment, daily trends, problem detection, system health.
---

# Performance Analytics Sub-Skill

> **Database:** `reporting-prod` on same RDS instance as config DB (use same credentials, override dbname)
> **Tables:** calls, scheduler_calls, receptionist_calls
> **Credentials:** Same `cari-readonly-rds-production` secret — see `references/aws-credentials.md`
> **Guardrails:** Follow `references/aws-query-guardrails.md` — read-only, 30s timeout, EXPLAIN before execute

## Purpose

This sub-skill runs analytics queries against the reporting-service database. It presents raw metrics — counts, percentages, timing — without qualitative interpretation. After presenting results, ask the user what they want to drill into.

## Before Running

1. Confirm which query the user needs (see Query Index below)
2. Confirm parameters: lskinid (optional), date range, agent type
3. For Problem Detection (Query 5): ask about threshold preferences or use defaults
4. Run query against reporting-<env> database
5. Present: raw table output + numerical summary (counts and percentages only)
6. Ask: "What stands out? Want to drill into anything?"

## Query Index

| # | Query | Parameters | Use When User Asks... |
|---|-------|------------|----------------------|
| 1 | Scheduler Call Detail | lskinid, date (optional) | "Show me scheduler calls for this dealer" |
| 2 | Receptionist Call Detail | lskinid, date (optional) | "Show me receptionist calls for this dealer" |
| 3 | Scheduler Daily Performance | lskinid (optional), date range | "How is this dealer's scheduler performing?" |
| 4 | Receptionist Daily Performance | lskinid (optional), date range | "How are transfers working for this dealer?" |
| 5 | Problem Detection | thresholds (configurable) | "Which dealers have issues this week?" |
| 6 | System Health Overview | date range | "How is the platform doing today?" |
| 7 | Hourly Volume Pattern | date range | "When do most calls come in?" |
| 8 | Transfer Reason Analysis | date range | "Why are calls being transferred?" → `references/performance-supplementary.md` |
| 9 | Extension Performance | date range | "Which extensions are timing out?" |

---

## Query 1: Scheduler Call Detail

```sql
SELECT
  c.call_id,
  c.lskinid,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  c.duration,
  sc.outcome AS outcomes,
  CASE
    WHEN sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[] THEN 'Booked'
    WHEN 'reschedule' = ANY(sc.outcome) THEN 'Reschedule'
    WHEN 'cancel' = ANY(sc.outcome) THEN 'Cancel'
    WHEN 'apptInquiry' = ANY(sc.outcome) THEN 'Appt Inquiry'
    WHEN sc.outcome @> ARRAY['transfer']::text[] THEN 'Transferred'
    WHEN sc.outcome IS NOT NULL AND array_length(sc.outcome, 1) > 0 THEN sc.outcome[1]
    WHEN c.call_classification = 'silent' THEN 'Silent'
    WHEN c.call_classification = 'spam' THEN 'Spam'
    WHEN c.call_classification = 'general_inquiry' THEN 'General Inquiry'
    WHEN c.call_classification = 'hangup' THEN 'Hangup (<30s)'
    WHEN c.call_classification = 'abandoned' THEN 'Abandoned (>30s)'
    ELSE 'Unknown'
  END AS call_status,
  sc.customer_type,
  sc.transfer_reason,
  sc.abandoned_reason,
  sc.service_complexity,
  sc.transportation_type,
  sc.time_until_first_available,
  sc.addon AS addons,
  c.message_status,
  c.cm_call_id,
  c.caller_phone_number,
  c.llm_reviewed,
  NULL AS transcript_preview  -- omit transcription preview (TOAST-heavy); use reporting-service drill-down for transcription
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.agent_type = 'scheduler'
  AND c.lskinid = :lskinid
  -- Optional date filter: AND DATE(c.start_time AT TIME ZONE 'America/New_York') = ':date'
ORDER BY c.start_time DESC
LIMIT 200;
```

## Query 2: Receptionist Call Detail

```sql
SELECT
  c.call_id,
  c.lskinid,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  c.duration,
  CASE
    WHEN rc.first_extension_response = 'blind_transfer' THEN 'Blind Transfer'
    WHEN rc.first_extension_response = 'dtmf' THEN 'DTMF Transfer'
    WHEN rc.first_extension_response = 'connected' THEN 'Connected'
    WHEN rc.first_extension_response = 'timeout' THEN 'Timeout'
    WHEN rc.first_extension_response = 'declined' THEN 'Declined'
    WHEN rc.first_extension_response = 'caller_hung_up' THEN 'Caller Hung Up'
    WHEN rc.transferred_to_scheduler = true THEN 'To Scheduler'
    WHEN c.call_classification = 'silent' THEN 'Silent'
    WHEN c.call_classification = 'spam' THEN 'Spam'
    WHEN c.call_classification = 'general_inquiry' THEN 'General Inquiry'
    WHEN c.call_classification = 'hangup' THEN 'Hangup (<30s)'
    WHEN c.call_classification = 'abandoned' THEN 'Abandoned (>30s)'
    ELSE 'Unknown'
  END AS call_status,
  rc.first_extension_name,
  rc.first_extension_response,
  rc.first_pickup_duration,
  rc.first_time_to_transfer,
  rc.second_extension_name,
  rc.second_extension_response,
  rc.second_pickup_duration,
  rc.second_time_to_transfer,
  rc.name_status,
  rc.transferred_to_scheduler,
  c.message_status,
  c.cm_call_id,
  c.caller_phone_number,
  c.llm_reviewed,
  NULL AS transcript_preview  -- omit transcription preview (TOAST-heavy); use reporting-service drill-down for transcription
FROM calls c
LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.agent_type = 'receptionist'
  AND c.lskinid = :lskinid
  -- Optional date filter: AND DATE(c.start_time AT TIME ZONE 'America/New_York') = ':date'
ORDER BY c.start_time DESC
LIMIT 200;
```

## Query 3: Scheduler Daily Performance

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  c.lskinid,
  COUNT(*) AS total_calls,
  COUNT(DISTINCT c.caller_phone_number) AS unique_callers,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]) AS booked,
  COUNT(*) FILTER (WHERE 'reschedule' = ANY(sc.outcome)) AS reschedule,
  COUNT(*) FILTER (WHERE 'cancel' = ANY(sc.outcome)) AS cancel,
  COUNT(*) FILTER (WHERE 'apptInquiry' = ANY(sc.outcome)) AS appt_inquiry,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['transfer']::text[]) AS transferred,
  COUNT(*) FILTER (WHERE c.call_classification = 'silent') AS silent,
  COUNT(*) FILTER (WHERE c.call_classification = 'spam') AS spam,
  COUNT(*) FILTER (WHERE c.call_classification = 'general_inquiry') AS general_inquiry,
  COUNT(*) FILTER (WHERE c.call_classification = 'hangup') AS hangup,
  COUNT(*) FILTER (WHERE c.call_classification = 'abandoned') AS abandoned,
  COUNT(*) FILTER (WHERE c.message_status = 'left_message') AS left_message,
  ROUND(100.0 * COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]) / NULLIF(COUNT(*), 0), 1) AS booking_rate_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE c.call_classification IN ('hangup', 'abandoned')) / NULLIF(COUNT(*), 0), 1) AS abandonment_rate_pct,
  ROUND(AVG(c.duration)::numeric, 0) AS avg_duration_sec,
  ROUND(AVG(sc.time_until_first_available)::numeric, 1) AS avg_days_to_appt
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.agent_type = 'scheduler'
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
  -- Optional: AND c.lskinid = :lskinid
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York'), c.lskinid
ORDER BY call_date DESC, total_calls DESC;
```

## Query 4: Receptionist Daily Performance

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  c.lskinid,
  COUNT(*) AS total_calls,
  COUNT(DISTINCT c.caller_phone_number) AS unique_callers,
  COUNT(*) FILTER (WHERE rc.first_extension_response IN ('blind_transfer', 'dtmf')) AS blind_transfers,
  COUNT(*) FILTER (WHERE rc.first_extension_response NOT IN ('blind_transfer', 'dtmf', 'not_attempted')
                   OR rc.first_extension_response IS NULL) AS warm_attempts,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected') AS warm_connected,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'timeout') AS warm_timeout,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'declined') AS warm_declined,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'caller_hung_up') AS caller_hung_up,
  COUNT(*) FILTER (WHERE rc.second_extension_response = 'connected') AS fallback_connected,
  COUNT(*) FILTER (WHERE rc.second_extension_response IN ('timeout', 'declined')) AS fallback_failed,
  COUNT(*) FILTER (WHERE rc.transferred_to_scheduler = true) AS to_scheduler,
  COUNT(*) FILTER (WHERE c.call_classification = 'silent') AS silent,
  COUNT(*) FILTER (WHERE c.call_classification = 'spam') AS spam,
  COUNT(*) FILTER (WHERE c.call_classification IN ('hangup', 'abandoned')) AS early_hangup,
  COUNT(*) FILTER (WHERE c.message_status = 'left_message') AS left_message,
  ROUND(100.0 * COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected')
        / NULLIF(COUNT(*) FILTER (WHERE rc.first_extension_response NOT IN ('blind_transfer', 'dtmf')), 0), 1) AS warm_success_rate_pct,
  ROUND(AVG(c.duration)::numeric, 0) AS avg_duration_sec,
  ROUND(AVG(rc.first_time_to_transfer)::numeric, 0) AS avg_time_to_transfer_sec,
  ROUND(AVG(rc.first_pickup_duration)::numeric, 0) AS avg_pickup_duration_sec
FROM calls c
LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.agent_type = 'receptionist'
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
  -- Optional: AND c.lskinid = :lskinid
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York'), c.lskinid
ORDER BY call_date DESC, total_calls DESC;
```

## Query 5: Problem Detection

**Before running:** Ask the user for threshold preferences. Defaults:
- Scheduler booking rate < 20%
- Scheduler abandonment > 30%
- Receptionist warm transfer success < 50%
- Junk rate (silent + spam) > 20%
- Minimum call volume: 10 calls in the period

```sql
WITH dealership_stats AS (
  SELECT
    c.lskinid,
    c.agent_type,
    COUNT(*) AS total_calls,
    COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]) AS booked,
    COUNT(*) FILTER (WHERE c.call_classification IN ('hangup', 'abandoned')) AS scheduler_abandoned,
    COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected') AS warm_connected,
    COUNT(*) FILTER (WHERE rc.first_extension_response IN ('timeout', 'declined')) AS warm_failed,
    COUNT(*) FILTER (WHERE c.call_classification = 'silent') AS silent,
    COUNT(*) FILTER (WHERE c.call_classification = 'spam') AS spam
  FROM calls c
  LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id AND c.agent_type = 'scheduler'
  LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id AND c.agent_type = 'receptionist'
  WHERE c.start_time >= NOW() - (:days * INTERVAL '1 day')
  GROUP BY c.lskinid, c.agent_type
  HAVING COUNT(*) >= :min_volume
)
SELECT
  lskinid, agent_type, total_calls,
  CASE WHEN agent_type = 'scheduler' THEN
    ROUND(100.0 * booked / NULLIF(total_calls, 0), 1) END AS booking_rate_pct,
  CASE WHEN agent_type = 'scheduler' THEN
    ROUND(100.0 * scheduler_abandoned / NULLIF(total_calls, 0), 1) END AS abandonment_rate_pct,
  CASE WHEN agent_type = 'receptionist' THEN
    ROUND(100.0 * warm_connected / NULLIF(warm_connected + warm_failed, 0), 1) END AS warm_success_rate_pct,
  ROUND(100.0 * (silent + spam) / NULLIF(total_calls, 0), 1) AS junk_rate_pct
FROM dealership_stats
WHERE
  (agent_type = 'scheduler' AND (
    (100.0 * booked / NULLIF(total_calls, 0)) < :booking_threshold
    OR (100.0 * scheduler_abandoned / NULLIF(total_calls, 0)) > :abandonment_threshold
  ))
  OR (agent_type = 'receptionist' AND (
    (100.0 * warm_connected / NULLIF(warm_connected + warm_failed, 0)) < :warm_threshold
  ))
  OR (100.0 * (silent + spam) / NULLIF(total_calls, 0)) > :junk_threshold
ORDER BY total_calls DESC;
```

## Query 6: System Health Overview

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  c.agent_type,
  COUNT(*) AS total_calls,
  COUNT(DISTINCT c.lskinid) AS active_dealerships,
  COUNT(DISTINCT c.caller_phone_number) AS unique_callers,
  COUNT(*) FILTER (WHERE
    (c.agent_type = 'scheduler' AND sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[])
    OR
    (c.agent_type = 'receptionist' AND rc.first_extension_response IN ('connected', 'blind_transfer', 'dtmf'))
  ) AS successful_calls,
  COUNT(*) FILTER (WHERE c.call_classification IN ('silent', 'spam')) AS junk_calls,
  COUNT(*) FILTER (WHERE c.call_classification IN ('hangup', 'abandoned')) AS abandoned_calls,
  COUNT(*) FILTER (WHERE c.llm_reviewed = true) AS llm_reviewed,
  COUNT(*) FILTER (WHERE c.message_status = 'left_message') AS messages_left,
  ROUND(AVG(c.duration)::numeric, 0) AS avg_duration_sec,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.duration) AS median_duration_sec,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY c.duration) AS p95_duration_sec
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id AND c.agent_type = 'scheduler'
LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id AND c.agent_type = 'receptionist'
WHERE c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York'), c.agent_type
ORDER BY call_date DESC, c.agent_type;
```


---

> **For Queries 7-9 (hourly volume, transfer reasons, extension performance) and schema reference → see `references/performance-supplementary.md`**

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present raw table output first
2. Follow with numerical summary: total counts and percentages only
3. Do NOT add qualitative labels (good, bad, struggling, healthy, needs attention)
4. Do NOT interpret what the numbers mean
5. After presenting, ask: "What stands out? Want to drill into anything specific?"
