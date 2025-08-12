# Issue Tracker Adapters

This skill set supports multiple issue tracking platforms through adapters.

## Supported Platforms

| Platform | MCP Tools | Status |
|----------|-----------|--------|
| Linear | `create_issue_linear`, `search_issues_linear`, etc. | ✅ Full support |
| GitHub Issues | `github-api` | ✅ Full support |
| Jira | `jira-api` (if available) | 🔶 Partial |
| Azure DevOps | `wit_create_work_item_azure-devops`, etc. | ✅ Full support |

## Configuration

Set `ISSUE_TRACKER_TYPE` in your environment:

```bash
export ISSUE_TRACKER_TYPE=linear  # or github, jira, azure-devops
```

## Platform-Specific Setup

See the adapter documentation for your platform:

- [linear.md](./linear.md) - Linear.app setup
- [github-issues.md](./github-issues.md) - GitHub Issues setup
- [jira.md](./jira.md) - Jira setup
- [azure-devops.md](./azure-devops.md) - Azure DevOps setup

## Adding New Adapters

See [adapter-interface.md](./adapter-interface.md) for the required operations.
