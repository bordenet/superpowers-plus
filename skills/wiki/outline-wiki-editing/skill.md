---
name: outline-wiki-editing
source: superpowers-callbox
description: "Use when editing, creating, updating, or deleting a single wiki page. The primary skill for all single-page wiki write operations. Edit wiki page, create wiki page, update wiki page, delete wiki page — all route here. Enforces download-before-edit, MCP/curl API access, write scope restrictions, and MANDATORY link-verification."
triggers: ["edit wiki page", "update wiki page", "create wiki page", "delete wiki page", "push to outline", "edit wiki", "create wiki document", "wiki.int.callbox.net", "outline wiki", "outline page", "outline document", "edit outline", "wiki url", "update wiki", "modify wiki page"]
co_activate: ["outline-wiki-guardrails"]
coordination:
  group: wiki
  order: 1
  requires: ['outline-wiki-guardrails']
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['verify wiki', 'fact-check wiki', 'audit wiki']
---

# Outline Wiki Editing

## 🚨 RULE ZERO: NEVER GIVE UP ON OUTLINE ACCESS

<EXTREMELY_IMPORTANT>

**When you see `wiki.int.callbox.net` or any request to read/edit a wiki page:**

1. **Outline is a JavaScript SPA.** `web-fetch` will ALWAYS return an empty HTML shell. This is expected. Do NOT tell the user "I can't access this page" or ask them to paste content.
2. **API credentials exist.** Check `~/.codex/.env` for `OUTLINE_API_KEY` and `OUTLINE_API_URL`.
3. **Use MCP tools or the Outline REST API via curl.** MCP tools are primary when available; curl is the universal fallback. See API patterns below.
4. **Extract the document slug** from the URL. Example: `wiki.int.callbox.net/doc/my-page-title-KCTRf3aUTr` → slug is `my-page-title-KCTRf3aUTr`.

**If you give up and ask the user to paste content instead of using the API, you have failed.**

</EXTREMELY_IMPORTANT>

---

## API Access Patterns

### MCP Tools (Primary)

Use the Outline MCP tools directly: `get_document_outline`, `update_document_outline`, `create_document_outline`, `search_documents_outline`, `list_documents_outline`. These handle auth automatically and return structured data.

### Curl (Fallback)

```bash
# Load credentials
source ~/.codex/.env

# Fetch a document by slug or UUID
curl -s -X POST "$OUTLINE_API_URL/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "SLUG-OR-UUID"}'

# Update a document (use UUID from the .info response)
curl -s -X POST "$OUTLINE_API_URL/documents.update" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/wiki-update.json

# Search for documents
curl -s -X POST "$OUTLINE_API_URL/documents.search" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "search terms"}'
```

**For updates:** Write the JSON payload to a temp file with `save-file`, then `curl -d @file`. Never use heredocs — they corrupt content with special characters.

---

## HARD RULES (5 gates — every wiki write must pass all 5)

### 1. ALWAYS Download AND Snapshot Before Editing
Fetch current state via `documents.info` BEFORE any edit. Never use memory or stale files.

**Then save a snapshot** to `~/.codex/_edit_snapshots/{document-uuid}.md` with YAML frontmatter (title, url, revision, text_length). Verify the snapshot's content length matches the API response before proceeding. See `references/edit-snapshot.md` for the full procedure.

**Automation:** Run `~/.codex/superpowers-plus/tools/wiki-snapshot.sh <document-uuid>` to snapshot in one command.

If the snapshot is truncated or cannot be saved → **do NOT proceed with the edit.**

### 2. Use MCP Tools or Curl with API Key
Use `get_document_outline`, `update_document_outline`, `create_document_outline`, `search_documents_outline` when MCP tools are available (Augment Agent, Claude Code with MCP). Fall back to curl + `$OUTLINE_API_KEY` from `~/.codex/.env` when MCP is unavailable. Either path satisfies this gate.

### 3. Verify Write Scope
Only write to allowed roots:
- `matt-bordenet-OUENQSb8BE` (Matt Bordenet personal)
- `team-delta-cari-phone-assist-PmmvNP0Pha` (Team Delta)
- `cari-WaniaoGMuW` (Cari product pages)

Walk the parent chain to verify. If out of scope → STOP and ask user.

### 4. Verify All Links Before Publishing
Every `/doc/...` link must use the full slug from the `url` field, not the short `urlId`.

