# Investigation State — JSON Schema Reference

> Reference material for the `investigation-state` skill.
> See `skill.md` for core guidance.

## Storage Location

```text
~/.superpowers/investigations/<uuid>.json
```

Each investigation is a single JSON file named by its UUID.

## Schema

```json
{
  "id": "string (UUID v4, lowercase)",
  "created": "string (ISO-8601 UTC, e.g., 2026-03-23T14:30:00Z)",
  "updated": "string (ISO-8601 UTC, e.g., 2026-03-23T15:45:00Z)",
  "status": "string (active | paused | resolved | abandoned)",
  "title": "string (brief description of the bug being investigated)",
  "symptoms": {
    "observed": "string (what actually happens)",
    "expected": "string (what should happen)",
    "reproduction": "string (steps to reproduce)"
  },
  "hypotheses": [
    {
      "id": "integer (sequential, starting at 1)",
      "text": "string (the hypothesis statement)",
      "evidence": [
        {
          "source": "string (freeform tool identifier)",
          "finding": "string (what was found)",
          "timestamp": "string (ISO-8601 UTC)"
        }
      ],
      "verdict": "null | \"confirmed\" | \"rejected\" | \"inconclusive\"",
      "verdict_reason": "null | string (why this verdict was reached)"
    }
  ],
  "eliminated": [
    {
      "approach": "string (what was tried)",
      "reason": "string (why it didn't work)",
      "timestamp": "string (ISO-8601 UTC)"
    }
  ],
  "currentTheory": "integer | null (hypothesis id, or null if no current theory)",
  "resolution": "null | { type, summary, fixTodo }",
  "nextSteps": ["string (action items for next session)"],
  "toolsConsulted": ["string (freeform tool identifiers)"],
  "relatedTodos": ["string (TODO references, e.g., #investigation-abc12345)"],
  "relatedTickets": ["string (ticket references, e.g., TST-123)"],

  "forkedDebugging": {
    "incidentPacketId": "string (UUID) | null — links to parent incident packet if this investigation was forked",
    "branchId": "string (UUID) | null — branch ID within the incident packet",
    "branchRole": "string | null — investigator role (e.g., timeline-trace, llm-behavior)",
    "conductorId": "string | null — investigation ID of the conductor that dispatched this branch",
    "forkReason": "string | null — why forking was chosen (rubric score, stalled investigation)",
    "forkRubricScore": "integer | null — fork-readiness rubric score at time of fork decision"
  }
}
```

## Field Details

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | UUID v4, lowercase. Generated via `uuidgen \| tr '[:upper:]' '[:lower:]'` |
| `created` | string | Yes | ISO-8601 UTC timestamp when investigation started |
| `updated` | string | Yes | ISO-8601 UTC timestamp of last modification. Updated on every write |
| `status` | string | Yes | One of: `active`, `paused`, `resolved`, `abandoned` |
| `title` | string | Yes | Brief description of the bug under investigation |
| `symptoms` | object | Yes | Observed vs expected behavior and reproduction steps |
| `hypotheses` | array | Yes | List of hypotheses (may be empty initially) |
| `eliminated` | array | Yes | Approaches tried and failed (may be empty) |
| `currentTheory` | int/null | Yes | `id` of the hypothesis currently being tested, or `null` |
| `resolution` | object/null | No | Set when status is `resolved`. See Resolution below |
| `nextSteps` | array | Yes | Action items for the next session (may be empty) |
| `toolsConsulted` | array | Yes | Tools used during investigation (may be empty) |
| `relatedTodos` | array | No | TODO references (e.g., `#investigation-abc12345`) |
| `relatedTickets` | array | No | External ticket references (Linear, ADO, etc.) |
| `forkedDebugging` | object | No | Present only when this investigation is a branch of a conductor-led forked debugging session. See Forked Debugging below |

### Forked Debugging Extension

Added for the `debug-conductor` forked debugging system. All fields are null/absent for standard investigations.

