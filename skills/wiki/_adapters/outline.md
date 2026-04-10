# Wiki Adapter — Outline

Platform adapter for [Outline](https://www.getoutline.com/) (self-hosted or cloud).

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OUTLINE_API_URL` | Base URL of your Outline instance | `https://wiki.example.com` |
| `OUTLINE_API_KEY` | API key (Settings → API → Create token) | `ol_api_...` |

Set in `~/.codex/.env`:
```bash
WIKI_PLATFORM=outline
OUTLINE_API_URL=https://your-outline-instance.com
OUTLINE_API_KEY=ol_api_your_key_here
```

## MCP Tool Mappings

| Generic Operation | MCP Tool |
|-------------------|----------|
| `list_collections` | `list_collections_outline` |
| `create_page` | `create_document_outline` |
| `update_page` | `update_document_outline` |
| `get_page` | *(no direct MCP tool — use curl fallback with `documents.info`)* |
| `search_pages` | `list_documents_outline` (with `query`) |
| `delete_page` | *(no MCP tool — use API directly)* |
| `archive_page` | *(no MCP tool — use API directly)* |
| `move_page` | `move_document_outline` |
| `verify_link` | curl against `$OUTLINE_API_URL` |

## Field Mappings

| Generic Field | Outline Field | Notes |
|---------------|---------------|-------|
| `title` | `title` | |
| `content` | `text` | Markdown |
| `collection_id` | `collectionId` | UUID of the collection |
| `parent_id` | `parentDocumentId` | Optional; nests under parent page |
| `url` | `url` | `$OUTLINE_API_URL/doc/{title-slug}-{id}` |
| `url_id` | `urlId` | Short alphanumeric suffix in page URL |

## Table of Contents Behavior

<EXTREMELY_IMPORTANT>
Outline does NOT auto-generate an in-page TOC. toc_behavior is `manual`.
Use `+++` toggle blocks ONLY. HTML `<details>`, `:::details`, and `<summary>` render as raw tags and do NOT work.
</EXTREMELY_IMPORTANT>

| Field | Value | Notes |
|-------|-------|-------|
| `toc_behavior` | `manual` | Outline does NOT auto-generate an in-page TOC. Insert a `+++` toggle block on pages with 4+ H2/H3 headings. |
| `toc_syntax` | `+++` | Wrap a bullet list of anchor links in `+++` markers (Outline toggle block). `<details>` and `:::details` are NOT valid — they render as raw HTML. |
| `toc_placement` | After intro paragraph, before first H2. No intro paragraph? Place on first line. | |
| `toc_anchor_format` | `#h-{slug}` | Outline prepends `h-` to the slug. Never use bare `#{slug}`. |

### Correct TOC format

```markdown
+++
**Table of contents**
- [Section One](#h-section-one)
- [Section Two](#h-section-two)
  - [Sub-section](#h-sub-section)
+++
```

Slug rules: lowercase, strip non-word chars, spaces to hyphens, collapse hyphens, prepend `h-`.

## URL Patterns

Outline page URLs follow: `$OUTLINE_API_URL/doc/{title-slug}-{urlId}`

For link verification, strip the domain and verify the `urlId` suffix is resolvable via:
```bash
curl -s -H "Authorization: Bearer $OUTLINE_API_KEY" \
  "$OUTLINE_API_URL/api/documents.info" \
  -d "id={urlId}" | jq '.data.title'
```

## Fallback (MCP Unavailable)

```bash
# Create a document
curl -s -H "Authorization: Bearer $OUTLINE_API_KEY" \
     -H "Content-Type: application/json" \
     "$OUTLINE_API_URL/api/documents.create" \
     -d '{"title":"...","text":"...","collectionId":"...","publish":true}'

# Update a document
curl -s -H "Authorization: Bearer $OUTLINE_API_KEY" \
     -H "Content-Type: application/json" \
     "$OUTLINE_API_URL/api/documents.update" \
     -d '{"id":"...","text":"...","publish":true}'

# Fetch a document by ID (for round-trip verification — no direct MCP tool)
curl -s -H "Authorization: Bearer $OUTLINE_API_KEY" \
     -H "Content-Type: application/json" \
     "$OUTLINE_API_URL/api/documents.info" \
     -d '{"id":"..."}' | jq '.data.text'

# Archive a document
curl -s -H "Authorization: Bearer $OUTLINE_API_KEY" \
     -H "Content-Type: application/json" \
     "$OUTLINE_API_URL/api/documents.archive" \
     -d '{"id":"..."}'
```

## Publishing Verification Contract

1. **Pre-write scan:** Run `tools/wiki-markdown-validate.js` on the outbound markdown.
   Check for: `\\[`, `\\]`, literal `&nbsp;`, literal `&mdash;`, empty hrefs, malformed tables.
2. **Write:** Call `create_document_outline` or `update_document_outline`.
3. **Round-trip:** Re-fetch via curl `documents.info` (no direct MCP tool for ID-based fetch —
   do NOT use `list_documents_outline` for this; it performs full-text search, not ID lookup).
   Re-run the same artifact scan on the returned `.data.text`. Fail closed if new artifacts appear.

## Scope Guards (Outline-Specific)

- **Allowed write roots:** check `outline-scope.json` (managed by sp-update) before any create/move.
- **Root-level creates** require a human-placed approval token: `~/.codex/outline-approval.token`.
- See MCP scope guard docs in `~/.codex/superpowers-plus/skills/wiki/_adapters/README.md`.
