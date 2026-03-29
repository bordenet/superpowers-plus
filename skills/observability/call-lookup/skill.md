---
name: call-lookup
source: superpowers-cari
triggers: ["look up call", "call details for callid", "who called this number", "what account for ANI", "find call by callguid", "callid lookup", "callguid lookup", "ANI lookup", "DNIS lookup", "tracking number lookup"]
anti_triggers: ["search calls", "call volume", "call count", "booking calls", "calls that booked", "call trends", "how many calls"]
description: Look up a SINGLE call by callid, callguid, ANI, or DNIS. Returns call record with account name, duration, spam rating, and tracking number. Use when investigating a specific call or caller. NOT for multi-call search or aggregation (use call-search). NOT for booking outcomes (use call-outcome-search).
summary: "Use when: investigating a specific call by callid, callguid, ANI, or DNIS. Skip when: multi-call search (use call-search), booking outcomes (use call-outcome-search)."
coordination:
  group: cari
  order: 1
  requires: []
  enables: ['cari-investigator']
  escalates_to: []
  internal: false
---

# Call & Account Lookup

> **Source:** `superpowers-cari`
> **Domain:** Call Review
> **Created:** 2026-03-18

Look up call metadata by callid, callguid (uniqueCallId), ANI (caller phone number), or DNIS (tracking number). Returns the call record with account name, duration, spam rating, and tracking number.

## When to Use

- User asks about a specific call ("look up call 6001540522802")
- User asks about calls from a phone number ("what calls came from 8065184536?")
- User asks about a tracking number ("what account owns 9153447413?")
- User asks about a callguid/uniqueCallId ("find call 79815257-772D-400B-BCDD-25AD49FE7FFE")

## How to Execute

### Step 1: Identify the Input Type

| Input | Pattern | Example |
|-------|---------|---------|
| callid | 13-digit number | `6001540522802` |
| callguid / uniqueCallId | UUID format | `79815257-772D-400B-BCDD-25AD49FE7FFE` |
| ANI (caller number) | 10-digit phone number | `8065184536` |
| DNIS (tracking number) | 10-digit phone number | `9153447413` |

If ambiguous between ANI and DNIS (both are 10-digit phone numbers), ask the user. ANI = who called, DNIS = what number they dialed.

### Step 2: Check Data Freshness & Select Table

Use `query_mssql` with connection `callmeasurement-prod`.

**Before querying, check if `xcall_long` has recent data:**
```sql
SELECT TOP 1 tz_datetime FROM xcall_long ORDER BY callid DESC
```

If the most recent row is older than yesterday, the ETL pipeline is lagging. **Use `xcall_short` instead of `xcall_long`** for all queries below. Replace `xcall_long` → `xcall_short` and `xcall_long_hcat` → `xcall_short_hcat` in your queries.

### Step 3: Run the Query

**By callid:**
```sql
SELECT TOP 20 x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.spamrating, d.lednis, d.dnisid, l.refname AS account_name, l.lskinid
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE x.callid = {callid}
```

**By callguid (uniqueCallId):**
```sql
SELECT TOP 20 x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.spamrating, d.lednis, d.dnisid, l.refname AS account_name, l.lskinid
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE x.uniqueCallId = '{callguid}'
```

**By ANI (caller phone number):**
```sql
SELECT TOP 20 x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.spamrating, d.lednis, d.dnisid, l.refname AS account_name, l.lskinid
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE x.ani = '{ani}'
ORDER BY x.tz_datetime DESC
```

**By DNIS (tracking number):**
```sql
SELECT TOP 20 x.callid, x.uniqueCallId, x.ani, x.tz_datetime, x.leminutes,
       x.spamrating, d.lednis, d.dnisid, l.refname AS account_name, l.lskinid
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE d.lednis = '{dnis}'
  AND x.tz_datetime >= DATEADD(day, -7, GETDATE())
ORDER BY x.tz_datetime DESC
```

Note: DNIS queries default to last 7 days to avoid full table scans. Adjust if the user specifies a different period.

### Step 4: Format the Output

**Single call:**
```
Call 6001540522802
  GUID:     79815257-772D-400B-BCDD-25AD49FE7FFE
  Time:     2026-03-17 22:56:58 UTC
  Duration: 3.0 minutes
  ANI:      (806) 518-4536
  DNIS:     (915) 344-7413
  Account:  JDA - Viva Nissan El Paso (lskinid: 186043)
  Spam:     Clean (0)
```

**Multiple calls (ANI/DNIS lookup):** Present as a table with most recent first.

### Spam Rating Reference

| Value | Meaning |
|-------|---------|
| 0 | Clean — not flagged as spam |
| 1 | Suspected spam |
| 2 | Confirmed spam |

## Key Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| xcall_long | Call records | callid, uniqueCallId, ani, tz_datetime, leminutes, spamrating, cf_frn_dnisid |
| dnis | Tracking numbers | dnisid, lednis, add_lskinid |
| lskin | Accounts | lskinid, refname |

## Join Path

```
xcall_long.cf_frn_dnisid → dnis.dnisid
dnis.add_lskinid → lskin.lskinid
```

## Gotchas

1. **ANI vs DNIS ambiguity:** Both are 10-digit phone numbers. ANI = caller, DNIS = tracking number dialed. Ask if unclear.
2. **Large result sets:** ANI and DNIS queries can return thousands of rows. Always use TOP and date filters.
3. **callguid format:** Must include hyphens. Case-insensitive in SQL Server.
4. **leminutes:** Duration in minutes as a decimal (e.g., 2.33 = 2 minutes 20 seconds).
5. **`xcall_long` can be stale.** ETL pipeline lags on weekends/holidays. Always check freshness first and fall back to `xcall_short`. See `references/mssql-schema-map.md`.
6. **`tz_datetime` is NOT UTC.** It's the dealer's local time with a fake `.000Z` suffix. See `references/mssql-schema-map.md`.


## Common Failure Modes

- **Wrong call ID format:** Using internal vs external call identifiers interchangeably
- **Missing connection string:** Querying without specifying dev vs prod database
- **Incomplete results:** Returning call metadata without associated tagging or scoring data

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Wrong ID type | No results despite valid call | Confirm input type: callid, callguid, ANI, or DNIS |
| Stale cache | Old data for recent call | Wait 5 min for pipeline lag, re-query |
