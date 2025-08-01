---
name: wiki-editing
source: superpowers-plus
triggers: ["update wiki page", "push to wiki", "edit wiki", "create wiki document", "delete wiki page"]
description: Use when editing wiki pages, pushing content to wiki, or managing wiki documents. Enforces download-before-edit pattern, MCP-first tooling, and write scope restrictions. Platform-specific setup in skills/wiki/_adapters/.
---

# Wiki Editing

> **Platform:** See `skills/wiki/_adapters/` for platform-specific configuration.
> **Currently supported:** Outline (more coming)

## Setup

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OUTLINE_API_TOKEN` | API token for Outline wiki | `ol_api_xxxxxxxxxxxx` |
| `OUTLINE_BASE_URL` | Your Outline instance URL (optional) | `https://wiki.example.com` |

### Getting Your API Token

1. Log into your Outline wiki instance
2. Go to **Settings** → **API** (or visit `/settings/tokens`)
3. Click **Create API Token**
4. Copy the token (starts with `ol_api_`)

### Configuration

Add to your `.env` file:

```bash
OUTLINE_API_TOKEN=ol_api_your_token_here
# Optional: set your Outline wiki base URL
OUTLINE_BASE_URL=https://your-wiki.example.com
```

> **See also:** `skills/wiki/_adapters/outline.md` for full platform configuration.

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
| "push to outline" | Skips all quality gates |
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

You have Outline MCP tools available. **ALWAYS use MCP tools first** — they handle authentication, error handling, and JSON escaping automatically.

### MCP Tools Available

| MCP Tool | Purpose | Use Instead Of |
|----------|---------|----------------|
| `get_document_outline` | Fetch document content | `curl documents.info` |
| `update_document_outline` | Update document | `curl documents.update` |
| `create_document_outline` | Create new document | `curl documents.create` |
| `search_documents_outline` | Search documents | `curl documents.search` |
| `list_documents_outline` | List documents | `curl documents.list` |
| `list_collections_outline` | List collections | `curl collections.list` |
| `ask_documents_outline` | Natural language query | N/A |
| `sync_to_local_outline` | Download wiki to local | N/A |
| `push_document_outline` | Push local file to wiki | N/A |
| `sync_status_outline` | Check local vs wiki | N/A |

### When to Use MCP vs Curl

| Scenario | Use |
|----------|-----|
| **Default** | MCP tools |
| MCP tool fails or unavailable | Curl fallback |
| Complex multi-step operations | MCP tools |
| Debugging API issues | Curl (for raw response) |

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

1. Get target document info via `get_document_outline(id)` or `documents.info`
2. Check if document ID OR any parent in the chain matches an allowed root
3. If **IN SCOPE** → proceed with write
4. If **OUT OF SCOPE** → STOP and display warning (see below)

### How to Check Parent Chain

```bash
# Fetch document and check collectionId / parentDocumentId
curl -s -X POST "https://your-wiki.example.com/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "TARGET_DOC_ID"}' | jq '{id: .data.id, url: .data.url, collectionId: .data.collectionId, parentDocumentId: .data.parentDocumentId}'
```

If `collectionId` or any `parentDocumentId` in the chain matches an allowed root → IN SCOPE.

### Warning Message (If Out of Scope)

```
⛔ WIKI WRITE BLOCKED — Outside permitted scope

Target: [document title/URL]
Reason: This document is not within Matt's allowed wiki areas.

Allowed areas:
- Personal (your name)
- Your Team
- Your product pages

This restriction prevents accidental edits to other teams' documentation.
To proceed, the user must explicitly confirm OR edit the page manually in the UI.
```

### Read Operations Are NOT Restricted

This scope restriction applies ONLY to:
- `documents.update` / `update_document_outline`
- `documents.create` / `create_document_outline`
- `documents.delete`
- `documents.move` / `move_document_outline`

**Read operations (`documents.info`, `get_document_outline`, `search_documents_outline`, etc.) remain unrestricted.**

### Why This Exists

On 2026-02-16, wiki cleanup accidentally affected pages outside Matt's ownership. This restriction ensures AI agents cannot accidentally modify other teams' documentation.

**Violating this restriction = STOP and ask for explicit user confirmation.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## ALWAYS Download Before Editing

