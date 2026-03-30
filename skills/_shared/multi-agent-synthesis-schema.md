# Multi-Agent Synthesis Schema

> **Canonical source.** The synthesis layer MUST produce output conforming to this schema after merging branch results.
> Referenced by: `plan-and-execute`, `brainstorming`, `subagent-driven-development`, `evidence-adjudicator`.

## Schema

```json
{
  "packetId": "uuid-v4",
  "synthesisStrategy": "merge | rank | select-best",
  "mergedOutput": { "/* skill-specific final output */": true },
  "conflictsResolved": [
    { "conflict": "description", "resolution": "how resolved", "evidence": "why" }
  ],
  "unresolved": [
    { "tradeoff": "description", "options": ["A", "B"], "recommendation": "A" }
  ],
  "branchesMerged": 3,
  "duplicatesDetected": 1,
  "overallConfidence": 0.78,
  "humanEscalationNeeded": false
}
```

## Field Notes

| Field | Required | Notes |
|-------|----------|-------|
| `packetId` | Yes | Must match the originating task packet |
| `synthesisStrategy` | Yes | Must match `synthesis.strategy` from task packet |
| `conflictsResolved` | Yes | Empty array if no conflicts. Fabricating resolutions is a failure mode |
| `unresolved` | Yes | Honest about what couldn't be merged |
| `humanEscalationNeeded` | Yes | `true` if overall confidence < 0.5 or unresolved tradeoffs > 2 |

## Historical Note

Previously defined inline in `multi-agent-skill-strategy.md` §3.4. Extracted to shared location 2026-03-29.
