# Issue Tracker Adapter Template

Use this file as the starting point for a provider-specific issue-tracker adapter.
Copy to `skills/issue-tracking/_adapters/{your-platform}.md` and fill in each section.

## Required Operations

All six operations defined in `adapter-interface.md` must be documented here.

| Operation | MCP tool or API call | Notes |
|-----------|---------------------|-------|
| `create_issue` | _fill in_ | Title, description, labels, assignee |
| `update_issue` | _fill in_ | Fields: status, assignee, labels, etc. |
| `get_issue` | _fill in_ | Returns full issue details by exact platform-native identifier (key, number, or ID). **Must satisfy the minimum output contract (see below).** |
| `search_issues` | _fill in_ | Query syntax for this platform |
| `add_comment` | _fill in_ | Adds text comment to an existing issue |
| `verify_link` | _fill in_ | Returns structured result: `{exists: boolean\|null, identifier: string\|null, entityType: "issue"\|"pull_request"\|"other"\|"unknown"}`. `exists: true` = confirmed found; `exists: false` = confirmed 404; `exists: null` = permission ambiguity / cannot determine (e.g. 401/403 or cross-workspace). Document how your platform maps HTTP status codes to `entityType` and to the tri-state `exists`. |

## Minimum `get_issue` Output Contract Mapping

Consumer skills rely on these normalized fields from `get_issue`. Document how your platform response maps to each:

| Normalized Field | Your Platform Response Field | Notes |
|-----------------|------------------------------|-------|
| `exists` | _fill in_ | `true` if confirmed found (HTTP 200); `false` if confirmed not found (HTTP 404); `null` if cannot determine (HTTP 401/403 or cross-workspace permission failure) — adapters must distinguish forbidden from not-found |
| `entityType` | _fill in_ | Must be `"issue"`, `"pull_request"`, `"other"`, or `"unknown"`. If your platform has no PR concept, always return `"issue"` on success. |
| `identifier` | _fill in_ | Platform-native identifier (key, number, or ID) as string |
| `url` | _fill in_ | Direct browser URL to the issue |
| `title` | _fill in_ | Issue title/summary |
| `status` | _fill in_ | Current workflow state as string |
| `updatedAt` | _fill in_ | ISO 8601 last-modified timestamp |

## Authentication

- **Environment variable(s):** _fill in (e.g., `PLATFORM_API_TOKEN`)_
- **Setup:** _fill in (e.g., generate a personal access token in Settings → API)_

## Field Mappings

| Generic Field | Platform-Specific Field | Notes |
|---------------|------------------------|-------|
| `title` | _fill in_ | |
| `description` | _fill in_ | |
| `labels` | _fill in_ | |
| `assignee` | _fill in_ | |
| `status` | _fill in_ | |
| `priority` | _fill in_ | |

## URL Pattern

```text
[base-url]/[project-or-team]/[issue-type]/[id-or-key]
```

_Example: `https://your-tracker.example.com/myproject/issues/42`_

## Platform-Specific Gotchas

_Document any quirks shared skills should not hardcode (e.g., rate limits, field formats, status transition rules)._
