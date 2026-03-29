---
name: infra-config-investigator
source: superpowers-plus
description: "Specialized investigator for diagnosing infrastructure, configuration, and deployment failures: config changes, resource exhaustion, deployment regressions, cloud provider issues, and environment mismatches. Dispatched by debug-conductor."
summary: "Use when: diagnosing infrastructure, config, or deployment failures."
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
  produces: [infra-evidence, deployment-correlation, config-diff-analysis]
  consumes: [incident-description, deployment-timeline, config-versions, infrastructure-topology]
  capabilities: [deployment-correlation, config-diff-analysis, resource-metric-assessment]
  priority: 2
  optional: true
  requires_all: false
---

# Infra / Config / Deployment Investigator

> **Role:** Diagnose infrastructure-level failures: config changes, deployment regressions, resource exhaustion, cloud provider issues.
> **Dispatched by:** `debug-conductor` — never invoked directly by user.
> **Evidence type:** `InfraEvidence` (see `skills/_shared/evidence-schema.md`)

## When to Use

Dispatched by `debug-conductor` when the incident involves infrastructure — config changes, deployment regressions, resource exhaustion, cloud provider maintenance, or environment mismatches.

## Investigation Protocol

### Step 1: Deployment Timeline Scan

1. List ALL deployments within the incident time window (± 2 hours)
2. For each deployment: service, version, timestamp, deployer, change description
3. **Temporal correlation:** deployment within 30 minutes of incident onset = strong signal
4. Check rollback history: was anything deployed and quickly rolled back?

### Step 2: Configuration Diff Analysis

1. Identify config sources: environment variables, config files, feature flags, cloud settings
2. Diff current vs. previous configuration for affected services
3. For each change:
   - What was changed? (key, old value, new value)
   - When? (timestamp relative to incident)
   - Who? (change author)
   - Was it tested? (staging deployment before prod?)
4. Flag "silent" changes: cloud provider maintenance, auto-scaling events, certificate rotations

### Step 3: Resource Metric Assessment

1. Check resource metrics for affected services:
   - CPU, memory, disk, network I/O
   - Connection pools (DB, HTTP client, message broker)
   - Queue depths, thread counts, file descriptors
2. Identify breached thresholds:
   - Resource at >90% capacity?
   - Connection pool exhausted?
   - Queue depth growing unbounded?
3. Correlate resource exhaustion with incident timeline

### Step 4: Health Check Review

1. Check service health endpoints for all services in failure path
2. Compare current health status vs. historical baseline
3. Identify services that are "healthy" but degraded (passing health checks but slow)
4. Check dependency health: downstream services, databases, message brokers, external APIs

### Step 5: Cloud Provider / Infrastructure Events

1. Check cloud provider status page (AWS Health, GCP Status, Azure Status)
2. Check for maintenance events, AZ failures, network issues
3. Check for auto-scaling events that coincide with incident
4. Check for infrastructure lifecycle events (NAT gateway replacement, certificate rotation)

### Step 6: Produce Evidence

```json
{
  "deployments": [
    { "service": "billing-service", "version": "2.4.1", "timestamp": "ISO-8601", "correlatesWithIncident": false },
    { "service": "billing-service", "version": "2.4.0-hotfix", "timestamp": "ISO-8601", "correlatesWithIncident": true }
  ],
  "configChanges": [
    { "key": "db.pool.maxSize", "before": "50", "after": "5", "timestamp": "ISO-8601" }
  ],
  "resourceMetrics": [
    { "resource": "billing-db", "metric": "active_connections", "value": 5, "threshold": 50, "breached": true }
  ],
  "healthStatus": [
    { "service": "billing-service", "status": "degraded", "since": "ISO-8601" }
  ]
}
```

## Stop Conditions

- Config or deployment change correlated with incident
- Resource exhaustion confirmed
- No changes found in window (strong negative evidence)
- Token budget exhausted
- Wall-clock limit (5 minutes)

## Escalation Conditions

- No deployment or config changes in the entire window → infra can't explain it alone
- All resource metrics nominal → not a resource issue
- Cloud provider reports no issues but behavior suggests infrastructure change (silent change)

## Common Patterns This Investigator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **Config-induced failure** | Config change timestamp < 30 min before incident onset |
| **Resource exhaustion cascade** | Connection pool exhaustion → timeout cascade → retry storm |
| **Silent cloud maintenance** | Cloud provider replaced infrastructure component without notification |
| **Deployment regression** | New version deployed; metrics degrade immediately after |
| **Environment mismatch** | Staging works, prod doesn't; config differs between environments |
| **Auto-scaling lag** | Load spike → scaling event → 2–5 min gap with degraded capacity |

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Config drift | Comparing against stale baseline | Always fetch current deployed config |
| Wrong environment | Inspecting dev when prod is broken | Verify target environment first |
| Resource false positive | Spike is normal load pattern | Compare against historical baselines |
