---
name: appointment-details
parent: cari-investigator
description: Cross-system correlation to find what time/lane an appointment was booked for. Joins MSSQL call data with CloudWatch agent traces via ANI.
---

# Appointment Details Investigation

> **Purpose:** Answer "What time was this appointment booked for?" and "Which service lane?"
> **Systems:** callmeasurement-prod (MSSQL) + CloudWatch (`cari-agent-lambda-production`)

## When to Use

- User asks what time a specific call's appointment was booked for
- User asks which service lane an appointment was booked into
- Investigating off-limits time violations (appointments booked for blocked slots)
- Need to know the actual appointment time, not just the call time

## Why This Exists

The `tz_datetime` column in MSSQL is when the **call happened**, not when the **appointment was booked for**. The booked appointment time lives only in the Cari agent's tool call traces in CloudWatch.

## Procedure

### Step 1: Get call data from MSSQL

Start with the calls you're investigating (from `call-outcome-search` or `call-lookup`):

```sql
-- callmeasurement-prod (use xcall_short if xcall_long is stale)
SELECT x.callid, x.ani, x.tz_datetime, x.leminutes, d.lednis
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN calltag ct ON ct.frn_callid = x.callid
WHERE d.add_lskinid = {lskinid}
AND ct.frn_calltagdatumid = 2390  -- Scheduled Appt
AND x.tz_datetime >= '{start}' AND x.tz_datetime < '{end}'
ORDER BY x.tz_datetime
```

Record the **ANI** (caller phone number) for each call. This is the join key to CloudWatch.

### Step 2: Search CloudWatch agent traces by ANI

For each ANI from Step 1, search the agent Lambda logs:

```bash
START_TIME=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "{start_utc}" "+%s")
END_TIME=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "{end_utc}" "+%s")

aws logs start-query \
  --log-group-name "/aws/lambda/cari-agent-lambda-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /schedule_appointment/ and @message like /{ani}/
    | sort @timestamp asc
    | limit 50" \
  --profile cari-prod
```

### Step 3: Extract the booked appointment time

From the results, look for `dateTime` in the tool call arguments:

```bash
aws logs start-query \
  --log-group-name "/aws/lambda/cari-agent-lambda-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /Agent API: Result/ and @message like /{ani}/
    | parse @message '\"dateTime\":\"*\"' as booked_time
    | parse @message '\"laneId\":*,' as lane_id
    | parse @message '\"laneName\":\"*\"' as lane_name
    | sort @timestamp asc
    | limit 20" \
  --profile cari-prod
```

Key fields to extract:
- `dateTime` — the appointment date/time booked
- `laneId` — numeric lane identifier
- `laneName` — human-readable lane name (e.g., "Express Lane", "Main Shop")
- `selectedTime` — the time slot the caller selected

### Step 4: Correlate and present

Match each MSSQL call record (by ANI + approximate timestamp) to the CloudWatch appointment details:

```
Appointment Details for South Tacoma Honda (lskinid 72965) — March 23, 2026

| Call ID | Call Time | ANI | Booked For | Lane | Duration |
|---------|-----------|-----|------------|------|----------|
| 6001543815826 | 09:52 PDT | (253) 555-1234 | 12:00 PM PDT | Express | 3.2 min |
| 6001543815912 | 09:55 PDT | (253) 555-5678 | 12:15 PM PDT | Express | 2.8 min |
| 6001543816001 | 10:03 PDT | (206) 555-9012 | 14:30 PM PDT | Main Shop | 4.1 min |

⚠️ Calls 1-2 booked for noon/12:15 — these are off-limits Express times.
   Config change to block these times landed at 10:02 PDT (17:02 UTC).
   Both calls were placed BEFORE the config fix.
```

### Step 5: If CloudWatch returns no results

Possible reasons:
1. **Wrong time window** — widen by ±1 hour
2. **ANI mismatch** — the agent may log a formatted ANI (with dashes) vs MSSQL's raw 10-digit format
3. **Call didn't reach the agent** — it may have been transferred before reaching Cari
4. **Log retention** — CloudWatch logs may have expired (check retention policy)

Try searching by lskinid instead of ANI:
```bash
aws logs start-query \
  --log-group-name "/aws/lambda/cari-agent-lambda-production" \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --query-string "fields @timestamp, @message
    | filter @message like /scheduledAppt/ and @message like /{lskinid}/
    | sort @timestamp asc
    | limit 50" \
  --profile cari-prod
```

## References

- Schema details: `references/mssql-schema-map.md`
- CloudWatch log groups: `references/cloudwatch-map.md`
- AWS credentials: `references/aws-credentials.md`