Before making ANY edit to an Outline wiki page, you MUST:

1. **Fetch the current document state** via `get_document_outline` MCP tool (or `documents.info` API)
2. **Use that fetched content as the base** for all edits
3. **Always verify** local temp files and memory reflect current wiki state

This prevents race conditions when multiple machines/agents are editing wiki pages concurrently.

**Violating this rule risks overwriting another agent's or user's work.**
</EXTREMELY_IMPORTANT>

---

## ✅ Preferred Pattern (MCP Tools)

```
# Step 1: Fetch current state
get_document_outline(id: "document-id-or-url-slug")

# Step 2: Edit content (use save-file to create temp file if needed)

# Step 3: Push update
update_document_outline(documentId: "document-uuid", text: "new content", publish: true)
```

**Benefits:**
- No JSON escaping needed
- No auth token management
- Better error messages
- Automatic retries

---

## 🔄 Fallback Pattern (Curl)

Only use if MCP tools are unavailable or failing:

```bash
# Step 1: ALWAYS fetch current state first
curl -s -X POST "https://your-wiki.example.com/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID_OR_URL_SLUG"}' | jq -r '.data.text' > /tmp/wiki-current.md

# Step 2: Edit /tmp/wiki-current.md (or create new temp file based on it)

# Step 3: Push the updated content
CONTENT=$(cat /tmp/wiki-current.md)
ESCAPED_CONTENT=$(echo "$CONTENT" | jq -Rs .)
curl -s -X POST "https://your-wiki.example.com/api/documents.update" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"DOCUMENT_UUID\", \"text\": $ESCAPED_CONTENT, \"publish\": true}"
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

## Outline API Reference (for curl fallback)

**Base URL:** `https://your-wiki.example.com/api`

### Key Endpoints

| Endpoint | Purpose | MCP Equivalent |
|----------|---------|----------------|
| `documents.info` | Fetch document content and metadata | `get_document_outline` |
| `documents.update` | Update document content | `update_document_outline` |
| `documents.create` | Create new document | `create_document_outline` |
| `documents.move` | Move document to new parent | `move_document_outline` |

### Anchor Format

Outline uses `#h-section-name` format for anchors (not standard markdown `#section-name`).

Example TOC entry:
```markdown
1. [Section Name](#h-section-name)
```

Back-to-top link:
```markdown
[↑ Back to top](#h-table-of-contents)
```

---

## Temp File Conventions

When editing wiki pages, use descriptive temp files:

```
/tmp/wiki-<descriptive-name>.md
```

Or in workspace:
```
a.Technology/OutlineWiki/_temp_<descriptive-name>.md
```

**Always clean up temp files** after successfully pushing to the wiki.

---

## Content Formatting Rules

### ❌ DO NOT Include H1 Title

Outline displays the document title in the UI. **Never start content with `# Title`** — it's redundant.

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
**BEFORE calling `create_document_outline`, ALWAYS check if a page with the same title already exists.**

### ⚠️ Real Failure: 2026-02-10

I created **5 duplicate "Azure DevOps MCP Server" pages** under `superpowers-plus-tools` because I didn't check first. 4 had to be manually deleted.

**This is not theoretical — it happened. Follow this pattern EVERY TIME.**

### MCP Pattern (Required)

```
# Step 1: List children of parent document
list_documents_outline(parentDocumentId: "parent-uuid")

# Step 2: Check if any child has the same title
# - If title exists → use update_document_outline instead
# - If title doesn't exist → safe to call create_document_outline
```

### Curl Fallback (if MCP unavailable)

```bash
PARENT_ID="parent-document-uuid"
TITLE="My New Page Title"

EXISTING=$(curl -s -X POST "https://your-wiki.example.com/api/documents.list" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"parentDocumentId\": \"$PARENT_ID\"}" | jq -r ".data[] | select(.title == \"$TITLE\") | .id")

if [ -n "$EXISTING" ]; then
  echo "Page already exists: $EXISTING — use update, not create"
else
  echo "Safe to create"
fi
```

### Why This Matters

| Problem | Consequence |
|---------|-------------|
| Outline allows duplicate titles | Multiple pages with same name under same parent |
| Multiple agents/sessions | Race condition creates duplicates |
| No automatic deduplication | Manual cleanup required |

