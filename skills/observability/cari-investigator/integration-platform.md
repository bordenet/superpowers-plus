---
name: integration-platform
parent: [product]-investigator
description: CloudWatch Insights queries for [Product] integration-platform — DMS/scheduler data sync, Redis cache health, polling cycles, CDK webhooks, DataFeedProvider lifecycle.
---

# Integration Platform Sub-Skill

Use this when the investigation is about **DMS data sync, appointment polling, Redis cache state, CDK webhooks, DataFeedProvider feeds, make/model or opcode freshness**.

This complements:
- `config-service.md` (dealer config — dmsType, schedulerType, dealerCode)
- `agent-api.md` (agent decisioning that *consumes* cached data)
- `[telephony-service].md` (call transport layer)

<EXTREMELY_IMPORTANT>
**Always ask which environment to investigate (prod vs dev/staging). Never default.**
</EXTREMELY_IMPORTANT>

## Architecture Overview

Three Lambda entry points feed a shared Redis/Valkey cache:

| Lambda | Trigger | Purpose |
|--------|---------|---------|
| integration-platform | SQS queue | Routes messages by SQS `type` attribute: `BookingPolling`, `MakeModelReceived`, `OpcodesPolling`, `DataFeedRequestStart`, `DataFeedStatus` |
| polling-service | CloudWatch cron (every 60s) | Iterates all dealers, enqueues SQS if poll interval expired (default 90s) |
| cdk-webhook | API Gateway POST | Real-time APPT_OPENED / APPT_UPDATED from CDK Drive |

### DMS Platforms (appointment data)

| Platform | DMS Types | How |
|----------|-----------|-----|
| CDK Drive | cdk | Bulk/delta async API + real-time webhooks |
| Motive (aggregator) | autosoft, dealertrack, pbs, reynolds, automate | REST API via Motive proxy |

### Scheduler Platforms (make/model + opcodes)

| Scheduler | Make/Model | Opcodes |
|-----------|------------|---------|
| xTime | ✅ (direct via scheduler API) | ❌ |
| MyKaarma | ✅ | ✅ (only scheduler with opcodes) |
| Dealer FX | ✅ | ❌ |
| UpdatePromise | ✅ | ❌ |

### Redis Cache Structure

| Key Pattern | TTL | What's Stored |
|-------------|-----|---------------|
| `{lskin}:config` | None | Dealer config + polling timestamps (LoaderConfig) |
| `{lskin}:bookings` | 24h | All appointments (admin view) |
| `{lskin}:{phone}:bookings` | 24h | Appointments by customer phone (call-time lookup) |
| `{lskin}:make-model` | 24h | Supported vehicle makes/models |
| `{lskin}:opcodes` | 24h | Service menu items (MyKaarma only) |
| `{lskin}:advisors` | 24h | Active service advisors |
| `{lskin}:advisor:{vin}` | 1 year | VIN→advisor mapping (DataFeedProvider) |
| `pollingConfig` | None | Global polling state |

### Key Constants

| Constant | Value | Source |
|----------|-------|--------|
| Polling interval | 90s default (`loaderConfig.expiration`) | `invokeLskins.ts:34` |
| Config API refresh | Every 4 hours (`POLLING_CONFIG_TIME`) | `updateConfig.ts:13` |
| Appointment retention | 30 days past date (`APPOINTMENT_RETENTION_DAYS`) | `common.ts:23` |
| DataFeedProvider status poll delay | 30s (`DELAY_SECONDS`) | `datafeedprovider.ts:4` |
| DataFeedProvider retry count | 10 retries, 3s delay (`RETRY_COUNT`, `RETRY_DELAY`) | `datafeedprovider.ts:2-3` |
| DataFeedProvider page size | 500 (`MAX_PAGE_SIZE`) | `datafeedprovider.ts:1` |
| DataFeedProvider lookback | 1 day incremental (`DAYS_BACK`), 1 year initial (`YEARS_BACK`) | `datafeedprovider.ts:6-7` |
| DataFeedProvider VIN map TTL | 1 year (`EXPIRE_YEAR`) | `common.ts:20` |
| Business hours for delta | 7am–5pm dealer timezone (`BUSINESS_START_HOUR`/`BUSINESS_END_HOUR`) | `common.ts:28-29` |
| Delta interval | 30 min (`DELTA_INTERVAL_MINUTES`) | `common.ts:27` |
| CDK delta loading | Currently DISABLED (`DELTA_ENABLED = false`) | `common.ts:26` |
| SQS max message size | 900KB (921,600 bytes) | `cdk/index.ts:27` |
| Metrics business hours | 7am–8pm CT (failure metrics only emitted during these hours) | `index.ts:89-91` |
| CloudWatch metrics namespace | `CariPhoneAssist/IntegrationPlatform` | `metrics-emitter.ts:24` |

