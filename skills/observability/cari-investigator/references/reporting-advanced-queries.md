---
name: reporting-advanced-queries
parent: reporting-service
description: Advanced reporting queries 5-12 — [[warm-transfer]]s, repeat callers, language, acquisition, containment, phone lookup, and schema reference.
---

# Reporting Service — Advanced Queries (5-12)

> **Loaded from:** `reporting-service.md` → this file for queries 5-12 and schema reference.
> **Queries 1-4 are in the main `reporting-service.md` file.**

## Query 5: [[warm-transfer]] Interaction Log

Parses the [[warm-transfer]]_log JSONB to show the full interaction sequence for a single call.

```sql
SELECT
  c.call_id,
  rc.first_extension_name,
  rc.first_extension_response,
  rc.[[warm-transfer]]_log->'stats'->>'totalDurationMs' AS warm_duration_ms,
  rc.[[warm-transfer]]_log->'stats'->>'ttsPlayCount' AS tts_plays,
  rc.[[warm-transfer]]_log->'stats'->>'repeatCount' AS repeats,
  rc.[[warm-transfer]]_log->'stats'->>'machineDetectionCount' AS machine_detections,
  rc.[[warm-transfer]]_log->'stats'->>'transcriptCount' AS transcript_count,
  rc.[[warm-transfer]]_log->'interactions' AS interactions
FROM calls c
JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.call_id = :call_id
  AND rc.[[warm-transfer]]_log IS NOT NULL;
```

**Interpreting the interactions array:** Each element has:
- \`type\`: tts_start, tts_complete, tts_interrupted, transcript_interim, transcript_final, detection, machine_reset, repeat_request, auto_repeat, decline_confirmation_requested, decline_confirmed, decline_overridden
- \`timestamp\`: Unix milliseconds
- \`text\`: TTS text or transcript text (when applicable)
- \`detection\`: (when type=detection) outcome (MACHINE/WAIT/ACCEPT/DECLINE/REPEAT), classification, confidence, method (keyword/timing/llm/hybrid), reasoning

Present the interactions as a timeline, ordered by timestamp.

## Query 6: [[warm-transfer]] Stats by Dealer

```sql
SELECT
  c.lskinid,
  rc.first_extension_name,
  COUNT(*) AS warm_attempts,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected') AS connected,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'timeout') AS timeout,
  COUNT(*) FILTER (WHERE rc.first_extension_response = 'declined') AS declined,
  ROUND(100.0 * COUNT(*) FILTER (WHERE rc.first_extension_response = 'connected')
        / NULLIF(COUNT(*), 0), 1) AS success_rate_pct,
  ROUND(AVG((rc.[[warm-transfer]]_log->'stats'->>'totalDurationMs')::numeric / 1000)::numeric, 1) AS avg_warm_duration_sec,
  ROUND(AVG((rc.[[warm-transfer]]_log->'stats'->>'ttsPlayCount')::numeric)::numeric, 1) AS avg_tts_plays,
  ROUND(AVG((rc.[[warm-transfer]]_log->'stats'->>'machineDetectionCount')::numeric)::numeric, 1) AS avg_machine_detections,
  ROUND(AVG(rc.first_pickup_duration)::numeric, 0) AS avg_pickup_sec,
  ROUND(AVG(rc.first_time_to_transfer)::numeric, 0) AS avg_time_to_transfer_sec
FROM calls c
JOIN receptionist_calls rc ON rc.call_id = c.call_id
WHERE c.agent_type = 'receptionist'
  AND c.lskinid = :lskinid
  AND rc.first_extension_response NOT IN ('blind_transfer', 'dtmf', 'not_attempted')
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY c.lskinid, rc.first_extension_name
ORDER BY warm_attempts DESC;
```

## Query 7: Transfer History Chain

Shows every transfer attempt for a single receptionist call, parsed from the transfer_history JSONB array.

```sql
SELECT
  c.call_id,
  elem->>'attempt' AS attempt,
  elem->>'timestamp' AS event_timestamp,
  elem->>'extensionName' AS extension_name,
  elem->>'extensionPhoneNumber' AS extension_phone,
  elem->>'response' AS response,
  (elem->>'pickupDuration')::numeric AS pickup_duration_sec,
  (elem->>'timeToTransfer')::numeric AS time_to_transfer_sec
FROM calls c
JOIN receptionist_calls rc ON rc.call_id = c.call_id,
LATERAL jsonb_array_elements(rc.transfer_history) AS elem
WHERE c.call_id = :call_id
ORDER BY (elem->>'timestamp')::timestamp;
```

For aggregate transfer history analysis across a dealer:

```sql
SELECT
  c.lskinid,
  elem->>'extensionName' AS extension_name,
  elem->>'response' AS response,
  COUNT(*) AS occurrences,
  ROUND(AVG((elem->>'pickupDuration')::numeric)::numeric, 0) AS avg_pickup_sec,
  ROUND(AVG((elem->>'timeToTransfer')::numeric)::numeric, 0) AS avg_transfer_sec
