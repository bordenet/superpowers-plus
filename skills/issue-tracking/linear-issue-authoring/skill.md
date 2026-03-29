---
name: linear-issue-authoring
source: superpowers-[company]
description: Use when creating Linear issues. Enforces formatting, required fields, live UUID resolution, duplicate checking with fail-closed preflight gates.
summary: "Use when: creating Linear issues. Fail-closed preflight before any create."
triggers: ["create Linear ticket", "create issue in Linear", "create project ticket", "file a bug in Linear", "new Linear issue"]
coordination:
  group: linear
  order: 1
  requires: []
  enables: ['linear-comment-debunker']
  escalates_to: []
  internal: false
anti_triggers: ['edit ticket', 'update ticket', 'comment on ticket', 'verify ticket']
---

# Linear Issue Authoring

> **Owns:** CREATE operations only
> **Workspace:** `LINEAR_TEAM_NAME` / `LINEAR_TEAM_ID` from `~/.codex/.env` | https://linear.app/[company]
<!-- Config: linear/_shared/project-config.md -->

<!-- Source of truth for write gates: linear/_shared/write-invariants.md -->
## Write Gates

1. **Never fabricate issue keys** — `search_issues_linear` first. If not found → STOP.
2. **Duplicate check before create** — search for similar titles. If match → STOP, report to user.
3. **Use UUIDs** for labels, assignees, states — resolve live via `linear` tool query. Never pass display names or emails.
4. **Verify URLs** before posting — wiki/ADO links HARD BLOCK on failure, external links WARN. Never construct wiki slugs from memory.
5. **On any gate failure → STOP.** Report which gate failed. Do not proceed.

---

## Preflight Evidence Block

<EXTREMELY_IMPORTANT>

**Emit this block immediately before calling `create_issue_linear`.** Do not summarize or skip fields. If `GATE != PASS`, do not call the tool.

```
PREFLIGHT: CREATE
- duplicate_search_terms: [terms used]
- duplicate_results: [count found | relevant titles, or "0 found"]
- duplicate_decision: CLEAR | BLOCKED (awaiting user)
- title: [validated title, ≤80 chars]
- description_sections: [Context: ✓/✗ | Acceptance Criteria: ✓/✗]
- initial_state: [live-resolved UUID] or "team default"
- assignee: [live-resolved UUID] or "unassigned"
- labels: [live-resolved UUIDs] or "none"
- url_verification: [PASS n/n | FAIL (which)] or "no URLs"
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed with the create. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Title Standards

| Pattern | Example | Status |
|---------|---------|--------|
| `[Type]: Brief description` | `Bug: Phone call drops after 30s on slow networks` | ✅ |
| `Specific, actionable title` | `Add retry logic to webhook handler` | ✅ |
| `Fix bug` | — | ❌ TOO VAGUE |
| `Update thing` | — | ❌ TOO VAGUE |
| `Issue with X` | — | ❌ TOO VAGUE |

Max 80 characters. No ticket key prefix.

---

## Description Template

```markdown
## Context
[What problem are we solving? Why does this matter?]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes
[Optional: implementation hints, constraints, related code]

## References
- PR: [link if exists — verify before posting]
- Wiki: [link if exists — verify before posting]
- Related: {PREFIX}-XXX [verify exists]
```

---

## Duplicate Detection

Before creating ANY issue:

```
search_issues_linear(query: "key words from title", limit: 10)
```

**If potential duplicate found:**
1. STOP — do not create
2. Report: "Found existing issue {PREFIX}-XXX with similar title: [title]"
3. Ask user: "Should I add a comment to the existing issue instead?"

**Incident 2026-02-18:** Created duplicate "[PRODUCT] Voice AI Cost Analysis" issues — search wasn't performed.

---

## Label Categories (query for UUIDs — do not hardcode)

| Category | Example Labels | When to Use |
|----------|---------------|-------------|
| Type | bug, enhancement | Every issue |
| Severity | production-blocker, high-visibility | Production bugs |
| Area | telephony, ai-ml, integration | Technical domain |

Always `linear query: "list all issue labels"` to resolve UUIDs before applying.

---

## Compound Workflows

| Intent | Handoff |
|--------|---------|
| "Create and set to In Progress" | authoring creates → `linear-issue-editing` updates status |
| "Create from investigation findings" | `linear-comment-debunker` validates claims in description → authoring creates |

---

## Failure Modes

| Failure | Consequence |
|---------|-------------|
| Duplicate creation without search | Noise, confusion, wasted triage time |
| Fabricated issue key in References | Broken cross-references, misleading links |
| Missing acceptance criteria | Ambiguous scope, rework |
| Label name instead of UUID | API error or silent failure |