| Field | Type | Description |
|-------|------|-------------|
| `incidentPacketId` | string/null | UUID of the parent incident packet that triggered this fork |
| `branchId` | string/null | This branch's ID within the incident packet |
| `branchRole` | string/null | Investigator role: `timeline-trace`, `llm-behavior`, `state-consistency`, `infra-config`, `reproduction-experiment`, `evidence-adjudicator` |
| `conductorId` | string/null | Investigation ID of the debug-conductor that dispatched this branch |
| `forkReason` | string/null | Why forking was chosen (e.g., "rubric score 7, multi-domain incident") |
| `forkRubricScore` | int/null | Fork-readiness rubric score at time of fork decision (0–10) |

**Backward compatibility:** Existing investigations without `forkedDebugging` continue to work unchanged. The field is optional and defaults to absent/null.

### Short ID

The `<short-id>` used in TODO tags is the **first 8 characters** of the investigation UUID.
Example: UUID `a1b2c3d4-e5f6-7890-abcd-ef1234567890` → short-id `a1b2c3d4` → tag `#investigation-a1b2c3d4`

### Resolution

Set when `status` is `resolved`. Null otherwise.

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"fix-needed"`, `"no-fix-needed"`, or `"external"` |
| `summary` | string | Brief description of the root cause and resolution |
| `fixTodo` | string/null | TODO tag (e.g., `#investigation-a1b2c3d4`) if `type` is `fix-needed`, null otherwise |

**Resolution types:**

- `fix-needed` — Code change required. Create a TODO tagged `#investigation-<short-id>`.
- `no-fix-needed` — Root cause found but no code change needed (config error, user error, data issue).
- `external` — Issue is outside our control (third-party service, infrastructure).

### Timestamps

All timestamps are UTC in ISO-8601 format with seconds precision:

- Format: `YYYY-MM-DDTHH:MM:SSZ`
- Example: `2026-03-23T14:30:00Z`
- No milliseconds. No timezone offsets. Always `Z` suffix.

### Status Values

| Value | Meaning | Transitions To |
|-------|---------|----------------|
| `active` | Under investigation | `paused`, `resolved`, `abandoned` |
| `paused` | Session ended, not resolved | `active` |
| `resolved` | Root cause found, fix identified | (terminal) |
| `abandoned` | No longer relevant | (terminal) |

### Hypothesis Verdicts

| Value | Meaning | Markdown Rendering |
|-------|---------|-------------------|
| `null` | Not yet tested | `ACTIVE` |
| `"confirmed"` | Evidence supports this hypothesis | `CONFIRMED` |
| `"rejected"` | Evidence contradicts this hypothesis | `REJECTED` |
| `"inconclusive"` | Evidence is ambiguous | `INCONCLUSIVE` |

### Evidence Source Format

The `source` field is freeform text. Common patterns:

| Pattern | Example | Meaning |
|---------|---------|---------|
| `db:<connection>` | `db:example-conn` | Database query via named connection |
| `ci:<project>` | `ci:my-project` | CI/issue tracker (pipelines, work items) |
| `linear` | `linear` | Linear issue tracker |
| `wiki` | `wiki` | Wiki platform |
| `local:<tool>` | `local:grep` | Local tool (grep, find, cat, etc.) |
| `browser` | `browser` | Web browser / fetch |
| `git:<action>` | `git:bisect` | Git operations |

## Validation

Validate a JSON file with:

```bash
python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
required = ['id', 'created', 'updated', 'status', 'title', 'symptoms', 'hypotheses', 'eliminated', 'currentTheory', 'nextSteps', 'toolsConsulted']
missing = [k for k in required if k not in data]
if missing:
    print(f'Missing fields: {missing}', file=sys.stderr)
    sys.exit(1)
valid_statuses = {'active', 'paused', 'resolved', 'abandoned'}
if data['status'] not in valid_statuses:
    print(f'Invalid status: {data[\"status\"]}', file=sys.stderr)
    sys.exit(1)
print('Valid')
" ~/.superpowers/investigations/<uuid>.json
```
