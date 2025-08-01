# Linear Adapter

Configuration for Linear.app issue tracking.

## MCP Tools Required

| Operation | MCP Tool |
|-----------|----------|
| create_issue | `create_issue_linear` |
| update_issue | `update_issue_linear` |
| search_issues | `search_issues_linear` |
| get_user_issues | `get_user_issues_linear` |
| add_comment | `add_comment_linear` |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LINEAR_API_KEY` | API key from Linear settings | `lin_api_...` |
| `LINEAR_TEAM_KEY` | Your team's URL key | `my-team` |
| `LINEAR_ISSUE_PREFIX` | Issue prefix | `PROJ` |

## URL Pattern

```
https://linear.app/[team-key]/issue/[PREFIX]-[number]
```

Example: `https://linear.app/my-team/issue/PROJ-123`

## Field Mappings

| Generic | Linear Field | Notes |
|---------|--------------|-------|
| title | `title` | Required |
| description | `description` | Markdown supported |
| labels | `labelIds` | Array of UUIDs |
| assignee | `assigneeId` | User UUID |
| status | `stateId` | Workflow state UUID |
| priority | `priority` | 0-4 (0=none, 1=urgent) |

## Setup

1. Get API key: Linear Settings → API → Personal API keys
2. Find team key: Your Linear URL `linear.app/[team-key]/...`
3. Configure MCP server with Linear integration

