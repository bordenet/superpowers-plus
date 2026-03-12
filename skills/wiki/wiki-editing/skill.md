---
name: wiki-editing
source: superpowers-plus
triggers: ["update wiki page", "push to wiki", "edit wiki", "create wiki document", "delete wiki page"]
description: Use when editing wiki pages, pushing content to wiki, or managing wiki documents. Enforces download-before-edit pattern, MCP-first tooling, and write scope restrictions. Platform-specific setup in skills/wiki/_adapters/.
---

# Wiki Editing

> **Adapter:** See `skills/wiki/_adapters/` for platform-specific configuration (Outline, Notion, Confluence, etc.)

## Setup

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `WIKI_PLATFORM` | Your wiki platform: `outline`, `notion`, `confluence` |

**Platform-specific variables:** See your adapter file in `skills/wiki/_adapters/` for required tokens and configuration.

### Configuration

1. Set `WIKI_PLATFORM` environment variable
2. Configure platform-specific tokens per your adapter
3. See adapter file for MCP tools and API endpoints

---

<EXTREMELY_IMPORTANT>
## ⚠️ ORCHESTRATOR BYPASS DETECTION — CHECK FIRST

**Before executing ANY create/update operation, ask yourself:**

> "Did this request come through `wiki-orchestrator`?"

### If YES (Orchestrator Invoked This Skill)

✅ Proceed — quality pipeline already ran (de-dup, links, secrets, slop, facts).

### If NO (Direct Invocation)

**You are about to bypass the quality pipeline.** Display this warning:

```
⚠️ ORCHESTRATOR BYPASS DETECTED

You're about to publish directly without the wiki-orchestrator pipeline.
This SKIPS:
- ❌ De-duplication check
- ❌ Link verification (HARD GATE)
- ❌ Secret scan (HARD GATE)
- ❌ Slop detection
- ❌ Fact-check

OPTIONS:
1. 🔄 Switch to full pipeline: "Let me use wiki-orchestrator instead"
2. ⚡ Proceed anyway (ONLY for trivial edits like typo fixes)
3. ❌ Cancel

Which option?
```

### Bypass Trigger Phrases (Watch For These)

These phrases invoke THIS skill directly, bypassing orchestrator:

| Phrase | Risk |
|--------|------|
| "push to wiki" | Skips all quality gates |
| "edit wiki" | Skips all quality gates |
| "update wiki page" | May skip quality gates |
| "create wiki document" | Skips de-dup check |

### When Bypass Is Acceptable

| Acceptable | Not Acceptable |
|------------|----------------|
| Fixing a typo | Adding new content |
| Updating a date | Adding links or references |
| Minor formatting | Substantive edits |

### Log Bypass Events

If user chooses to proceed with bypass, log as potential miss:

```bash
./tools/skill-fire-logger.sh miss wiki-orchestrator "user bypassed pipeline" "direct wiki-editing invocation"
```

</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## 🎯 PREFER MCP TOOLS OVER CURL

**ALWAYS use your platform's MCP tools first** — they handle authentication, error handling, and JSON escaping automatically.

### Generic Operations → Platform MCP Tools

| Operation | Purpose | See Adapter For |
|-----------|---------|-----------------|
| `get_page` | Fetch document content | Platform-specific tool |
| `update_page` | Update document | Platform-specific tool |
| `create_page` | Create new document | Platform-specific tool |
| `search_pages` | Search documents | Platform-specific tool |
| `list_pages` | List documents | Platform-specific tool |
| `delete_page` | Archive/delete document | Platform-specific tool |

**See `skills/wiki/_adapters/{platform}.md` for your platform's MCP tool mappings.**

### When to Use MCP vs API

| Scenario | Use |
|----------|-----|
| **Default** | MCP tools |
| MCP tool fails or unavailable | API fallback |
| Complex multi-step operations | MCP tools |
| Debugging API issues | API (for raw response) |

**Violating this preference wastes time on JSON escaping and auth handling.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## ⛔ WIKI WRITE SCOPE RESTRICTION (Blast Radius Reduction)

**Before ANY `documents.update`, `documents.create`, `documents.delete`, or `documents.move` call, verify the target is within allowed scope.**

### Allowed Write Roots (Fork-Friendly Config)

```yaml
# WIKI_ALLOWED_ROOTS — Edit this section for your own wiki areas
# Each entry is a document/collection URL slug that permits writes to itself + all descendants

WIKI_ALLOWED_ROOTS:
  - id: "personal-collection-id"
    name: "Personal (your name)"
  - id: "your-team-id"
    name: "Your Team"
  - id: "your-product-id"
    name: "Your product pages"
```

### Scope Verification Procedure

**Before ANY write operation:**

1. Get target document info via your adapter's `get_page` operation
2. Check if document ID OR any parent in the chain matches an allowed root
3. If **IN SCOPE** → proceed with write
4. If **OUT OF SCOPE** → STOP and display warning (see below)

### How to Check Parent Chain

Use your adapter's `get_page` operation to fetch document metadata including:
- Document ID
- Collection/space ID
- Parent document ID

