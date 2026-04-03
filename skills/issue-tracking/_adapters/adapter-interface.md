# Adapter Interface

All issue tracker adapters must implement these operations.

## Required Operations

| Operation | Input | Output |
|-----------|-------|--------|
| `create_issue` | title, description, labels, assignee | created issue identifier and URL |
| `update_issue` | identifier (platform-native key, number, or ID), fields | success/failure |
| `get_issue` | exact platform-native identifier (key, number, or ID) | issue details |
| `search_issues` | query | list of issues |
| `add_comment` | identifier (platform-native key, number, or ID), text | comment ID |
| `verify_link` | url | structured result: `{exists: bool, identifier: string\|null, entityType: "issue"\|"pull_request"\|"other"\|"unknown"}` — consumers use `entityType` to distinguish issues from PRs; must not return a bare exists/not-found flag |

## Minimum `get_issue` Output Contract

Consumer skills may rely on these fields being present in the `get_issue` response. Adapters must guarantee them at minimum:

| Field | Type | Notes |
|-------|------|-------|
| `exists` | boolean | Whether the target was found |
| `entityType` | `"issue"\|"pull_request"\|"other"\|"unknown"` | Normalized target classification. Consumer skills must stop and reject non-`"issue"` values before mutating or referencing the target. |
| `identifier` | string \| null | Platform-native identifier (key, number, or ID); null if not found |
| `url` | string \| null | Direct URL to the issue; null if not found |
| `title` | string \| null | Issue title/summary; null if not found |
| `status` | string \| null | Current workflow state; null if not found |
| `updatedAt` | ISO 8601 string \| null | Last modification timestamp; null if not found |

Additional fields (`assignee`, `labels`, `priority`) are optional but recommended.

## Field Mappings

Each adapter documents how generic fields map to platform-specific fields:

| Generic Field | Description |
|---------------|-------------|
| `title` | Issue title/summary |
| `description` | Issue body/description |
| `labels` | Tags/labels/components |
| `assignee` | Assigned user |
| `status` | Workflow state |
| `priority` | Priority level |

## URL Patterns

Each adapter specifies the URL pattern for link verification:

```text
[base-url]/[project-or-team]/[issue-type]/[id-or-key]
```

## Authentication

Each adapter documents required environment variables for authentication.
