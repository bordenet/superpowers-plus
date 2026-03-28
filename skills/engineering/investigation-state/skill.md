---
name: investigation-state
source: superpowers-plus
triggers: ["start investigation", "investigate this bug", "resume investigation",
           "what have we tried", "investigation status", "debug checkpoint",
           "save investigation state", "investigation handoff"]
anti_triggers: ["implement", "write code", "create feature"]
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

> **Wrong skill?** Debugging → `systematic-debugging`. Getting unstuck → `think-twice`. Requirements analysis → `requirements-validation`.

> **Purpose:** Persist debugging investigation context across sessions so no hypothesis, evidence, or eliminated approach is lost.
> **Storage:** `~/.superpowers/investigations/<uuid>.json`
> **Authoritative format:** JSON. Markdown export is read-only.

**Announce at start:** "I'm using the **investigation-state** skill to track this investigation."

## Companion Skills

- **systematic-debugging**: Step-by-step bug investigation
- **adversarial-search**: Confirmation bias prevention during investigation
- **think-twice**: When investigation hits a wall

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
2. Files with `updated` > 7 days → prompt: "Resolve, abandon, or resume?"
3. Active within 7 days → resume (one) or list for selection (multiple)

## Investigation Lifecycle

States: `active` → `paused` / `resolved` / `abandoned`

- **→ PAUSED:** Session ending or blocked. Run `export` manually. Record next steps via `update --next-steps`.
- **→ RESOLVED:** Root cause confirmed. Create fix TODO tagged `#investigation-<short-id>` if needed.
- **→ ABANDONED:** No longer relevant. Record reason.
- **PAUSED → ACTIVE:** Load JSON, display summary, continue from next steps.

---

## Tooling

**Use `investigation-crud.sh` for ALL investigation operations.** It handles directory creation, atomic writes, UUID generation, advisory locking, backup, and schema validation.

```bash
# Core operations
investigation-crud.sh create --title "Bug title" [--observed OBS] [--expected EXP] [--reproduction REP]
investigation-crud.sh list [--status active] [--stale]
investigation-crud.sh show --id UUID
investigation-crud.sh export --id UUID

# Hypothesis tracking
investigation-crud.sh add-hypothesis --id UUID --text "Hypothesis text"
investigation-crud.sh add-evidence --id UUID --hypothesis N --source SRC --finding TEXT
investigation-crud.sh set-verdict --id UUID --hypothesis N --verdict confirmed|rejected|inconclusive [--reason TEXT]

# Lifecycle
investigation-crud.sh add-eliminated --id UUID --approach "What was tried" --reason "Why it failed"
investigation-crud.sh set-status --id UUID --status paused|resolved|abandoned [--resolution-type fix-needed] [--summary TEXT]
investigation-crud.sh update --id UUID [--next-steps "step1|step2"] [--current-theory N] [--add-ticket TST-123]
```

**Anti-pattern:** Do NOT write investigation JSON manually with heredocs, jq, or inline Python. Use `investigation-crud.sh`.

## Starting a New Investigation

1. `investigation-crud.sh create --title "Bug title" --observed "..." --expected "..." --reproduction "..."`
2. Note the returned `id` and `short_id`
3. Form first hypothesis: `investigation-crud.sh add-hypothesis --id UUID --text "..."`
4. Begin evidence gathering

---

## Hypothesis Tracking

Each hypothesis: `{id, text, evidence: [{source, finding, timestamp}], verdict: null|confirmed|rejected|inconclusive, verdict_reason}`

1. `investigation-crud.sh add-hypothesis --id UUID --text "..."` → gather evidence
2. `investigation-crud.sh add-evidence --id UUID --hypothesis N --source SRC --finding TEXT`
3. `investigation-crud.sh set-verdict --id UUID --hypothesis N --verdict confirmed --reason "..."`
4. If > 10 hypotheses: prompt for consolidation (likely scope creep)

Evidence sources: freeform strings (`mssql:staging-db`, `ado:MyProject`, `linear`, `local:grep`, etc.)

---

## Eliminated Approaches

Track approaches that were tried and failed (distinct from hypotheses):

```bash
investigation-crud.sh add-eliminated --id UUID --approach "Restarted the API service" --reason "Data still stale after restart"
```

This prevents future agents from retrying failed approaches.

---

## Persistence

`investigation-crud.sh` handles all persistence automatically:
- Atomic writes (temp file + `os.replace`)
- Auto-updates `updated` timestamp on every write
- Creates `~/.superpowers/investigations/` and `.gitignore` on first use
- Schema: see `references/schema.md`

---

## Concurrent Investigations

UUID-based filenames. One active → resume. Multiple active → `investigation-crud.sh list --status active`, agent picks one.

## Markdown Export

Generate on demand for pause/handoff:

```bash
investigation-crud.sh export --id UUID
```

Rules: `verdict: null` → ACTIVE. `currentTheory` → `← CURRENT THEORY` suffix. Generated on demand only, not auto-synced.

---

## Skill Connections

| Skill | Integration |
|-------|-------------|
| `thinking-orchestrator` | Routes "debugging a bug, starting investigation" here |
| `todo-management` | On resolution (if fix needed), create fix task tagged `#investigation-<short-id>` |
| `systematic-debugging` | Companion: debugging process → investigation-state stores context |
| `think-twice` | When stuck with >3 hypotheses rejected, get fresh perspective |

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Forgot to update JSON after verdict | Always write JSON immediately after each hypothesis verdict |
| Retried an eliminated approach | Check `eliminated` array before trying any approach |
| Lost investigation on session end | Pause with `set-status --status paused`, then `export` before ending |
| JSON corruption from interrupted write | Atomic write pattern (temp + mv) prevents this |
| Investigation scope creep (>10 hypotheses) | Prompt for consolidation — likely multiple bugs |
