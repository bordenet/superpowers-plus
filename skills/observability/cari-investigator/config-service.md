---
name: config-service
parent: cari-investigator
description: Config DB queries for dealer lookup — account setup, DMS/scheduler integration, feature flags, prompt configuration.
---

# Config-Service Sub-Skill

> **Database:** config-service Postgres (RDS)
> **Primary Key:** lskinid (dealership identifier)
> **Database Name:** config-prod (production) / config-dev (dev) / config-staging (staging)
> **Guardrails:** Follow `references/aws-query-guardrails.md` — read-only, 30s timeout, EXPLAIN before execute

## Database Schema

| Table | Keyed By | Storage Pattern | Purpose |
|-------|----------|----------------|---------|
| account | lskinid (PK) | Columns + JSONB | Core dealership info |
| scheduler_configs | account_id -> lskinid | JSONB config blob | Service scheduler AI config |
| receptionist_configs | account_id -> lskinid | JSONB config blob | Receptionist AI config |
| acquisition_configs | account_id -> lskinid | JSONB config blob | SellMyRide acquisition AI config |

All config tables use versioning: is_active = true marks the current config, ORDER BY created_at DESC LIMIT 1 gets the latest.

## SQL Query Templates

### 1. Full Account + All Configs

```sql
SELECT
  a.lskinid, a.name, a.time_zone, a.language_support, a.test_account,
  a.dealership_hours, a.dealership_locations, a.holiday_dates,
  sc.config AS scheduler_config,
  rc.config AS receptionist_config,
  ac.config AS acquisition_config
FROM account a
LEFT JOIN scheduler_configs sc ON sc.account_id = a.lskinid AND sc.is_active = true
LEFT JOIN receptionist_configs rc ON rc.account_id = a.lskinid AND rc.is_active = true
LEFT JOIN acquisition_configs ac ON ac.account_id = a.lskinid AND ac.is_active = true
WHERE a.lskinid = :lskinid;
```

### 2. Quick Status Check (Active/Inactive + Account Type)

```sql
SELECT
  a.lskinid, a.name, a.test_account,
  sc.config->>'active' AS scheduler_active,
  sc.config->'dms'->>'type' AS dms_type,
  sc.config->'scheduler'->>'type' AS scheduler_type,
  rc.config->>'active' AS receptionist_active,
  ac.config->>'active' AS acquisition_active
FROM account a
LEFT JOIN scheduler_configs sc ON sc.account_id = a.lskinid AND sc.is_active = true
LEFT JOIN receptionist_configs rc ON rc.account_id = a.lskinid AND rc.is_active = true
LEFT JOIN acquisition_configs ac ON ac.account_id = a.lskinid AND ac.is_active = true
WHERE a.lskinid = :lskinid;
```

### 3. Individual Config Details

```sql
-- Scheduler
SELECT config FROM scheduler_configs
WHERE account_id = :lskinid AND is_active = true ORDER BY created_at DESC LIMIT 1;

-- Receptionist
SELECT config FROM receptionist_configs
WHERE account_id = :lskinid AND is_active = true ORDER BY created_at DESC LIMIT 1;

-- Acquisition
SELECT config FROM acquisition_configs
WHERE account_id = :lskinid AND is_active = true ORDER BY created_at DESC LIMIT 1;
```

### 4. Lookup by SellMyRide Store ID

```sql
SELECT a.lskinid, a.name, ac.config
FROM acquisition_configs ac
JOIN account a ON a.lskinid = ac.account_id
WHERE ac.is_active = true
  AND ac.config->>'sellmyrideStoreId' = '<storeId>'
  AND (ac.config->>'active')::boolean = true
ORDER BY ac.created_at DESC LIMIT 1;
```

### 5. Config History (previous versions)

```sql
SELECT id, account_id, is_active, created_at, updated_at, config->>'active' AS active_flag
FROM scheduler_configs WHERE account_id = :lskinid ORDER BY created_at DESC LIMIT 10;
```
## Interpreting Results

### DMS vs Scheduler Account Type

| Condition | Account Type | Appointment Routing |
|-----------|-------------|-------------------|
| scheduler_type IS NULL | DMS-only | Posts directly to DMS API |
| scheduler_type = xtime | DMS + xtime | Posts to xtime scheduler |

