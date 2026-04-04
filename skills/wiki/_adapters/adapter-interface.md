# Wiki Adapter Interface

All wiki adapters must implement these operations.

## Required Operations

| Operation | Input | Output |
|-----------|-------|--------|
| `create_page` | title, content, collection_id, parent_id | page ID/URL |
| `update_page` | id, content, publish | success/failure |
| `get_page` | id or url_slug | page content + metadata |
| `search_pages` | query, collection_id | list of pages |
| `delete_page` | id | success/failure |
| `archive_page` | id | success/failure |
| `move_page` | id, target_collection_id, parent_id | success/failure |
| `list_collections` | — | list of collections |
| `verify_link` | url | exists/not-found |

## Field Mappings

Each adapter documents how generic fields map to platform-specific fields:

| Generic Field | Description |
|---------------|-------------|
| `title` | Page title |
| `content` | Page body (markdown) |
| `collection_id` | Parent collection/space |
| `parent_id` | Parent page (for nesting) |
| `url` | Canonical page URL |
| `url_id` | Short URL identifier |

## Table of Contents

Each adapter must document TOC behavior:

| Field | Required | Description |
|-------|----------|-------------|
| `toc_behavior` | Yes | `auto`, `manual`, or `unsupported` |
| `toc_syntax` | If `manual` | Markup to insert (e.g., `[[_TOC_]]`) |
| `toc_placement` | If `manual` | Where to place markup |
| `toc_anchor_format` | Optional | How heading anchors are generated |

See `platform-template.md` for value definitions.

## URL Patterns

Each adapter specifies URL patterns for link verification:

```text
[base-url]/[path-prefix]/[url-id-or-slug]
```

Example: `https://wiki.example.com/doc/page-title-abc123`

## Authentication

Each adapter documents:

- Required environment variables
- How to obtain API credentials
- Token format and permissions needed

## MCP Tools

Each adapter maps operations to available MCP tools:

| Generic Operation | MCP Tool (example) |
|-------------------|-------------------|
| `create_page` | `platform_create_page` |
| `update_page` | `platform_update_page` |
| `get_page` | `platform_get_page` |
| `search_pages` | `platform_search_pages` |

## Fallback Behavior

When MCP tools are unavailable, adapters should document:

- curl command equivalents
- Required headers and authentication
- Response parsing

## Publishing Verification Contract

Adapters MUST treat markdown safety checks as executable requirements, not prose advice.

Before `create_page` or `update_page` returns success:

1. **Pre-write artifact scan:** validate the outbound markdown for `\\[`, `\\]`, literal `&nbsp;`, literal `&mdash;`, empty hrefs, and malformed/collapsed tables.
2. **Write the page** via the platform's primary API/tool.
3. **Round-trip verification:** fetch the page again via `get_page`, re-run the same artifact scan on the persisted content, and fail closed if new artifacts appear.

The shared reference implementation is `lib/wiki-publish.js` (`assertRoundTripArtifacts`) with `tools/wiki-markdown-validate.js` as the low-level CLI for artifact scans. Platform adapters may call the publish helper directly, use `lib/wiki-markdown.js`, or shell out to the CLI, but they MUST enforce equivalent checks before reporting success.
