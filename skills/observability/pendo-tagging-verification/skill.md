---
name: pendo-tagging-verification
source: superpowers-[company]
description: Use when AUDITING or VERIFYING existing Pendo tag coverage — finding untagged features, checking coverage gaps, validating instrumentation. Read-only — does not create or modify features (use pendo-feature-tagging for that).
triggers: ["verify pendo tagging", "audit pendo coverage", "pendo tag audit", "untagged features", "pendo verification report"]
coordination:
  group: [company]
  order: 1
  requires: ['pendo-feature-tagging']
  enables: []
  escalates_to: []
  internal: false
---

# Pendo Tagging Verification

> **API:** `https://app.pendo.io/api/v1`
> **Credentials:** `PENDO_API_KEY` in `~/.codex/.env`

---

## Purpose

Cross-references deployed code against Pendo Feature definitions to identify gaps in tracking coverage. Integrates with Azure DevOps (PRs), Linear (issues), and Monday (sprints) to determine what was shipped.

**Announce at start:** "I'm using the pendo-tagging-verification skill to audit Pendo feature coverage."

---

## Input Modes

| User Says | What To Do |
|-----------|------------|
| "Verify tagging for this PR" | Pull PR diff from ADO → identify UI features → cross-ref Pendo |
| "Verify tagging for Sprint 6" | Monday board → sprint stories → Linear issues → ADO PRs → scan |
| "Verify tagging for {PREFIX}-123" | Linear issue → linked branches/PRs in ADO → scan code |
| "Check everything since Friday" | ADO merged PRs since date → scan for untagged features |

---

## Workflow

### Step 1: Determine Scope

Based on user input, gather the code changes:

**By PR:**
```
ADO MCP: repo_get_pull_request_by_id_azure-devops → get PR details
ADO MCP: repo_list_pull_request_threads_azure-devops → get PR diff context
```

**By Sprint:**
```
1. Monday MCP: get sprint stories from board 3452425919 (Delta sprint board)
2. Linear MCP: search_issues_linear for each story
3. ADO MCP: repo_list_pull_requests_by_repo_or_project_azure-devops → find linked PRs
4. Collect all diffs
```

**By Linear Issue:**
```
1. Linear MCP: search_issues_linear(query: "{PREFIX}-123")
2. ADO MCP: repo_list_pull_requests_by_repo_or_project_azure-devops → find PRs referencing {PREFIX}-123
3. Collect diffs
```

**By Date Range:**
```
ADO MCP: repo_list_pull_requests_by_repo_or_project_azure-devops(status: "Completed") → merged PRs
Filter by completion date
Collect all diffs
```

### Step 2: Identify UI Features in Code Changes

Scan the diff for new/modified UI elements that represent user-facing features:

**Include:**
- New page routes or URL paths
- Interactive components: buttons, modals, forms, dropdowns, tabs
- Components with `pendo.track()` calls already present (confirm they match Pendo)
- Components with `data-testid` attributes (likely intentionally trackable)

**Exclude:**
- Pure layout/styling changes
- Internal refactors with no UI impact
- Utility functions and helpers
- Test files

**Present identified features to the user for confirmation** before cross-referencing. Don't silently assume.

### Step 3: Cross-Reference Against Pendo

```bash
source ~/.codex/.env
# Get all Pendo features
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/feature" | jq '.[] | {id, name}' > /tmp/pendo_features.json
```

### Step 4: Match Features

Apply matching strategy in order:

1. **Exact match** (case-insensitive) — "Export CSV" matches "export csv"
2. **Normalized match** — strip whitespace, hyphens, underscores → "ExportCSV" matches "export-csv"
3. **Fuzzy/substring** — flag as "possible match, needs confirmation" → "CSV Export" ↔ "Export CSV"
4. **No match** — flag as missing

**Ambiguous matches always require user confirmation.**

### Step 5: Check Code Instrumentation

```bash
# Scan for pendo.track() in changed files
grep -rn "pendo\.track" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" <changed_files>
```

### Step 6: Generate Report

Present verification table:

```
## Pendo Tagging Verification — [SCOPE]

| Feature | Code Instrumented | Pendo Feature Exists | Status |
|---------|-------------------|----------------------|--------|
| Report Builder modal | ✓ pendo.track() in ReportBuilder.tsx | ✓ "Report Builder" | ✅ Complete |
| Export CSV button | ✗ No track call | ✗ Not defined | ❌ Needs both |
| Filter dropdown | ✓ pendo.track() in FilterBar.tsx | ✗ Not defined | ⚠️ Needs Pendo feature |

Recommended actions:
- Create Pendo feature for "Export CSV" with selector [data-testid="export-csv"]
- Create Pendo feature for "Filter Dropdown" with selector .filter-dropdown
- Add pendo.track() call to ExportButton.tsx

Shall I proceed with any of these?
```

---

## Safety Gates

<EXTREMELY_IMPORTANT>
- **Verification is read-only** — report gaps, don't auto-fix
- **Fixes require separate approval** — code instrumentation and Pendo feature creation are independent approval steps
- **Use pendo-feature-tagging skill** for actual creation/updates after user approves
</EXTREMELY_IMPORTANT>

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| Can't find PR | Wrong PR ID or repo | Verify with ADO MCP |
| Can't find Linear issue | Wrong issue key | Search with Linear MCP |
| No Pendo features returned | API key issue or no features defined | Check auth, verify in Pendo UI |
| Sprint not found | Wrong sprint name | Check Monday board 3452426100 |


## When to Use

- Auditing Pendo tag coverage across code changes
- Finding untagged UI features that shipped without Pendo instrumentation
- Coverage gap analysis before sprint retrospectives

## Failure Modes

- **No features defined** → Empty list is valid; means starting from scratch
- **API returns empty** → Verify auth key and that Pendo dashboard shows features
- **Confusing with pendo-feature-tagging** → This skill audits only. Use pendo-feature-tagging to create features
