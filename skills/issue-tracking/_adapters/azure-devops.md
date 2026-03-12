# Azure DevOps Adapter

Configuration for Azure DevOps work item tracking.

## MCP Tools Required

| Operation | MCP Tool |
|-----------|----------|
| create_issue | `wit_create_work_item_azure-devops` |
| update_issue | `wit_update_work_item_azure-devops` |
| search_issues | `wit_get_query_results_by_id_azure-devops` |
| get_issue | `wit_get_work_item_azure-devops` |
| add_comment | `wit_add_work_item_comment_azure-devops` |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_DEVOPS_ORG` | Organization name | `my-org` |
| `AZURE_DEVOPS_PROJECT` | Project name | `my-project` |
| `AZURE_DEVOPS_PAT` | Personal access token | `...` |

## URL Pattern

```
https://dev.azure.com/[org]/[project]/_workitems/edit/[id]
```

Example: `https://dev.azure.com/my-org/my-project/_workitems/edit/123`

## Field Mappings

| Generic | Azure DevOps Field | Notes |
|---------|-------------------|-------|
| title | `System.Title` | Required |
| description | `System.Description` | HTML supported |
| labels | `System.Tags` | Semicolon-separated |
| assignee | `System.AssignedTo` | User email |
| status | `System.State` | Workflow state |
| priority | `Microsoft.VSTS.Common.Priority` | 1-4 |

## Work Item Types

| Type | Use For |
|------|---------|
| User Story | Features |
| Bug | Defects |
| Task | Sub-tasks |
| Epic | Large initiatives |

## Setup

1. Create PAT: Azure DevOps → User Settings → Personal access tokens
2. Grant Work Items (Read, Write) scope
3. Configure MCP server with Azure DevOps integration
