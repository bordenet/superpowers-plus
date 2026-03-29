---
name: aws-query-guardrails
parent: [product]-investigator
description: Production guardrails for RDS queries, CloudWatch Insights scans, and environment safety. Reusable by any skill that queries production AWS.
---

# AWS Query Guardrails

<EXTREMELY_IMPORTANT>
These guardrails protect the production [Product] system from investigation-related impact. **Violating any guardrail is a blocking error — stop and fix before proceeding.**

## RDS Query Discipline

**Connection safety — every psql session MUST start with:**

```sql
SET statement_timeout = '30s';
SET transaction_read_only = ON;
SET idle_in_transaction_session_timeout = '60s';
```

| Rule | Default | User Override | Hard Block |
|------|---------|---------------|------------|
| Statement timeout | 30s | Up to 60s | 120s max |
| Date range (aggregates) | 7 days | Up to 30 days | 90 days |
| Date range (drill-downs) | 1 day | Up to 7 days | 30 days |
| LIMIT clause | 100 | Up to 1000 | 1000 max |
| Concurrent connections | 1 | — | Never parallel |
| EXPLAIN before execute | Always | Skip for known-safe queries | — |

**EXPLAIN gate:** Before executing any query, run `EXPLAIN (COSTS)` first (NOT `EXPLAIN ANALYZE` — that executes the query). Check the plan:
- `Seq Scan` on a table with >100K estimated rows → **warn user**, suggest narrower date filter or additional WHERE clause
- Estimated rows >100K → **warn user**
- `Nested Loop Join` → **warn** about potential slowness

If the plan looks safe → execute. If not → present the plan to the user and ask how to proceed.

**Every query MUST include:**
1. A date range filter (`WHERE start_time >= NOW() - INTERVAL 'N days'`)
2. A `LIMIT` clause

**Blocked on production:**
- Leading wildcard `LIKE '%pattern%'` — cannot use indexes, forces full scan
- Queries without date range filters
- `EXPLAIN ANALYZE` (executes the query to get actual timings — use `EXPLAIN (COSTS)` instead)

**After every query:** Disconnect immediately. No persistent sessions.

**If a query times out (30s):** Report to user and suggest narrowing filters. Do NOT auto-retry the same query.

## CloudWatch Logs Insights

| Rule | Default | User Override | Hard Block |
|------|---------|---------------|------------|
| Scan window | 1 hour | Up to 24 hours | 7 days max |
| Concurrent queries | 1 (serial) | — | Max 3 |
| Unfiltered scans (no lskin) | 1 hour max | Up to 6 hours with confirmation | 24 hours |

**Always wait** for `get-query-results` to return status `Complete` before starting the next query.

**For unfiltered queries** (IP7 bulk error scan, IP9 metrics): suggest dev/staging first if the issue isn't production-specific.

## Production Safety

- **Always ask** which environment before the first query of an investigation
- **Prefix production output** with `⚠️ PRODUCTION` so it's visually distinct
- **For aggregate queries across all dealers** (no lskinid filter): suggest dev/staging first
- **Fetch credentials once per session** — cache in environment variables, don't re-fetch unless auth error

## Guardrail Violation Response

If you realize you've violated a guardrail mid-investigation:

1. **Stop immediately** — do not continue the query
2. **Kill the connection** if one is open
3. **Report** what happened to the user
4. **Fix** — narrow the query, add filters, switch to dev/staging
5. **Resume** only after the fix is confirmed
</EXTREMELY_IMPORTANT>
