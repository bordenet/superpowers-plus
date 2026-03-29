---
name: integration-platform-reference
parent: integration-platform
description: LoaderConfig schema, booking eligibility, investigation scenarios, and report template for integration-platform investigations.
---

# Integration Platform Reference

> **Loaded from:** `integration-platform.md` → this file for advanced queries (IP6-IP9), LoaderConfig details, investigation playbooks, and report templates.

## Query IP6: DataFeedProvider Lifecycle

Traces the async state machine: feed request → status polling → data processing.

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter @message like /<<LSKINID>>/
  and @message like /[Aa]uthenticom|feed|Feed|advisor|VIN/
| display @timestamp, level, msg
| sort @timestamp asc
| limit 200
```

**Expected lifecycle sequence (from code):**
1. `"Retrieving DataFeedProvider Feed last updated since"` — polling cron discovers updated dealers
2. `"<lskin> - Sending DataFeedProvider request"` — SQS message queued for this dealer
3. `"<lskin> - Sending DataFeedProvider request status"` — feed request sent, status check queued (30s delay)
4. Status polling loop:
   - `Queued` / `InProgress` → re-queue with 30s delay, log `"Sending DataFeedProvider request status"` again
   - `Ready` → paginate results (500/page), build VIN→advisor map, store in Redis (1yr TTL)
   - `Error` / `Purged` → `"<lskin> - DataFeedProvider request status not valid (<status>) dropping request"` (WARN)
5. `"<lskin> - Error requesting DataFeedProvider Feed"` — API call failed (ERROR)
6. `"Exceeded retries: <url>"` — all 10 retries exhausted (ERROR)

## Query IP7: Bulk Error Scan

Find all integration errors across all dealers in a time window.

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter level = 'ERROR'
| stats count() as errors by msg
| sort errors desc
| limit 30
```

## Query IP8: CDK Bulk/Delta Load Trace

Track CDK async bulk loading for a dealer (POST → poll status → fetch results → split batches).

```sql
parse @message '"level":"*"' as level
| parse @message '"message":"*"' as msg
| filter @message like /<<LSKINID>>/
  and @message like /bulk|delta|Starting|Retrieved|Splitting|appointments|skipping load|Processing/
| display @timestamp, level, msg
| sort @timestamp asc
| limit 200
```

**Expected CDK load sequence (from `cdk/index.ts`):**
1. `"<lskin> - Starting bulk appointments load (business hours check: true)"` — load initiated
2. CDK returns status link → queued for polling with `checkStatusAfterSeconds` delay
3. Status polling: `"<lskin> - Processing bulk appointment status response"` — checking CDK job status
4. On complete: `"<lskin> - Retrieved <N> appointments from result"` — data fetched
5. If large: `"<lskin> - Splitting appointments into <N> batches to fit SQS limit"` — >900KB response
6. Per batch: `"<lskin> - Sent batch <i>/<total> to SQS (<N> appointments, <bytes> bytes)"`
7. `"<lskin> - normalizedData:"` — data normalized and ready for Redis
8. Skip: `"<lskin> - Delta processing disabled, skipping load"` — already has full load, delta disabled

**Note:** CDK delta loading is currently **disabled** (`DELTA_ENABLED = false`). Only bulk (full) loads run.

## Query IP9: CloudWatch Metrics Query

**Namespace:** `CariPhoneAssist/IntegrationPlatform`

```bash
aws cloudwatch get-metric-statistics \
  --namespace "CariPhoneAssist/IntegrationPlatform" \
  --metric-name "ProviderRequestFailure" \
  --dimensions Name=provider,Value=<<PROVIDER>> \
  # macOS: `date -d` is GNU-only. Use: `date -v-1H -u +%Y-%m-%dT%H:%M:%SZ`
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Sum \
  --profile telephony-prod
```