### SQS Message Types (exact enum values)

| Enum Key | SQS `type` Attribute Value | Handler |
|----------|---------------------------|---------|
| `BOOKINGS_POLLING` | `BookingPolling` | `handleBookingsRecord` → CDK or Motive |
| `MAKE_MODEL_RECEIVED` | `MakeModelReceived` | `handleMakeModel` → CDK or scheduler |
| `OPCODES_POLLING` | `OpcodesPolling` | `handleOpcodesRecord` → MyKaarma only |
| `DATA_FEED_REQUEST_START` | `DataFeedRequestStart` | `handleStartDataFeedRequest` |
| `DATA_FEED_STATUS` | `DataFeedStatus` | `handleDataFeedRequestStatus` |

### DataFeedProvider Delivery Status Values (PascalCase)

`Queued` → `InProgress` → `Ready` | `Error` | `Purged`

### Logger

Uses `@aws-lambda-powertools/logger` with `serviceName: 'integration-platform'`. All logs are **structured JSON**. Key fields:
- `level` — `INFO`, `WARN`, `ERROR`
- `message` — the log message string
- `service` — always `integration-platform`
- Additional context passed as structured objects: `{ error }`, `{ event }`, `{ data }`, `{ normalizedData }`, `{ loaderConfig }`

Log message patterns (from code):
- `"<lskin> - Invoking DMS service"` — polling triggered for dealer
- `"<lskin> - No config found in REDIS"` — missing config (ERROR)
- `"<lskin> - There was an error sending to SQS"` — SQS send failure
- `"<lskin> - Getting make and model from <provider>"` — make/model fetch
- `"<lskin> - Starting <bulk|delta> appointments load"` — CDK load initiated
- `"<lskin> - Retrieved <N> appointments from result"` — CDK load complete
- `"<lskin> - Splitting appointments into <N> batches"` — large CDK response
- `"<lskin> - Sending DataFeedProvider request status"` — DataFeedProvider status queued
- `"<lskin> - DataFeedProvider request status not valid (<status>) dropping request"` — DataFeedProvider failed/expired
- `"<lskin> - Error requesting DataFeedProvider Feed"` — DataFeedProvider API error
- `"Polling cycle failed"` — entire polling cycle crashed
- `"Polling configuration-api data"` — config refresh triggered
- `"There was an error fetching configuration-api"` — config API failure
- `"Dealer configuration not found for lskin: <lskin>"` — Motive handler missing config
- `"Subscription ID not found, returning 200"` — CDK webhook for unknown dealer
- `"Unhandled event type, returning 200"` — CDK webhook unknown event type

## Environments

| Lambda | Prod Log Group | Dev/Staging Log Group |
|--------|---------------|----------------------|
| integration-platform | `/aws/lambda/[product]-integration-platform-production` | `/aws/lambda/[product]-integration-platform-dev-staging` |
| polling-service | `/aws/lambda/[product]-polling-service-production` | `/aws/lambda/[product]-polling-service-dev-staging` |
| cdk-webhook | `/aws/lambda/[product]-cdk-webhook-production` | `/aws/lambda/[product]-cdk-webhook-dev-staging` |
| CDK webhook API | `/aws/apigateway/[product]-cdk-webhook-api-production` | `/aws/apigateway/[product]-cdk-webhook-api-dev-staging` |

