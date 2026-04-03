# Adapter Interface

All issue tracker adapters must implement these operations.

## Required Operations

| Operation | Input | Output |
|-----------|-------|--------|
| `create_issue` | title, description, labels, assignee | created issue identifier and URL |
| `update_issue` | identifier (platform-native key, number, or ID), fields | success/failure |
| `get_issue` | exact platform-native identifier (key, number, or ID) | structured result including `exists`, `entityType`, `identifier`, `url`, `title`, `status`, `updatedAt` — see Minimum `get_issue` Output Contract below |
| `search_issues` | query | list of issues |
| `add_comment` | identifier (platform-native key, number, or ID), text | comment ID |
| `verify_link` | url | structured result: `{exists: bool, identifier: string\|null, entityType: "issue"\|"pull_request"\|"other"\|"unknown"}` — consumers use `entityType` to distinguish issues from PRs; must not return a bare exists/not-found flag |

## Minimum `get_issue` Output Contract

Consumer skills may rely on these fields being present in the `get_issue` response. Adapters must guarantee them at minimum:

| Field | Type | Notes |
|-------|------|-------|
| `exists` | boolean | Whether the target was found |
| `entityType` | `"issue"\|"pull_request"\|"other"\|"unknown"` | Normalized target classification. See **entityType Consumer Policy** below for required handling. `"pull_request"` and `"other"` are always rejected. `"unknown"` handling depends on operation class. |
| `identifier` | string \| null | Platform-native identifier (key, number, or ID); null if not found |
| `url` | string \| null | Direct URL to the issue; null if not found |
| `title` | string \| null | Issue title/summary; null if not found |
| `status` | string \| null | Current workflow state; null if not found |
| `updatedAt` | ISO 8601 string \| null | Last modification timestamp; null if not found |

Additional fields (`assignee`, `labels`, `priority`) are optional but recommended.

## entityType Consumer Policy

Adapters classify; consumers enforce. The following policy is deterministic and applies to ALL adapters:

| entityType | Mutation paths (`update_issue`, `add_comment`) | Reference-only paths (`verify_link`, cross-references) |
|------------|-----------------------------------------------|--------------------------------------------------------|
| `"issue"` | ✅ Proceed | ✅ Proceed |
| `"pull_request"` | ❌ HARD BLOCK — do not mutate or reference as issue | ❌ HARD BLOCK — do not reference as issue |
| `"other"` | ❌ HARD BLOCK — route to the correct workflow | ❌ HARD BLOCK — do not reference as issue |
| `"unknown"` | ❌ HARD BLOCK — report cannot confirm type; do not mutate without new fetch resolving to `"issue"` | ⚠️ WARN — stop and require **explicit user confirmation** (silence, echoing, and partial responses do not count as approval) |

**When to return `"other"`:** Same-platform URLs that are clearly not issues or PRs (e.g., GitHub repo root, commit, discussion, release; Jira board, filter, project page). Adapters must not silently map these to `"unknown"`.

**When to return `"unknown"`:** Permission ambiguity, cross-workspace references, masked 404 (where the platform cannot distinguish not-found from forbidden), or any case where entity type cannot be determined. Adapters must not collapse confirmed 404s (known not-found) with access-denied responses — document which HTTP status codes map to `"unknown"` vs confirmed not-found.

**`exists` field note:** When `entityType: "unknown"` and `exists: false`, treat as confirmed not-found (hard block). When `entityType: "unknown"` and `exists` cannot be determined (permission ambiguity), retain `"unknown"` and apply the reference-only WARN policy.

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
