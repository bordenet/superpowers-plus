# Multi-Agent Result Schema

> **Canonical source.** Every branch in a multi-agent dispatch MUST produce output conforming to this schema.
> Referenced by: `plan-and-execute`, `brainstorming`, `subagent-driven-development`, `evidence-adjudicator`.

## Schema

```json
{
  "branchId": "uuid-v4",
  "role": "Role name",
  "status": "completed | killed | merged",
  "output": { "/* role-specific structured output */": true },
  "confidence": 0.85,
  "assumptions": ["assumption-1"],
  "risks": ["risk-1"],
  "missingInformation": ["what-i-dont-know"],
  "objections": ["weakest-point-in-my-output"],
  "tokensUsed": 4200,
  "wallClockSeconds": 45
}
```

## Field Notes

| Field | Required | Notes |
|-------|----------|-------|
| `branchId` | Yes | Must match `branches[].branchId` from the task packet |
| `status` | Yes | `killed` = budget exceeded or conductor terminated |
| `confidence` | Yes | 0.0–1.0. Branches with < 0.3 after first evidence may be killed |
| `objections` | Yes | Self-identified weakness. Empty array is a red flag |
| `tokensUsed` | Yes | Actual consumption for cost tracking |

## Historical Note

Previously defined inline in `multi-agent-skill-strategy.md` §3.3. Extracted to shared location 2026-03-29.
