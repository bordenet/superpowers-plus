# Wiki Editing - Examples

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Usage patterns and incident examples for wiki editing.

---

## Preferred Pattern (MCP Tools)

```
# Step 1: Fetch current state using your adapter's get_page operation
# See skills/wiki/_adapters/{platform}.md for specific tool

# Step 2: Edit content (use save-file to create temp file if needed)

# Step 3: Push update using your adapter's update_page operation
```

**Benefits:**
- No JSON escaping needed
- No auth token management
- Better error messages
- Automatic retries

---

## Pre-Create Duplicate Check Example

```
# Step 1: List children of parent document
# Use your adapter's list_pages operation

# Step 2: Check if any child has the same title
# Result: [{"title": "Existing Page"}, {"title": "Another Page"}]

# Step 3: If title exists → use update_page instead
# If title doesn't exist → safe to call create_page
```

---

## Pre-Delete Backup Example

**Step 1: Fetch full document**
```
get_page(id: "document-uuid")
# Returns full markdown content
```

**Step 2: Save backup with frontmatter**
```markdown
---
document_id: "abc123-uuid"
title: "Important Document"
url: "/doc/important-document-abc123"
deleted_at: "2026-03-12T10:30:00Z"
collection_id: "collection-uuid"
parent_document_id: "parent-uuid"
backup_reason: "Pre-deletion backup"
---

# Original Content

This is the full document content...
```

**Step 3: Verify backup exists**
```bash
ls -la $HOME/.wiki-backups/2026-03-12_abc123_important-document.md
```

**Step 4: Only then delete**
```
delete_page(id: "abc123-uuid")
```

---

## Bypass Warning Message

When wiki-editing is invoked directly (not through wiki-orchestrator):

```
⚠️ ORCHESTRATOR BYPASS DETECTED

You're about to publish directly without the wiki-orchestrator pipeline.
This SKIPS:
- ❌ De-duplication check
- ❌ Link verification (HARD GATE)
- ❌ Secret scan (HARD GATE)
- ❌ Slop detection
- ❌ Fact-check

OPTIONS:
1. 🔄 Switch to full pipeline: "Let me use wiki-orchestrator instead"
2. ⚡ Proceed anyway (ONLY for trivial edits like typo fixes)
3. ❌ Cancel

Which option?
```

---

## Scope Restriction Warning

When attempting to write outside allowed areas:

```
⛔ WIKI WRITE BLOCKED — Outside permitted scope

Target: [document title/URL]
Reason: This document is not within your allowed wiki areas.

Allowed areas:
- Personal (your name)
- Your Team
- Your product pages

This restriction prevents accidental edits to other teams' documentation.
To proceed, the user must explicitly confirm OR edit the page manually in the UI.
```

---

## Table Column Width Warning

```
⚠️ Formatting Warning: Pushing content via API may reset custom table column widths.
After this update, you may need to re-adjust column widths manually.

Proceed? [Yes/No]
```

---

## Secret Detection Examples

### ❌ Real Credentials (BLOCK)

```
Password=j69KZhsk_6935Bayn2W0ZZmA
api_key=sk-proj-abc123xyz
Bearer eyJhbGciOiJIUzI1NiIs...
connection_string="Server=prod;Password=secret123"
```

### ✅ Safe Alternatives

```
Password=${DB_PASSWORD}
Password=[REDACTED: production SQL password]
api_key=${OPENAI_API_KEY}
Bearer ${AUTH_TOKEN}
connection_string="Server=prod;Password=${SQL_PASSWORD}"
```

---

## Real Incident History

| Date | Failure | Root Cause | Prevention |
|------|---------|------------|------------|
| 2026-02-24 | SQL creds published to wiki | No secret scan | Mandatory secret detection |
| 2026-02-16 | Duplicate pages created | No dedup check | Mandatory list_pages before create |
| 2026-02-16 | Pages deleted without backup | No backup step | Mandatory pre-deletion backup |
| 2026-02-20 | Overwrote colleague's edit | No fetch before edit | Mandatory get_page first |

**These are not theoretical — they happened. Follow the checklists.**
