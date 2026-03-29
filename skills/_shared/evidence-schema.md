# Evidence Schema — Forked Debugging

> **Purpose:** Shared schema for structured evidence produced by all investigators.
> **Authoritative format:** JSON. This doc defines the canonical schema.

## Evidence Item

Every piece of evidence from any investigator follows this schema:

```json
{
  "source": "string — tool or data source (e.g., 'sip-trace', 'mssql:prod', 'git:log', 'metrics:datadog')",
  "finding": "string — what was observed (factual, not interpretive)",
  "timestamp": "ISO-8601 — when evidence was collected",
  "confidence": "number 0.0–1.0 — how confident is this finding?",
  "type": "supporting | disconfirming — relationship to branch hypothesis"
}
```

### Confidence Calibration Guide

| Score | Meaning | Example |
|-------|---------|---------|
| 0.9–1.0 | Deterministic proof | Stack trace showing exact error line |
| 0.7–0.9 | Strong correlation | Deployment timestamp matches incident onset within 2 minutes |
| 0.5–0.7 | Moderate correlation | Metric spike in same window, could be coincidence |
| 0.3–0.5 | Weak signal | Config change in adjacent service, unclear if related |
| 0.0–0.3 | Speculation | "This might be related because it changed recently" |

## Branch Evidence

Each investigation branch produces:

```json
{
  "branchId": "uuid-v4",
  "investigator": "string — investigator role name",
  "hypothesis": "string — what this branch is testing",
  "status": "in-progress | completed | killed | merged",
  "evidence": {
    "supporting": [ /* EvidenceItem[] */ ],
    "disconfirming": [ /* EvidenceItem[] — MANDATORY min 1 for status:completed; MAY be empty for status:killed */ ]
  },
  "killReason": "string | null — required when status is 'killed' (e.g., 'budget-exceeded', 'low-confidence', 'duplicate')",
  "verdict": "confirmed | rejected | partial-cause | inconclusive",
  "verdictReason": "string — why this verdict",
  "tokensUsed": "number",
  "wallClockSeconds": "number"
}
```

> **Killed branches:** When status is `killed`, the conductor MUST still forward all partial evidence collected so far. The `disconfirming` array MAY be empty. The `killReason` field is REQUIRED. The `verdict` SHOULD be `inconclusive` unless the partial evidence already supported a conclusion.

## Investigator-Specific Evidence Types

### TimelineEvidence (Timeline & Trace Investigator)
```json
{
  "events": [{ "timestamp": "ISO-8601", "service": "string", "event": "string", "traceId": "string" }],
  "gaps": [{ "from": "ISO-8601", "to": "ISO-8601", "service": "string", "explanation": "string | null" }],
  "correlations": [{ "eventA": "string", "eventB": "string", "lagMs": "number", "suspicious": "boolean" }]
}
```

### TelephonyEvidence (Telephony Flow Investigator)
```json
{
  "callFlow": [{ "step": "number", "state": "string", "timestamp": "ISO-8601", "expected": "string | null" }],
  "anomalies": [{ "step": "number", "type": "string", "detail": "string", "severity": "high | medium | low" }],
  "timingIssues": [{ "event": "string", "expectedMs": "number", "actualMs": "number", "delta": "number" }]
}
```

### LLMEvidence (Prompt / LLM Behavior Investigator)
```json
{
  "toolCalls": [{ "tool": "string", "params": "object", "success": "boolean", "expected": "string | null" }],
  "promptDiffs": [{ "section": "string", "before": "string", "after": "string", "impact": "string" }],
  "contextUsage": { "promptTokens": "number", "maxTokens": "number", "utilization": "number" },
  "parsingFailures": [{ "rawOutput": "string", "expectedFormat": "string", "error": "string" }]
}
```

### StateEvidence (State Consistency Investigator)
```json
{
  "inconsistencies": [{ "entity": "string", "sourceA": "string", "sourceB": "string", "valueA": "any", "valueB": "any" }],
  "replicationLag": { "primaryToReplica": "number_ms", "measured": "ISO-8601" },
  "eventOrdering": [{ "expected": "string[]", "actual": "string[]", "divergencePoint": "number" }],
  "staleReads": [{ "query": "string", "staleValue": "any", "currentValue": "any", "lagMs": "number" }]
}
```

### InfraEvidence (Infra / Config / Deployment Investigator)
```json
{
  "deployments": [{ "service": "string", "version": "string", "timestamp": "ISO-8601", "correlatesWithIncident": "boolean" }],
  "configChanges": [{ "key": "string", "before": "string", "after": "string", "timestamp": "ISO-8601" }],
  "resourceMetrics": [{ "resource": "string", "metric": "string", "value": "number", "threshold": "number", "breached": "boolean" }],
  "healthStatus": [{ "service": "string", "status": "healthy | degraded | down", "since": "ISO-8601" }]
}
```

### ExperimentEvidence (Reproduction & Experiment Investigator)
```json
{
  "hypothesis": "string",
  "steps": [{ "action": "string", "result": "string", "success": "boolean" }],
  "outcome": "reproduced | not-reproduced | partial",
  "reproduced": "boolean",
  "attempts": "number",
  "successRate": "number 0.0–1.0",
  "environmentDiff": "string | null — differences from production"
}
```

## Root Cause Verdict (Evidence Adjudicator)

```json
{
  "rootCause": "string — plain language description",
  "confidence": "number 0.0–1.0",
  "supportingEvidence": [ /* EvidenceItem[] from winning branches */ ],
  "disconfirmingEvidence": [ /* EvidenceItem[] that were addressed */ ],
  "alternativeCauses": [{ "cause": "string", "confidence": "number", "reason": "string — why rejected or deferred" }],
  "divergencePoints": [ "string — where investigators disagreed" ],
  "gaps": [ "string — what we still don't know" ]
}
```