**Key metric names:**
| Metric | What It Measures |
|--------|-----------------|
| `ProviderRequestSuccess` / `ProviderRequestFailure` | Per-provider API call results |
| `ProviderRequestLatency` / `ProviderRequestTimeout` | Per-provider latency and timeouts |
| `MessageProcessingSuccess` / `MessageProcessingFailure` | SQS processing by messageType |
| `WebhookRequestReceived` / `WebhookProcessingSuccess` / `WebhookProcessingFailure` | CDK webhook results |
| `PollingCycleSuccess` / `PollingCycleFailure` / `PollingLskinsInvoked` | Polling cycle health |
| `PollingConfigUpdateSuccess` / `PollingConfigUpdateFailure` | Config API refresh |
| `CacheOperationSuccess` / `CacheOperationFailure` / `CacheConnectionFailure` | Redis health |
| `DataFeedRequestStarted` / `DataFeedStatusCheck` / `DataFeedReceived` | DataFeedProvider lifecycle |
| `DataVinMappingsStored` / `DataFeedFailure` | DataFeedProvider results |

**Note:** Failure metrics only emitted during business hours (7am–8pm CT).

---

## LoaderConfig Reference ({lskin}:config)

The per-dealer config record stored in Redis. Key fields for investigation:

### Identity & Routing (from Config API, refreshed every 4 hours)
| Field | Purpose |
|-------|---------|
| `lskin` | Dealer ID, primary key |
| `platform` | Derived: "cdk", "motive", or "scheduler" |
| `dmsType` | Specific DMS/scheduler type |
| `dealerCode` | Dealer's ID at the provider (Subscription-Id for CDK, x-dealer-code for Motive) |
| `timeZone` | IANA timezone for business-hours checks |
| `serviceDepartmentId` | CDK: service department for appointment queries |
| `customerDepartmentId` | CDK: customer-facing department filtering |
| `schedulerDepartmentId` | Scheduler providers: department for make/model and opcode queries |

### Polling Timestamps (set after successful operations)
| Field | Purpose |
|-------|---------|
| `lastInvocation` | Last bookings poll; compared against `expiration` |
| `lastFullLoad` | Last bulk appointment sync |
| `lastDeltaLoad` | Last delta sync (determines incremental window) |
| `lastCdkMakeModelInvocation` | CDK-only; triggers daily make/model refresh |
| `lastDataFeedLoad` | Last DataFeedProvider feed; determines date range for next request |
| `lastOpcodeInvocation` | Last opcode fetch (MyKaarma only) |
| `expiration` | Seconds between polls (default 90) |

### Feature Flags
| Field | Purpose |
|-------|---------|
| `previousAdvisorEnabled` | Enables DataFeedProvider VIN→advisor integration |
| `staleOpcodeDays` | Purge opcodes unseen for N days (default 60) |
| `staleAdvisorDays` | Purge advisors unseen for N days (default 30) |
| `disabled` | (on DealerConfig) If true, dealer may be excluded from processing |

### Booking Eligibility by Platform

<EXTREMELY_IMPORTANT>
Not all platforms get `BookingPolling` SQS messages. From `invokeLskins.ts`:

```typescript
function shouldSendSqsMessage(loaderConfig: LoaderConfig): boolean {
  return loaderConfig.dmsType === 'cdk' || loaderConfig.platform !== 'scheduler'
}
```

| Platform | Gets BookingPolling? | Gets Make/Model? | Gets Opcodes? |
|----------|---------------------|------------------|---------------|
| cdk | ✅ Yes | ✅ (CDK API) | ❌ |
| motive (autosoft, dealertrack, pbs, reynolds, automate) | ✅ Yes | ❌ (no scheduler) | ❌ |
| scheduler (xtime, mykaarma, dealer-fx, update-promise) | ❌ **No** | ✅ (scheduler API) | ✅ MyKaarma only |

**If a dealer is scheduler-only, searching for `BookingPolling` will return nothing. This is expected — schedulers don't provide appointment data through this platform.**
</EXTREMELY_IMPORTANT>

---

## Common Investigation Scenarios

### "This dealer's appointment data is stale"
1. **IP4** (Polling Health) — look for `"<lskin> - Invoking DMS service"` messages. If absent, poller isn't reaching this dealer.
2. **IP3** (SQS Trace) with `BookingPolling` — is the message being processed by the main Lambda?
3. **IP2** (Error Triage) — any errors? Common: `"No config found in REDIS"`, `"error sending to SQS"`, `"Unknown platform"`
4. For CDK dealers: **IP8** — check if bulk load completed. Look for `"Retrieved <N> appointments from result"`.
5. For Motive dealers: check if `"Dealer configuration not found for lskin"` (WARN) — config may have been purged as stale.
6. Cross-reference with `config-service.md` Query 2 — is the dealer active? What dmsType?

