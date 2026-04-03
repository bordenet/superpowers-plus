# GitHub Issues Adapter

Configuration for GitHub Issues tracking.

## MCP Tools Required

| Operation | MCP Tool | API Path |
|-----------|----------|----------|
| create_issue | `github-api` | `POST /repos/{owner}/{repo}/issues` |
| update_issue | `github-api` | `PATCH /repos/{owner}/{repo}/issues/{number}` |
| search_issues | `github-api` | `GET /search/issues` |
| get_issue | `github-api` | `GET /repos/{owner}/{repo}/issues/{number}` — returns issue by numeric ID. **Important: this endpoint also returns PRs. Verify response is not a PR by checking that `pull_request` field is absent before treating as a valid issue.** |
| add_comment | `github-api` | `POST /repos/{owner}/{repo}/issues/{number}/comments` |
| verify_link | `github-api` | `GET /repos/{owner}/{repo}/issues/{number}` — confirms URL resolves to a valid issue |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | Personal access token | `ghp_...` |
| `GITHUB_OWNER` | Repository owner | `my-org` |
| `GITHUB_REPO` | Repository name | `my-repo` |

## URL Pattern

```text
https://github.com/[owner]/[repo]/issues/[number]
```

Example: `https://github.com/my-org/my-repo/issues/123`

## Minimum `get_issue` Output Contract Mapping

| Normalized Field | GitHub Response Field | Notes |
|-----------------|----------------------|-------|
| `identifier` | `number` (as string) | e.g. `"42"` |
| `url` | `html_url` | Direct browser URL |
| `title` | `title` | Issue title |
| `status` | `state` (`open` / `closed`) | Map to normalized status |
| `updatedAt` | `updated_at` | ISO 8601 timestamp |

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