> **⚠️ API Gateway logs** (`/aws/apigateway/...`) are access logs — different format from Lambda logs. They show HTTP status codes, latency, request IDs. Use these to verify webhooks are *arriving*, then switch to the Lambda log group for processing details.

**AWS Profiles:** `telephony-prod` (production), `telephony-dev` (dev/staging)

## Query Index

| # | Query | Log Group | Parameters | Use When User Asks... |
|---|-------|-----------|------------|----------------------|
| IP1 | Full Timeline (one dealer) | integration-platform | lskin | "What's happening with data sync for this dealer?" |
| IP2 | Error/Warn Triage | integration-platform | lskin or time range | "Why is this dealer's data stale?" / "Sync errors?" |
| IP3 | SQS Message Trace | integration-platform | message type, lskin | "Are bookings polling?" / "Is make-model syncing?" |
| IP4 | Polling Health Check | polling-service | time range | "Is the poller running?" / "Which dealers aren't being polled?" |
| IP5 | CDK Webhook Events | cdk-webhook | lskin or time range | "Are CDK webhooks arriving?" / "Real-time appointment updates?" |
| IP6 | DataFeedProvider Lifecycle | integration-platform | lskin | "What's happening with DataFeedProvider for this dealer?" |
| IP7 | Bulk Error Scan | integration-platform | time range | "Any integration errors in the last hour?" |
| IP8 | CDK Bulk/Delta Load | integration-platform | lskin | "When was the last full load?" / "CDK sync status?" |
| IP9 | CloudWatch Metrics | CariPhoneAssist/IntegrationPlatform | provider or messageType | "Provider failure rate?" / "Polling cycle health?" |

> **Note:** The codebase uses `lskin` (not `lskinid`) throughout. Query placeholders use `<<LSKINID>>` for clarity, but the actual field name in logs is `lskin`.

---

## Running CloudWatch Insights Queries

Use the AWS CLI. Substitute the correct log group from the Environments table above.

```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[product]-integration-platform-production" \
  # macOS: `date -d` is GNU-only. Use: `date -v-1H +%s`
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string '<QUERY>' \
  --profile telephony-prod

# Then fetch results:
aws logs get-query-results --query-id <QUERY_ID> --profile telephony-prod
```

On Windows (PowerShell):

```powershell
$startTime = [int][double]::Parse((Get-Date (Get-Date).AddHours(-1).ToUniversalTime() -UFormat %s))
$endTime = [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s))

$queryId = aws logs start-query `
  --log-group-name "/aws/lambda/[product]-integration-platform-production" `
  --start-time $startTime --end-time $endTime `
  --query-string '<QUERY>' `
  --profile telephony-prod | ConvertFrom-Json | Select-Object -ExpandProperty queryId

# Wait a few seconds, then:
aws logs get-query-results --query-id $queryId --profile telephony-prod
```

---

## Query IP1: Full Timeline (One Dealer)

Shows all integration-platform log entries for a specific dealer. The logger uses `@aws-lambda-powertools/logger` — all logs are structured JSON with `level`, `message`, `service` fields.

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| parse @message '"service":"*"' as service
| filter @message like /<<LSKINID>>/
| display @timestamp, level, msg, service
| sort @timestamp asc
| limit 500
```

> **Why `@message like`?** The lskin appears in different positions: sometimes in the `message` string as `"<lskin> - Invoking DMS service"`, sometimes in structured context as `"lskin":"<value>"`. A broad `like` catches both.

## Query IP2: Error/Warn Triage

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter level in ['ERROR', 'WARN']
  and @message like /<<LSKINID>>/
| display @timestamp, level, msg
| sort @timestamp asc
| limit 200
```

