# Incident Packet Schema

> **Canonical source.** The debugging orchestration system uses this schema for cross-skill communication.
> Referenced by: `debug-conductor`, `evidence-adjudicator`, all `*-investigator` skills, `investigation-state`.
>
> **Status:** Protocol definition only. End-to-end packet persistence tooling is not yet implemented.
> Agents maintain packet state in-context; there is no durable store.

## Schema

```json
{
  "incidentId": "uuid-v4",
  "summary": "One-line description of the incident",
  "severity": "P1 | P2 | P3",
  "conductor": {
    "agentId": "conductor-session-id",
    "startedAt": "ISO-8601",
    "status": "investigating | adjudicating | resolved | escalated"
  },
  "hypotheses": [
    {
      "id": "H1",
      "description": "What we think went wrong",
      "confidence": 0.0,
      "status": "active | confirmed | eliminated",
      "evidence": ["E1", "E2"],
      "assignedInvestigator": "investigator-role-name"
    }
  ],
  "evidence": [
    {
      "id": "E1",
      "source": "investigator-role-name",
      "type": "log | metric | config | trace | reproduction | code-change",
      "summary": "What was found",
      "supports": ["H1"],
      "contradicts": ["H2"],
      "confidence": 0.85,
      "timestamp": "ISO-8601"
    }
  ],
  "branches": [
    {
      "branchId": "uuid-v4",
      "investigator": "timeline-trace-investigator | state-consistency-investigator | ...",
      "hypothesis": "H1",
      "status": "running | completed | killed",
      "tokensUsed": 4200,
      "wallClockSeconds": 45
    }
  ],
  "adjudication": {
    "verdict": "Root cause description",
    "confidence": 0.82,
    "alternativeCauses": ["Alternative 1"],
    "contradictions": [],
    "adjudicatedAt": "ISO-8601"
  },
  "budget": {
    "maxBranches": 4,
    "maxTokensTotal": 32000,
    "maxWallClockSeconds": 600,
    "tokensUsed": 12400,
    "wallClockUsed": 120
  },
  "nextSteps": ["Recommended action 1", "Recommended action 2"]
}
```

## Field Notes

| Field | Required | Notes |
|-------|----------|-------|
| `incidentId` | Yes | UUIDv4, unique per investigation |
| `severity` | Yes | Determines budget limits and escalation thresholds |
| `hypotheses` | Yes | At least 1 before forking. Conductor generates from initial evidence |
| `evidence` | Accumulates | Each investigator appends evidence items |
| `adjudication` | After Phase 5 | Produced by `evidence-adjudicator`, not conductor |
| `budget` | Yes | Hard limits. Conductor kills branches exceeding these |

## Persistence Note

Currently, the incident packet exists only in the conductor's working context. Future work:

- Persist via a dedicated `incident-packet-crud.sh` tool (not yet implemented); the incident packet is a **separate artifact** from `investigation-state` evidence — bridging requires explicit field mapping: packet `summary` → investigation `finding`; packet `supports`/`contradicts` have no direct equivalent; packet `id` and `type` have different semantics. Do not attempt to map packet evidence directly into `investigation-state` evidence entries without a defined migration spec.
- Enable resume-after-crash for long-running investigations
- Support cross-session incident handoff
