---
name: issue-editing
source: superpowers-plus
triggers: ["update ticket", "edit issue", "change status of", "assign issue to", "add label to issue"]
anti_triggers: ["create ticket", "create issue", "open a ticket", "file a bug"]
description: Use when updating issues in your project tracker. Enforces fetch-before-edit workflow to prevent stale updates, validates field changes, detects concurrent modifications.
summary: "Use when: updating existing issues. Skip when: creating new issues."
coordination:
  group: issue-tracking
  order: 2
  requires: []
  enables: ['issue-verify']
  escalates_to: []
  internal: false
---

# Issue Editing

> **Purpose:** Prevent stale updates and race conditions when modifying issues
> **Pattern:** Mirrors wiki editing — always fetch current state before modifying
> **Adapter:** See `_adapters/` for platform-specific configuration
>
> **Wrong skill?** Creating new issues → `issue-authoring`. Verifying issue identifiers → `issue-verify`. Adding comments → `issue-comment-debunker`.

## When to Use

- Updating status, assignee, labels, or any field on an existing issue/ticket
- Editing issue descriptions or titles after initial creation
- Bulk-updating issues (apply fetch-before-edit to each one)

---

## ALWAYS Fetch Before Edit

<EXTREMELY_IMPORTANT>

**Before calling your adapter's `update_issue` operation, you MUST:**

1. **Fetch current issue state** — Call `get_issue` with the platform-native identifier
2. **Validate the target type** — Check the `get_issue` response:
   - If `exists: false` → **STOP. Report identifier not found. Do not mutate.**
   - If `entityType: "pull_request"` or `"other"` → **STOP. Route to the appropriate non-issue workflow. Do not call update_issue.**
   - If `entityType: "unknown"` → **STOP. Hard-block on mutation paths. Report to user that the target's type cannot be confirmed. Do not mutate without a new fetch that resolves to `"issue"`.**
3. **Use fetched data as base** — Don't assume memory reflects current state
4. **Check for recent changes** — `updatedAt` timestamp indicates modifications

**Why this matters:**

- Multiple agents/users may edit the same issue
- Memory may reflect stale state from earlier in conversation
- Prevents overwriting recent changes with outdated data

</EXTREMELY_IMPORTANT>

---

## Pre-Edit Workflow

```text
┌─────────────────────────────────────────────────────────────┐
│ BEFORE ANY update_issue CALL                                │
├─────────────────────────────────────────────────────────────┤
│ 1. FETCH: Call get_issue via adapter                        │
│ 2. VERIFY: exists:true AND entityType:"issue" — else STOP   │
│ 3. CHECK: updatedAt for recent modifications                │
│ 4. COMPARE: Your intended changes vs current state          │
│ 5. UPDATE: Only then call adapter's update operation        │
└─────────────────────────────────────────────────────────────┘
```

---

## Field Validation Before Update

| Field | Validation Required |
|-------|---------------------|
| `status` | Verify state exists in your workflow |
| `assignee` | Verify the assignee exists AND that the value uses the platform-specific identifier format (e.g., GitHub username, Jira accountId) — not an email address unless your adapter explicitly maps from email |
| `labels` | Verify each label exists |
| `priority` | Use platform-appropriate values |
| `title` | Follow title standards (see issue-authoring) |
| `description` | Invoke issue-link-verification for URLs |

---

## Concurrent Edit Detection

**Check `updatedAt` timestamp before updating.**

**If issue was updated in the last 5 minutes:**

```text
⚠️ RECENT MODIFICATION DETECTED

Issue: [IDENTIFIER]
Last updated: [timestamp]
By: [user if available]

Your edit may conflict with recent changes.
Options:
1. Proceed with update (may overwrite recent changes)
2. Fetch fresh state and review before editing
3. Cancel update
```

---

## Status Transitions

**Common workflow transitions (configure for your platform):**

| From | To (Valid) |
|------|------------|
| New/Triage | Backlog, Ready, Canceled |
| Backlog | Ready, In Progress |
| Ready/Todo | In Progress, Backlog |
| In Progress | Done, Ready, Canceled |
| Done | In Progress (reopen) |

**Before changing status, verify transition is valid for your workflow.**

---

## Hallucination Prevention

<EXTREMELY_IMPORTANT>

**NEVER fabricate issue identifiers:**

| Behavior | Action |
|----------|--------|
| User says "update [IDENTIFIER]" | Use get_issue first — issue may not exist |
| Issue not found via get_issue | Report: "Issue [IDENTIFIER] not found" |
| Assuming issue identifier | ALWAYS query first via get_issue |

</EXTREMELY_IMPORTANT>

---

## Edit Checklist

```text
Before EVERY update:
1. FETCH — Query issue by platform-native identifier
2. VERIFY — Issue exists, identifier is confirmed
3. CHECK — Recent modifications (updatedAt)
4. VALIDATE — Field values are valid
5. UPDATE — Only then modify
```

---

## Example

```bash
# Before editing: capture current state for comparison
# After editing: verify changes applied correctly
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill issue-editing
```

## Failure Modes

- **Stale update:** Editing without fetching — overwrites a teammate's concurrent change
- **Stale identifier:** Using a memorized or guessed identifier instead of fetching it fresh
- **Field type mismatch:** Passing a label name instead of the platform-specific label identifier (e.g., label ID, label name string — depends on tracker)

## Companion Skills

- **issue-authoring**: Standards for creating issues
- **issue-link-verification**: Verify URLs before posting
- **issue-comment-debunker**: Evidence-based comments
- **issue-verify**: Post-edit verification
