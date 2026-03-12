# Adapter Interface

All issue tracker adapters must implement these operations.

## Required Operations

| Operation | Input | Output |
|-----------|-------|--------|
| `create_issue` | title, description, labels, assignee | issue ID/URL |
| `update_issue` | id, fields | success/failure |
| `get_issue` | id | issue details |
| `search_issues` | query | list of issues |
| `add_comment` | issue_id, text | comment ID |
| `verify_link` | url | exists/not-found |

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

```
[base-url]/[project-or-team]/[issue-type]/[id-or-key]
```

## Authentication

Each adapter documents required environment variables for authentication.