For bulk error scan (no dealer filter):

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter level = 'ERROR'
| display @timestamp, level, msg
| sort @timestamp desc
| limit 200
```

## Query IP3: SQS Message Trace

Track processing of a specific SQS message type for a dealer. The message type is in the SQS `messageAttributes.type.stringValue`, which appears in the Lambda event log.

```sql
parse @message '"message":"*"' as msg
| parse @message '"level":"*"' as level
| filter @message like /<<LSKINID>>/
  and @message like /<<MESSAGE_TYPE>>/
| display @timestamp, level, msg
| sort @timestamp asc
| limit 200
```

Replace `<<MESSAGE_TYPE>>` with the **exact enum value** (case-sensitive):
- `BookingPolling` — appointment sync
- `MakeModelReceived` — vehicle make/model fetch
- `OpcodesPolling` — service menu (MyKaarma only)
- `DataFeedRequestStart` — initiate DataFeedProvider feed
- `DataFeedStatus` — poll DataFeedProvider feed status

## Query IP4: Polling Health Check

**Log group:** `/aws/lambda/[product]-polling-service-production` (or dev-staging)

Shows polling activity — are polls running on schedule?

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter @message like /Invoking DMS service|No config found|error sending to SQS|error saving config|Polling configuration-api|Polling cycle failed/
| display @timestamp, level, msg
| sort @timestamp desc
| limit 200
```

For a specific dealer:

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter @message like /<<LSKINID>>/
| display @timestamp, level, msg
| sort @timestamp desc
| limit 100
```

**Interpreting results:**
- Healthy: dealer appears every ~90s with `"Invoking DMS service"` messages
- Stale: dealer not appearing → check if config has valid `expiration`, or if poller is erroring before reaching this dealer
- Missing config: `"<lskin> - No config found in REDIS"` → config API refresh may have failed
- SQS failure: `"<lskin> - There was an error sending to SQS"` → check SQS queue health
- Skipped: dealer not appearing → `shouldInvokeLskin()` returned false (poll interval not expired)

## Query IP5: CDK Webhook Events

**Log group:** `/aws/lambda/[product]-cdk-webhook-production` (or dev-staging)

The CDK webhook handler logs the full event on entry: `"Processing event"`. Event types come from the `fortellis-event-id` header and the body's `eventType` field.

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter @message like /<<LSKINID>>/
| display @timestamp, level, msg
| sort @timestamp desc
| limit 100
```

For all webhook activity (no dealer filter):

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| parse @message '"statusCode":*' as statusCode
| filter msg = 'Processing event' or level in ['ERROR', 'WARN']
| display @timestamp, level, msg, statusCode
| sort @timestamp desc
| limit 100
```

**Expected patterns:**
- `"Processing event"` — webhook received (INFO, logs full event)
- `"Subscription ID not found, returning 200"` — unknown department-id (INFO, not an error)
- `"Unhandled event type, returning 200"` — not APPT_OPENED/APPT_UPDATED (WARN)
- `"Missing required CDK headers"` — 400 response
- `"Invalid token"` — JWT validation failed, 401 response
- `"Webhook processing error"` — 500 response

**Expected event types in body:** `APPT_OPENED`, `APPT_UPDATED`

**CDK webhook data flow:** API Gateway → cdk-webhook Lambda → validates JWT + headers → queues to SQS as `BookingPolling` with `cdkAsyncData` field → main Lambda `handleCdkBookings` detects `data.cdkAsyncData` and processes directly (no CDK API call needed, data already in body). Failed webhook events ARE retried via SQS partial batch failure (unlike polling messages which are not retried).

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present the CloudWatch log timeline in chronological order
2. Highlight polling gaps (>2× expected interval)
3. For DataFeedProvider: show the full lifecycle state (which step is it on?)
4. Do NOT interpret data freshness as "good" or "bad" — present timestamps, let user assess
5. After presenting, ask: "What stands out? Want to drill into any specific area?"

---

> **For Queries IP6-IP9 (DataFeedProvider lifecycle, bulk error scan, CDK load trace, CloudWatch metrics), LoaderConfig schema, booking eligibility, investigation scenarios, and report template → see `references/integration-platform-reference.md`**

