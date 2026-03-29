---
name: cari-investigator
source: superpowers-cari
triggers: ["investigate cari", "debug cari", "lookup account", "lookup lskinid", "cari investigation", "what config does this dealer have", "check dealer config", "investigate call", "investigate account", "dealer performance", "booking rate", "call volume", "system health", "problem detection", "call drill-down", "what happened on this call", "RO value", "opcodes", "warm transfer", "repeat callers", "containment rate", "acquisition sessions", "sellmyride", "agent logs", "what did the agent do", "model failover", "LLM error", "tool calls", "integration error", "why didn't it book", "slot unavailable", "data sync", "stale appointments", "polling broken", "CDK webhook", "Authenticom", "Redis cache", "make model sync", "opcode sync", "integration platform", "polling health"]
description: Cari Investigator - orchestrates investigations across Cari services. Given an lskinid, call ID, phone number, or lead ID, queries the appropriate service databases to produce structured investigation reports.
---

# Cari Investigator

> **Source:** superpowers-callbox
> **Type:** Orchestrator skill with sub-skill files

## When to Use

- User says "investigate lskinid XXXXX" or "debug cari for dealer Y"
- Diagnosing call issues: "what happened on call X", "why didn't it book"
- Performance questions: "booking rate for dealer X", "call volume last 7 days"
- Config verification: "what config does lskinid X have", "check dealer setup"
- Agent debugging: "what did the agent do on this call", "LLM errors for dealer X"
- Telephony issues: "SIP rejects", "transfer failures", "call lifecycle for callid X"
- Data sync issues: "stale appointments", "polling broken", "CDK webhooks not arriving", "Authenticom feed stuck"

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| DB credentials not in Secrets Manager | Connection refused / auth error | Check AWS Secrets Manager for the target environment |
| Wrong environment queried | Results don't match expectations | Default is production; if results look wrong, confirm env with user |
| lskinid not found | Empty result set on config lookup | Verify lskinid is correct; try resolving from phone number or account name |
| CloudWatch log group missing | ResourceNotFoundException | Verify Lambda/ECS service is deployed in target environment |
| Query timeout on large tables | Query exceeds 30s | Add tighter date range filters or LIMIT clause |

## Maintenance Check (Auto-Suggest)

<EXTREMELY_IMPORTANT>
Before starting an investigation, check if the skill is up to date:

```bash
source ~/.codex/.env 2>/dev/null
source callbox/cari-investigator-maintenance/.maintenance-state 2>/dev/null \
  || source ~/.codex/skills/cari-investigator-maintenance/.maintenance-state 2>/dev/null \
  || last_maintenance="2026-03-19"
```

**If `CARI_REPO_PATH` is set and the path exists:**

```bash
cd "$CARI_REPO_PATH"
git log --no-merges --since="$last_maintenance" --oneline -- \
  agent-api/ src/ integration-platform/src/ telephony-service/src/ \
  config-service/ reporting-service/ infra/ | wc -l
```

If the count is **>10 commits**, suggest:

```
ℹ️ The Cari codebase has <N> new commits since last skill maintenance (<last_maintenance>).
   Some investigation queries may be outdated.
   Say "run cari maintenance" to check, or continue investigating.
```

**If `CARI_REPO_PATH` is not set or path doesn't exist:**

Show a one-time warning, then proceed with the investigation:

```
⚠️ Cari monorepo not found (CARI_REPO_PATH not set in ~/.codex/.env).
   Investigation queries may be outdated if the codebase has changed
   since this skill was last maintained. Results are still valid but
   verify critical findings against the actual codebase.

   To enable drift checking, set CARI_REPO_PATH in ~/.codex/.env
   or say "run cari maintenance" to configure it.
```

**Never block an investigation due to missing repo.** The queries work without it — only drift checking is unavailable.
</EXTREMELY_IMPORTANT>

## Purpose

This skill investigates Cari platform issues by querying service databases directly. Each Cari service has its own sub-skill file with schema references and SQL templates.

### Investigation Report Workflow

When a user says "investigate lskinid XXXXX" (or provides any identifier), the agent:

1. **Creates a report file:** `<workspace>/_investigations/<lskinid>_<YYYY-MM-DD>.md`
2. **Runs summary queries** across all built sub-skills (config, performance, reporting)
3. **Writes a summarized report** with key metrics into the markdown file
4. **Presents the summary** to the user in chat
5. **Waits for follow-up questions** — user can ask to drill into any section
6. **Updates the report** with expanded sections as the user drills down

