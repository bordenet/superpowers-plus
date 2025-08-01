---
name: link-verification
source: superpowers-plus
triggers: ["add code reference", "link to repo", "reference the wiki page", "cite the issue ticket", "verify links", "check if URL exists", "update wiki", "push to wiki", "create wiki page", "edit wiki"]
description: Use when adding repository links, code references, internal wiki links, or external URLs to documentation. Invoke BEFORE writing any link to prevent hallucination. Also invoked by wiki-orchestrator as HARD GATE.
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
| 2 | voice-service | dev.azure.com/... | Azure DevOps | ✅ PASS | Repo exists |
| 3 | Old Page | /doc/old-page-123 | Internal Wiki | ❌ FAIL | 404 - not found |
| 4 | Example.com | https://example.com | External | ⚠️ WARN | 503 - may be temporary |

**Summary:** 2 ✅ PASS | 1 ❌ FAIL | 1 ⚠️ WARN
**Gate Status:** ❌ BLOCKED (internal wiki link failure)
```

### Gate Logic

| Link Type | On Failure | Reason |
|-----------|------------|--------|
| Internal Wiki (`/doc/...`) | **HARD BLOCK** | Readers get 404, unacceptable |
| Azure DevOps Repo | **HARD BLOCK** | Likely hallucinated |
| Issue Reference | **WARN** | May be private (verify org urlKey is `your-team`) |
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

**YourOrg source code lives EXCLUSIVELY in Azure DevOps, not GitHub.**

| Pattern | Reality | Action |
|---------|---------|--------|
| `github.com/your-org/*` | **DOES NOT EXIST** | ❌ Never use — always hallucinated |
| `github.com/YourOrg/*` | **DOES NOT EXIST** | ❌ Never use — always hallucinated |
| `dev.azure.com/YourOrg/*` | ✅ Real repos | Query Azure DevOps API to verify repo exists |
| `github.com/bordenet/*` | Matt's personal repos | ✅ Allowed — verify exists via GitHub API |

</EXTREMELY_IMPORTANT>

---

## Verification Checklist

Before writing ANY repository link:

- [ ] **Query the API** — Confirm repo exists before writing URL
- [ ] **Get exact repo name** — Case-sensitive, from API response
- [ ] **Construct URL from API response** — Not from assumption
- [ ] **For Azure DevOps** — URL-encode special characters in project name (e.g., `Your%20Project`)

---

## How to Verify

### YourOrg Repos (Azure DevOps)

```
# List all repos in a project
repo_list_repos_by_project_azure-devops
  project: "Your Project"

# Get specific repo
repo_get_repo_by_name_or_id_azure-devops
  project: "Your Project"
  repositoryNameOrId: "voice-service"
```

**URL Format:** `https://dev.azure.com/YourOrg/Your%20Project/_git/{repo-name}`

### GitHub Repos (Personal or External)

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

**Using MCP (preferred):**
```
get_document_outline(id: "PAGE_SLUG_HERE")
```

**Using curl (fallback):**
```bash
# See skills/wiki/_adapters/outline.md for environment setup
source .env
curl -s -X POST "$OUTLINE_BASE_URL/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "PAGE_SLUG_HERE"}' | jq '.ok, .data.title // .error'
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

1. **List repos first** — Query Azure DevOps to see what repos exist
2. **Use relative paths** — `src/file.ts` not `repo/src/file.ts` (repo is in link)
3. **Verify files exist** — Confirm file paths via API before linking
4. **Column header = "Repository"** — Not "GitHub" (platform-agnostic naming)

### Template

```markdown
### Code References

| File | Purpose | Repository |
|------|---------|------------|
| `src/path/to/file.ts` | Brief description | [repo-name](https://dev.azure.com/YourOrg/Project/_git/repo-name) |
```

---

## Incident Log

| Date | Page | Issue | Resolution |
|------|------|-------|------------|
| 2026-02-18 | Speech: Deepgram | 6 fake `github.com/your-org/*` links | Fixed to `dev.azure.com/YourOrg/*` |
| 2026-02-18 | Telephony: Telnyx | 5 fake GitHub links + 1 non-existent repo | Fixed links, removed `phone-service` reference |
| 2026-02-20 | Getting Started with superpowers-plus | Hallucinated internal wiki link `/doc/example-page-xyz789` | Fixed to `/doc/correct-page-abc123` |

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
2. QUERY — Use Azure DevOps MCP or github-api to verify
3. CONFIRM — Check exact name, case, existence
4. LINK — Only then write the URL
```

