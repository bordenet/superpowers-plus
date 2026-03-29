# Pre-Edit Snapshot Procedure

Before calling `documents.update` (MCP or curl), you MUST save the current page content to a local snapshot file. This is your rollback safety net if the update truncates or corrupts the page.

## Snapshot Directory

```
~/.codex/_edit_snapshots/
```

Create if it doesn't exist. This directory persists across sessions.

## When to Snapshot

| Operation | Snapshot Required? |
|-----------|-------------------|
| `documents.update` | **YES** — always |
| `documents.create` | No — nothing to roll back to |
| `documents.delete` / `documents.archive` | Use `deletion-backup.md` instead |

## Required Steps

### Step 1: Fetch current page content

```bash
# MCP (preferred)
get_document_outline(id: "document-id")

# Curl fallback
source ~/.codex/.env
curl -s -X POST "$OUTLINE_API_URL/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}' | jq '.data'
```

Record the text length (character count) from the API response. You will need this for verification.

### Step 2: Save snapshot file

**Filename:** `{document-uuid}.md` — one file per document, overwritten on each new edit cycle.

```yaml
---
document_id: "uuid-here"
title: "Page Title"
url: "/doc/page-slug-xyz123"
revision: 42
snapshot_at: "2026-03-25T18:30:00Z"
text_length: 12345
collection_id: "uuid"
parent_document_id: "uuid or null"
---

[Full original document text here — unmodified]
```

Use `save-file` to write the snapshot. Never use heredocs.

### Step 3: Verify snapshot integrity

```bash
# Check file exists and has content
wc -c ~/.codex/_edit_snapshots/{document-uuid}.md
```

**Integrity check:** The file's content (after YAML frontmatter) must be ≥ the `text_length` recorded in Step 1. If the snapshot is shorter than the original, the snapshot itself is truncated — do NOT proceed with the edit.

### Step 4: Proceed with edit

Only after the snapshot is verified, apply your changes and call `documents.update`.

### Step 5: Post-update verification

After the update returns, re-fetch the page and verify:

1. **Length check:** Updated text length ≥ original text length (unless content was intentionally removed).
2. **Tail check:** The last heading or paragraph of the page is still present.
3. **Artifact check:** No `\[`, `\]`, literal `&nbsp;`, or other escape artifacts.
4. **Structure check:** Opening and closing `+++` toggles are balanced.

If ANY check fails → **restore immediately** from the snapshot (see Recovery below).

## Retention Policy

- **One snapshot per document.** Each new edit cycle overwrites the previous snapshot for that document.
- **Snapshots older than 30 days** may be purged. After 30 days, use Outline's built-in revision history for recovery.
- **Never delete a snapshot** for a page you just edited in the current session.

## Recovery

If post-update verification fails, restore the page from the snapshot:

```bash
# MCP
update_document_outline(
  documentId: "uuid-from-frontmatter",
  text: "[content after YAML frontmatter]",
  publish: true
)

# Curl fallback
CONTENT=$(sed '1,/^---$/d' ~/.codex/_edit_snapshots/{uuid}.md | sed '1,/^---$/d')
ESCAPED=$(echo "$CONTENT" | jq -Rs .)
curl -s -X POST "$OUTLINE_API_URL/documents.update" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"DOCUMENT_UUID\", \"text\": $ESCAPED, \"publish\": true}"
```

After restoring, re-fetch and verify the page is back to its original state.

## Sub-Agent Safety

Sub-agents editing wiki pages MUST follow this same procedure. However:

- **Large pages (>5,000 chars):** Sub-agents may not have enough context to hold the full page text while constructing edits. For mid-page text surgery on large pages, prefer doing the edit in the main agent.
- **Sub-agents MUST report** the text length before and after their edit. If `after < before` and no content was intentionally removed, the edit is bad — restore from snapshot.
- **Prepend/append operations** are safer than mid-page replacements for sub-agents.

## Snapshot Without Edit = Policy Violation

If you snapshot a page, you MUST either:
1. Complete the edit and verify it, OR
2. Explicitly abandon the edit (snapshot remains for safety).

Never leave a page in a damaged state because "the snapshot exists." The snapshot is a safety net, not permission to be careless.
