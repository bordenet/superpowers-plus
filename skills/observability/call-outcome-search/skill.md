---
name: call-outcome-search
source: superpowers-[product]
description: "Find [Product] calls by booking outcome, time window, service lane, and dealer. Resolves dealer names to lskinids, maps outcome descriptions to calltag IDs, converts local time to UTC, and optionally identifies service lane from scheduler config."
summary: "Use when: investigating specific booking outcomes at a dealer within a time window. Skip when: general call search (use call-search), full investigation (use [product]-investigator)."
triggers: ["booking calls", "find bookings", "calls that booked", "express lane bookings", "service lane calls", "scheduled appointments", "who booked", "track down calls", "call IDs for bookings"]
coordination:
  group: [product]
  order: 1
  requires: []
  enables: ['[product]-investigator']
  escalates_to: []
  internal: false
---

# Call Outcome Search

> **Source:** superpowers-[product]
> **Domain:** [Product] booking investigation
> **Databases:** [[database]-prod] (MSSQL), config-prod (Postgres RDS)

Find calls that produced a specific [Product] outcome (e.g., "Scheduled Appt") at a dealer within a time window. Optionally filter by service lane (Express, Main Shop).

## Workflow

### Step 1: Resolve dealer to lskinid

```sql
-- [[database]-prod]
SELECT TOP 10 l.lskinid, l.refname,
  (SELECT MAX(x.tz_datetime) FROM xcall_long x
   JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
   WHERE d.add_lskinid = l.lskinid) AS last_call
FROM lskin l
WHERE l.refname LIKE '%{dealer_name}%'
ORDER BY l.lskinid DESC
```

**⚠️ Dealers can have multiple lskinids (old/new).** Pick the one with the most recent `last_call`. Confirm with user if multiple active matches.

### Step 2: Identify the outcome tag

See `references/outcome-tags.md` for the full [Product] Service Scheduler tag catalog (18 calltagdatumid values from `[[database]-prod].dbo.calltagdatum`).

Common tags for quick reference:
- **2390** — Scheduled Appt (booking confirmed)
- **2383** — Involved ([Product] handled call, any outcome)
- **2392** — Cancelled Appt
- **2394** — Abandoned (caller hung up)

### Step 3: Convert time window to dealer's local time

**⚠️ `tz_datetime` stores the dealer's LOCAL time (not UTC), despite the `.000Z` suffix.**

The user provides local time. Use it directly — do NOT convert to UTC. If the user says "noon PDT" and the dealer is in Pacific time, query for `tz_datetime >= '2026-03-23 12:00:00'`.

If the user gives UTC times, convert them TO the dealer's local timezone before querying.

| Timezone | UTC → Local Adjustment (standard) | UTC → Local Adjustment (DST) |
|----------|----------------------------------|------------------------------|
| America/Los_Angeles (PDT) | -8 hours | -7 hours |
| America/Denver (MDT) | -7 hours | -6 hours |
| America/Chicago (CDT) | -6 hours | -5 hours |
| America/New_York (EDT) | -5 hours | -4 hours |

Example: User says "noon PDT" for a PDT dealer → query `tz_datetime >= '2026-03-23 12:00:00' AND tz_datetime < '2026-03-23 13:00:00'`

### Step 4: Check data freshness & query calls

**Before querying, check if `xcall_long` has recent data:**
```sql
-- [[database]-prod]
SELECT TOP 1 tz_datetime FROM xcall_long ORDER BY callid DESC
```

If the most recent row is older than yesterday, **use `xcall_short` instead of `xcall_long`** in the query below.

```sql
-- [[database]-prod] (use xcall_short if xcall_long is stale)
SELECT x.callid, x.ani, x.tz_datetime, x.leminutes, d.lednis
FROM xcall_long x
JOIN dnis d ON x.cf_frn_dnisid = d.dnisid
JOIN calltag ct ON ct.frn_callid = x.callid
JOIN calltagdatum ctd ON ct.frn_calltagdatumid = ctd.calltagdatumid
WHERE d.add_lskinid = {lskinid}
AND ctd.calltagdatumid = {tag_id}
AND x.tz_datetime >= '{local_start}'
AND x.tz_datetime < '{local_end}'
ORDER BY x.tz_datetime
```

### Step 5: Identify service lane (optional)

If the user asks about a specific service lane (Express, Main Shop, etc.), check the dealer's scheduler config for lane definitions.

```sql
-- config-prod (Postgres RDS)
SELECT config->'scheduler'->'lanes' AS lanes
FROM scheduler_configs
WHERE account_id = {lskinid} AND is_active = true
ORDER BY created_at DESC LIMIT 1;
```

The `lanes` JSONB array contains objects like:
```json
[
  { "id": 1, "name": "Main Shop", "enabled": true },
  { "id": 2, "name": "Express Lane", "enabled": true }
]
```

Cross-reference the lane ID against the [Product] agent trace logs (CloudWatch) for the specific call IDs to confirm which lane the appointment was booked into:

```
parse @message '"lskinid":*,' as lskin
| parse @message '"laneId":*,' as lane_id
| parse @message '"laneName":"*"' as lane_name
| filter @message like /{callid}/
| display @timestamp, lane_id, lane_name
| sort @timestamp asc
| limit 50
```

### Step 6: Present results

Format output as a table:

| callid | ANI | Time (local) | Duration | DNIS | Service Lane |
|--------|-----|-------------|----------|------|-------------|

Include:
- Total count of matching calls
- Time range covered
- If lane filtering was requested, note which calls matched the specific lane
- Recommend next steps (e.g., "review agent traces for these call IDs" via `[product]-investigator`)

## When to Use

- Finding calls by booking outcome (Scheduled, Cancelled, Abandoned, etc.) within a time window
- Searching by dealer, time range, and service lane
- Mapping outcome descriptions to calltag IDs

## Failure Modes

- **Dealer name not found** → Use `lskinid` directly if dealer was renamed
- **UTC conversion incorrect** → `tz_datetime` is dealer's LOCAL time, not UTC (despite `.000Z` suffix)
- **Outcome description not matching** → Cross-check against `outcome-tags.md` reference
