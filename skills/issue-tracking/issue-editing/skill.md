---
name: issue-editing
source: superpowers-plus
triggers: ["update ticket", "edit issue", "change status of", "assign issue to", "add label to issue"]
description: Use when updating issues in your project tracker. Enforces fetch-before-edit workflow to prevent stale updates, validates field changes, detects concurrent modifications.
---

# Issue Editing

> **Purpose:** Prevent stale updates and race conditions when modifying issues
> **Pattern:** Mirrors wiki editing — always fetch current state before modifying
> **Adapter:** See `_adapters/` for platform-specific configuration

---

## ALWAYS Fetch Before Edit

<EXTREMELY_IMPORTANT>

**Before calling your adapter's `update_issue` operation, you MUST:**

1. **Fetch current issue state** — Query the issue by key or ID
2. **Use fetched data as base** — Don't assume memory reflects current state
3. **Check for recent changes** — `updatedAt` timestamp indicates modifications

**Why this matters:**
- Multiple agents/users may edit the same issue
- Memory may reflect stale state from earlier in conversation
- Prevents overwriting recent changes with outdated data

</EXTREMELY_IMPORTANT>

---

## Pre-Edit Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ BEFORE ANY update_issue CALL                                │
├─────────────────────────────────────────────────────────────┤
│ 1. FETCH: Query issue by key using adapter                  │
│ 2. VERIFY: Issue exists and you have correct ID             │
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
| `assignee` | Verify user ID exists (not email) |
| `labels` | Verify each label exists |
| `priority` | Use platform-appropriate values |
| `title` | Follow title standards (see issue-authoring) |
| `description` | Invoke issue-link-verification for URLs |

---

## Concurrent Edit Detection

**Check `updatedAt` timestamp before updating.**

**If issue was updated in the last 5 minutes:**

```
⚠️ RECENT MODIFICATION DETECTED

Issue: [KEY]-XXX
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

**NEVER fabricate issue keys:**

| Behavior | Action |
|----------|--------|
| User says "update [KEY]-999" | Search first — issue may not exist |
| Issue not found in search | Report: "Issue [KEY]-999 not found" |
| Assuming issue ID | ALWAYS query first |

</EXTREMELY_IMPORTANT>

---

## Quick Reference

```
Before EVERY update:
1. FETCH — Query issue by key
2. VERIFY — Issue exists, ID is correct
3. CHECK — Recent modifications (updatedAt)
4. VALIDATE — Field values are valid
5. UPDATE — Only then modify
```

---

## Related Skills

- **issue-authoring**: Standards for creating issues
- **issue-link-verification**: Verify URLs before posting
- **issue-comment-debunker**: Evidence-based comments
