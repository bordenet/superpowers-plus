---
name: cari-data-flow-verification
source: superpowers-cari
triggers: ["scheduler config change", "opCode change", "CDK integration", "appointment booking change", "add field to config-service", "CARI service scheduler"]
description: CallBox-specific data flow verification for Cari Scheduler changes. Encodes the known "chain of custody" for scheduler configuration data through all services. MUST invoke when modifying scheduler.ts, cari_config.js, or post-*-appointment.ts.
summary: "Use when: modifying scheduler.ts, cari_config.js, or post-*-appointment.ts."
coordination:
  group: cari
  order: 1
  requires: []
  enables: []
  escalates_to: ['cari-investigator']
  internal: false
---

# Cari Data Flow Verification

> **Source:** `superpowers-cari`
> **Created:** 2026-03-05 after DELTA-1216 incident

## The Problem This Skill Solves

**Incident:** DELTA-1216 — Added `laborType` field to Cari scheduler configuration. Implemented in 3 places, missed the 4th. Feature would have been completely broken in production.

**What Was Missed:** `agent-api/src/integrations/post-appointment/index.ts` constructs `serviceLaborScheduling` from opCodes but wasn't passing `laborType` through.

## Cari Scheduler Data Flow Chain

`scheduler.ts` (schema) → `cariConfig/` (admin UI) → config-service API → **⚠️ `post-appointment/index.ts`** (router, constructs `serviceLaborScheduling` — MOST LIKELY TO BE MISSED) → `post-*-appointment.ts` (DMS integration) → CDK DMS API

## Mandatory Checklist for Scheduler Changes

When adding or modifying ANY field in scheduler configuration:

### Layer 1: Schema Definition
- [ ] `Cari/config-service/src/validators/scheduler.ts`
  - Added field to the appropriate `z.object()`
  - Set appropriate default value with `.default()`
  - Exported type if needed

### Layer 2: Admin UI
- [ ] `hackerfarm-core/admin/cariConfig/index.cfm`
  - Added column header `<th>` if table field
  - Added input/select element in row template
  - Added `data-cy` attributes for testing

- [ ] `hackerfarm-core/admin/cariConfig/cari_config.js`
  - Updated CSV export to include new field
  - Updated CSV import to parse new field
  - Set default value when importing old CSVs (backward compatibility)
  - Validate field values on import

### Layer 3: Type Definitions
- [ ] `Cari/agent-api/src/integrations/helpers/types.ts`
  - Added field to appropriate interface (e.g., `CdkAppointmentAppointment`)

### Layer 4: Router (⚠️ THE CRITICAL ONE)
- [ ] `Cari/agent-api/src/integrations/post-appointment/index.ts`
  - **THIS IS WHERE DELTA-1216 WAS MISSED**
  - The `serviceLaborScheduling` construction at line ~123
  - Must map `op.newField` through to the output object

### Layer 5: Integration Logic
- [ ] `Cari/agent-api/src/integrations/post-appointment/post-*-appointment.ts`
  - CDK: `post-cdk-appointment.ts`
  - XTime: `post-xtime-appointment.ts`
  - MyKaarma: `post-mykaarma-appointment.ts`
  - DealerFX: `post-dealerfx-appointment.ts`
  - UpdatePromise: `post-updatepromise-appointment.ts`

### Verification Commands

```bash
# 1. Find all references to the new field
grep -rn "newFieldName" --include="*.ts" --include="*.js" --include="*.cfm" Cari/ hackerfarm-core/

# 2. Find all serviceLaborScheduling constructions (for scheduler fields)
grep -rn "serviceLaborScheduling" --include="*.ts" Cari/agent-api/src/

# 3. Find all opCode consumers
grep -rn "opCodes\\.map\|opCodes\\.forEach" --include="*.ts" Cari/agent-api/src/
```

## Why the Router Gets Missed

`index.ts` is a pass-through — TS doesn't error on missing optional fields, tests mock the output, and it "looks complete" without the new field. **Fix:** add `newFieldName: op.newFieldName` to the `serviceLaborScheduling` map at line ~123.

## DMS-Specific Considerations

| DMS | Router Path | Integration File | Notes |
|-----|-------------|------------------|-------|
| CDK | Lines 107-145 | post-cdk-appointment.ts | Uses `serviceLaborScheduling` |
| XTime | Lines 63-89 | post-xtime-appointment.ts | Different payload structure |
| MyKaarma | Line 92-94 | post-mykaarma-appointment.ts | Passes raw params |
| DealerFX | Lines 101-104 | post-dealerfx-appointment.ts | Passes raw params |
| UpdatePromise | Lines 96-98 | post-updatepromise-appointment.ts | Passes raw params |

**Note:** CDK and XTime construct `serviceLaborScheduling` in the router. MyKaarma/DealerFX/UpdatePromise pass `sanitizedParams` directly.

## Pre-PR Checklist

Before creating a PR for scheduler changes:

1. [ ] All 5 layers checked and modified
2. [ ] Grep verification run for new field name
3. [ ] Unit tests for integration logic
4. [ ] E2E tests or manual testing instructions
5. [ ] CSV import/export tested for new field
6. [ ] Backward compatibility verified (old configs still work)


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Partial path trace | Declares verified after 1 hop | Trace full: DMS -> IP -> Redis -> Cari |
| Config vs runtime confusion | Reports false mismatch | Check static config AND runtime overrides |

## Companion Skills

- `engineering-rigor` - Generic multi-component verification
- `field-rename-verification` - When renaming existing fields
- `vitest-testing-patterns` - For writing the unit tests


## When to Use

- Verifying data flows between Cari and downstream systems (Humanatic, HCAT)
- Debugging tagging discrepancies or missing call data
- Validating DNIS/extension-form mappings

## Common Failure Modes

- **Wrong join condition:** Using dnisfunctionid instead of tagid for DNIS lookups
- **Stale mappings:** Verifying against cached DNIS/extension data instead of live database
- **Missing edge cases:** Checking happy-path flows but skipping transfer and overflow scenarios
