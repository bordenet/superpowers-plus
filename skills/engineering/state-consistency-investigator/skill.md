---
name: state-consistency-investigator
source: superpowers-plus
description: >
  Specialized investigator for diagnosing state consistency failures: replication lag,
  cache staleness, event ordering issues, cross-service data divergence, and eventual
  consistency bugs. Dispatched by debug-conductor.
triggers: []
anti_triggers: []
coordination:
  group: engineering
  order: 10
  requires: ["debug-conductor"]
  enables: []
  escalates_to: ["debug-conductor"]
  internal: true
composition:
  produces: [state-evidence, consistency-analysis, replication-assessment]
  consumes: [incident-description, affected-entities, service-boundaries, consistency-expectations]
  capabilities: [cross-source-comparison, replication-lag-detection, event-ordering-audit]
  priority: 2
  optional: true
  requires_all: false
---

# State Consistency Investigator

> **Role:** Diagnose state consistency failures across services: stale reads, replication lag, event ordering, cache-vs-source divergence.
> **Dispatched by:** `debug-conductor` — never invoked directly by user.
> **Evidence type:** `StateEvidence` (see `skills/_shared/evidence-schema.md`)

## When to Use

Dispatched by `debug-conductor` when the incident involves data inconsistency — stale reads, replication lag, cache staleness, event reordering, or cross-service state divergence.

## Investigation Protocol

### Step 1: Identify the Consistency Boundary

1. Which data entities are affected? (user profiles, order records, account settings)
2. Which services read this data? (source of truth vs. replicas vs. caches)
3. What consistency model is expected? (strong, eventual, read-after-write)
4. What propagation paths exist? (DB replication, event bus, cache invalidation, API sync)

### Step 2: Cross-Source Comparison

For each affected entity:

1. Query the **source of truth** (primary DB) — what's the current value?
2. Query each **consumer** (replica DB, cache, downstream service) — what do they see?
3. Record discrepancies with timestamps:

```json
{
  "inconsistencies": [
    {
      "entity": "customer:C-1001:phone",
      "sourceA": "primary-db",
      "sourceB": "replica-db",
      "valueA": "+1-555-0199",
      "valueB": "+1-555-0100"
    }
  ]
}
```

### Step 3: Replication Lag Assessment

1. Measure current replication lag (primary → replica)
2. Check historical lag: is it steady or spiking?
3. Compare lag SLA vs. actual:
   - Average within SLA but P99 outside? (intermittent issue)
   - Lag correlated with load patterns? (peak hours)
4. Check if lag explains the observed inconsistency window

### Step 4: Event Ordering Audit

1. Inspect the event/message bus for the affected entity
2. Verify events were published in correct order
3. Verify events were consumed in correct order
4. Check for:
   - Duplicate events (at-least-once delivery)
   - Lost events (check consumer acknowledgment)
   - Reordered events (partition key mismatch, consumer parallelism)

### Step 5: Cache Behavior Analysis

1. Check cache TTL vs. invalidation timing
2. Trace the invalidation flow: event received → cache key deleted → next read
3. Identify: does the cache-miss read go to source of truth or replica?
   - **Critical pattern:** Cache invalidation works, but re-fill reads stale replica → re-caches stale data
4. Check cache hit rate: sudden drops may indicate invalidation storms

### Step 6: Produce Evidence

```json
{
  "inconsistencies": [ /* cross-source comparison results */ ],
  "replicationLag": { "primaryToReplica": 4500, "measured": "ISO-8601" },
  "eventOrdering": [
    { "expected": ["update", "invalidate", "read"], "actual": ["update", "read", "invalidate"], "divergencePoint": 1 }
  ],
  "staleReads": [
    { "query": "SELECT phone FROM profiles WHERE id=C-1001", "staleValue": "+1-555-0100", "currentValue": "+1-555-0199", "lagMs": 4500 }
  ]
}
```

## Stop Conditions

- Inconsistency source identified (replication lag, cache re-fill, event ordering)
- 3 cross-source comparison checks completed
- Token budget exhausted
- Wall-clock limit (5 minutes)

## Escalation Conditions

- Multiple unrelated inconsistencies with no common cause (may indicate data corruption)
- Replication lag within SLA but inconsistency persists (not a lag issue — something else)
- Event bus shows correct delivery but consumer state is wrong (consumer bug)

## Common Patterns This Investigator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **Stale replica read** | Primary has new value, replica has old; lag > consistency window |
| **Cache re-fill from replica** | Cache invalidated correctly, but refill reads stale replica |
| **Event reordering** | Events consumed in different order than published |
| **Invalidation race** | Read arrives between invalidation and re-fill → cache miss → stale read |
| **Dual-write inconsistency** | Two services write same entity independently; values diverge |
| **Eventual consistency window violation** | Consumer reads during propagation delay |
