---
name: linear-issue-verify
source: superpowers-[company]
description: Use BEFORE referencing any Linear issue key in commits, PRs, wiki, docs, or reports. Verifies issues exist and returns current state. Also covers search, batch verification, and cross-reference validation.
summary: "Use when: referencing, searching, or reporting on Linear issues."
triggers: ["reference Linear issue", "link to Linear issue", "verify issue exists", "find Linear issues", "search issues", "sprint report", "summarize issues", "what's in backlog", "list tickets"]
coordination:
  group: linear
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['create ticket', 'edit ticket', 'comment on ticket']
---

# Linear Issue Verification

> **Owns:** READ operations — search, verify, report, cross-reference
> **No mutation.** This skill never calls create/update/comment tools.
<!-- Config: linear/_shared/project-config.md -->

## Core Rule

<EXTREMELY_IMPORTANT>

**Before writing ANY Linear issue key ({PREFIX}-XXX), verify it exists:**

```
search_issues_linear(query: "{PREFIX}-123")
```

AI agents hallucinate issue keys based on sequential patterns, prior conversations, and assumptions. Verification is mandatory, not optional.

</EXTREMELY_IMPORTANT>

---

## Search Patterns

| Intent | Query |
|--------|-------|
| By key | `search_issues_linear(query: "{PREFIX}-123")` |
| By title keywords | `search_issues_linear(query: "webhook retry", limit: 10)` |
| By assignee | `linear query: "issues assigned to [user UUID]"` |
| By status | `linear query: "issues with started state type for team cf47d4d8..."` |

---

## Commit Messages

**Format:** `[{PREFIX}-XXX] Brief description`

Before committing:
1. Verify issue exists in Linear
2. Verify issue is not Done/Canceled (unless reopening)

---

## Cross-Reference Validation

### Linear ↔ Azure DevOps

When linking PRs to Linear issues:
1. Verify Linear issue: `search_issues_linear(query: "{PREFIX}-123")`
2. Verify ADO PR: `repo_get_pull_request_by_id_azure-devops(pullRequestId: 1234)` (if tool available)
3. Only then assert the link

If ADO MCP tools are not available, verify PR existence via `web-fetch` to the ADO URL.

### Linear ↔ Wiki

When referencing issues in wiki pages:
1. Verify issue exists
2. Use `url` field from Linear response for the canonical link
3. Never construct `linear.app/[company]/issue/...` URLs from memory

---

## Batch Verification (Reports/Changelogs)

For bulk operations, verify all references and produce a report:

```
## Issue Verification Report
| Key | Status | Title | Verified |
|-----|--------|-------|----------|
| DELTA-123 | Done | Implement X | ✅ |
| DELTA-456 | In Progress | Fix Y | ✅ |
| DELTA-789 | — | — | ❌ NOT FOUND |
Summary: 2 verified, 1 not found
```

If issue not found: `{PREFIX}-XXX: [Not found in Linear — may have been deleted]`

---

## Incident Log

| Date | Incident | Resolution |
|------|----------|------------|
| 2026-02-18 | Referenced DELTA-999 in changelog — didn't exist | Verification added |
| 2026-02-20 | Linked PR to deleted issue | Cross-reference validation added |

---

## Failure Modes

| Failure | Consequence |
|---------|-------------|
| Assumed issue exists (sequential pattern) | Broken references, misleading docs |
| Used stale state from memory | Report shows wrong status |
| Mixed up key numbers across conversations | Wrong issue linked |

## When to Use

- Before referencing any Linear issue key in commits, PRs, wiki, or docs
- Batch verification for changelogs (verify all issue keys exist)
- Cross-reference validation: verifying Linear issues link to actual resources