Each investigation starts fresh. Old report files in `_investigations/` are historical artifacts.

### Report Structure

The auto-generated report follows this structure:

```markdown
# Investigation: [Dealer Name] (lskinid XXXXX)
> Generated: YYYY-MM-DD HH:MM ET | Environment: production

## Account Overview
- Name, timezone, language, test account status
- Active services: scheduler ✅/❌, receptionist ✅/❌, acquisition ✅/❌
- DMS type, scheduler type, dealer code

## Performance Summary (Last 7 Days)
- Total calls, unique callers, booking rate, abandonment rate
- Containment rate, avg duration, RO value
- Top transfer reasons

## Call Patterns
- Hourly volume distribution (peak hours)
- Language distribution
- Repeat callers (3+ calls, never booked)

## Flags
- Any metrics that cross default thresholds (for awareness, not judgment)
- Repeat callers never booked
- High transfer rates

---
*Sections below are added on demand when user asks to drill down*

## [Expanded Section: OpCode Detail]
## [Expanded Section: Specific Call Drill-Down]
## [Expanded Section: Warm Transfer Analysis]
```

### Creating the _investigations/ Directory

Before writing the report, ensure the directory exists:

```javascript
const fs = require('fs');
const path = require('path');
const dir = path.join(process.cwd(), '_investigations');
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
```

The report file path: `_investigations/<lskinid>_<YYYY-MM-DD>.md`

### Presentation Rules for Reports

1. Write the full summary to the markdown file
2. Present a condensed version in chat (key numbers only, not the full file)
3. End with: "Report saved to `_investigations/<filename>`. What do you want to drill into?"
4. When user asks a follow-up, run the detailed query, append results to the report file, and present in chat
5. Do NOT add qualitative labels — numbers only, user interprets

## Sub-Skills (read the relevant file from this directory)

| Sub-Skill File | Service | What It Covers |
|----------------|---------|----------------|
| config-service.md | config-service | Dealership configs, account setup, DMS/scheduler integration |
| performance-analytics.md | reporting-service | Call performance metrics, daily stats, problem detection, system health |
| reporting-service.md | reporting-service | Single call drill-down, opcodes/RO value, warm transfer logs, transfer history, repeat callers, acquisition sessions |
| agent-api.md | agent-api (CloudWatch) | Agent decision logs, model failover, tool calls, integration debug |
| telephony-service.md | telephony-service (ECS logs) | Call lifecycle, audio/websocket streaming, SIP rejects, transfer sequence failures, call cost |
| integration-platform.md | integration-platform (CloudWatch) | DMS/scheduler data sync, Redis cache health, polling cycles, CDK webhooks, Authenticom lifecycle |

> **Planned sub-skills (not yet built):** acquisition-service (leads, cadence, appointments), call-processing (real-time call state, agent actions)

## Step 0: Check for Existing Temp Scripts

Before creating new scripts, check if temp files from a previous session already exist:

```bash
ls -la /tmp/cari/ 2>/dev/null
```

**If found:** Reuse them. Modify the existing scripts for the new callId or lskinid rather than rebuilding from scratch. This saves time on npm installs, credential fetches, and AWS CLI discovery that was already done.

**If not found:** Create the directory structure and proceed to Step 1:

```bash
mkdir -p /tmp/cari/{creds,cw,db,node}
```

### Temp File Naming Convention

| Directory | File Pattern | Example | Contents |
|-----------|-------------|---------|----------|
| `/tmp/cari/creds/` | `db-{dbname}.json` | `db-config.json`, `db-reporting.json` | DB credentials from Secrets Manager |
| `/tmp/cari/cw/` | `{service}-{query}.json` | `agent-q1-timeline.json`, `telephony-t3-lifecycle.json` | CloudWatch query results |
| `/tmp/cari/db/` | `{service}-{query}.json` | `config-q1-account.json`, `reporting-q1-call.json` | DB query results |
| `/tmp/cari/node/` | `node_modules/`, `package.json` | — | Node.js pg package install |

**Cleanup:** `rm -rf /tmp/cari/`

## Step 1: Determine Investigation Type

When the user provides an identifier:

**Full investigation** ("investigate lskinid 76293"):
- Default to production environment
- Run the summary report workflow (see Report Structure above)
- Create the report file, present summary, wait for drill-down

**Targeted question** ("what's the containment rate for 76293"):
- Skip the full report
- Run the specific query from the appropriate sub-skill
- Present the answer directly
- Offer to generate a full report if the user wants more context

**Clarify only if ambiguous:**
- Environment (if not obvious — default to production)
- Identifier type (if the user gives a number without context)

## Step 2: Check AWS Access & Fetch Credentials

> **Full AWS SSO setup, credential commands, and troubleshooting → see `references/aws-credentials.md`**

### Discover AWS CLI

On WSL, `aws` may not be in PATH. Resolve it first:

```bash
if command -v aws &>/dev/null; then
  AWS_CMD="aws"
elif [ -f "/mnt/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]; then
  AWS_CMD="/mnt/c/Program Files/Amazon/AWSCLIV2/aws.exe"
else
  echo "AWS CLI not found. Install it or add to PATH."
fi
```

Use `$AWS_CMD` (or `"$AWS_CMD"` when the path has spaces) for all subsequent aws commands.

Quick check:
```bash
"$AWS_CMD" sts get-caller-identity --profile telephony-prod
```

- **Success** → fetch readonly creds: `aws secretsmanager get-secret-value --secret-id cari-readonly-rds-production --profile telephony-prod`
- **Profile not found** → first-time setup needed (see `references/aws-credentials.md`)
- **Token expired** → `aws sso login --profile telephony-prod`

| Environment | Profile | Secret | Access |
|-------------|---------|--------|--------|
| Production | telephony-prod | cari-readonly-rds-production | SELECT only |
| Dev/Staging | telephony-dev | cari-readonly-rds-dev-staging | SELECT only |

> **⚠️ ALWAYS use the readonly secret.** Never use admin secrets for investigations.

## Step 3: Select the Correct Database

The RDS secret's `dbname` field is **not reliable** across environments. You MUST explicitly choose the service-specific database name:

| Service | Database Name (prod) | Database Name (dev/staging) |
|---------|---------------------|-----------------------------|
| config-service | config-prod | config-dev / config-staging |
| reporting-service | reporting-prod | reporting-dev / reporting-staging |
| acquisition-service | acquisition-prod | acquisition-dev / acquisition-staging | *(sub-skill not yet built)* |
| texting-service | texting-prod | texting-dev / texting-staging |

## Step 4: Run Queries

Detect which query method is available and use the first one that works:

### Option A: psql (preferred if installed)

Check: `which psql` (macOS/Linux) or `where psql` (Windows)

```bash
psql "host=$DB_HOST port=$DB_PORT dbname=<database-name> user=$DB_USER password=$DB_PASS sslmode=require" \
  -c "<SQL from sub-skill file>"
```

### Option B: Node.js with postgres package

If psql is not installed, use Node.js with the `postgres` npm package.

**Setup (one-time):** Create a temp working directory and install the package:
```bash
cd /tmp/cari/node && npm init -y && npm install pg  # package name is 'pg', require as: const { Client } = require('pg')
```

Or if the Cari monorepo is cloned locally, use the existing package:
```bash
# Set CARI_REPO_PATH to skip this — e.g. in ~/.codex/.env
# The postgres package is at: <cari-repo>/config-service/node_modules/postgres
```

```javascript
// Option 1: standalone install (no codebase needed)
const { Client } = require('/tmp/cari/node/node_modules/pg');
// Credentials from: /tmp/cari/creds/db-config.json (config DB) or db-reporting.json (reporting DB)
const creds = JSON.parse(require('fs').readFileSync('/tmp/cari/creds/db-config.json', 'utf8'));

const client = new Client({
  host: creds.host,
  port: parseInt(creds.port),
  database: '<database-name>',  // 'config-prod' or 'reporting-prod'
  user: creds.username,
  password: creds.password,
  ssl: { rejectUnauthorized: false },
  statement_timeout: 30000,
});
await client.connect();
await client.query('SET transaction_read_only = ON');  // guardrail: see references/aws-query-guardrails.md
const result = await client.query('<SQL from sub-skill>');
await client.end();
```


### CloudWatch Queries: Output Handling

