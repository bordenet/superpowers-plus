# Jira Adapter

Configuration for Jira issue tracking.

## MCP Tools Required

| Operation | MCP Tool / API |
|-----------|----------------|
| create_issue | `jira-api` or REST API |
| update_issue | `jira-api` or REST API |
| search_issues | JQL queries |
| get_issue | `jira-api` or REST API |
| add_comment | `jira-api` or REST API |
| verify_link | `jira-api` or REST API — `GET /rest/api/3/issue/{key}` — confirms URL resolves to a valid issue |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `JIRA_BASE_URL` | Jira instance URL | `https://mycompany.atlassian.net` |
| `JIRA_EMAIL` | Account email | `user@example.com` |
| `JIRA_API_TOKEN` | API token | `...` |
| `JIRA_PROJECT_KEY` | Project key | `PROJ` |

## URL Pattern

```text
https://[instance].atlassian.net/browse/[KEY]-[number]
```

Example: `https://mycompany.atlassian.net/browse/PROJ-123`

## Minimum `get_issue` Output Contract Mapping

| Normalized Field | Jira Response Field | Notes |
|-----------------|---------------------|-------|
| `identifier` | `key` | e.g. `"PROJ-123"` |
| `url` | Construct: `{baseUrl}/browse/{key}` | Not directly in response body |
| `title` | `fields.summary` | Issue title |
| `status` | `fields.status.name` | Workflow state string |
| `updatedAt` | `fields.updated` | ISO 8601 timestamp |

## Field Mappings

| Generic | Jira Field | Notes |
|---------|------------|-------|
| title | `fields.summary` | Required |
| description | `fields.description` | Atlassian Doc Format or Markdown |
| labels | `fields.labels` | Array of strings |
| assignee | `fields.assignee.accountId` | Atlassian account ID |
| status | `fields.status.name` | Workflow state |
| priority | `fields.priority.name` | Highest, High, Medium, Low, Lowest |

## Issue Types

| Type | Use For |
|------|---------|
| Story | Features |
| Bug | Defects |
| Task | Tasks |
| Epic | Large initiatives |
| Sub-task | Child items |

## Setup

1. Create API token: Atlassian Account → Security → API tokens
2. Find project key: Your Jira URL `[instance].atlassian.net/browse/[KEY]-...`
3. Configure MCP server with Jira integration (if available)

## Note

Jira MCP support varies. You may need to use direct REST API calls via `web-fetch` or a custom MCP server.
