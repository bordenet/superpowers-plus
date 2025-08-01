---
name: field-rename-verification
source: superpowers-plus
triggers: ["rename this field", "change the API contract", "refactor this type across services", "update field name from X to Y"]
description: Use when renaming fields, changing API contracts, or refactoring data models across multiple services. Prevents incomplete dependency analysis — the #1 source of production incidents from "complete" work. Requires tracing READ → STORE → PASS paths.
---

# Field Rename Verification

## Overview

Field renames and API contract changes are the #1 source of production incidents from "complete" work that wasn't actually complete.

**Core principle:** Trace the FULL data flow, not just the obvious touchpoints.

**Incident that created this skill:** PROJ-XXX (Feb 2026) - Renamed `trackingLine` to `inboundLine`/`outboundLine` across 6 PRs, but missed the telephony client adapter that actually calls voice-service. Quality gates (lint, typecheck, tests) all passed because each service was internally consistent.

## The Iron Law

```
NO FIELD RENAME IS COMPLETE UNTIL YOU VERIFY EVERY PATH:
READ → STORE → PASS TO OTHER SERVICES
```

If you only traced READ and STORE, you missed PASS.

## The Three Paths

Every field has THREE data flow paths that must be traced:

| Path | Description | Example |
|------|-------------|---------|
| **READ** | Where the field is read FROM | Config endpoint, database query |
| **STORE** | Where the field is written TO | Database insert, cache storage |
| **PASS** | Where the field is sent TO ANOTHER SERVICE | HTTP client, message queue, event payload |

**The PROJ-XXX mistake:** Traced READ (settings-service → post-lead.ts) and STORE (lead table), but missed PASS (telephony-client.adapter → voice-service).

## Pre-Rename Checklist

BEFORE claiming a field rename is complete:

### 1. Grep Exhaustively

```bash
# Search ALL affected repos for the old field name
grep -rn "oldFieldName" --include="*.ts" --include="*.tsx" --include="*.js" repo1/ repo2/ repo3/

# Also search for the CamelCase, snake_case, and UPPER_CASE variants
grep -rn "old_field_name\|OLD_FIELD_NAME\|OldFieldName" --include="*.ts" repo/
```

### 2. Trace Every Service Boundary

For each service that handles this field:

| Question | If Yes → Check |
|----------|----------------|
| Does this service call another service? | HTTP clients, SDK calls, API adapters |
| Does this service emit events? | Event payloads, message queue producers |
| Does this service store data? | Database schemas, cache keys |
| Does this service expose an API? | Request/response types, OpenAPI specs |
| Does this service have NPM packages? | Published type definitions |

### 3. Verify Type Definitions

```bash
# Check if old types are still published
grep -rn "oldFieldName" node_modules/@yourorg/*/dist/*.d.ts
```

If old types exist in node_modules, consumers may compile against wrong contract.

### 4. Integration Test the Full Path

Unit tests pass but integration fails because:
- Service A sends `oldFieldName`
- Service B expects `newFieldName`
- Both services' unit tests pass (internally consistent)
- E2E test fails (contract mismatch)

**REQUIRED:** Run at least one test that crosses the service boundary you changed.

## Common Failure Patterns

| Pattern | What Gets Missed | Prevention |
|---------|------------------|------------|
| "I updated the route handler" | HTTP client that calls the route | Trace callers, not just callees |
| "I updated the type definition" | Runtime code still uses old name | Grep before commit |
| "Tests pass" | Tests mock the boundary, don't test it | Add integration test |
| "Schema is updated" | Transform/adapter layer unchanged | Check every layer |
| "Config reads correctly" | Config is passed to another service wrong | Trace PASS path |

## Service Boundary Verification

For cross-service field renames, verify at BOTH ends:

```
Service A (sender)        Service B (receiver)
─────────────────         ────────────────────
HTTP client sends    →    Route handler expects
message.fieldName         body.fieldName
     ↓                         ↓
   MUST                      MUST
   MATCH                     MATCH
```

**PROJ-XXX failure:**
- voice-service (receiver) expected `inboundLine`/`outboundLine` ✅
- acquisition-service (sender) still sent `trackingLine` ❌

## Red Flags - STOP

If you find yourself thinking:
- "The database column uses the old name, that's fine" → Maybe, but verify callers
- "I just need to update the schema" → No, trace the full flow
- "The tests pass so it's done" → Tests may not cross the boundary
- "I updated the obvious files" → The non-obvious ones break production
- "It's just a field rename" → Field renames touch everything

## The Gate Function

```
BEFORE claiming a field rename is complete:

1. GREP: Run exhaustive search for old field name in ALL affected repos
2. LIST: Enumerate every service boundary the field crosses
3. TRACE: For each boundary, verify BOTH sender and receiver
4. TEST: Run at least one integration test crossing each boundary
5. ONLY THEN: Claim the rename is complete

Skip any step = incomplete work
```

## Related Skills

- `verification-before-completion` - General verification discipline
- `systematic-debugging` - When the field mismatch causes runtime errors
- `link-verification` - For verifying API endpoint URLs still exist

