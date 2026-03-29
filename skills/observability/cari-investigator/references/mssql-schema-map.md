---
name: mssql-schema-map
parent: cari-investigator
description: MSSQL schema reference for callmeasurement-prod and humanatic-prod. Tables, columns, join paths, and known gotchas.
---

# MSSQL Schema Map

> **Databases:** callmeasurement-prod (MSSQL), humanatic-prod (MSSQL)
> **⚠️ These are separate hosts — no cross-database JOINs.**

## callmeasurement-prod

### xcall_long — Processed call records (historical)

The main call table. Contains processed calls after ETL pipeline completes. **Can lag 24-48 hours on weekends/holidays.**

| Column | Type | Notes |
|--------|------|-------|
| callid | bigint (PK) | 13-digit call identifier |
| uniqueCallId | uniqueidentifier | UUID / callguid |
| ani | varchar | Caller phone number (10 digits, no formatting) |
| cf_frn_dnisid | int | FK → dnis.dnisid — the tracking number dialed |
| extension_frn_dnisid | int | FK → dnis.dnisid — extension DNIS (if transferred) |
| ringto_frn_dnisid | int | FK → dnis.dnisid — ring-to DNIS |
| tz_datetime | datetime | **⚠️ GOTCHA: Dealer's LOCAL time, stored with `.000Z` suffix. NOT UTC.** |
| tz_date | date | Date portion of tz_datetime |
| insert_datetime | datetime | When the row was inserted (actual UTC) |
| leminutes | float | Call duration in minutes (decimal: 2.33 = 2m 20s) |
| spamrating | smallint | 0=clean, 1=suspected, 2=confirmed spam |
| transferInitiated | bit | Whether a transfer was initiated |
| entered_CP | datetime | When call entered call processing |

### xcall_short — Hot/recent call records

**Same schema as xcall_long.** Contains last ~24-48 hours before ETL processes them into xcall_long.

**USE THIS TABLE WHEN:** `xcall_long` returns 0 rows for today/yesterday, or when ETL pipeline is lagging.

### xcall_long_hcat / xcall_short_hcat — Humanatic review results

| Column | Type | Notes |
|--------|------|-------|
| call_hcatid | int (PK) | Auto-increment primary key |
| frn_callid | bigint | FK → xcall_long.callid (or xcall_short) — **⚠️ NOT `callid`** |
| frn_hcatid | int | FK → hcat.hcatid (humanatic-prod) |
| frn_hcat_optionid | int | Review answer option ID — **⚠️ NOT `frn_hresultid`. Lookup table not accessible via MCP connections.** |
| machine_processed | bit | Whether the review was automated |
| frn_hproductid | int | Product that triggered the review |
| task_cost | decimal | Cost of the review task |
| recordCreated | datetime | When the review record was created |

### dnis — Tracking numbers

| Column | Type | Notes |
|--------|------|-------|
| dnisid | int (PK) | Internal DNIS identifier |
| lednis | varchar | The actual phone number (10 digits) |
| add_lskinid | int | FK → lskin.lskinid — owning account |
| dnisfunctionid | tinyint | **⚠️ 1 = ALL inbound, not just scheduler. Use tagid=1397 for scheduler.** |
| inbound_ringto | varchar | Where inbound calls ring to |
| tzadjust | int | Timezone offset for this DNIS |
| isActive | bit | Whether number is currently active |
| e_leextension | varchar | Extension number |

### lskin — Accounts (dealerships)

| Column | Type | Notes |
|--------|------|-------|
| lskinid | int (PK) | **⚠️ Dealers can have multiple lskinids (old/new). Use the one with recent activity.** |
| refname | varchar | Account display name (e.g., "South Tacoma Honda") |

### calltag — Call outcome tags

| Column | Type | Notes |
|--------|------|-------|
| frn_callid | bigint | FK → xcall_long.callid |
| frn_calltagdatumid | int | FK → calltagdatum.calltagdatumid |
| calltagDT | datetime | When the tag was applied |

> **⚠️ `frn_calltagsourceid` exists but NO `calltagsource` lookup table is accessible.** The FK target is not in any MCP-connected database. Ignore this column — filter by `frn_calltagdatumid` instead.

