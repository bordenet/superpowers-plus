# GitHub Issues Adapter

Configuration for GitHub Issues tracking.

## MCP Tools Required

| Operation | MCP Tool | API Path |
|-----------|----------|----------|
| create_issue | `github-api` | `POST /repos/{owner}/{repo}/issues` |
| update_issue | `github-api` | `PATCH /repos/{owner}/{repo}/issues/{number}` |
| search_issues | `github-api` | `GET /search/issues` |
| get_issue | `github-api` | `GET /repos/{owner}/{repo}/issues/{number}` |
| add_comment | `github-api` | `POST /repos/{owner}/{repo}/issues/{number}/comments` |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | Personal access token | `ghp_...` |
| `GITHUB_OWNER` | Repository owner | `my-org` |
| `GITHUB_REPO` | Repository name | `my-repo` |

## URL Pattern

```
https://github.com/[owner]/[repo]/issues/[number]
```

Example: `https://github.com/my-org/my-repo/issues/123`

## Field Mappings

| Generic | GitHub Field | Notes |
|---------|--------------|-------|
| title | `title` | Required |
| description | `body` | Markdown supported |
| labels | `labels` | Array of label names |
| assignee | `assignees` | Array of usernames |
| status | state (`open`/`closed`) | Limited states |
| priority | N/A | Use labels instead |

## Setup

1. Create PAT: GitHub Settings → Developer settings → Personal access tokens
2. Grant `repo` scope for private repos, `public_repo` for public
3. Configure MCP server with GitHub integration
