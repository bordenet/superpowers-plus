# Design: Investigation State Management for Debugging

> ⚠️ **STATUS: NOT IMPLEMENTED** — This is a design spec, not documentation of existing functionality.

**Status:** Approved
**Author:** Matt Bordenet (via Augment Agent)
**Date:** 2026-03-23
**Design Triad:** Completed (3 options evaluated, 3 rounds of harsh review)

---

## 1. Problem Statement

### The Gap

Long debugging sessions (20+ turns) lose investigation context across sessions. When a debug session spans multiple conversations or gets interrupted, there is no structured way to record:

- Hypotheses tested and their outcomes
- Evidence gathered from multiple tools (MSSQL, Azure DevOps, Linear, local code)
- Approaches eliminated and why
- Current working theory and next steps

### Root Cause

The existing skill ecosystem has task management (`todo-management`) and debugging methodology (`systematic-debugging`), but nothing bridges them — no skill persists the *forensic state* of an investigation.

### Impact

- Agents restart investigations from scratch after context loss
- Failed approaches get retried because there is no elimination log
- Cross-session handoff requires manual reconstruction of debugging context
- No audit trail for post-incident review

---

## 2. Selected Design: Companion Skill with JSON State + Markdown Export (Option C)

### Architecture

```bash
skills/engineering/investigation-state/
├── skill.md              # Core skill definition
└── references/
    ├── schema.md         # JSON schema reference
    ├── cross-tool-patterns.md  # Evidence gathering patterns per tool
    ├── evidence-synthesis.md   # Multi-source evidence synthesis technique
    └── git-bisect.md          # Regression hunting via git bisect
```

