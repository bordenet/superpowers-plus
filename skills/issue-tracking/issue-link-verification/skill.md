---
name: issue-link-verification
source: superpowers-plus
triggers: ["add link to issue", "post comment with URL", "update description with reference"]
description: Use when adding URLs to issue descriptions or comments. Verifies all links before posting to prevent broken references.
---

# Issue Link Verification

> **Purpose:** Verify all URLs before including in issue descriptions/comments
> **Pattern:** Same rigor as wiki link verification — no broken links
> **Adapter:** See `_adapters/` for platform-specific configuration

---

## When to Use

Invoke this skill when:

- Adding URLs to issue descriptions
- Posting comments with links
- Cross-referencing wiki pages
- Linking PRs/commits
- Any external URL in issue content

---

## Pre-Posting Link Check (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before posting ANY content with URLs:**

1. **Extract all URLs** from content
2. **Verify each URL** by type
3. **Report verification status**
4. **Block if critical links fail**

</EXTREMELY_IMPORTANT>

---

## Link Type Verification Methods

| Link Type | How to Verify | On Failure |
|-----------|---------------|------------|
| **Internal Wiki** | Wiki API query | **HARD BLOCK** |
| **Pull Request** | Source control API | **HARD BLOCK** |
| **Repository** | Source control API | **HARD BLOCK** |
| **Issue Reference** | Issue tracker search | **WARN** |
| **External URL** | `web-fetch` or `curl` | **WARN** |

---

## Verification Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ BEFORE posting issues with links                         │
├─────────────────────────────────────────────────────────────┤
│ 1. EXTRACT: Parse all URLs from content                     │
│ 2. CATEGORIZE: Internal wiki / Source Control / Issues / External      │
│ 3. VERIFY: Check each link by appropriate method            │
│ 4. REPORT: Generate verification table                      │
│ 5. GATE: Block on HARD failures, warn on soft failures      │
│ 6. POST: Only if verification passes                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Verification Report Format

```markdown
## Link Verification Report

| # | Type | URL | Status | Notes |
|---|------|-----|--------|-------|
| 1 | Wiki | /doc/deployment-guide-xyz | ✅ PASS | Page exists |
| 2 | ADO PR | PR #1234 in voice-service | ✅ PASS | PR exists |
| 3 | Wiki | /doc/old-page-deleted | ❌ FAIL | 404 - not found |
| 4 | External | https://example.com | ⚠️ WARN | 503 - may be temp |

**Summary:** 2 ✅ | 1 ❌ | 1 ⚠️
**Gate Status:** ❌ BLOCKED (wiki link failure)
```

---

## Wiki Link Verification

**Internal wiki URL pattern:** `https://your-wiki.example.com/doc/{slug}`

```
# Use your wiki adapter's get_page operation
adapter.get_page(id: "slug-from-url")

# Verify response has content
# If error or empty → link is broken
```

**Common mistake:** Fabricating wiki slugs based on expected page titles.

---

## Repository Link Verification

Use your repository adapter to verify PR and repo links exist.

**PR verification:** Use adapter's `get_pull_request` operation with the PR ID.

**Repo verification:** Use adapter's `get_repository` operation with the repo name/ID.

See `skills/issue-tracking/_adapters/` for platform-specific tools.

---

## Issue Reference Verification

**Issue URL pattern:** `https://[your-tracker-url]/PROJ-{XXX}`

```
adapter: search_issues(query: "PROJ-123")
```

**Note:** Issue links may fail if issue is in another workspace or deleted.

---

## External URL Verification

For external URLs:

```bash
# Quick check
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "URL"
```

Or use `web-fetch` for full retrieval.

**Expected results:**
- `200`, `301`, `302` → PASS
- `401`, `403` → WARN (may need auth)
- `404` → FAIL
- `5xx` → WARN (server issues)

---

## Link Extraction Pattern

Extract markdown links:
```regex
\[([^\]]+)\]\(([^)]+)\)
```

Extract bare URLs:
```regex
https?://[^\s<>\[\]()]+
```

---

## Hallucination Prevention

<EXTREMELY_IMPORTANT>

**AI commonly hallucinates these link patterns:**

| Pattern | Reality |
|---------|---------|
| `github.com/org/assumed-repo` | Repo may not exist or may be private |
| `/doc/assumed-page-name` | Wiki slugs include random IDs |
| `[your-tracker-url]/issue/XXX-999` | Issue may not exist |

**ALWAYS verify. Never assume URLs are valid.**

</EXTREMELY_IMPORTANT>

---

## Quick Reference

```
Before posting content with links:
1. EXTRACT — Find all URLs
2. CATEGORIZE — Wiki/Source Control/Issues/External
3. VERIFY — Check each by type
4. REPORT — Generate status table
5. GATE — Block on critical failures
6. POST — Only after verification
```

---

## Related Skills

- **link-verification**: General link verification (wiki-focused)
- **issue-authoring**: Creating issues with proper links
- **issue-comment-debunker**: Evidence-based comments