**Note:** xtime dealers may have 0 schedules, 0 lanes, and 0 opCodes locally. This is normal — xtime manages availability and services externally. Only DMS-only and some other scheduler types define local schedules/opCodes.
| scheduler_type = mykaarma | DMS + MyKaarma | Posts to MyKaarma |
| scheduler_type = dealer-fx | DMS + Dealer-FX | Posts to Dealer-FX |
| scheduler_type = update-promise | DMS + UpdatePromise | Posts to UpdatePromise |
| scheduler_type = tekion | DMS + Tekion | Posts to Tekion |

### DMS Types

dms.type identifies the dealership management system: autosoft, reynolds, dealertrack, automate, cdk, pbs, dominion, quorum

**CDK special case:** CDK accounts require laborType on opCodes (C, CR, W, INT). Missing laborType = broken appointments.

### Active Status

Each config has an independent active boolean in its JSONB:
- scheduler_config->>'active' -- Scheduler AI answering calls?
- receptionist_config->>'active' -- Receptionist AI answering calls?
- acquisition_config->>'active' -- Acquisition (SellMyRide) AI active?

A dealer can have any combination active.

## Schema Quick Reference

### Account Fields
lskinid (int PK), name, time_zone (IANA), language_support (ENGLISH_ONLY / SPANISH_ENGLISH / FRENCH_ENGLISH / TRILINGUAL), test_account (bool), dealership_hours (JSONB array: department name + day-of-week + time ranges), dealership_locations (JSONB array: name/address/city/state/zip), holiday_dates (JSONB array: YYYY-MM-DD strings)

### Scheduler Config Key Fields (JSONB)
active, agentName, voice_en/es/fr, oem[], dms (code, type, serviceDepartmentId, customerDepartmentId), scheduler (type, code, departmentId -- nullable), greeting, twoPartyConsent, schedules[] (name, availability windows, intervals), lanes[] (name, priority, scheduleName), opCodes[] (code, description, price, duration, lane, slotCount, laborType, restrictions), advisors[] (dmsId, name, oem, lanes, profileKeys, rotationStartDate, ptoDates), advisorProfiles[], transferExtensions[], transportation[] (Waiter/Shuttle/DropOff/Loaner/MobileService/PickupRequest/Valet/Rental), vehicles[] (make/model/year restrictions), recall (bool), previousAdvisor (bool), upsells[]

### Receptionist Config Key Fields (JSONB)
active, agentName, voice_en/es/fr, greeting, twoPartyConsent, transferToScheduler (All/During Hours/After Hours/Never), humanRequestStrategy (immediate/attempt_assistance/persistent), agentLines (bool), agentProfileId, Car Wars IDs (ghostBridgeId, abandonedId, hangupId, noTransferId, schedulerExtId, silentCaller, spamLikely, generalInquiry), transferExtensions[] (name, number, description, type, timeoutSeconds, active, warmTransfer, dealershipHoursName, collectName, fallbackConfig, dnisId, shares, reviewService, reviewSales)

### Acquisition Config Key Fields (JSONB)
active, agentName, voice_en/es/fr, greeting, twoPartyConsent, inboundLine, outboundLine, escalationPhoneNumber, sellmyrideStoreId, dealershipName, friendlyName (CNAM), address, dealershipPhoneNumber, timezone, businessHours (mon-sun open/close or null), cadenceInitialDelayMinutes, cadenceSteps[] (type: text/call, delayHours), alertPhoneNumbers[], alertEmailAddresses[], alertTriggers (onBooking, onReschedule, onCancellation, onDecline, onDnc, onEscalation, onExhausted), transferExtensions[]

## Common Investigation Scenarios

### "Is this dealer set up correctly?"
1. Run Query 2 -- verify active flags, DMS type, scheduler type
2. Check test_account (fakes appointments in prod if true)
3. Verify dms.code and scheduler.code are populated

### "Why can't this dealer book appointments?"
1. Run Query 2 -- is scheduler_active true?
2. Run Query 3 (scheduler) -- do opCodes exist? Are schedules configured with availability?
3. If CDK: verify all opCodes have laborType
4. Check transferExtensions for valid 10-digit phone numbers

### "What changed in this dealer's config?"
1. Run Query 5 (Config History) -- see all versions with timestamps
2. Pull the two most recent configs and diff them

## Presentation Rules

> **Use the report template selected in Step 5** — see `references/report-templates.md`. Fill in the sections relevant to this sub-skill. If no template was selected, adapt to the user's request.

1. Present raw query output first
2. For JSONB fields (scheduler config, receptionist config): format as readable key-value pairs, not raw JSON
3. Highlight any `is_active = false` or `test_account = true` flags
4. Do NOT interpret config values — present what's there, let the user assess
5. After presenting, ask: "What stands out? Want to drill into any specific config?"