**This check is MANDATORY before every `create_document_outline` call. No exceptions.**
</EXTREMELY_IMPORTANT>

---

## 🛡️ MANDATORY Pre-Deletion Backup

<EXTREMELY_IMPORTANT>
**Before calling `documents.delete` or `documents.archive`, you MUST create a local backup.**

### ⚠️ Real Failure: 2026-02-16

Both "Rules of Engagement (ROE)" pages were accidentally deleted during duplicate cleanup. While Outline's soft-delete allowed recovery via `documents.restore`, **we should never rely on trash retention**.

**This is not theoretical — it happened. Follow this pattern EVERY TIME before deleting.**

### Backup Directory

Configure a backup directory that persists across sessions. Examples:

```bash
# Option 1: Home directory (recommended)
$HOME/.outline-backups/

# Option 2: Workspace-relative
./wiki-backups/
```

**Important:** Do not use temporary directories (`/tmp/`) — backups must survive system restarts.

### Required Steps (MANDATORY)

**Step 1: Fetch full document content**

```
# MCP
get_document_outline(id: "document-id")

# Curl fallback
curl -s -X POST "https://your-wiki.example.com/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}' | jq '.data'
```

**Step 2: Save backup file with YAML frontmatter**

Filename: `{YYYY-MM-DD}_{document-id}_{url-slug}.md`

Example: `2026-02-16_2e45549a-c351-4f1d-9dab-b9d3f2639ff9_example-page-abc123xyz.md`

**Step 3: Include YAML frontmatter header**

```yaml
---
document_id: "2e45549a-c351-4f1d-9dab-b9d3f2639ff9"
title: "Rules of Engagement (ROE)"
url: "/doc/example-page-abc123xyz"
deleted_at: "2026-02-16T21:15:05.607Z"
collection_id: "81283145-644b-4f42-99a7-90018816c6c8"
parent_document_id: null
created_by: "Zach Nielsen"
backup_reason: "Pre-deletion backup before duplicate cleanup"
---

[Original document content here]
```

**Step 4: Verify backup file exists BEFORE proceeding**

```bash
# Confirm backup was written successfully
ls -la "a.Technology/OutlineWiki/_deleted_backups/{filename}.md"
cat "a.Technology/OutlineWiki/_deleted_backups/{filename}.md" | head -20
```

**Step 5: Only THEN call delete/archive**

```
# MCP (if available)
# Note: No MCP delete tool exists — use curl

# Curl
curl -s -X POST "https://your-wiki.example.com/api/documents.delete" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

### Recovery Procedure

If an accidentally deleted page needs to be restored:

**Option 1: Use Outline's Trash (if still available)**

```bash
curl -s -X POST "https://your-wiki.example.com/api/documents.restore" \
  -H "Authorization: Bearer $OUTLINE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

**Option 2: Recreate from Backup File**

```bash
# 1. Read backup file
cat "a.Technology/OutlineWiki/_deleted_backups/{filename}.md"

# 2. Extract content (skip YAML frontmatter)
# 3. Call documents.create with preserved content and metadata
```

```
create_document_outline(
  title: "[from frontmatter]",
  text: "[content after frontmatter]",
  collectionId: "[from frontmatter]",
  parentDocumentId: "[from frontmatter, if not null]",
  publish: true
)
```

### What Gets Preserved

| Field | Source |
|-------|--------|
| Document ID (original) | YAML frontmatter |
| Title | YAML frontmatter |
| URL slug | YAML frontmatter |
| Collection | YAML frontmatter |
| Parent document | YAML frontmatter |
| Full content | Body after frontmatter |
| Deletion timestamp | YAML frontmatter |
| Creator | YAML frontmatter |

**Note:** Restoring via `documents.create` generates a NEW document ID. The original URL slug will NOT be preserved.

### Deletion Without Backup = Policy Violation

**DO NOT skip this step.** If you attempt to delete without creating a backup:

1. **STOP immediately**
2. Create the backup first
3. Verify the backup file exists
4. Only then proceed with deletion

**This is not optional. This is not negotiable.**
</EXTREMELY_IMPORTANT>

---

## ⚠️ Table Column Widths Are Lost on API Update

