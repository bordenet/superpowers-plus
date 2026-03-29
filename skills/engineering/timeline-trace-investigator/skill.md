---
name: timeline-trace-investigator
source: superpowers-plus
description: >
  Specialized investigator for reconstructing incident timelines from distributed traces,
  logs, deployments, and metrics. Produces structured TimelineEvidence for the debug conductor.
  NOT a standalone skill — dispatched by debug-conductor as part of forked debugging.
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
  produces: [timeline-evidence, gap-analysis, correlation-map]
  consumes: [incident-description, incident-timeframe, trace-ids, service-names]
  capabilities: [timeline-reconstruction, trace-gap-detection, deployment-correlation]
  priority: 2
  optional: true
  requires_all: false
---

# Timeline & Trace Investigator

> **Role:** Reconstruct what happened and when across distributed services.
> **Dispatched by:** `debug-conductor` — never invoked directly by user.
> **Evidence type:** `TimelineEvidence` (see `skills/_shared/evidence-schema.md`)

## When to Use

Dispatched by `debug-conductor` when the incident involves temporal causation — deployment correlations, cascading failures, or event ordering across services.

## Investigation Protocol

### Step 1: Scope the Timeline

From the incident packet, extract:
- **Time window:** When was the incident first detected? Add 30-minute buffer on each side.
- **Affected services:** Which services are in the failure path?
- **Trace/correlation IDs:** Any specific request IDs to follow?

### Step 2: Gather Evidence (Ordered by Signal Strength)

| Source | Tool | Signal Strength | What to Look For |
|--------|------|----------------|-----------------|
| **Distributed traces** | Tracing queries (Jaeger, Zipkin, OTEL) | Highest | Request path, latency breakdown, span errors |
| **Deployment history** | Git log, CI/CD history | High | Deployments within time window → temporal correlation |
| **Application logs** | Log search (structured) | High | Error messages, warnings, state transitions |
| **Metrics** | Metric queries (Prometheus, Datadog) | Medium | Latency spikes, error rate changes, resource utilization |
| **Git history** | `git log --since --until` | Medium | Code changes that correlate with incident onset |

### Step 3: Reconstruct Timeline

Build a chronological event sequence:

```json
{
  "events": [
    { "timestamp": "ISO-8601", "service": "call-router", "event": "deployment v2.3.1", "traceId": null },
    { "timestamp": "ISO-8601", "service": "call-router", "event": "first error logged", "traceId": "abc123" },
    { "timestamp": "ISO-8601", "service": "telephony-gw", "event": "SIP timeout spike", "traceId": null }
  ]
}
```

### Step 4: Identify Gaps

| Gap Type | Detection | Significance |
|----------|-----------|-------------|
| **Trace gap** | Request enters service A, no trace in service B | High — something happened between A and B |
| **Time gap** | >5 seconds between related events | Medium — unusual delay worth investigating |
| **Service gap** | Known service in path has no events | High — service may be silently failing |
| **Log gap** | Expected log entries missing in window | Medium — logging may be broken or delayed |

### Step 5: Correlate Events

Look for temporal correlations:
- Deployment timestamp vs. error onset (< 5 min gap = strong correlation)
- Config change vs. behavior change
- Metric spike vs. error spike
- Cross-service event ordering (A happens, then B happens — causal?)

### Step 6: Produce Evidence

Return `TimelineEvidence` to conductor:

```json
{
  "events": [ /* chronological event list */ ],
  "gaps": [
    { "from": "ISO-8601", "to": "ISO-8601", "service": "string", "explanation": "string | null" }
  ],
  "correlations": [
    { "eventA": "deployment v2.3.1", "eventB": "first SIP timeout", "lagMs": 120000, "suspicious": true }
  ]
}
```

Plus standard evidence wrapper:
- **Supporting evidence:** Events that point toward a hypothesis
- **Disconfirming evidence:** Events that contradict or complicate the hypothesis
- **Confidence:** Based on trace completeness (% of request path covered)
- **Verdict:** What the timeline suggests happened

## Stop Conditions

- Complete timeline reconstructed (all services accounted for, no critical gaps)
- 3 evidence items collected (sufficient for conductor to work with)
- Token budget exhausted
- Wall-clock limit reached (5 minutes)

## Escalation Conditions

- Trace gaps > 30% of expected request path → tell conductor "timeline is incomplete"
- Conflicting timestamps across services (clock skew?) → flag as suspicious
- No deployment or config changes in window → timeline can't explain the incident alone

## Common Patterns This Investigator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **Deployment-correlated failure** | Deployment event < 30 min before error onset |
| **Cascading timeout** | Service A timeout → Service B timeout → Service C timeout (each delayed) |
| **Event ordering bug** | Events arrive out of sequence (checked via trace timestamps) |
| **Silent service failure** | Service in path has zero events (gap in timeline) |
| **Clock skew** | Event in Service B "before" the event in Service A that triggered it |
