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

## URL Patterns

Each adapter specifies URL patterns for link verification:

```
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
