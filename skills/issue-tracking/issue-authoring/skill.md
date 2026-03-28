---
name: issue-authoring
source: superpowers-plus
triggers: ["create ticket", "create issue", "open a ticket for", "file a bug"]
anti_triggers: ["update ticket", "edit issue", "change status", "close ticket"]
description: Use when creating issues in your project tracker. Enforces formatting standards, required fields, label validation, duplicate checking.
summary: "Use when: creating issues in any tracker. Skip when: updating existing issues."
coordination:
  group: issue-tracking
  order: 0
  requires: []
  enables: ['issue-verify']
  escalates_to: []
  internal: false
---

# Issue Authoring

> **Purpose:** Ensure consistent, high-quality issues with verified fields
> **Adapter:** See `_adapters/` for platform-specific configuration

> **Wrong skill?** Updating existing issues → `issue-editing`. Verifying issue keys → `issue-verify`. Adding comments → `issue-comment-debunker`.

---

## Configuration

Before using this skill, configure your issue tracker:

1. Set `ISSUE_TRACKER_TYPE` to your configured issue-tracker adapter key
2. See `skills/issue-tracking/_adapters/` for platform-specific setup
3. Ensure required MCP tools are available for your platform

---

## Pre-Creation Checklist (MANDATORY)

Before calling your adapter's `create_issue` operation:

- [ ] **Search for duplicates** — Use adapter's search operation
- [ ] **Validate labels exist** — Query label IDs for your platform
- [ ] **Validate assignee exists** — Query user IDs for your platform
- [ ] **Title follows format** — See Title Standards below
- [ ] **Description has required sections** — See Description Template

---

## Title Standards

<EXTREMELY_IMPORTANT>

| Pattern | Example | Status |
|---------|---------|--------|
| `[Type]: Brief description` | `Bug: Phone call drops after 30s on slow networks` | ✅ GOOD |
| `Specific, actionable title` | `Add retry logic to webhook handler` | ✅ GOOD |
| `Fix bug` | — | ❌ TOO VAGUE |
| `Update thing` | — | ❌ TOO VAGUE |
| `Issue with X` | — | ❌ TOO VAGUE |

**Title must be:**
- Specific enough to understand without reading description
- Max 80 characters (Some trackers truncate longer titles in views)
- No ticket key prefix (PROJ-XXX added automatically)

</EXTREMELY_IMPORTANT>

---

## Description Template

```markdown
## Context
[What problem are we solving? Why does this matter?]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes
[Optional: Implementation hints, constraints, related code]

## References
- PR: [link if exists]
- Wiki: [link if exists]
- Related: PROJ-XXX
```

---

## Label Taxonomy

**Query labels first using your adapter's API.**

| Category | Example Labels | When to Use |
|----------|----------------|-------------|
| **Type** | `bug`, `enhancement`, `feature` | Every issue needs a type |
| **Severity** | `critical`, `high`, `medium`, `low` | For bugs affecting production |
| **Source** | `support`, `internal`, `customer` | Where request originated |
| **Area** | `backend`, `frontend`, `infrastructure` | Technical domain |

---

## Workflow States

Configure workflow states for your platform. Common patterns:

| State | Use When |
|-------|----------|
| Triage / New | New issues needing review |
| Backlog | Prioritized but not scheduled |
| Ready / Todo | Ready for current sprint |
| In Progress | Actively being worked |
| Done / Closed | Completed |
| Canceled / Won't Fix | Will not be done |

---

## Duplicate Detection

<EXTREMELY_IMPORTANT>

**Before creating ANY issue, search for duplicates using your adapter's search operation.**

**If potential duplicate found:**
1. STOP — do not create new issue
2. Report to user: "Found existing issue [KEY]-XXX with similar title"
3. Ask: "Should I add a comment to the existing issue instead?"

</EXTREMELY_IMPORTANT>

---

## Pre-Flight Checklist

```
Before creating issue:
1. SEARCH — Check for duplicates
2. VALIDATE — Labels and assignee exist
3. FORMAT — Title follows standards
4. STRUCTURE — Description has required sections
5. CREATE — Only then call adapter's create operation
```

---

## Companion Skills

- **issue-editing**: Fetch-before-edit workflow
- **issue-link-verification**: Verify URLs before posting
- **issue-comment-debunker**: Evidence-based comments only

## Related Tools

For formal acceptance criteria documents with adversarial review, use [docforge-ai acceptance-criteria](https://bordenet.github.io/docforge-ai/assistant/?type=acceptance-criteria) — Claude drafts, Gemini critiques, Claude synthesizes.


## Failure Modes

- **Vague titles:** "Fix bug" or "Update thing" — titles must be specific and actionable (max 80 chars)
- **Missing acceptance criteria:** Issue created without clear definition of done
- **Unverified links:** Including URLs in description without checking they resolve (see link-verification skill)
