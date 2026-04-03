---
name: issue-verify
source: superpowers-plus
triggers: ["verify issue", "check if ticket exists", "issue identifier in commit message", "link PR to issue"]
anti_triggers: ["create issue", "update issue", "edit ticket"]
description: Use when referencing issues in documentation, commits, or PRs. Verifies issue identifiers exist, validates cross-references.
summary: "Use when: referencing issues in docs, commits, or PRs."
coordination:
  group: issue-tracking
  order: 4
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Issue Verification

> **Purpose:** Verify issue identifiers before referencing in commits, PRs, or documentation
> **Pattern:** Evidence before assertion — verify existence before citing
> **Adapter:** See `_adapters/` for platform-specific configuration
>
> **Wrong skill?** Creating issues → `issue-authoring`. Updating issues → `issue-editing`. Verifying URLs in issues → `issue-link-verification`.

---

## When to Use

Invoke this skill when:

- Writing commit messages with issue identifier prefixes
- Linking PRs to issues
- Documenting issues in wiki pages
- Cross-referencing issues in changelogs
- Any time you reference an issue identifier outside your tracker

---

## Issue Identifier Verification

<EXTREMELY_IMPORTANT>

**Before writing ANY issue reference, verify it exists using your adapter's `get_issue` operation (preferred for exact platform-native identifier lookup) or `verify_link` for URL-based verification. Use `search_issues` only when the exact identifier is unknown.**

**Expected response for existing issue:**

- Issue ID, title, status returned

**For non-existent issue:**

- Empty results or "not found"

**If issue doesn't exist:**

```text
⚠️ ISSUE NOT FOUND

The issue "[IDENTIFIER]" does not exist.
- Verify the issue identifier is correct
- Check if the issue was deleted or moved
- Do NOT reference this identifier in commits/docs
```

</EXTREMELY_IMPORTANT>

---

## Cross-Reference Validation

### Issue → PR Linking

When linking PRs to issues:

1. **Verify issue exists** using your adapter
2. **Verify PR exists** in your source control
3. **Only then create the link**

### Commit Messages with Issue Identifiers

**Recommended format:** `[IDENTIFIER] Brief description` (use the exact identifier format your tracker uses — e.g. `PROJ-123`, `#42`, or `TICKET-456`)

Before committing with issue identifier:

1. Verify issue exists
2. Verify issue is in appropriate state (not Done/Closed unless reopening)

---

## Batch Verification

For bulk operations (changelog, sprint reports):

```markdown
## Issue Verification Report

| Issue Identifier | Status | Title | Verified |
|-----------------|--------|-------|----------|
| PROJ-123 | Done | Implement feature X | ✅ |
| #456 | In Progress | Fix bug Y | ✅ |
| TICKET-789 | — | — | ❌ NOT FOUND |

Summary: 2 verified, 1 not found
```

---

## Hallucination Prevention

<EXTREMELY_IMPORTANT>

**AI assistants commonly hallucinate issue identifiers based on:**

- Sequential patterns (PROJ-100 exists, so PROJ-101 must too)
- Memory from previous conversations
- Assuming issues referenced in docs still exist

**Verification is MANDATORY, not optional.**

</EXTREMELY_IMPORTANT>

---

## Verification Checklist

```text
Before referencing ANY issue identifier:
1. QUERY — Use get_issue for exact identifier lookup (or verify_link for URL-based verification)
2. VERIFY — Issue exists and is in expected state
3. FETCH — Get actual title (don't guess)
4. REFERENCE — Only then cite the issue
```

---

## Companion Skills

- **issue-authoring**: Creating new issues
- **issue-editing**: Updating existing issues

## Example

```bash
# Verify issue metadata matches reality
# Check assignee exists, sprint is current, labels are valid
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill issue-verify
```

## Failure Modes

- **Skipping URL verification:** Assuming all links in the issue body are valid without fetching them
- **Checking only title/description:** Missing label, assignee, or priority validation
- **Trusting memory:** Verifying against what you remember the issue said instead of re-fetching it
