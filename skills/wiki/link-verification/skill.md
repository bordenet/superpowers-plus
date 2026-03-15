---
name: link-verification
source: superpowers-plus
triggers: ["add code reference", "link to repo", "reference the wiki page", "cite the issue ticket", "verify links", "check if URL exists", "verify this URL", "check this link", "wiki:verify-links", "link:verify"]
description: Use when adding repository links, code references, internal wiki links, or external URLs to documentation. Invoke BEFORE writing any link to prevent hallucination. Also invoked by wiki-orchestrator as HARD GATE (Stage 3, after content generation, before publish).
coordination:
  group: wiki-pipeline
  order: 4
  requires: ["wiki-orchestrator"]
  enables: ["wiki-editing"]
  escalates_to: []
  internal: false
---

# Link Verification

> **Purpose:** Prevent hallucinated links in documentation
> **Last Updated:** 2026-02-28
> **Incident:** Hallucinated `github.com/your-org/*` links on Speech: Deepgram and Telephony: Telnyx wiki pages

---

## Orchestrator Integration

This skill is invoked by `wiki-orchestrator` as a **HARD GATE** for internal wiki links.

### Batch Verification Mode

When called by orchestrator, extract ALL links from content and verify each:

```
## Link Verification Report

| # | Link Text | URL | Type | Status | Notes |
|---|-----------|-----|------|--------|-------|
| 1 | Deployment Guide | /doc/deployment-xyz | Internal Wiki | ✅ PASS | Resolves to "Deployment Guide" |
| 2 | service-repo | [your-repo-host]/... | Repository | ✅ PASS | Repo exists |
| 3 | Old Page | /doc/old-page-123 | Internal Wiki | ❌ FAIL | 404 - not found |
| 4 | Example.com | https://example.com | External | ⚠️ WARN | 503 - may be temporary |

**Summary:** 2 ✅ PASS | 1 ❌ FAIL | 1 ⚠️ WARN
**Gate Status:** ❌ BLOCKED (internal wiki link failure)
```

### Gate Logic

| Link Type | On Failure | Reason |
|-----------|------------|--------|
| Internal Wiki (`/doc/...`) | **HARD BLOCK** | Readers get 404, unacceptable |
| Repository Link | **HARD BLOCK** | Likely hallucinated |
| Issue Reference | **WARN** | May be private |
| External URL | **WARN** | Sites have downtime |

### Link Extraction Pattern

Extract all markdown links from content:
```regex
\[([^\]]+)\]\(([^)]+)\)
```

Also extract bare URLs:
```regex
https?://[^\s<>\[\]()]+
```

---

## When to Use

Invoke when:

- Writing wiki page with "Code References" section
- Adding links to README or documentation
- Documenting architecture with repository links
- Any time you're about to write a URL to source code
- **Adding internal wiki links** (e.g., `/doc/page-slug-xyz123`)

---

## ⛔ The Rule

<EXTREMELY_IMPORTANT>

**VERIFY BEFORE YOU WRITE. Evidence before assertion.**

**AI models frequently hallucinate repository URLs. Always verify before linking.**

| Pattern | Reality | Action |
|---------|---------|--------|
| `github.com/assumed-org/*` | **MAY NOT EXIST** | ⚠️ Verify — often hallucinated |
| `[your-repo-host]/org/*` | Verify via API | Query your repo host API to verify |

</EXTREMELY_IMPORTANT>

---

## Verification Checklist

Before writing ANY repository link:

- [ ] **Query the API** — Confirm repo exists before writing URL
- [ ] **Get exact repo name** — Case-sensitive, from API response
- [ ] **Construct URL from API response** — Not from assumption
- [ ] **URL-encode special characters** — Spaces, special characters in project/org names

---

## How to Verify

### Using Your Repository Adapter

```
# Use your repository adapter to verify the repo exists
# See skills/issue-tracking/_adapters/ for platform-specific tools
```

### GitHub Repos

```
# Verify repo exists
github-api GET /repos/{owner}/{repo}
```

If 404 → **DOES NOT EXIST** → Do not write the link.

---

## Known Hallucination Patterns

AI assistants commonly hallucinate these patterns because they're common in training data:

| Hallucinated Pattern | Why It's Wrong |
|----------------------|----------------|
| `github.com/your-org/*` | YourOrg doesn't use GitHub for source code |
| `github.com/{company}/{repo}` assumed | AI assumes GitHub is universal |
| Line number links without verification | File structure may have changed |
| `main` branch assumed | Default branch may be `master` or other |
| `/doc/made-up-slug-xyz123` | **Internal wiki links fabricated without verification** |

---

## Internal Wiki Link Verification

<EXTREMELY_IMPORTANT>

**Internal wiki links (`/doc/slug-xyz123`) are just as likely to be hallucinated as external links.**

### Before Writing ANY Internal Wiki Link

Use the wiki platform adapter for verification. See `skills/wiki/_adapters/` for platform-specific setup.

**Using adapter:**
```
# Use your wiki adapter's get_page operation
# See skills/wiki/_adapters/ for platform-specific tools
adapter.get_page(id: "PAGE_SLUG_HERE")
```

**Expected output for existing page:**
```
true
"Page Title Here"
```

**Output for non-existent page:**
```
false
"not_found"
```

### If Page Doesn't Exist

1. Search for the correct page: `documents.search` with keywords
2. Get the correct URL slug from search results
3. Use the verified slug in your link

### Incident: 2026-02-20

Hallucinated `/doc/example-page-xyz789` on Getting Started page.
Real page: `/doc/correct-page-abc123`.

**This was caught by user, not by agent. Unacceptable.**

</EXTREMELY_IMPORTANT>

---

## Code References Section Template

When adding a "Code References" section to wiki pages:

1. **List repos first** — Query your repository adapter to see what repos exist
2. **Use relative paths** — `src/file.ts` not `repo/src/file.ts` (repo is in link)
3. **Verify files exist** — Confirm file paths via API before linking
4. **Column header = "Repository"** — Platform-agnostic naming

### Template

```markdown
### Code References

| File | Purpose | Repository |
|------|---------|------------|
| `src/path/to/file.ts` | Brief description | [repo-name]([your-repo-url]) |
```

---

## Incident Log

| Date | Page | Issue | Resolution |
|------|------|-------|------------|
| Example | Example Page | Fake repository links | Fixed to verified repo URLs |
| Example | Example Page | Hallucinated internal wiki link | Fixed to correct page URL |

---

## Related Skills

- **wiki-authoring**: Content structure and formatting
- **wiki-editing**: Download-before-edit workflow
- **wiki-verify**: Post-hoc verification of wiki claims
- **verification-before-completion**: General verification skill

---

## Quick Reference

```
Before writing ANY link:

1. STOP — Do not assume the repo/URL exists
2. QUERY — Use your repository adapter or github-api to verify
3. CONFIRM — Check exact name, case, existence
4. LINK — Only then write the URL
```