FROM calls c
JOIN receptionist_calls rc ON rc.call_id = c.call_id,
LATERAL jsonb_array_elements(rc.transfer_history) AS elem
WHERE c.lskinid = :lskinid
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
  AND jsonb_array_length(rc.transfer_history) > 0
GROUP BY c.lskinid, elem->>'extensionName', elem->>'response'
ORDER BY occurrences DESC;
```

## Query 8: Repeat Callers

```sql
SELECT
  c.caller_phone_number,
  COUNT(*) AS total_calls,
  COUNT(DISTINCT DATE(c.start_time AT TIME ZONE 'America/New_York')) AS days_called,
  MIN(c.start_time AT TIME ZONE 'America/New_York')::date AS first_call,
  MAX(c.start_time AT TIME ZONE 'America/New_York')::date AS last_call,
  COUNT(*) FILTER (WHERE c.agent_type = 'scheduler') AS scheduler_calls,
  COUNT(*) FILTER (WHERE c.agent_type = 'receptionist') AS receptionist_calls,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]) AS times_booked,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['transfer']::text[]) AS times_transferred
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.lskinid = :lskinid
  AND c.caller_phone_number IS NOT NULL
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY c.caller_phone_number
HAVING COUNT(*) >= 2
ORDER BY total_calls DESC
LIMIT 50;
```

## Query 9: Language Distribution

```sql
SELECT
  c.language,
  c.agent_type,
  COUNT(*) AS total_calls,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY c.agent_type), 1) AS pct_of_agent_type,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]) AS booked,
  COUNT(*) FILTER (WHERE c.call_classification IN ('hangup', 'abandoned')) AS abandoned
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id
WHERE c.start_time >= NOW() - (:days * INTERVAL '1 day')
  AND c.language IS NOT NULL
  -- Optional: AND c.lskinid = :lskinid
GROUP BY c.language, c.agent_type
ORDER BY c.agent_type, total_calls DESC;
```

## Query 10: Acquisition Session Lookup

```sql
SELECT
  c.call_id, c.lskinid,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  c.duration, c.caller_phone_number,
  aq.smr_lead_id, aq.channel, aq.direction, aq.outcome,
  aq.decline_reason, aq.transfer_reason,
  aq.is_reschedule,
  aq.appointment_datetime,
  aq.vehicle_info->>'year' AS vehicle_year,
  aq.vehicle_info->>'make' AS vehicle_make,
  aq.vehicle_info->>'model' AS vehicle_model,
  aq.vehicle_info->>'vin' AS vehicle_vin,
  aq.offer_range->>'min' AS offer_min,
  aq.offer_range->>'max' AS offer_max,
  c.transcription
FROM calls c
JOIN acquisition_sessions aq ON aq.session_id = c.call_id
WHERE c.agent_type = 'acquisition'
  AND c.lskinid = :lskinid
  -- Optional: AND aq.smr_lead_id = :smr_lead_id
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
ORDER BY c.start_time DESC
LIMIT 100;
```

**Acquisition summary by dealer:**

```sql
SELECT
  c.lskinid,
  aq.channel, aq.direction, aq.outcome,
  COUNT(*) AS session_count,
  COUNT(*) FILTER (WHERE aq.outcome = 'appointment_booked') AS booked,
  COUNT(*) FILTER (WHERE aq.outcome = 'transferred') AS transferred,
  COUNT(*) FILTER (WHERE aq.outcome = 'declined') AS declined,
  COUNT(*) FILTER (WHERE aq.outcome = 'dnc') AS dnc,
  COUNT(*) FILTER (WHERE aq.is_reschedule = true) AS reschedules
FROM calls c
JOIN acquisition_sessions aq ON aq.session_id = c.call_id
WHERE c.lskinid = :lskinid
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY c.lskinid, aq.channel, aq.direction, aq.outcome
ORDER BY session_count DESC;
```

## Query 11: Containment Rate

Containment = calls NOT transferred to a human agent, as a percentage of all handled calls.

```sql
SELECT
  DATE(c.start_time AT TIME ZONE 'America/New_York') AS call_date,
  c.lskinid,
  COUNT(*) AS total_handled,
  COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['transfer']::text[]) AS transferred,
  COUNT(*) - COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['transfer']::text[]) AS contained,
  ROUND(100.0 * (COUNT(*) - COUNT(*) FILTER (WHERE sc.outcome @> ARRAY['transfer']::text[]))
        / NULLIF(COUNT(*), 0), 1) AS containment_rate_pct,
  ROUND(SUM(co_agg.ro_value)::numeric, 2) AS daily_ro_value
