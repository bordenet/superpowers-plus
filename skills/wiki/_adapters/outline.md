# Outline Adapter

Configuration for [Outline](https://www.getoutline.com/) wiki platform.

## MCP Tools

| Operation | MCP Tool |
|-----------|----------|
| `create_page` | `create_document_outline` |
| `update_page` | `update_document_outline` |
| `get_page` | `get_document_outline` |
| `search_pages` | `search_documents_outline` |
| `delete_page` | `archive_document_outline` |
| `move_page` | `move_document_outline` |
| `list_collections` | `list_collections_outline` |
| `verify_link` | `get_document_outline` (check if exists) |

Additional tools:
- `ask_documents_outline` — Natural language queries
- `sync_to_local_outline` — Download wiki to local filesystem
- `push_document_outline` — Push local file to wiki
- `sync_status_outline` — Check sync status

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `OUTLINE_API_TOKEN` | ✅ Yes | API token from Outline settings | `ol_api_xxxxxxxxxxxx` |
| `OUTLINE_BASE_URL` | ❌ No | Wiki instance URL | `https://wiki.example.com` |

## Getting Your API Token

1. Log into your Outline instance
2. Navigate to **Settings** → **API** (or `/settings/tokens`)
3. Click **Create API Token**
4. Copy the token (format: `ol_api_...`)

## URL Pattern

```
https://[base-url]/doc/[page-title-slug]-[url-id]
```

Example: `https://wiki.example.com/doc/getting-started-abc123xyz`

**Important:** Use the `url` field from API responses, not constructed URLs. See `wiki-editing` skill for details.

## Field Mappings

| Generic | Outline Field | Notes |
|---------|---------------|-------|
| `title` | `title` | Required |
| `content` | `text` | Markdown format |
| `collection_id` | `collectionId` | UUID |
| `parent_id` | `parentDocumentId` | UUID (optional) |
| `url` | `url` | Use for user-facing links |
| `url_id` | `urlId` | Use for API calls |
| `id` | `id` | Internal UUID |

## Anchor Format

Outline uses `#h-section-name` format for anchors:

```markdown
[Section Name](#h-section-name)
```

## API Base URL

Set via `OUTLINE_BASE_URL` environment variable. Example: `https://your-wiki.example.com/api`

All endpoints:
- `POST /documents.info` — Get document
- `POST /documents.create` — Create document
- `POST /documents.update` — Update document
- `POST /documents.delete` — Delete document
- `POST /documents.search` — Search documents
- `POST /collections.list` — List collections

## Curl Fallback

When MCP tools are unavailable:

```bash
source .env
curl -s -X POST "https://wiki.example.com/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "document-id-or-url-slug"}'
```

## Known Limitations

| Feature | Limitation |
|---------|------------|
| Table column widths | Lost on API update (ProseMirror metadata) |
| Document embeds | Lost on API update (ProseMirror metadata) |
| Custom formatting | May not survive round-trip |

See `wiki-editing` skill for detailed workarounds.