### calltagdatum — Tag definitions (key Cari IDs)

| Column | Type | Notes |
|--------|------|-------|
| calltagdatumid | int (PK) | Tag identifier |
| datum | varchar | **⚠️ Column is `datum`, NOT `description` or `name`.** Full text like "Cari Service Scheduler Scheduled Appt" |
| isActive | bit | Whether the tag is currently active |

**Common Cari tag IDs** (see `call-outcome-search/references/outcome-tags.md` for the full catalog):

| calltagdatumid | datum (abbreviated) | Meaning |
|----------------|---------------------|---------|
| 2390 | ...Scheduled Appt | Booking confirmed |
| 2391 | ...Rescheduled Appt | Appt rescheduled |
| 2392 | ...Cancelled Appt | Appt cancelled |
| 2383 | ...Involved | Cari handled call (any outcome) |
| 2394 | ...Abandoned | Caller hung up during scheduling |
| 2393 | ...Hang Up | Cari detected hang-up |
| 2397 | ...Declined Time Offering | Caller rejected offered times |
| 2389 | ...Afterhours | Call arrived outside hours |
| 2400 | ...Rule Based Transfer | Transferred by rule |

### hcat_dnis — Per-DNIS HCAT overrides

**⚠️ TWO DNIS columns exist.** Always use `frn_dnisid` for joins.

## humanatic-prod

### hcat — Review category definitions

| Column | Type | Notes |
|--------|------|-------|
| hcatid | int (PK) | Category identifier |
| display_name | varchar | Human-readable name |
| hc_question | varchar | Question reviewers answer |

### hcat_lskin — Per-account HCAT configuration

| Column | Type | Notes |
|--------|------|-------|
| frn_hcatid | int | FK → hcat.hcatid |
| frn_lskinid | int | **⚠️ -1 = wildcard (applies to ALL accounts)** |
| make_priority | bit | Priority review flag |
| isPaused | bit | Whether reviews are suspended |

## Join Paths

```
xcall_long.cf_frn_dnisid → dnis.dnisid → dnis.add_lskinid → lskin.lskinid
xcall_long.callid → calltag.frn_callid, calltag.frn_calltagdatumid → calltagdatum.calltagdatumid
xcall_long.callid → xcall_long_hcat.frn_callid, xcall_long_hcat.frn_hcatid → hcat.hcatid (⚠️ CROSS-DB: requires two separate queries — one to callmeasurement-prod, one to humanatic-prod)
```

## Critical Gotchas

1. **`tz_datetime` is NOT UTC.** Dealer's local time with fake `.000Z` suffix.
2. **`xcall_long` can be stale.** Always check `xcall_short` as fallback for today's data.
3. **Two DNIS columns in `dnis`.** `lednis` = phone number, `dnisid` = internal ID.
4. **Cross-DB JOINs impossible.** callmeasurement-prod and humanatic-prod are separate hosts.
5. **`lskinid` can be ambiguous.** Pick the one with most recent call activity.
6. **`dnisfunctionid=1` ≠ scheduler.** Use `tagid=1397` to filter scheduler calls.

## MSSQL vs Postgres Coverage

**Not all MSSQL calls have Postgres (reporting DB) records.**

The Postgres `reporting-prod.calls` table only contains calls handled by Cari. Calls that ring directly to a dealer employee's desk phone (agent lines, outbound caller IDs) appear in MSSQL `xcall_long` but never touch Cari, so they have no Postgres transcript.

**How to tell if a DNIS is a Cari line:**
- Check `calltag` for the call — if it has any `Cari%` tags (e.g., "Cari Receptionist Involved"), Cari handled it
- Check `dnis.label1` — agent lines say "{Name}'s Agent Line"; outbound lines say "outbound caller id" or "Sales outbound line"
- Check `dnis.leoutdial` — `force_manual` means the DNIS is not routed through Cari

**Rule of thumb:** If comparing MSSQL call counts to Postgres call counts, expect 20-30% fewer Postgres records. The "missing" calls are non-Cari traffic.


