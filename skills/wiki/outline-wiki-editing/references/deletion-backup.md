# Pre-Deletion Backup Procedure

Before calling `documents.delete` or `documents.archive`, you MUST create a local backup.

## Backup Directory

```
_deleted_backups/
```

OneDrive-synced, persists across sessions.

## Required Steps

### Step 1: Fetch full document content

```
# MCP (preferred)
get_document_outline(id: "document-id")

# Curl fallback
curl -s -X POST "https://wiki.int.[company].net/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}' | jq '.data'
```

### Step 2: Save backup file with YAML frontmatter

Filename: `{YYYY-MM-DD}_{document-id}_{url-slug}.md`

```yaml
---
document_id: "uuid-here"
title: "Page Title"
url: "/doc/page-slug-xyz123"
deleted_at: "ISO timestamp"
collection_id: "uuid"
parent_document_id: "uuid or null"
created_by: "Author Name"
backup_reason: "Why this was deleted"
---

[Original document content here]
```

### Step 3: Verify backup exists

```bash
ls -la "_deleted_backups/{filename}.md"
cat "_deleted_backups/{filename}.md" | head -20
```

### Step 4: Only THEN delete

```bash
# MCP: archive_document_outline(id: "...")
# Curl:
curl -s -X POST "https://wiki.int.[company].net/api/documents.delete" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

## Recovery

**Option 1: Outline Trash**

```bash
curl -s -X POST "https://wiki.int.[company].net/api/documents.restore" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

**Option 2: Recreate from backup**

```
create_document_outline(
  title: "[from frontmatter]",
  text: "[content after frontmatter]",
  collectionId: "[from frontmatter]",
  parentDocumentId: "[from frontmatter, if not null]",
  publish: true
)
```

Note: Recreating generates a NEW document ID. Original URL slug is NOT preserved.

## Deletion Without Backup = Policy Violation

No exceptions. STOP → backup → verify → delete.
