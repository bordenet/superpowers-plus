# Issue Tracker Adapters

This skill set supports multiple issue tracking platforms through adapters.

## Supported Platforms

| Platform | MCP Tools | Status |
|----------|-----------|--------|
| Your current issue tracker | See your local adapter docs | ⚙️ Configure locally |
| GitHub Issues | `github-api` | ✅ Full support |
| Jira | `jira-api` (if available) | ✅ Contract complete (runtime requires jira-api or REST) |
| Other platforms | Use `platform-template.md` to create your own adapter | ⚙️ Bring your own |

## Configuration

Set `ISSUE_TRACKER_TYPE` in your environment:

```bash
export ISSUE_TRACKER_TYPE=your-tracker
```

## Platform-Specific Setup

See the adapter documentation for your platform:

- [platform-template.md](./platform-template.md) - Provider-neutral adapter template
- [github-issues.md](./github-issues.md) - GitHub Issues setup
- [jira.md](./jira.md) - Jira setup

## Adding New Adapters

See [adapter-interface.md](./adapter-interface.md) for the required operations.
