---
name: call-search
source: superpowers-[product]
triggers: ["search calls", "find calls by criteria", "call volume", "call count", "calls today", "calls this week", "how many calls", "call summary", "call trends", "spam calls", "call pattern", "calls for account", "daily call count"]
anti_triggers: ["look up call", "callid", "callguid", "booking calls", "calls that booked", "scheduled appointments", "investigate [product]"]
description: Flexible multi-criteria call search with optional aggregation. Find calls by account, ANI, DNIS, date range, duration, or spam status. Supports both detail listing and summary/aggregation modes (daily volume, spam counts, average duration). NOT for single-call lookup by ID (use call-lookup). NOT for booking outcomes (use call-outcome-search).
summary: "Use when: searching calls by multiple criteria or analyzing call patterns/volume. Skip when: single-call lookup (use call-lookup), booking outcomes (use call-outcome-search)."
coordination:
  group: [product]
  order: 1
  requires: []
  enables: ['[product]-investigator']
  escalates_to: []
  internal: false
---

# Call Pattern Search

> **Source:** `superpowers-[product]`
> **Domain:** Call Review
> **Created:** 2026-03-18

Search and aggregate call data across multiple criteria. Two modes: **detail** (list individual calls) and **aggregate** (counts, averages, trends by day/account).

## When to Use

- User asks about call volume ("how many calls did Viva Nissan get today?")
- User wants to search by multiple criteria ("show me spam calls over 5 minutes this week")
- User asks about trends ("daily call counts for account 186043 over the last week")
- User wants a summary rather than individual call records

## How to Execute

### Step 1: Identify the User's Intent

Determine **mode** and **filters** from the question:

| Mode | Triggered by | Returns |
|------|-------------|---------|
| **Detail** | "show me calls", "find calls", "list calls" | Individual call records (TOP 20) |
| **Aggregate** | "how many", "call volume", "daily counts", "summary", "trends" | Counts, averages, grouped results |

### Step 2: Build the WHERE Clause

Combine any of these filters. All are optional — use only what the user specifies:

| Filter | Column | Example |
|--------|--------|---------|
| Account (by lskinid) | `l.lskinid = {id}` | `l.lskinid = 186043` |
| Account (by name) | `l.refname LIKE '%{name}%'` | `l.refname LIKE '%Viva Nissan%'` |
| ANI (caller phone) | `x.ani = '{ani}'` | `x.ani = '8065184536'` |
| DNIS (tracking number) | `d.lednis = '{dnis}'` | `d.lednis = '9153447413'` |
| Date range | `x.tz_datetime >= '{start}' AND x.tz_datetime < '{end}'` | Today: `>= CAST(GETDATE() AS DATE)` |
| Minimum duration | `x.leminutes >= {min}` | `x.leminutes >= 2` |
| Spam only | `x.spamrating = 2` | Confirmed spam |
| Non-spam only | `x.spamrating = 0` | Clean calls |

### Step 3: Check Data Freshness & Select Table

Use `query_mssql` with connection `[[database]-prod]`.

**Before querying, check if `xcall_long` has recent data:**
```sql
SELECT TOP 1 tz_datetime FROM xcall_long ORDER BY callid DESC
```

If the most recent row is older than yesterday, the ETL pipeline is lagging. **Use `xcall_short` instead of `xcall_long`** for all queries below. Replace `xcall_long` → `xcall_short` in your queries.

### Step 4: Execute the Query

**Detail mode:**
```sql
SELECT TOP 20 x.callid, x.ani, x.tz_datetime, x.leminutes, x.spamrating,
       d.lednis, l.refname AS account_name, l.lskinid
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE {filters}
ORDER BY x.tz_datetime DESC
```

**Aggregate mode — account summary:**
```sql
SELECT l.refname AS account_name, l.lskinid,
       COUNT(*) AS call_count,
       AVG(x.leminutes) AS avg_duration_min,
       MIN(x.leminutes) AS min_duration,
       MAX(x.leminutes) AS max_duration,
       SUM(CASE WHEN x.spamrating = 2 THEN 1 ELSE 0 END) AS confirmed_spam
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE {filters}
GROUP BY l.refname, l.lskinid
```

