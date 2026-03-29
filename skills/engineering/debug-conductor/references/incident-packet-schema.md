# Incident Packet Schema

> See `skills/_shared/evidence-schema.md` for the full evidence schema.
> This file documents the top-level incident packet structure that the conductor produces.

The incident packet is the structured output of a conductor-led investigation.
It replaces chat transcripts with a machine-readable, auditable artifact.

## Schema

See the complete JSON example in the design doc:
`docs/superpowers/specs/2026-03-29-forked-debugging-design.md` § 5.

## Key Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | uuid-v4 | yes | Unique investigation identifier |
| `status` | enum | yes | active, resolved, escalated, abandoned |
| `incident` | object | yes | Description, severity, affected systems, timeline |
| `forkDecision` | object | yes | Rubric score, details, decision, rationale |
| `branches` | array | yes | Investigation branches with evidence |
| `adjudication` | object | no | Root cause verdict (populated at resolution) |
| `budget` | object | yes | Token/time/branch usage tracking |
| `nextSteps` | array | no | Recommended follow-up actions |

## Relationship to investigation-state

The incident packet is a NEW artifact type, separate from `investigation-state` JSON.
It references investigation-state entries but does not replace them.

**Migration path (Wave 3):**
1. `investigation-state` gains optional `incidentPacketId` field linking to parent incident
2. Branch objects in incident packet reference `investigation-state` hypothesis IDs
3. No breaking changes to existing `investigation-crud.sh` operations
4. New `incident-packet-crud.sh` tool handles incident packet lifecycle
