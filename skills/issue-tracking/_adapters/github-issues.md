# GitHub Issues Adapter

Configuration for GitHub Issues tracking.

## MCP Tools Required

| Operation | MCP Tool | API Path |
|-----------|----------|----------|
| create_issue | `github-api` | `POST /repos/{owner}/{repo}/issues` |
| update_issue | `github-api` | `PATCH /repos/{owner}/{repo}/issues/{number}`. **Precondition: validate as non-PR issue via `get_issue`/`verify_link` before mutating.** |
| search_issues | `github-api` | `GET /search/issues` — always include `is:issue` in query to exclude PRs (e.g. `q=is:issue repo:{owner}/{repo} {query}`) |
| get_issue | `github-api` | `GET /repos/{owner}/{repo}/issues/{number}` — looks up by **issue number** (not GitHub's global `id` field). **Important: this endpoint also returns PRs. Verify response is not a PR by checking that `pull_request` field is absent before treating as a valid issue.** |
| add_comment | `github-api` | `POST /repos/{owner}/{repo}/issues/{number}/comments`. **Precondition: same PR-separation requirement as `update_issue`.** |
| verify_link | `github-api` | `GET /repos/{owner}/{repo}/issues/{number}` — resolve URL to issue number, then call endpoint. Returns `{exists: true, identifier: "{number}", entityType: "issue"}` if `pull_request` field absent; returns `{exists: true, identifier: "{number}", entityType: "pull_request"}` if `pull_request` field present; returns `{exists: false, identifier: null, entityType: "unknown"}` on 404. |

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

## Identifier Normalization

GitHub issue identifiers appear in two forms in the wild:

| Human-facing form | Exact lookup input | Notes |
|-------------------|--------------------|-------|
| `#42` | `42` (bare number) | Strip the `#` before passing to `get_issue` |
| `owner/repo#42` | `42` | Strip owner/repo prefix and `#` |

Always strip the `#` prefix and any `owner/repo` prefix before passing the identifier to `get_issue`.

## Minimum `get_issue` Output Contract Mapping

| Normalized Field | GitHub Response Field | Notes |
|-----------------|----------------------|-------|
| `exists` | HTTP 200 = `true`; 404 = `false` | Check HTTP status, not body |
| `entityType` | `"issue"` if `pull_request` field absent; `"pull_request"` if `pull_request` field present; `"unknown"` on 404 | **Consumer skills must reject any non-`"issue"` result before mutation or cross-reference** |
| `identifier` | `number` (as string) | e.g. `"42"` (strip any `#` prefix before lookup) |
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
