# Investigation State — Cross-Tool Evidence Gathering Patterns

> Reference material for the `investigation-state` skill.
> See `skill.md` for core guidance.

When investigating bugs that span multiple systems, use these patterns to gather evidence systematically. Log each finding to the active investigation's `evidence` array.

---

## MSSQL (via MCP tools)

### Diagnostic Queries

| Pattern | When to Use | Evidence Source |
|---------|-------------|----------------|
| Compare row counts across environments | Data migration issues | `mssql:<connection>` |
| Check recent modifications (`updated_at` columns) | Stale data suspicion | `mssql:<connection>` |
| Verify connection targets | Wrong database suspicion | `mssql:<connection>` |
| Query execution plans | Performance regressions | `mssql:<connection>` |

### Process

1. **Identify the connection** — use `list_connections_mssql` to find available connections
2. **Describe the table** — use `describe_table_mssql` to understand schema before querying
3. **Run diagnostic query** — use `query_mssql` with targeted SELECT
4. **Log finding** — record source as `mssql:<connection-name>` with a summary of what was found

### Example Evidence Entry

```json
{
  "source": "db:example-conn",
  "finding": "Users table has 1,247 rows; expected 1,500 after migration. 253 rows missing.",
  "timestamp": "2026-03-23T14:35:00Z"
}
```

---

## CI / Issue Tracker (via your configured MCP tools)

### Pipeline Run Analysis

| Pattern | When to Use | Evidence Source |
|---------|-------------|----------------|
| Check recent pipeline runs | Build/deploy failures | `ci:<project>` |
| Compare pipeline logs across runs | Intermittent failures | `ci:<project>` |
| Review PR merge history | Regression hunting | `ci:<project>` |
| Check work item state transitions | Process issues | `ci:<project>` |

### Process

1. **Identify the project** — use your issue tracker's project-list MCP tool
2. **Find relevant pipelines/PRs** — use your VCS MCP's list-pull-requests operation
3. **Check commit history** — use your VCS MCP's commit-search operation with date filters
4. **Log finding** — record source as `ci:<project-name>`

### Work Item State Tracing

When a bug correlates with a work item change:

1. Get the work item using your issue tracker's get-issue MCP operation
2. Check revision history using your issue tracker's list-revisions MCP operation
3. Look for state changes that correlate with the bug's first appearance

---

## Linear (via MCP tools)

### Issue Timeline Reconstruction

| Pattern | When to Use | Evidence Source |
|---------|-------------|----------------|
| Search related issues | Similar bugs reported | `linear` |
| Check issue history | When bug was first reported | `linear` |
| Review linked PRs | What code changes relate | `linear` |

### Process

1. **Search for related issues** — use `search_issues_linear` with relevant keywords
2. **Get issue details** — check status, assignee, labels, priority
3. **Check user's issues** — use `get_user_issues_linear` if investigating user-specific problems
4. **Log finding** — record source as `linear`

---

## Wiki Platform (via MCP tools)

> **Platform-specific patterns are in adapter files.** See `_adapters/` for vendor-specific wiki tool commands.

### Content Drift Detection

| Pattern | When to Use | Evidence Source |
|---------|-------------|----------------|
| Search for outdated documentation | Config/process changed but docs didn't | wiki platform |
| Compare document versions | When docs contradict observed behavior | wiki platform |
| Check recently updated pages | Correlate doc changes with bug timing | wiki platform |

### Process

1. **Search documents** — use the wiki platform's search/ask tools
2. **Check document content** — use the wiki platform's get-page tools
3. **Filter by date** — use date filters to find recently changed docs
4. **Log finding** — record source as the wiki platform name

---

## Local Tools (grep, find, git)

### Code Investigation

| Pattern | When to Use | Evidence Source |
|---------|-------------|----------------|
| `grep -r` for config values | Wrong config suspicion | `local:grep` |
| `git log --oneline` for recent changes | Regression timing | `local:git-log` |
| `git diff` between versions | What changed | `local:git-diff` |
| `find` for file existence | Missing files | `local:find` |

### Anti-Pattern Warning

Per the `adversarial-search` skill: **search for the WRONG thing, not the right thing.** If the user says value X is wrong, grep for X — don't grep for the correct value Y to confirm it exists.

---

## Cross-Tool Correlation

When evidence spans multiple tools, look for:

1. **Temporal correlation** — did a deploy (ADO) happen right before the bug appeared?
2. **Data consistency** — does the database (MSSQL) match what the API returns?
3. **Documentation drift** — do the docs (wiki) describe the current behavior or the old behavior?
4. **Ticket history** — was this bug reported before (Linear) and marked resolved prematurely?

See `evidence-synthesis.md` for the full synthesis technique.