If `collectionId` or any `parentDocumentId` in the chain matches an allowed root → IN SCOPE.

### Warning Message (If Out of Scope)

```
⛔ WIKI WRITE BLOCKED — Outside permitted scope

Target: [document title/URL]
Reason: This document is not within your allowed wiki areas.

Allowed areas:
- Personal (your name)
- Your Team
- Your product pages

This restriction prevents accidental edits to other teams' documentation.
To proceed, the user must explicitly confirm OR edit the page manually in the UI.
```

### Read Operations Are NOT Restricted

This scope restriction applies ONLY to write operations:
- `update_page`
- `create_page`
- `delete_page`
- `move_page`

**Read operations (`get_page`, `search_pages`, `list_pages`, etc.) remain unrestricted.**

### Why This Exists

Wiki cleanup can accidentally affect pages outside your ownership. This restriction ensures AI agents cannot accidentally modify other teams' documentation.

**Violating this restriction = STOP and ask for explicit user confirmation.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## ALWAYS Download Before Editing

Before making ANY edit to a wiki page, you MUST:

1. **Fetch the current document state** via your adapter's `get_page` operation
2. **Use that fetched content as the base** for all edits
3. **Always verify** local temp files and memory reflect current wiki state

This prevents race conditions when multiple machines/agents are editing wiki pages concurrently.

**Violating this rule risks overwriting another agent's or user's work.**
</EXTREMELY_IMPORTANT>

---

## ✅ Preferred Pattern (MCP Tools)

```
# Step 1: Fetch current state using your adapter's get_page operation
# See skills/wiki/_adapters/{platform}.md for specific tool

# Step 2: Edit content (use save-file to create temp file if needed)

# Step 3: Push update using your adapter's update_page operation
```

**Benefits:**
- No JSON escaping needed
- No auth token management
- Better error messages
- Automatic retries

---

## 🔄 Fallback Pattern (API)

Only use if MCP tools are unavailable or failing. See your adapter for API endpoints:

```bash
# Generic API fallback pattern - see your adapter for specific endpoints

# Step 1: ALWAYS fetch current state first
# Use your adapter's get_page API endpoint

# Step 2: Edit the content locally

# Step 3: Push the updated content
# Use your adapter's update_page API endpoint
```

---

## ❌ NEVER Use Heredocs

<EXTREMELY_IMPORTANT>
**Heredocs (`<< EOF ... EOF`) fail silently in this environment.** They appear to work but produce empty or corrupted output.

**NEVER do this:**
```bash
cat > /tmp/file.md << 'EOF'
content here
EOF
```

**ALWAYS do this instead:**
1. Use `save-file` tool to create temp files in the workspace
2. Then use MCP tool or read with `cat` and push via API

**This is not optional. Heredocs WILL fail and waste debugging time.**
</EXTREMELY_IMPORTANT>

---

## Platform-Specific API Reference

**See your adapter file in `skills/wiki/_adapters/` for:**
- Base URL format
- Authentication headers
- API endpoints
- Anchor format (varies by platform)

Example TOC entry (syntax varies by platform):
```markdown
1. [Section Name](#section-name)
```

Back-to-top link:
```markdown
[↑ Back to top](#table-of-contents)
```

---

## Temp File Conventions

When editing wiki pages, use descriptive temp files:

```
/tmp/wiki-<descriptive-name>.md
```

**Always clean up temp files** after successfully pushing to the wiki.

---

## Content Formatting Rules

### ❌ DO NOT Include H1 Title

Most wiki platforms display the document title in the UI. **Never start content with `# Title`** — it's redundant.

**Wrong:**
```markdown
# How We Use Issue Tracking

**Last Updated:** 2026-02-10
...
```

**Correct:**
```markdown
**Last Updated:** 2026-02-10

This document analyzes...
```

Start with metadata, intro paragraph, or directly with `## First Section`.

---

## 🚨 CRITICAL: Check for Duplicates Before Creating

<EXTREMELY_IMPORTANT>
**BEFORE calling your adapter's `create_page` operation, ALWAYS check if a page with the same title already exists.**

### ⚠️ Real Failure

Duplicate pages were created because the check wasn't performed first. Multiple pages had to be manually deleted.

**This is not theoretical — it happened. Follow this pattern EVERY TIME.**

### Pattern (Required)

```
# Step 1: List children of parent document using your adapter's list_pages operation

# Step 2: Check if any child has the same title
# - If title exists → use update_page instead
# - If title doesn't exist → safe to call create_page
```

### Why This Matters

| Problem | Consequence |
|---------|-------------|
| Many wikis allow duplicate titles | Multiple pages with same name under same parent |
| Multiple agents/sessions | Race condition creates duplicates |
| No automatic deduplication | Manual cleanup required |

**This check is MANDATORY before every `create_page` call. No exceptions.**
</EXTREMELY_IMPORTANT>

---

## 🛡️ MANDATORY Pre-Deletion Backup

<EXTREMELY_IMPORTANT>
**Before calling your adapter's `delete_page` or `archive_page` operation, you MUST create a local backup.**

### ⚠️ Real Failure

