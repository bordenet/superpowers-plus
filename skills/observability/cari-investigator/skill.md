---
name: cari-investigator
source: superpowers-cari
triggers: ["investigate cari", "debug cari", "lookup lskinid", "cari investigation", "check dealer config", "investigate cari call", "what happened on this call", "why didn't it book", "cari booking rate", "cari containment rate", "cari agent logs", "cari model failover", "cari polling health", "cari opcode sync", "cari system health"]
anti_triggers: ["Redis cache", "data sync", "tool calls", "integration error", "LLM error", "general debugging"]
description: Cari Investigator - orchestrates investigations across Cari services. Given an lskinid, call ID, phone number, or lead ID, queries the appropriate service databases to produce structured investigation reports.
summary: "Use when: investigating Cari issues by lskinid, call ID, phone number, or lead ID."
coordination:
  group: cari
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Cari Investigator

> **Source:** superpowers-cari
> **Type:** Orchestrator skill with sub-skill files

## When to Use

Use this when you need to diagnose issues or answer questions across Cari services using an identifier like `lskinid` or `call_id`, for example:

- "Investigate lskinid XXXXX" / "Debug Cari for dealer Y"
- "What happened on call X" / "Why didn't it book"
- "Check dealer config" / "What config does this dealer have"
- "Warm transfer failure" / "Repeat callers" / "Containment rate"
- "Polling broken" / "CDK webhook" / "Authenticom feed stuck"

## Inputs (any)

- `lskinid` (preferred)
- `call_id` / `cm_call_id`
- phone number
- lead id / appointment id (if available)
- time window (default to last 7 days unless the user specifies)

## Output expectations

Produce:

1) A short **chat summary** (what we found + most likely cause + next steps)
2) A structured **investigation report** in markdown with sections appropriate to the user request

For standardized output layouts, use:

- `references/report-templates.md`

## Guardrails (required)

Before running any DB queries or CloudWatch scans, load and follow:

- `references/aws-query-guardrails.md`

Minimum safety defaults:

- Confirm environment (prefix production output with `🚨 PRODUCTION`)
- RDS: set statement timeout, use a date range, and use `LIMIT`
- Prefer narrow queries first; avoid leading-wildcard `LIKE '%...%'` on prod

## Investigation workflow (high-level)

1) Confirm the identifier and environment
2) Resolve to `lskinid` if the user provided another identifier. **⚠️ If searching by dealer name, check for multiple lskinids — use the one with the most recent call activity** (see `references/mssql-schema-map.md`)
3) Pull account/config context first (DMS type, scheduler type, enabled services)
4) Pull performance/call patterns as needed (bounded time window)
5) Pull call-level traces when investigating a specific call
6) **Check for config changes** around the incident time → `config-change-detection.md`
7) Summarize findings and recommend the next most informative drill-down

## Route to sub-skill files

Use these sub-skill files as the canonical source for schemas and query templates:

- Config / dealer setup / enabled services → `config-service.md`
- Performance / dealer health / transfer trends → `performance-analytics.md`
- Call-level reporting + warm transfers + repeat callers → `reporting-service.md`
- Agent behavior / tool calls / model failover → `agent-api.md`
- Telephony lifecycle / routing / transfer failures → `telephony-service.md`
- Integrations / polling / CDK webhooks / Redis cache freshness → `integration-platform.md`
- Config change audit / "what changed?" → `config-change-detection.md`
- Appointment time/lane details (cross-system) → `appointment-details.md`

## Maintenance / drift

If investigation results look inconsistent with expectations, run the maintenance workflow before making strong claims:

- Say: "run cari maintenance"
- Skill: `cari-investigator-maintenance`

(For prior full guidance, see `references/skill-legacy.md`.)

## Example: DNIS Tag Verification

To verify DNIS tag configuration, use the verified schema tables documented in
`references/mssql-schema-map.md`. The exact query depends on which tags and
accounts are under investigation — consult the schema map for current table names.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Wrong sub-skill routed | Misses key data | telephony=call flow, agent-api=tools, config=setup |
| Missing AWS creds | CloudWatch fails silently | Run aws sso login first |
| Stale schema | Query errors | Run maintenance to refresh schema |