### "CDK webhooks aren't updating appointments"
1. **IP5** (CDK Webhooks) — look for `"Processing event"` entries. If absent, webhooks aren't arriving.
2. Check for `"Missing required CDK headers"` (400) or `"Invalid token"` (401) — auth issues.
3. Check for `"Subscription ID not found, returning 200"` — the `department-id` header doesn't match any dealer's `serviceDepartmentId` in Redis.
4. If events arriving but data stale → **IP2** for processing errors in the main Lambda (webhook queues to SQS as `BookingPolling` with `cdkAsyncData`).

### "DataFeedProvider advisor mapping isn't working"
1. **IP6** (DataFeedProvider Lifecycle) — trace the full feed request → status → data flow
2. Look for status values: `Queued`, `InProgress` (still processing), `Ready` (should have data), `Error`/`Purged` (dropped)
3. Check for `"Exceeded retries"` — all 10 retries exhausted on data fetch
4. Check `previousAdvisorEnabled` flag in LoaderConfig — if `false`, DataFeedProvider is skipped entirely for this dealer
5. Check `"Missing datafeedprovider secrets"` — credentials not configured in Secrets Manager

### "Make/model list is empty or wrong"
1. **IP3** (SQS Trace) with `MakeModelReceived` — is the message being processed?
2. **IP2** — any errors? Look for `"Getting make and model from <provider>"` followed by errors.
3. Check dmsType routing: CDK → `handleCdkMakeModel`, xTime/DFX/MyKaarma/UpdatePromise → scheduler-specific handlers
4. **IP9** — check `ProviderRequestFailure` metric with dimension `provider=<scheduler-type>`

### "OpCodes not syncing"
1. Only MyKaarma supports opcode syncing — verify `dmsType = 'mykaarma'` first (config-service.md)
2. **IP3** with `OpcodesPolling` — is the message being processed?
3. If dmsType is not `mykaarma`, the handler throws `"Unsupported scheduler type"` — opcodes are N/A for this dealer
4. Check `lastOpcodeInvocation` and `staleOpcodeDays` in LoaderConfig

### "Config API refresh failing"
1. **IP4** (Polling Health) — look for `"Polling configuration-api data"` (refresh triggered) and `"There was an error fetching configuration-api"` (failure)
2. **IP9** — check `PollingConfigUpdateFailure` metric
3. If config refresh fails, stale dealers won't be purged and new dealers won't be added



---

## Output: Integration Platform Report (required)

When this skill is used, return a short report in this format:

```markdown
## Integration Platform Report
- **Environment:** <prod|dev|staging>
- **Dealer:** lskin=<id>
- **Platform:** <cdk|motive|scheduler> (dmsType=<type>)
- **Log window:** <start..end searched>

### Polling Status (inferred from logs — Redis state not directly visible)
- Last poll: <timestamp from "Invoking DMS service" log> | Interval: <N>s
- Last full load: <timestamp from "Starting bulk appointments load" log>
- Last delta load: N/A (delta DISABLED for CDK)

### Recent Activity
| Timestamp | Message Type | Status | Notes |
|-----------|-------------|--------|-------|
| <ts> | BookingPolling | success/error | ... |

### Errors / Warnings (last N hours)
| Timestamp | Level | Message |
|-----------|-------|---------|
| <ts> | ERROR/WARN | <message> |

### Cache Freshness Assessment
| Cache Key | Expected Refresh | Last Seen Update | Status |
|-----------|-----------------|------------------|--------|
| bookings | Every 90s | <ts> | ✅/⚠️ |
| make-model | Daily | <ts> | ✅/⚠️ |
| opcodes | Daily (MyKaarma only) | <ts> | ✅/⚠️/N/A |
| advisors | Daily (DataFeedProvider) | <ts> | ✅/⚠️/N/A |

### Next Steps (cross-correlation)
- Run `config-service.md` Query 2 to verify dealer config and dmsType.
- Run `agent-api.md` Query 5 to check if agent-side integration calls are failing.
```

## Presentation Rules

1. Present the report in the format above
2. Highlight any polling gaps (>2× expected interval)
3. For DataFeedProvider: show the full lifecycle state (which step is it on?)
4. Do NOT interpret data freshness as "good" or "bad" — present timestamps, let user assess
5. After presenting, ask: "What stands out? Want to drill into any specific area?"
