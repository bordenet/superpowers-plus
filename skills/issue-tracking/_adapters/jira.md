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

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `JIRA_BASE_URL` | Jira instance URL | `https://mycompany.atlassian.net` |
| `JIRA_EMAIL` | Account email | `user@example.com` |
| `JIRA_API_TOKEN` | API token | `...` |
| `JIRA_PROJECT_KEY` | Project key | `PROJ` |

## URL Pattern

```
https://[instance].atlassian.net/browse/[KEY]-[number]
```

Example: `https://mycompany.atlassian.net/browse/PROJ-123`

## Field Mappings

| Generic | Jira Field | Notes |
|---------|------------|-------|
| title | `summary` | Required |
| description | `description` | Atlassian Doc Format or Markdown |
| labels | `labels` | Array of strings |
| assignee | `assignee.accountId` | Atlassian account ID |
| status | `status.name` | Workflow state |
| priority | `priority.name` | Highest, High, Medium, Low, Lowest |

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
