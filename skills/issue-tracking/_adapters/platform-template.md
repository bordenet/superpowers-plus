# Issue Tracker Adapter Template

Use this file as the starting point for a provider-specific issue-tracker adapter.
Copy to `skills/issue-tracking/_adapters/{your-platform}.md` and fill in each section.

## Required Operations

All six operations defined in `adapter-interface.md` must be documented here.

| Operation | MCP tool or API call | Notes |
|-----------|---------------------|-------|
| `create_issue` | _fill in_ | Title, description, labels, assignee |
| `update_issue` | _fill in_ | Fields: status, assignee, labels, etc. |
| `get_issue` | _fill in_ | Returns full issue details by exact platform-native identifier (key, number, or ID) |
| `search_issues` | _fill in_ | Query syntax for this platform |
| `add_comment` | _fill in_ | Adds text comment to an existing issue |
| `verify_link` | _fill in_ | Confirms a URL resolves to a valid issue |

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
