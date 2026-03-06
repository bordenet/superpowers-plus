---
name: issue-verify
source: superpowers-plus
triggers: ["verify issue", "check if ticket exists", "[KEY-XXX] in commit message", "link PR to issue"]
description: Use when referencing issues in documentation, commits, or PRs. Verifies issue keys exist, validates cross-references.
---

# Issue Verification

> **Purpose:** Verify issue keys before referencing in commits, PRs, or documentation
> **Pattern:** Evidence before assertion — verify existence before citing
> **Adapter:** See `_adapters/` for platform-specific configuration

---

## When to Use

Invoke this skill when:

- Writing commit messages with `[KEY-XXX]` prefixes
- Linking PRs to issues
- Documenting issues in wiki pages
- Cross-referencing issues in changelogs
- Any time you reference an issue key outside your tracker

---

## Issue Key Verification

<EXTREMELY_IMPORTANT>

**Before writing ANY issue key, verify it exists using your adapter's search operation.**

**Expected response for existing issue:**
- Issue ID, title, status returned

**For non-existent issue:**
- Empty results or "not found"

**If issue doesn't exist:**
```
⚠️ ISSUE NOT FOUND

The issue key "[KEY]-XXX" does not exist.
- Verify the issue number is correct
- Check if the issue was deleted or moved
- Do NOT reference this key in commits/docs
```

</EXTREMELY_IMPORTANT>

---

## Cross-Reference Validation

### Issue → PR Linking

When linking PRs to issues:

1. **Verify issue exists** using your adapter
2. **Verify PR exists** in your source control
3. **Only then create the link**

### Commit Messages with Issue Keys

**Required format:** `[KEY-XXX] Brief description`

Before committing with issue key:
1. Verify issue exists
2. Verify issue is in appropriate state (not Done/Closed unless reopening)

---

## Batch Verification

For bulk operations (changelog, sprint reports):

```
## Issue Verification Report

| Issue Key | Status | Title | Verified |
|-----------|--------|-------|----------|
| KEY-123 | Done | Implement feature X | ✅ |
| KEY-456 | In Progress | Fix bug Y | ✅ |
| KEY-789 | — | — | ❌ NOT FOUND |

Summary: 2 verified, 1 not found
```

---

## Hallucination Prevention

<EXTREMELY_IMPORTANT>

**AI assistants commonly hallucinate issue keys based on:**
- Sequential patterns (KEY-100 exists, so KEY-101 must too)
- Memory from previous conversations
- Assuming issues referenced in docs still exist

**Verification is MANDATORY, not optional.**

</EXTREMELY_IMPORTANT>

---

## Quick Reference

```
Before referencing ANY issue key:
1. QUERY — Search for the exact key
2. VERIFY — Issue exists and is in expected state
3. FETCH — Get actual title (don't guess)
4. REFERENCE — Only then cite the issue
```

---

## Related Skills

- **issue-authoring**: Creating new issues
- **issue-editing**: Updating existing issues

