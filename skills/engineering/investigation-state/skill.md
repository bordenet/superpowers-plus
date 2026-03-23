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

1. **JSON is authoritative.** Markdown is a read-only export for handoff.
2. Create `~/.superpowers/investigations/` on first use if it doesn't exist.

## Session Start: Stale Investigation Check

1. List `*.json` in `~/.superpowers/investigations/`
2. Files with `updated` > 7 days → prompt: "Close, archive, or resume?"
3. Active within 7 days → auto-resume (one) or list for selection (multiple)

## Investigation Lifecycle

States: `active` → `paused` / `resolved` / `abandoned`

- **→ PAUSED:** Session ending. Generate markdown export. Record next steps.
- **→ RESOLVED:** Root cause confirmed. Create fix TODO tagged `#investigation-<short-id>` if needed.
- **→ ABANDONED:** No longer relevant. Record reason.
- **PAUSED → ACTIVE:** Load JSON, display summary, continue from next steps.

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

Each hypothesis: `{id, text, evidence: [{source, finding, timestamp}], verdict: null|confirmed|rejected|inconclusive, verdict_reason}`

1. State hypothesis → gather evidence → render verdict → update JSON (atomic write)
2. If > 10 hypotheses: prompt for consolidation (likely scope creep)

Evidence sources: freeform strings (`mssql:staging-db`, `ado:MyProject`, `linear`, `local:grep`, etc.)

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

UUID-based filenames. One active → auto-resume. Multiple active → list for user selection.

## Markdown Export

Generate on demand (pause/handoff). Template: `# Investigation: [title]` with sections: Symptoms (observed/expected/reproduction), Hypotheses (H1: text — VERDICT, evidence, verdict_reason), Eliminated Approaches, Next Steps, Tools Consulted, Related TODOs/Tickets.

Rules: `verdict: null` → ACTIVE. `currentTheory` → `← CURRENT THEORY` suffix. Generated on demand only, not auto-synced.

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