<EXTREMELY_IMPORTANT>
**Always save CloudWatch output to a temp file before parsing.** On WSL, piping `aws.exe` output directly to python/jq truncates results >128KB.

```bash
"$AWS_CMD" logs get-query-results --query-id "$QID" --profile telephony-prod \
  --output json 2>/dev/null | tr -d '\r' > /tmp/cari/cw/agent-q1-timeline.json

# Then parse from file
python3 -c "import json; d=json.load(open('/tmp/cari/cw/agent-q1-timeline.json')); ..."
```

All sub-skill queries use `display` to suppress the raw `@message` field and return only parsed fields. This reduces output from ~20KB/row to ~200 bytes/row. **Never add `@message` back to the `display` list** unless you specifically need the full raw JSON for a single log entry.
</EXTREMELY_IMPORTANT>

## Step 5: Select Report Template

Before routing, pick the report template from `references/report-templates.md`:

| User Request | Template |
|-------------|----------|
| "What happened on call {callId}" | 1: Single Call Investigation |
| "How is dealer {lskinid} doing" | 2: Dealer Health Check |
| "Why did call {callId} fail" | 3: Error Investigation |
| "Show me calls for {lskinid} this week" | 4: Bulk/Trend Analysis |
| "Check xtime/PBS/Motive for {lskinid}" | 5: Integration Deep Dive |
| "Show me trends for {lskinid} over 30 days" | 6: Dealership Trend Report |

> **If no template fits**, adapt the output to match what the user actually asked. The templates are guardrails, not handcuffs.

## Step 6: Route to Sub-Skill

Based on what the user is investigating, read the appropriate sub-skill file from this directory:

- Account config, dealer setup, DMS type, scheduler type, active status -> config-service.md
- Dealer performance, booking rates, call volume, transfer analysis -> performance-analytics.md
- Problem detection, system health, hourly patterns, extension stats -> performance-analytics.md
- Single call lookup, call drill-down, what happened on this call -> reporting-service.md
- OpCodes, RO value, revenue, services booked -> reporting-service.md
- Warm transfer logs, transfer history, transfer chain -> reporting-service.md
- Repeat callers, language distribution -> reporting-service.md
- Acquisition sessions, SellMyRide, vehicle info -> reporting-service.md
- Containment rate, call lookup by phone number -> reporting-service.md
- Agent logs, what happened on this call (agent side) -> agent-api.md
- Model failover, LLM errors, token usage -> agent-api.md
- Tool call trace, what did the agent do -> agent-api.md
- Integration debug, DMS/scheduler API failures -> agent-api.md
- Slot unavailability, why couldn't it book -> agent-api.md
- Bulk error scan, agent errors in time range -> agent-api.md
- Phone routing, SIP, websocket/audio streaming, ringback, carrier callControlId, transfer sequence failures -> telephony-service.md
- DMS data sync, appointment polling, Redis cache freshness, polling intervals -> integration-platform.md
- CDK webhooks, real-time appointment updates from CDK Drive -> integration-platform.md
- Authenticom feeds, VIN-to-advisor mapping, feed status -> integration-platform.md
- Make/model sync, opcode sync (MyKaarma), stale data -> integration-platform.md
- Leads, cadence, SMS/call attempts, appointments -> ⚠️ acquisition-service (not yet built)
- Real-time call state, agent decisions -> ⚠️ call-processing (not yet built)

## Key Concept: lskinid

lskinid is the primary dealership identifier across ALL Cari services. It links account info, all config types, call records, leads, and appointments. If the user provides a different identifier, resolve it to an lskinid first.

## Security Notes

- NEVER log or display full database passwords in output
- NEVER commit credentials to any file
- Credentials are fetched at runtime from AWS Secrets Manager

## Guardrails

> **Full guardrails: `references/aws-query-guardrails.md`** — load before running any queries.

<EXTREMELY_IMPORTANT>
Every RDS query MUST: (1) `SET statement_timeout='30s'`, (2) include date range filter, (3) include `LIMIT`, (4) run `EXPLAIN (COSTS)` first. One connection at a time. Disconnect after each query. Leading wildcard `LIKE '%...'` blocked on production.

CloudWatch Insights: 1h default scan window, 7d max. Serial queries only. Wait for `Complete` before next query.

Always confirm environment first. Prefix production output with `⚠️ PRODUCTION`.
</EXTREMELY_IMPORTANT>
