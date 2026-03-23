---
name: investigation-state
source: superpowers-plus
triggers: ["start investigation", "investigate this bug", "resume investigation",
           "what have we tried", "investigation status", "debug checkpoint",
           "save investigation state", "investigation handoff"]
description: Persists debugging investigation context (hypotheses, evidence, eliminated approaches) across sessions. Companion to systematic-debugging. Use when starting, resuming, or handing off a multi-turn debugging session.
summary: "Use when: starting, resuming, or handing off a multi-turn debugging investigation."
coordination:
  group: debugging
  order: 1
  requires: []
  enables: ["think-twice"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [bug-report, observed-behavior]
  produces: [investigation-context, investigation-handoff]
  capabilities: [tracks-investigation, persists-debug-state]
  priority: 5
---

# Investigation State

> **Purpose:** Persist debugging investigation context across sessions so no hypothesis, evidence, or eliminated approach is lost.
> **Storage:** `~/.superpowers/investigations/<uuid>.json`
> **Authoritative format:** JSON. Markdown export is read-only.

**Announce at start:** "I'm using the **investigation-state** skill to track this investigation."

## When to Use

- Starting a new multi-turn debugging session
- Resuming a previous investigation after context loss
- Handing off an investigation to another agent or session
- Checking what has already been tried ("what have we tried?")
- Saving a checkpoint before ending a session

## Core Principles

1. **JSON is authoritative.** Markdown is a generated, read-only export for human review and cold handoff.
2. **Skills instruct, agents execute.** This skill tells you what to write and where. You execute file operations directly.
3. **Directory creation is on-demand.** Create `~/.superpowers/investigations/` on first use if it doesn't exist.

---

## Session Start: Stale Investigation Check

On every session start where this skill fires, check for stale investigations:

```
1. List *.json files in ~/.superpowers/investigations/
2. For each file with "updated" > 7 days ago:
   → Prompt: "Investigation '[title]' has been inactive for N days. Close, archive, or resume?"
3. For active investigations updated within 7 days:
   → If exactly one: "Resuming investigation '[title]'. Last updated [date]."
   → If multiple: List them and ask user to select.
```

---

## Investigation Lifecycle

```
[new] → ACTIVE → [PAUSED] → RESOLVED | ABANDONED
                     ↑           |
                     └───────────┘ (resume)
```

| Status | Meaning |
|--------|---------|
| `active` | Hypotheses being tested, evidence being gathered |
| `paused` | Session ending without resolution; markdown handoff generated |
| `resolved` | Root cause found, fix identified; linked TODO created |
| `abandoned` | Investigation invalid or no longer relevant |

### Status Transitions

- **ACTIVE → PAUSED:** Session ending. Auto-generate markdown export. Record next steps.
- **ACTIVE → RESOLVED:** Root cause confirmed. If a fix is needed, create fix task in TODO tagged `#investigation-<short-id>` (first 8 chars of UUID). If no fix is needed (e.g., config error, user error, external issue), record resolution without creating a TODO.
- **ACTIVE → ABANDONED:** User confirms investigation is no longer needed. Record reason.
- **PAUSED → ACTIVE:** Resume. Load JSON state, display markdown summary, continue from next steps.

---

## Starting a New Investigation

1. `mkdir -p ~/.superpowers/investigations`
2. `INVESTIGATION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')`
3. Capture symptoms: observed behavior, expected behavior, reproduction steps
4. Write initial JSON via atomic write (see Persistence below)
5. `[ -f "$HOME/.superpowers/investigations/.gitignore" ] || echo '*.json' > "$HOME/.superpowers/investigations/.gitignore"`
6. Form first hypothesis and begin evidence gathering

---

## Hypothesis Tracking

Each hypothesis gets a sequential integer `id`. Track:

| Field | Description |
|-------|-------------|
| `id` | Sequential integer (1, 2, 3...) |
| `text` | The hypothesis statement |
| `evidence` | Array of `{source, finding, timestamp}` entries |
| `verdict` | `null` (untested), `"confirmed"`, `"rejected"`, `"inconclusive"` |
| `verdict_reason` | Why this verdict was reached |

### Process

1. **State the hypothesis** clearly before testing it.
2. **Gather evidence** — log each finding with source and timestamp.
3. **Render verdict** — confirm, reject, or mark inconclusive with reason.
4. **Update JSON** after each verdict via atomic write.
5. **If > 10 hypotheses:** Prompt for consolidation — likely scope creep or multiple bugs.

### Evidence Sources

Use freeform `source` strings: `mssql:staging-db`, `ado:MyProject`, `linear`, `local:grep`, `browser`, etc.
See `references/cross-tool-patterns.md` for tool-specific evidence gathering patterns.
See `references/evidence-synthesis.md` for multi-source synthesis technique.

---

## Eliminated Approaches

Track approaches that were tried and failed (distinct from hypotheses):

```json
{ "approach": "Restarted the API service", "reason": "Data still stale after restart", "timestamp": "2026-03-23T14:40:00Z" }
```

This prevents future agents from retrying failed approaches.

---

## Persistence: Atomic JSON Writes

Use `python3 -c "import json..."` for all writes. **Never use heredocs.** Write to `.tmp.json` first, then `mv` to final `.json`:

```bash
python3 -c "
import json, sys
data = json.loads(sys.argv[1])
with open(sys.argv[2], 'w') as f:
    json.dump(data, f, indent=2)
" '<JSON_STRING>' "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.tmp.json"

mv "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.tmp.json" \
   "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.json"
```

Update the `updated` timestamp on every write. Schema: see `references/schema.md`.

---

## Concurrent Investigations

Each investigation has a UUID-based filename. To manage multiple:

1. List `*.json` files in `~/.superpowers/investigations/`
2. If only one is `active`: resume it automatically
3. If multiple are `active`: list titles and ask user to select
4. New investigations always get a fresh UUID — no conflicts

---


## Markdown Export Template

Generate this on demand for cross-session handoff. A fresh agent can resume from this alone.

```markdown
# Investigation: [title]

**ID:** [uuid] | **Status:** [status] | **Started:** [created] | **Updated:** [updated]

## Symptoms
- **Observed:** [observed]
- **Expected:** [expected]
- **Reproduction:** [reproduction]

## Hypotheses

### H1: [text] — [REJECTED/CONFIRMED/INCONCLUSIVE/ACTIVE]
- Evidence: [source] — [finding] ([timestamp])
- Verdict: [verdict_reason]

### H2: [text] — ACTIVE ← CURRENT THEORY
- (no evidence yet)

## Eliminated Approaches
1. [approach] — [reason] ([timestamp])

## Next Steps
1. [next step 1]
2. [next step 2]

## Tools Consulted
[comma-separated list]

## Related
- TODOs: [related todos]
- Tickets: [related tickets]
```

**Rendering rules:**
- `verdict: null` renders as `ACTIVE`
- The hypothesis matching `currentTheory` gets `← CURRENT THEORY` suffix
- Empty arrays render as "(none)"
- Markdown is generated **on demand** (pause, handoff, or user request) — it is NOT auto-synced with JSON

---

## Techniques

When an investigation needs specialized approaches:

- **Multi-source evidence synthesis:** See `references/evidence-synthesis.md`
- **Cross-tool evidence gathering:** See `references/cross-tool-patterns.md`
- **Regression hunting:** See `references/git-bisect.md`

---

## Integration with Other Skills

| Skill | Integration |
|-------|-------------|
| `thinking-orchestrator` | Routes "debugging a bug, starting investigation" here |
| `todo-management` | On resolution (if fix needed), create fix task tagged `#investigation-<short-id>` |

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Forgot to update JSON after verdict | Always write JSON immediately after each hypothesis verdict |
| Retried an eliminated approach | Check `eliminated` array before trying any approach |
| Lost investigation on session end | Auto-pause with markdown export on session end |
| JSON corruption from interrupted write | Atomic write pattern (temp + mv) prevents this |
| Investigation scope creep (>10 hypotheses) | Prompt for consolidation — likely multiple bugs |
