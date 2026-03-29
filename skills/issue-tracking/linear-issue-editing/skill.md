---
name: linear-issue-editing
source: superpowers-callbox
description: "Use when modifying any existing Linear issue — update status, change state, set to done/in-progress/backlog, assign, update labels, move ticket. Enforces fetch-before-edit with fail-closed preflight gates, live UUID resolution, concurrent edit detection."
summary: "Use when: changing, updating, or modifying any existing Linear issue's state, assignee, labels, or priority."
triggers: ["update Linear ticket", "edit Linear issue", "change issue status", "update issue status", "assign Linear issue", "update issue labels", "move issue to backlog", "change issue to done", "update Linear issue", "set issue state", "move Linear ticket"]
coordination:
  group: linear
  order: 1
  requires: ['linear-issue-verify']
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['create ticket', 'new ticket', 'comment on ticket', 'verify ticket']
---

# Linear Issue Editing

> **Owns:** UPDATE operations on existing issues only
> **Workspace:** `LINEAR_TEAM_NAME` / `LINEAR_TEAM_ID` from `~/.codex/.env` | https://linear.app/callbox
<!-- Config: linear/_shared/project-config.md -->

<!-- Source of truth for write gates: linear/_shared/write-invariants.md -->
## Write Gates

1. **Never fabricate issue keys** — `search_issues_linear` first. If not found → STOP.
2. **Fetch before edit** — always query current state before modifying. Never rely on memory.
3. **Use UUIDs** for labels, assignees, states — resolve live. Never pass display names or emails.
4. **Verify URLs** if description changes — wiki/ADO HARD BLOCK on failure, external WARN.
5. **On any gate failure → STOP.** Report which gate failed. Do not proceed.

---

## Preflight Evidence Block

<EXTREMELY_IMPORTANT>

**Emit this block immediately before calling `update_issue_linear`.** Do not summarize or skip fields. If `GATE != PASS`, do not call the tool.

```
PREFLIGHT: UPDATE
- issue_key: {PREFIX}-XXX
- issue_found: YES (uuid: ...) | NO → STOP
- current_state: [fetched from API]
- intended_changes: [field: old → new, ...]
- status_change: [target state live-resolved UUID] or N/A
- assignee_change: [live-resolved UUID] or N/A
- label_changes: [live-resolved UUIDs] or N/A
- updated_at: [timestamp] | RECENT_CONFLICT (<5min) → WARN user
- url_verification: [PASS/FAIL if description changed] or N/A
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed with the update. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Field Validation

| Field | Rule |
|-------|------|
| `status` | Live-resolve target state UUID. Verify state exists in your team's workflow. |
| `assigneeId` | Live-resolve user UUID. Never use email. |
| `labelIds` | Live-resolve each label UUID. |
| `priority` | Integer 0-4 (0=none, 1=urgent, 4=low). |
| `title` | Max 80 chars, specific, no key prefix. |
| `description` | If changed: verify all URLs per `url-verification.md`. If contains claims: route through `linear-comment-debunker`. |

---

## Concurrent Edit Detection

Fetch `updatedAt` as part of the preflight. If issue was modified in the last 5 minutes:

```
⚠️ RECENT MODIFICATION DETECTED
Issue: {PREFIX}-XXX | Last updated: [timestamp]
Your edit may conflict. Options:
1. Fetch fresh state and review
2. Proceed (may overwrite)
3. Cancel
```

Default: option 1 (fetch fresh).

---

## Status Transitions

Do NOT hardcode valid transitions. Instead:

1. Fetch current status from API
2. Live-resolve target state UUID
3. If the API rejects the transition, report the error — do not retry with a different state

Linear enforces valid transitions server-side. The skill's job is to ensure the target state exists and is intentional.

---

## Compound Workflows

| Intent | Sequence |
|--------|----------|
| "Close with explanation" | `linear-comment-debunker` validates comment → editing updates status → debunker posts comment |
| "Update status and comment" | editing updates status first → debunker posts comment second (not parallel) |
| "Reassign and update labels" | Single editing preflight covering both changes |
| "Edit description with investigation" | `linear-comment-debunker` validates claims in new description → editing updates |

---

## Failure Modes

| Failure | Consequence |
|---------|-------------|
| Stale state overwrite | Reverts someone else's work — fetch-before-edit prevents this |
| Wrong UUID (memorized/guessed) | Updates wrong issue or API error |
| Label name instead of UUID | Silent failure or API error |
| Status change without live resolution | May use stale/deleted state UUID |

## When to Use

- Updating Linear issue status (moving between workflow states)
- Assigning Linear issues to team members
- Changing issue labels or priority