FROM calls c
JOIN scheduler_calls sc ON sc.call_id = c.call_id
LEFT JOIN (
  SELECT call_id, SUM(price) AS ro_value
  FROM call_opcodes
  GROUP BY call_id
) co_agg ON co_agg.call_id = c.call_id AND sc.outcome @> ARRAY['serviceAppointmentScheduled']::text[]
WHERE c.agent_type = 'scheduler'
  AND c.lskinid = :lskinid
  AND c.call_classification IS NULL  -- exclude silent/spam/hangup
  AND c.start_time >= NOW() - (:days * INTERVAL '1 day')
GROUP BY DATE(c.start_time AT TIME ZONE 'America/New_York'), c.lskinid
ORDER BY call_date DESC;
```

## Query 12: Call Lookup by Phone Number

```sql
SELECT
  c.call_id, c.cm_call_id, c.lskinid, c.agent_type,
  TO_CHAR(c.start_time AT TIME ZONE 'America/New_York', 'YYYY-MM-DD HH12:MI:SS AM') AS start_time_et,
  c.duration, c.call_classification, c.message_status,
  CASE
    WHEN c.agent_type = 'scheduler' THEN array_to_string(sc.outcome, ', ')
    WHEN c.agent_type = 'receptionist' THEN rc.first_extension_response
    ELSE 'N/A'
  END AS call_result,
  sc.transfer_reason,
  rc.first_extension_name,
  NULL AS transcript_preview  -- omit transcription preview (TOAST-heavy); use Query 1/2 for transcription
FROM calls c
LEFT JOIN scheduler_calls sc ON sc.call_id = c.call_id AND c.agent_type = 'scheduler'
LEFT JOIN receptionist_calls rc ON rc.call_id = c.call_id AND c.agent_type = 'receptionist'
WHERE c.caller_phone_number = :phone_number
  -- Optional: AND c.lskinid = :lskinid
ORDER BY c.start_time DESC
LIMIT 50;
```

---

## Schema Reference

### call_opcodes table
call_id (FK -> calls.call_id), code (VARCHAR 255), description (VARCHAR 255), price (DECIMAL 10,2), duration (INTEGER, minutes). Composite PK: (call_id, code).

### acquisition_sessions table
session_id (FK -> calls.call_id, PK), smr_lead_id (VARCHAR 128), channel (voice/text), direction (inbound/outbound), outcome (appointment_booked/transferred/declined/dnc/abandoned/hangup), decline_reason (not_selling/better_offer/too_far/price_too_low/wrong_timing/other), transfer_reason (complex_inquiry/hot_lead/cancellation_request/escalation/customer_request), is_reschedule (BOOLEAN), appointment_datetime (TIMESTAMPTZ), vehicle_info (JSONB: year, make, model, vin), offer_range (JSONB: min, max), call_context (JSONB)

### [[warm-transfer]]_log JSONB structure (receptionist_calls)
- interactions[]: array of {timestamp (unix ms), type (tts_start/tts_complete/tts_interrupted/transcript_interim/transcript_final/detection/machine_reset/repeat_request/auto_repeat/decline_confirmation_requested/decline_confirmed/decline_overridden), text?, detection?: {outcome (MACHINE/WAIT/ACCEPT/DECLINE/REPEAT), classification, confidence, method (keyword/timing/llm/hybrid), reasoning?}}
- stats: {totalDurationMs, ttsPlayCount, repeatCount, machineDetectionCount, transcriptCount}

### transfer_history JSONB structure (receptionist_calls)
Array of: {attempt (first/second), timestamp (ISO), extensionName, extensionPhoneNumber, response (connected/declined/timeout/caller_hung_up/blind_transfer/dtmf), pickupDuration (seconds), timeToTransfer (seconds)}

### Key Computed Metrics
- **RO Value:** Sum of call_opcodes.price for calls with outcome 'serviceAppointmentScheduled'
- **Containment Rate:** (handled_calls - transferred_calls) / handled_calls * 100. Excludes silent/spam/hangup calls.

## Presentation Rules

1. Present raw table output first
2. Follow with numerical summary: total counts and percentages only
3. For JSONB data ([[warm-transfer]]_log, transfer_history): format as readable timeline
4. Do NOT add qualitative labels (good, bad, struggling, healthy, needs attention)
5. Do NOT interpret what the numbers mean
6. After presenting, ask: "What stands out? Want to drill into anything specific?"