**Aggregate mode — daily trend:**
```sql
SELECT CAST(x.tz_datetime AS DATE) AS call_date,
       COUNT(*) AS call_count,
       AVG(x.leminutes) AS avg_duration_min,
       SUM(CASE WHEN x.spamrating = 2 THEN 1 ELSE 0 END) AS confirmed_spam
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN lskin l ON d.add_lskinid = l.lskinid
WHERE {filters}
GROUP BY CAST(x.tz_datetime AS DATE)
ORDER BY call_date DESC
```

### Step 5: Format the Output

**Detail mode:**
```
5 calls for JDA - Viva Nissan El Paso (lskinid: 186043) on 2026-03-17, duration >= 2 min

  Call 6001540522802  22:56  3.0 min  ANI: (806) 518-4536  DNIS: (915) 344-7413  Clean
  Call 6001540522784  22:52  4.3 min  ANI: (806) 518-4536  DNIS: (915) 344-7413  Clean
  Call 6001540511457  19:41  2.0 min  ANI: (915) 504-0459  DNIS: (915) 344-7392  Clean
  ...
```

**Aggregate mode:**
```
JDA - Viva Nissan El Paso — Daily Volume (last 7 days)

  2026-03-17:  883 calls  avg 1.4 min  0 spam
  2026-03-16:  678 calls  avg 1.5 min  0 spam
  2026-03-15:    5 calls  avg 1.4 min  0 spam  (weekend)
  2026-03-14:  349 calls  avg 1.7 min  0 spam
  2026-03-13:  778 calls  avg 1.5 min  0 spam
  2026-03-12:  675 calls  avg 1.6 min  0 spam
  2026-03-11:  816 calls  avg 1.4 min  0 spam

  Total: 5,060 calls over 7 days
```

## Common Date Filters

| User says | SQL WHERE |
|-----------|-----------|
| "today" | `x.tz_datetime >= CAST(GETDATE() AS DATE)` |
| "yesterday" | `x.tz_datetime >= DATEADD(day, -1, CAST(GETDATE() AS DATE)) AND x.tz_datetime < CAST(GETDATE() AS DATE)` |
| "this week" | `x.tz_datetime >= DATEADD(day, -7, GETDATE())` |
| "this month" | `x.tz_datetime >= DATEADD(month, -1, GETDATE())` |
| "March 15" | `x.tz_datetime >= '2026-03-15' AND x.tz_datetime < '2026-03-16'` |

## Resolving Account Names

If the user provides an account name instead of lskinid:
```sql
SELECT TOP 5 lskinid, refname FROM lskin
WHERE refname LIKE '%{search_term}%'
ORDER BY refname
```
Use this to find the lskinid, then use it in the main query. If multiple matches, show them and ask the user to clarify.

## Gotchas

1. **Always use TOP or date filters.** The xcall_long table has billions of rows. Never run an unbounded query.
2. **leminutes can be 0.** Zero-duration calls are hangups/abandoned. Exclude with `x.leminutes > 0` unless the user explicitly wants them.
3. **spamrating values:** 0 = clean, 1 = suspected, 2 = confirmed. Most users mean "confirmed spam" when they say "spam calls."
4. **Weekend volume drops are normal.** Saturday/Sunday typically show 90%+ drops. Don't flag this as anomalous.
5. **LIKE queries on refname are slow.** Prefer lskinid when possible. If the user gives a name, resolve to lskinid first, then use the ID for the main query.
6. **`xcall_long` can be stale.** ETL pipeline lags on weekends/holidays. Always check freshness first and fall back to `xcall_short`. See `references/mssql-schema-map.md`.
7. **`tz_datetime` is NOT UTC.** Dealer's local time with fake `.000Z` suffix. See `references/mssql-schema-map.md`.


## Common Failure Modes

- **Overly broad query:** Searching without date range or DNIS filter, returning too many results
- **Wrong database:** Querying dev when production data is needed (or vice versa)
- **Missing join:** Searching calls table without joining to get tagging/scoring data

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Too broad filter | Thousands of results | Add time window and 2+ filter criteria |
| Missing timezone | Wrong calls returned | Confirm timezone, use UTC in queries |