Pages were accidentally deleted during duplicate cleanup. While some platforms support soft-delete recovery, **you should never rely on trash retention**.

**This is not theoretical — it happened. Follow this pattern EVERY TIME before deleting.**

### Backup Directory

Configure a backup directory that persists across sessions:

```bash
# Home directory (recommended)
$HOME/.wiki-backups/
```

**Important:** Do not use temporary directories (`/tmp/`) — backups must survive system restarts.

### Required Steps (MANDATORY)

**Step 1: Fetch full document content using your adapter's `get_page` operation**

**Step 2: Save backup file with YAML frontmatter**

Filename: `{YYYY-MM-DD}_{document-id}_{url-slug}.md`

**Step 3: Include YAML frontmatter header**

```yaml
---
document_id: "uuid-here"
title: "Page Title"
url: "/path/to/page"
deleted_at: "ISO-timestamp"
collection_id: "collection-uuid"
parent_document_id: null
backup_reason: "Pre-deletion backup"
---

[Original document content here]
```

**Step 4: Verify backup file exists BEFORE proceeding**

**Step 5: Only THEN call your adapter's `delete_page` operation**

### Recovery Procedure

If an accidentally deleted page needs to be restored:

**Option 1: Use your platform's trash/restore feature (if available)**

**Option 2: Recreate from Backup File**

1. Read backup file
2. Extract content (skip YAML frontmatter)
3. Call your adapter's `create_page` operation with preserved content

### Deletion Without Backup = Policy Violation

**DO NOT skip this step.** If you attempt to delete without creating a backup:

1. **STOP immediately**
2. Create the backup first
3. Verify the backup file exists
4. Only then proceed with deletion

**This is not optional. This is not negotiable.**
</EXTREMELY_IMPORTANT>

---

## ⚠️ Table Column Widths May Be Lost on API Update

<EXTREMELY_IMPORTANT>
Some wiki platforms store table column widths as **editor metadata**, NOT in the markdown text. When you push content via the API, **custom column widths may be reset**.

### Before Updating Any Page with Tables

1. **Warn the user** that custom table formatting may be lost
2. **Ask for confirmation** before proceeding with the update
3. **After update**, inform user they may need to re-adjust column widths in the UI

### Standard Warning Message

> ⚠️ **Formatting Warning:** Pushing content via API may reset custom table column widths. After this update, you may need to re-adjust column widths manually. Proceed?

**Check your adapter documentation for platform-specific formatting limitations.**
</EXTREMELY_IMPORTANT>

---

## Checklist

### Before Creating New Pages
- [ ] 🚨 **FIRST: Used adapter's `list_pages` to check for duplicates**
- [ ] Confirmed no existing page has the same title
- [ ] 🔒 **SECRET SCAN** — Scanned content for credentials (see below)
- [ ] Only then called adapter's `create_page`

### Before Editing/Pushing Any Wiki Content
- [ ] **Used MCP tools** (not API) unless MCP unavailable
- [ ] Fetched current document state via adapter's `get_page`
- [ ] Used fetched content as base for edits (not memory or stale local file)
- [ ] Verified document ID/UUID is correct
- [ ] **Content does NOT start with `# Title`** (most platforms show title in UI)
- [ ] 🔒 **SECRET SCAN** — Scanned content for credentials (see below)
- [ ] **Warned user about table column width loss** (if page has tables)
- [ ] 🔗 **VERIFIED ALL LINKS** (see below)
- [ ] Pushed updated content via adapter's `update_page`
- [ ] Cleaned up temp files

### 🔒 Secret Detection (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before pushing ANY wiki content, scan for secrets:**

| Search For | If Real Value Found |
|------------|---------------------|
| `password`, `pwd`, `secret` | 🛑 STOP — remove or redact |
| `token`, `api_key`, `credential` | 🛑 STOP — remove or redact |
| `private_key`, `connection_string` | 🛑 STOP — remove or redact |

**Safe alternatives:**
- Environment variable: `${DB_PASSWORD}`
- Redacted marker: `[REDACTED: production password]`
- Placeholder: `<YOUR_API_KEY_HERE>`

**See:** `_shared/secret-detection.md` for full pattern list.

</EXTREMELY_IMPORTANT>

### 🔗 Link Verification (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before pushing ANY wiki content, verify ALL links:**

| Link Type | How to Verify |
|-----------|---------------|
| Internal wiki links | Use adapter's `get_page` to verify page exists |
| External URLs | `curl -s -o /dev/null -w "%{http_code}"` — check 200/302 |
| Repository links | Use your repo adapter to verify repo exists |

**Invoke `superpowers:link-verification` skill if adding code references or multiple links.**

</EXTREMELY_IMPORTANT>

### Before Deleting/Archiving Pages
- [ ] 🛡️ **FIRST: Fetched full document content via adapter's `get_page`**
- [ ] Created backup file at `$HOME/.wiki-backups/{YYYY-MM-DD}_{id}_{slug}.md`
- [ ] Included YAML frontmatter with: document_id, title, url, deleted_at, collection_id, parent_document_id
- [ ] **Verified backup file exists and contains content**
- [ ] Only then called adapter's `delete_page` or `archive_page`