<EXTREMELY_IMPORTANT>
Outline stores table column widths as **ProseMirror editor metadata**, NOT in the markdown text. When you push content via the API, **all custom column widths are reset to auto**.

**The API only accepts the `text` field (markdown) — no width metadata is exposed or accepted.**

### Before Updating Any Page

1. **Warn the user** that custom table formatting will be lost
2. **Ask for confirmation** before proceeding with the update
3. **After update**, inform user they may need to re-adjust column widths in the Outline UI

### Standard Warning Message

Use this before any `documents.update` call:

> ⚠️ **Formatting Warning:** Pushing content via API will reset any custom table column widths you've set in the Outline UI. After this update, you may need to re-adjust column widths manually. Proceed?

### What Gets Lost

| Preserved (in markdown) | Lost (editor metadata) |
|-------------------------|------------------------|
| Table content | Column widths |
| Cell alignment (`|:---|`) | Drag-resized columns |
| Row/column count | Visual proportions |

**This is a limitation of Outline's architecture, not a bug.**
</EXTREMELY_IMPORTANT>

---

## Checklist

### Before Creating New Pages
- [ ] 🚨 **FIRST: Called `list_documents_outline(parentDocumentId)` to check for duplicates**
- [ ] Confirmed no existing page has the same title
- [ ] 🔒 **SECRET SCAN** — Scanned content for credentials (see below)
- [ ] Only then called `create_document_outline`

### Before Editing/Pushing Any Wiki Content
- [ ] **Used MCP tools** (not curl) unless MCP unavailable
- [ ] Fetched current document state via `get_document_outline`
- [ ] Used fetched content as base for edits (not memory or stale local file)
- [ ] Verified document ID/UUID is correct
- [ ] **Content does NOT start with `# Title`** (Outline shows title in UI)
- [ ] 🔒 **SECRET SCAN** — Scanned content for credentials (see below)
- [ ] **Warned user about table column width loss** (if page has tables)
- [ ] 🔗 **VERIFIED ALL LINKS** (see below)
- [ ] Pushed updated content via `update_document_outline`
- [ ] Cleaned up temp files

### 🔒 Secret Detection (MANDATORY)

<EXTREMELY_IMPORTANT>

**Security Incident 2026-02-24:** SQL Server credentials were published to wiki. **This MUST NEVER happen again.**

**Before pushing ANY wiki content, scan for secrets:**

| Search For | If Real Value Found |
|------------|---------------------|
| `password`, `pwd`, `secret` | 🛑 STOP — remove or redact |
| `token`, `api_key`, `credential` | 🛑 STOP — remove or redact |
| `private_key`, `connection_string` | 🛑 STOP — remove or redact |

**Safe alternatives:**
- Environment variable: `${DB_PASSWORD}`
- Redacted marker: `[REDACTED: production SQL password]`
- Placeholder: `<YOUR_API_KEY_HERE>`

**MCP Hard Block (v5.9.0+):** The Outline MCP server will **automatically reject** content containing secrets. This is the last line of defense — catch secrets BEFORE hitting this block.

**See:** `_shared/secret-detection.md` for full pattern list.

</EXTREMELY_IMPORTANT>

### 🔗 Link Verification (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before pushing ANY wiki content, verify ALL links:**

| Link Type | How to Verify |
|-----------|---------------|
| Internal wiki (`/doc/slug`) | `documents.info` API — check `.ok == true` |
| External URLs | `curl -s -o /dev/null -w "%{http_code}"` — check 200/302 |
| Azure DevOps repos | `repo_get_repo_by_name_or_id_azure-devops` |

**Invoke `superpowers:link-verification` skill if adding Code References or multiple links.**

**Incident 2026-02-20:** Hallucinated `/doc/example-page-xyz789` — caught by USER, not agent.

</EXTREMELY_IMPORTANT>

### Before Deleting/Archiving Pages
- [ ] 🛡️ **FIRST: Fetched full document content via `get_document_outline`**
- [ ] Created backup file at `a.Technology/OutlineWiki/_deleted_backups/{YYYY-MM-DD}_{id}_{slug}.md`
- [ ] Included YAML frontmatter with: document_id, title, url, deleted_at, collection_id, parent_document_id
- [ ] **Verified backup file exists and contains content**
- [ ] Only then called `documents.delete` or `documents.archive`

