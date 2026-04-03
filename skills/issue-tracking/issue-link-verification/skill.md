---
name: issue-link-verification
source: superpowers-plus
triggers: ["add link to issue", "post comment with URL", "update description with reference", "link to PR in ticket", "reference commit in issue", "add repo link to ticket"]
anti_triggers: ["verify wiki links", "check wiki page links", "scan wiki"]
description: Use when adding URLs to issue descriptions or comments. Verifies all links before posting to prevent broken references.
summary: "Use when: adding URLs to issue descriptions or comments."
coordination:
  group: issue-tracking
  order: 3
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Issue Link Verification

> **Purpose:** Verify all URLs before including in issue descriptions/comments
> **Pattern:** Same rigor as wiki link verification — no broken links
> **Adapter:** See `_adapters/` for platform-specific configuration
>
> **Wrong skill?** Verifying wiki links → `link-verification`. Creating issues → `issue-authoring`. Verifying issue identifiers → `issue-verify`.

## When to Use

Invoke this skill when:

- Adding URLs to issue descriptions
- Posting comments with links
- Cross-referencing wiki pages
- Linking PRs/commits
- Any external URL in issue content

## Pre-Posting Link Check (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before posting ANY content with URLs:**

1. **Extract all URLs** from content
2. **Verify each URL** by type
3. **Report verification status**
4. **Block if critical links fail**

</EXTREMELY_IMPORTANT>

## Link Type Verification Methods

| Link Type | How to Verify | On Failure |
|-----------|---------------|------------|
| **Internal Wiki** | Wiki API query | **HARD BLOCK** |
| **Pull Request** | Source control API | **HARD BLOCK** |
| **Repository** | Source control API | **HARD BLOCK** |
| **Issue Reference** | `verify_link` (URL) or `get_issue` (platform-native identifier) via adapter; `search_issues` for discovery only | **HARD BLOCK** if `exists: false`; route to source-control workflow if `entityType: "pull_request"`; **HARD BLOCK** if `entityType: "other"` (unknown non-issue entity — do not reference without reclassification); **WARN** if `entityType: "unknown"` (permission/cross-workspace ambiguity — surface uncertainty to user before proceeding) |
| **External URL** | `web-fetch` or `curl` | **WARN** |

## Verification Workflow

1. **EXTRACT** — Parse all URLs (`\[([^\]]+)\]\(([^)]+)\)` and bare `https?://` patterns)
2. **CATEGORIZE** — Wiki / Source Control / Issues / External
3. **VERIFY** — Check each by type (see below)
4. **REPORT** — Generate status table: `| # | Type | URL | Status | Notes |`
5. **GATE** — Block on HARD failures, warn on soft. Post only if verification passes.

## Verification by Type

**Wiki links**: Use wiki adapter's `get_page` operation. Common mistake: fabricating slugs from titles.

**Repository/PR links**: Use source control adapter's `get_pull_request` / `get_repository` operations. See `skills/issue-tracking/_adapters/`.

**Issue links**: Use your adapter's `verify_link` operation for URL-based verification, or `get_issue` for exact platform-native identifier lookup (key, number, or ID). Fall back to `search_issues` only for discovery. May fail if issue is in another workspace.

**External URLs**: `curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "URL"` or `web-fetch`. Status: `200/301/302` → PASS · `401/403` → WARN · `404` → FAIL · `5xx` → WARN.

```bash
# Verify an external URL before posting
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://example.com/docs/setup"
# 200 → PASS, 404 → FAIL, 5xx → WARN (retry once)
```

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

## Failure Modes

| Failure | Fix |
|---------|-----|
| Verifying domain but not full path — domain correct, slug fabricated | Verify the complete URL, not just the host |
| Skipping verification for URLs "verified earlier in conversation" | Context drifts — re-verify before every post |
| Link target exists but content doesn't match anchor text | Read the target page title, not just HTTP status |
| Timeout on link check marked as "warn" instead of "fail" | Transient timeout → retry once; persistent → fail |

## Companion Skills

- **link-verification**: General link verification (wiki-focused)
- **issue-authoring**: Creating issues with proper links
- **issue-comment-debunker**: Evidence-based comments
- **issue-editing**: Editing issues after link verification