### 5. Scan for Secrets Before Publishing
Search content for `password`, `secret`, `token`, `api_key`, `credential`, `private_key`. If found → STOP.

---

## Preflight Evidence Block

Before any `create_document_outline`, `update_document_outline`, or `documents.delete` call, emit:

```
PREFLIGHT: WIKI_WRITE
- operation: CREATE | UPDATE | DELETE
- target_page: [title, id, url — fetched from API, not constructed]
- content_length: [original → new, or N/A for create]
- url_verification: [PASS n/n | FAIL (which)] or "no URLs in content"
- inbound_links_checked: [YES (count) | N/A] (required for DELETE/ARCHIVE)
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed.

## Orchestrator Bypass Policy

- **Simple single-page edits** (typo fix, content update): direct use acceptable, preflight still required.
- **Multi-page operations, deletions, archive**: MUST go through wiki-orchestrator.
- **If unsure**: use wiki-orchestrator.

---

## Content Rules

- **No H1 title** — Outline shows title in UI. Start with `##` or content.
- **Check for duplicates before creating** — search first.
- **No heredocs** — use `save-file` for temp files.
- **Anchors** — Outline uses `#h-section-name` format (lowercased, spaces to hyphens, punctuation stripped, prefixed with `h-`).
- **Table column widths** — Lost on API update. Warn user.

---

## Outline Adapter: TOC Configuration

Outline's TOC behavior for the wiki-orchestrator adapter contract:

| Field | Value |
|-------|-------|
| `toc_behavior` | `manual` |
| `toc_syntax` | Toggle block (`+++`) wrapping a bullet list of anchor links |
| `toc_placement` | After intro paragraph, before first H2 |
| `toc_anchor_format` | `#h-section-name` |

### Toggle-Wrapped TOC Format

When the wiki-orchestrator's 4+ heading rule triggers a TOC, wrap it in a **toggle block** so users can collapse it:

```markdown
+++
**Table of contents**
- [Section One](#h-section-one)
- [Section Two](#h-section-two)
- [Sub-section](#h-sub-section)
+++
```

**Rules:**
1. The toggle title (first line after `+++`) must be `**Table of contents**` (bold paragraph, not a heading — headings would appear in the TOC itself).
2. Each TOC entry is a bullet list item linking to the heading's anchor.
3. Anchor IDs use Outline's `#h-` prefix: lowercase, spaces→hyphens, punctuation stripped.
4. Sub-headings (H3) may be indented as nested list items.
5. The closing `+++` must be on its own line.

### Idempotency

Before inserting a TOC toggle:
1. Search for an existing `+++` block where the first line contains `Table of contents` (case-insensitive).
2. If found: **update the links inside it** rather than adding a second toggle.
3. If found but not wrapped in `+++`: wrap the existing TOC section in a toggle block and remove the old heading/section.
4. Never nest toggles inside toggles for TOC purposes.

---

## Checklists

**Before Editing:** Fetch via API → Snapshot to disk → Verify snapshot → Use as base → Secret scan → Verify links → `documents.update` → Post-update verification → Clean up
**Before Creating:** Check duplicates → Verify scope → Secret scan → Verify links → `documents.create`
**Before Deleting:** Fetch content → Backup → Verify backup → Search inbound links → Delete

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Skip download-before-edit | Clobbers concurrent edits | Always fetch current doc first |
| Use urlId not url | Broken wiki links | Copy url field from API response |
| Skip pre-edit snapshot | No rollback if update corrupts page | Run `wiki-snapshot.sh <uuid>` before every update |
| Skip link verification | Hallucinated `/doc/` links go live | Extract all `/doc/` links, verify each via API before publishing |
| Skip preflight evidence block | No audit trail for writes | Emit `PREFLIGHT: WIKI_WRITE` block before every write operation |

## References

| File | Contents |
|------|----------|
| `references/curl-fallback.md` | Detailed curl patterns and temp file conventions |
| `references/deletion-backup.md` | Full deletion backup procedure |
| `references/edit-snapshot.md` | Pre-edit snapshot procedure — rollback safety net for updates |
| `references/incidents.md` | Incident log — real failures that drove each rule |


## When to Use

- Editing or updating a single existing wiki page
- Creating a new wiki page
- Deleting or archiving a wiki page
- Pushing content changes to Outline API