Runtime state stored in (path relative to user's **home directory**):

```python
~/.superpowers/investigations/
├── <uuid>.json           # Authoritative investigation state (machine-readable)
└── .gitignore            # Excludes investigations from version control
```

**Why `~/` not project-relative:** Investigations span multiple repos and sessions. A home-directory location ensures the agent always finds them regardless of CWD. This mirrors `todo-management` which uses `~/.codex/TODO.md`.

### Skill Frontmatter

```yaml
---
name: investigation-state
source: superpowers-plus
triggers: ["start investigation", "investigate this bug", "resume investigation",
           "what have we tried", "investigation status", "debug checkpoint",
           "save investigation state", "investigation handoff"]
description: Persists debugging investigation context (hypotheses, evidence, eliminated approaches) across sessions. Companion to systematic-debugging. Use when starting, resuming, or handing off a multi-turn debugging session.
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
```

### Core Principles

1. **JSON is authoritative. Markdown is a read-only export.** The JSON file is the single source of truth. Markdown summaries are generated on demand for human review and cross-session handoff. There is no mechanism to edit the markdown directly.
2. **Skills instruct, agents execute.** This skill tells the agent what to write and where. The agent executes file operations directly (like `todo-management` instructs agents to run `todo-crud.sh`). No background process or daemon is required.
3. **Directory creation is on-demand.** The agent creates `~/.superpowers/investigations/` on first use if it doesn't exist.

### JSON Schema

All timestamps are UTC in ISO-8601 format with seconds precision (e.g., `2026-03-23T14:30:00Z`).
`currentTheory` is an integer referencing a hypothesis `id` field, or `null` if no current theory.
Evidence `source` is freeform text describing the tool used (e.g., `mssql:my-db`, `ado:MyProject`, `linear`, `local:grep`, `browser`). No strict format enforced.
Hypothesis `verdict` values: `null` (not yet tested), `"confirmed"`, `"rejected"`, `"inconclusive"`.
Markdown export renders `null` verdict as `ACTIVE`.

```json
{
  "id": "uuid-v4",
  "created": "2026-03-23T14:30:00Z",
  "updated": "2026-03-23T15:45:00Z",
  "status": "active",
  "title": "Users table returning stale data after config migration",
  "symptoms": {
    "observed": "GET /api/users returns data from before migration",
    "expected": "Should return migrated user records",
    "reproduction": "Call GET /api/users on staging after running migrate.sh"
  },
  "hypotheses": [
    {
      "id": 1,
      "text": "Connection string still points to old database",
      "evidence": [
        { "source": "mssql:staging-db", "finding": "Connection verified pointing to correct DB", "timestamp": "2026-03-23T14:35:00Z" },
        { "source": "local:grep", "finding": "Config file has correct connection string", "timestamp": "2026-03-23T14:36:00Z" }
      ],
      "verdict": "rejected",
      "verdict_reason": "Connection string is correct; issue is elsewhere"
    },
    {
      "id": 2,
      "text": "Query cache serving stale results",
      "evidence": [],
      "verdict": null,
      "verdict_reason": null
    }
  ],
  "eliminated": [
    { "approach": "Restarted the API service", "reason": "Data still stale after restart", "timestamp": "2026-03-23T14:40:00Z" }
  ],
  "currentTheory": 2,
  "nextSteps": ["Check Redis cache TTL", "Query database directly to verify data exists"],
  "toolsConsulted": ["mssql:staging-db", "local:grep", "ado:MyProject"],
  "relatedTodos": ["#investigation-abc123"],
  "relatedTickets": ["TST-123"]
}
```

### Persistence Mechanism

The agent executes file operations directly using shell commands embedded in the skill instructions:

```bash
# Create investigation directory (first use)
mkdir -p ~/.superpowers/investigations

# Generate UUID (macOS/Linux)
INVESTIGATION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Write JSON atomically via Python (avoids fragile heredocs)
python3 -c "
import json, sys
data = json.loads(sys.argv[1])
with open(sys.argv[2], 'w') as f:
    json.dump(data, f, indent=2)
" '{"id":"'"$INVESTIGATION_ID"'", ...}' \
  "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.tmp.json"

mv "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.tmp.json" \
   "$HOME/.superpowers/investigations/${INVESTIGATION_ID}.json"

# Ensure .gitignore exists (don't overwrite if already present)
[ -f "$HOME/.superpowers/investigations/.gitignore" ] || \
  echo '*.json' > "$HOME/.superpowers/investigations/.gitignore"
```

**Why atomic writes:** Protects against partial writes if the agent's session is interrupted mid-write (e.g., context window exhaustion, crash). This is defensive, not concurrency protection.

### Markdown Export Template

Generated on demand for cross-session handoff. A fresh agent can resume from this alone.

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
mssql:staging-db, local:grep, ado:MyProject

## Related
- TODOs: #investigation-abc123
- Tickets: TST-123
```

### Skill Integration

Each integration requires a **manual edit** to the target skill file:

| Existing Skill | Integration (manual edit required) |
|----------------|-------------------|
| `thinking-orchestrator` | Add routing entry: "debugging a bug, starting investigation" → `investigation-state` |
| `think-twice` | Skill instructions say: "if active investigation exists, include its markdown export in consultation prompt" |
| `todo-management` | When investigation resolves, create fix task tagged `#investigation-<short-id>` |
| `adversarial-search` | When running adversarial search during investigation, log evidence to active investigation |

**Note:** `systematic-debugging` is an upstream (`obra/superpowers`) skill — we do NOT edit it. Instead, `investigation-state` fires via its own triggers and `thinking-orchestrator` routing.

### Investigation Lifecycle

```markdown
[new] → ACTIVE → [PAUSED] → RESOLVED | ABANDONED
                     ↑           |
                     └───────────┘ (resume)
```

- **ACTIVE:** Created on trigger; hypotheses being tested, evidence being gathered
- **PAUSED:** Session ending without resolution; markdown handoff generated automatically
- **RESOLVED:** Root cause found and fix identified; linked TODO created (or explicit "no fix needed" note)
- **ABANDONED:** Investigation determined to be invalid or no longer relevant

### Concurrent Investigations

Each investigation gets a UUID-based filename. The agent manages them by:

- Listing `*.json` files in `~/.superpowers/investigations/`
- Resuming the most recent (by `updated` timestamp) if only one is active
- Asking user to select if multiple are active

### Stale Investigation Detection

On session start, the skill instructs the agent to check for stale investigations:
> "Check `~/.superpowers/investigations/` for files with `updated` > 7 days ago. If found, prompt: 'Investigation [title] has been inactive for N days. Close, archive, or resume?'"

This is a session-start check, not a background process.

---

## 3. Rejected Alternatives

### Option A: Standalone Investigation Journal (Rejected)

**Approach:** Fully independent `investigation-journal` skill with its own markdown persistence format and CRUD operations.

**Why rejected:** Creates a fully parallel persistence system (its own file format, CRUD operations, backup strategy) when the problem only requires lightweight JSON state files. Markdown-only format lacks the queryability of JSON for future tooling. The overhead of maintaining a second full persistence stack (alongside `todo-management`) outweighs the benefit of complete independence.

### Option B: Investigation Mode inside `todo-management` (Rejected)

**Approach:** Extend `todo-crud.sh` with `--mode investigation` flag, storing investigation entries in TODO.md.

**Why rejected:** Violates single-responsibility principle. TODO.md already serves task management (200+ lines); adding forensic debugging state would create cognitive overload. Investigation state is fundamentally different from task tracking — hypotheses have verdicts, not completion states. Would make the already-complex `todo-crud.sh` even harder to maintain.

---

## 4. Secondary Enhancements

These are incremental additions to existing skills, not new skills:

### 4a. Evidence Synthesis Technique

**What:** A reference document teaching agents to synthesize evidence from multiple sources into a coherent diagnostic narrative before forming their next hypothesis.

**Implementation:** New `references/evidence-synthesis.md` **in the `investigation-state` skill directory** (not upstream). The `investigation-state` skill.md references it as a technique to use when evidence spans multiple tools.

**Why here, not in upstream `systematic-debugging`:** We cannot add files to `obra/superpowers`. Placing it in `investigation-state/references/` keeps it with the skill that needs it.

### 4b. Cross-Tool Investigation Patterns

**What:** A reference document covering patterns for debugging across MCP tools (MSSQL queries, Azure DevOps pipeline logs, Linear ticket state, wiki content).

**Implementation:** New `references/cross-tool-patterns.md` in the `investigation-state` skill directory.

**Content:** Tool-specific evidence gathering patterns:

- MSSQL: diagnostic queries, connection comparison
- Azure DevOps: pipeline run analysis, work item state tracing
- Linear: issue timeline reconstruction
- Wiki: content drift detection

### 4c. Git Bisect Technique Reference

**What:** A reference document for regression hunting via git bisect.

**Implementation:** New `references/git-bisect.md` **in the `investigation-state` skill directory** (not upstream). Referenced from the skill's "Techniques" section.

**Why here, not in upstream `systematic-debugging`:** We cannot add files to `obra/superpowers`. Git bisect is a natural technique to reference when an investigation needs regression hunting.

---

## 5. Edge Case Catalog

| # | Edge Case | Handling |
|---|-----------|----------|
| 1 | JSON corruption from interrupted write | Atomic write: temp file + mv |
| 2 | Multiple concurrent investigations | UUID-based filenames, `investigation list` command |
| 3 | Investigation markdown edited directly | Not supported — JSON is authoritative, markdown is generated |
| 4 | Upstream `systematic-debugging` changes phases | Integration via coordination block, not code coupling |
| 5 | Agent skips investigation-state under pressure | Auto-trigger via `thinking-orchestrator` routing table |
| 6 | Investigation older than 7 days | Stale detection prompt: close, archive, or resume |
| 7 | More than 10 hypotheses per investigation | Prompt for consolidation — likely scope creep |
| 8 | Sensitive data in investigation files | `.gitignore` by default; evidence entries use descriptions, not raw data |
| 9 | Fresh agent needs to resume investigation | Markdown export is self-contained for cold handoff |
| 10 | Investigation resolved but TODO not created | Resolved status requires linked TODO or explicit "no fix needed" note |

---

## 6. Implementation Plan (High Level)

### Deliverables

| # | Deliverable | Location | Type | Priority |
|---|-------------|----------|------|----------|
| 1 | `investigation-state` skill.md | `skills/engineering/investigation-state/` | New skill | P1 |
| 2 | `references/schema.md` | Same directory | Reference | P1 |
| 3 | `references/cross-tool-patterns.md` | Same directory | Reference | P2 |
| 4 | `references/evidence-synthesis.md` | Same directory | Reference | P2 |
| 5 | `references/git-bisect.md` | Same directory | Reference | P3 |
| 6 | `thinking-orchestrator` routing update | `skills/productivity/thinking-orchestrator/` | Edit | P1 |

### Implementation Order

1. Create `investigation-state` skill.md with full process, schema, and lifecycle
2. Create `references/schema.md` with JSON schema documentation
3. Update `thinking-orchestrator` routing table to include investigation triggers
4. Create `references/cross-tool-patterns.md`
5. Create `references/evidence-synthesis.md`
6. Create `references/git-bisect.md`
7. Run `harsh-review.sh` and `skill-trigger-validator.sh audit`
8. Test via `./install.sh` deployment

### Success Criteria

- [ ] `investigation-state` skill fires via its own triggers and via `thinking-orchestrator` routing during bug investigations
- [ ] JSON schema validates with `python3 -c "import json; json.load(...)"`
- [ ] Markdown export generates self-contained handoff document
- [ ] `thinking-orchestrator` routes bug investigations to investigation-state
- [ ] No trigger collisions with existing skills
- [ ] `harsh-review.sh` passes
- [ ] All new files end with exactly one newline

---

## 7. Harsh Review Findings and Resolutions

### Round 1 (Design Triad)

| Finding | Resolution |
|---------|------------|
| Compliance risk — agents may skip under pressure | Added to `thinking-orchestrator` routing table for auto-trigger |
| JSON corruption from interrupted writes | Atomic write pattern (temp + mv) via Python one-liner |
| Dual-format sync risk (JSON vs markdown) | JSON authoritative, markdown is read-only generated export |
| Concurrent investigation clobbering | UUID-based filenames, list/resume commands |
| Upstream breaking changes | Integration via `coordination:` block, not code modification |

### Round 2 (Spec Review)

| Finding | Resolution |
|---------|------------|
| No trigger phrases defined | Added 8 triggers to frontmatter |
| Coordination block incomplete | Full block with group/order/requires/enables/escalates_to |
| JSON write mechanism unclear | Clarified: "Skills instruct, agents execute" + example code |
| Markdown export format missing | Full template with all sections provided |
| Auto-trigger mechanism vague | Specified manual edit to `thinking-orchestrator` routing table |
| Stale detection mechanism missing | Defined as session-start check, not background process |

### Round 3 (Adversarial Review)

| Finding | Resolution |
|---------|------------|
| `.superpowers/` path ambiguous (CWD vs home) | Fixed to `~/.superpowers/investigations/` with rationale — mirrors `~/.codex/TODO.md` |
| Heredoc in persistence code is fragile | Replaced with `python3 -c "import json..."` for safe JSON construction |
| `evidence-synthesis.md` and `git-bisect.md` target upstream (can't add files to `obra/superpowers`) | Moved all reference files into `investigation-state/references/` |
| Option A rejection rationale contradicts selected design | Revised rationale to focus on unnecessary complexity, not `todo-crud.sh` reuse |
| `.gitignore` clobbered on every create | Added `[ -f ... ] \|\|` guard to only create if missing |
| `group: debugging` has no other members | Acknowledged — group exists for future skills to join; not broken |

---

## Appendix: Composition Metadata

Composition metadata is defined in the skill frontmatter (Section 2). The key artifacts:

| Artifact | Type | Description |
|----------|------|-------------|
| `bug-report` | Consumed | User-reported bug symptoms (freeform text) |
| `observed-behavior` | Consumed | Specific observed vs. expected behavior |
| `investigation-context` | Produced | Active investigation JSON state |
| `investigation-handoff` | Produced | Markdown summary for cross-session resume |

This enables future auto-composition: `systematic-debugging` could automatically chain to `investigation-state` when the router detects an investigation is needed.
