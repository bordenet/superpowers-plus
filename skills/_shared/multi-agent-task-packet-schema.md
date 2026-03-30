# Multi-Agent Task Packet Schema

> **Canonical source.** All multi-agent skills MUST use this schema for dispatch.
> Referenced by: `plan-and-execute`, `brainstorming`, `subagent-driven-development`, `debug-conductor`.

## Schema

```json
{
  "packetId": "uuid-v4",
  "skill": "plan-and-execute | subagent-driven-development | brainstorming",
  "mode": "single-agent | multi-agent",
  "activationScore": 6,
  "task": {
    "description": "Free text task description",
    "context": "Relevant codebase/system context",
    "constraints": ["constraint-1", "constraint-2"],
    "successCriteria": ["criterion-1", "criterion-2"]
  },
  "branches": [
    {
      "branchId": "uuid-v4",
      "role": "Role name (e.g., Risk Planner, Architecture Lens)",
      "mandate": "Specific scoped instruction for this branch",
      "tokenBudget": 8000,
      "timeoutSeconds": 300
    }
  ],
  "budget": {
    "maxBranches": 4,
    "maxTokensTotal": 32000,
    "maxWallClockSeconds": 600
  },
  "synthesis": {
    "strategy": "merge | rank | select-best",
    "conflictResolution": "evidence-weighted | user-decision | conductor-decision"
  }
}
```

## Field Notes

| Field | Required | Notes |
|-------|----------|-------|
| `packetId` | Yes | UUIDv4, unique per dispatch |
| `skill` | Yes | Must match a skill with multi-agent mode |
| `activationScore` | Yes | From `multi-agent-activation-rubric.md`. ≥6 = eligible |
| `branches` | Yes | At least 1; max governed by `budget.maxBranches` |
| `budget` | Yes | Hard limits. Conductor kills branches exceeding these |
| `synthesis.strategy` | Yes | How branch outputs are combined |

## Historical Note

Previously defined inline in `multi-agent-skill-strategy.md` §3.2. Extracted to shared location 2026-03-29.
