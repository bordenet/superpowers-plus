---
name: test-call-transcript
source: superpowers-cari
triggers: ["test call transcript", "pull test calls", "test call IDs", "find my test calls", "what calls did I make", "warm transfer test calls", "dev test calls", "testing transcripts", "call records from testing"]
anti_triggers: ["look up call", "callid lookup", "call volume", "booking calls", "investigate cari"]
description: Pull call records from Dev/QA test sessions by caller ANI and time window. Returns callid, uniqueCallId (for CloudWatch correlation), duration, and transfer status. Designed for warm-transfer and other CARI testing workflows where you need to quickly identify which calls were made during a test session.
summary: "Use when: pulling call IDs and metadata from a test session to correlate with logs. Skip when: investigating production calls (use call-lookup), searching by account (use call-search)."
coordination:
  group: cari
  order: 1
  requires: []
  enables: []
  escalates_to: ['cari-investigator']
  internal: false
---

# Test Call Transcript Lookup

> **Source:** `superpowers-cari`
> **Domain:** Dev/QA Testing
> **Created:** 2026-03-26

Pull call records from test sessions. Returns call IDs, GUIDs (for CloudWatch log correlation), timestamps, duration, and transfer status. Use during or after manual testing to identify calls for debugging.

## When to Use

- After a warm transfer test session: "pull up the calls I just made"
- During testing: "what's the callid for the call I just made?"
- Correlating logs: "I need the uniqueCallId for my test calls"
- Any manual test session where the tester's phone number is known

## How to Execute

### Step 1: Gather Parameters

| Parameter | Source | Default |
|-----------|--------|---------|
| ANI (caller number) | `$WARM_TRANSFER_TEST_PHONE` from `~/.codex/.env`, or ask user | None — required |
| Time window | Ask user or infer from context ("today", "last hour", "last night") | Today |

**Check env first:**
```bash
source ~/.codex/.env 2>/dev/null
echo "${WARM_TRANSFER_TEST_PHONE:-not set}"
```

If set, use it without asking. If not, ask: *"What phone number did you call from?"*

If the user says multiple people were testing, or if the ANI search returns 0 results, fall back to searching by Cari test account name (see Step 3 alternative query).

Normalize: strip non-digits, drop leading `1` if 11 digits. Must be exactly 10.

### Step 2: Check Data Freshness

Use `query_mssql` with connection `callmeasurement-prod`.

```sql
SELECT TOP 1 tz_datetime FROM xcall_long ORDER BY callid DESC
```

If most recent row is older than yesterday, use `xcall_short` instead. Warn the user: *"xcall_long is stale — using xcall_short (data may differ slightly)."*

### Step 3: Pull Test Calls

```sql
SELECT x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.transferInitiated, d.lednis, l.refname AS account_name
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE x.ani = '{ani}'
  AND x.tz_datetime >= '{start_datetime}'
  AND x.tz_datetime < '{end_datetime}'
ORDER BY x.tz_datetime DESC
```

**Alternative: Search by Cari test account (when multiple testers use different phones):**

```sql
SELECT x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.transferInitiated, d.lednis, l.refname AS account_name
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE l.refname LIKE '%Cari Phone Assist Test%'
  AND x.tz_datetime >= '{start_datetime}'
  AND x.tz_datetime < '{end_datetime}'
ORDER BY x.tz_datetime DESC
```

Use this when: multiple team members made test calls from different phones, or the ANI-based search returns 0 rows but you know testing happened.

### Step 4: Format Output

**Present as a numbered table:**
```
Test calls from (425) 246-1703 on 2026-03-25:

| # | Call ID         | Time (CT)  | Duration | Transfer? | Account              | Unique Call ID                       |
|---|-----------------|------------|----------|-----------|----------------------|--------------------------------------|
| 1 | 6001547195904   | 22:00:30   | 0.87 min | ✅        | XTime - Test Account | aa28c4d2-1ff4-424c-9c48-b0a73fcb10ec |
| 2 | 6001547186208   | 21:43:39   | 1.25 min | ✅        | XTime - Test Account | e6b4ea3e-1efd-4d9e-be18-7f1e5da8e9e4 |

2 calls found. Use uniqueCallId to search CloudWatch logs.
```

**Always include:**
- Total call count
- Reminder that `uniqueCallId` is the CloudWatch correlation key
- Note if any calls have `transferInitiated = 0` (transfer NOT initiated — may indicate early hangup or detection failure)

### Step 5: Offer Next Steps

After displaying results, offer:
- *"Want me to look up HCAT tags for any of these calls?"* (→ use `hcat-lookup`)
- *"Need CloudWatch logs for a specific call?"* (search by `uniqueCallId`)

## Common Time Filters

| User says | start_datetime | end_datetime |
|-----------|---------------|-------------|
| "just now" / "the call I just made" | `DATEADD(minute, -15, GETDATE())` | `GETDATE()` |
| "today" | `CAST(GETDATE() AS DATE)` | `GETDATE()` |
| "last hour" | `DATEADD(hour, -1, GETDATE())` | `GETDATE()` |
| "last night" / "yesterday evening" | Previous day 17:00 | Previous day 23:59 |
| "yesterday" | `DATEADD(day, -1, CAST(GETDATE() AS DATE))` | `CAST(GETDATE() AS DATE)` |
| "March 25" | `'2026-03-25'` | `'2026-03-26'` |

## Gotchas

1. **Dev calls appear in Prod MSSQL.** Dev environment calls flow through the same telephony infrastructure and land in the prod `xcall_long`/`xcall_short` tables. This is expected — Dev and Prod share the call recording pipeline.
2. **`tz_datetime` is NOT UTC.** It's the dealer's local timezone with a fake `.000Z` suffix. See `references/mssql-schema-map.md`.
3. **Short calls (< 0.1 min) are usually hangups.** Filter with `x.leminutes > 0.1` if the user wants only connected calls.
4. **`transferInitiated` is a bit flag.** `1` = transfer was initiated, `0` = no transfer. For warm transfer testing, all successful test calls should show `1`.
5. **`xcall_long` can lag.** If testing just happened, data might only be in `xcall_short`. Always check freshness first.
6. **Transcripts are NOT in MSSQL.** Call transcripts (STT conversation history) are sent via SQS to the `transcriptions` service and stored in S3/Postgres. MSSQL only has call metadata. Use CloudWatch logs (search by `uniqueCallId`) to see the real-time transcript that the telephony-service processed.


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Transcript not yet available | Empty results | Pipeline has 2-5 min lag |
| Wrong call segment | IVR instead of agent | Filter by segment type |

## Companion Skills

- `call-lookup` — single call investigation by callid/callguid
- `call-search` — multi-criteria search and aggregation
- `warm-transfer-tester` — set up a Dev warm transfer test session
- `hcat-lookup` — check HCAT tagging for a call
