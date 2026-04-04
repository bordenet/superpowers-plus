# Incident Packet Schema

> See `skills/_shared/evidence-schema.md` for the full evidence schema.
> This file documents the top-level incident packet structure that the conductor produces.

The incident packet is the structured output of a conductor-led investigation.
It replaces chat transcripts with a machine-readable, auditable artifact.

## Schema

The canonical packet structure is defined in `skills/_shared/incident-packet-schema.md`.
Key top-level fields are summarized below.

## Key Fields

See `skills/_shared/incident-packet-schema.md` for the authoritative JSON schema. Quick reference:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `incidentId` | uuid-v4 | yes | Unique investigation identifier |
| `summary` | string | yes | One-line description of the incident |
| `severity` | enum | yes | P1, P2, or P3 |
| `conductor` | object | yes | Agent ID, start time, and status |
| `hypotheses` | array | yes | Working hypotheses with confidence and evidence refs |
| `evidence` | array | yes | Evidence items (id, source, type, summary, supports, contradicts) |
| `branches` | array | yes | Investigation branches with investigator, hypothesis, status |
| `adjudication` | object | no | Root cause verdict (populated at resolution) |
| `budget` | object | yes | Token/time/branch usage tracking |
| `nextSteps` | array | no | Recommended follow-up actions |

## Relationship to investigation-state

The incident packet is a NEW artifact type, separate from `investigation-state` JSON.
It references investigation-state entries but does not replace them.

**Migration path (Wave 3):**

1. `investigation-state` gains optional `forkedDebugging.incidentPacketId` field linking to parent incident (nested under the existing `forkedDebugging` object, not a top-level field)
2. Branch objects in incident packet reference `investigation-state` hypothesis IDs
3. No breaking changes to existing `investigation-crud.sh` operations
4. New `incident-packet-crud.sh` tool handles incident packet lifecycle
