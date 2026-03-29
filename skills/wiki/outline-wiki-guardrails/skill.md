---
name: outline-wiki-guardrails
source: superpowers-callbox
description: Outline wiki platform-specific guardrails — URL construction, content operations, table syntax, embed handling, pre-archive checks. Co-activated by wiki editing skills. Not intended for direct user invocation.
summary: "Platform guardrails for Outline wiki. Co-activated automatically by outline-wiki-editing."
triggers: ["wiki embed", "wiki table syntax", "outline guardrails", "outline toggle syntax"]
coordination:
  group: wiki
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Outline Wiki — Platform Guardrails

## Content Operations: Never Use Heredocs

Terminal heredocs with special characters (emojis, pipes, quotes) corrupt wiki content.
**Always:** `save-file` → MCP tool → cleanup. **Never:** heredocs or inline JSON with markdown.

---

## URL Fields: `url` vs `urlId`

Outline API returns two fields. Using the wrong one produces broken links:

| Field | Use For | Example |
|-------|---------|---------|
| `urlId` | API calls only | `eeIBYJXPez` |
| `url` | **User-facing links** | `/doc/page-title-eeIBYJXPez` |
| `id` | Internal UUID | `uuid-string` |

**WRONG:** `https://wiki.int.callbox.net/doc/{urlId}` → 404 (SPA returns 200 but renders "Not Found")
**RIGHT:** `https://wiki.int.callbox.net{url}` → works

Outline is an SPA — curl always returns 200, so HTTP status checks are unreliable for link verification.

---

## Link Construction: Full Slug Required

**WRONG:** `/doc/Buc2GNFqhG` (short urlId — does not resolve)
**RIGHT:** `/doc/the-role-of-the-interviewer-Buc2GNFqhG` (full slug from `url` field)

Before writing ANY `/doc/` link: fetch the document, extract the `url` field, use that.

---

## Table Cell Syntax Restrictions

Outline's ProseMirror parser inside table cells:
- Escapes `[` to `\[` (breaks checkboxes, links)
- Renders `&nbsp;` as literal text (not whitespace)

**Use:** `Yes/No` or `✓/✗` instead of `[ ]/[x]`. Plain spaces instead of `&nbsp;`.

---

## Post-Update Verification

After EVERY wiki update via API, fetch the document again and verify:

1. **Length check:** Updated text length ≥ original text length (unless content was intentionally removed).
2. **Tail check:** The last heading or paragraph of the page is still present.
3. **Artifact scan:** No `\[`, `\]`, literal `&nbsp;`, `&mdash;`, empty hrefs `[text]()`, malformed tables.
4. **Structure check:** Opening and closing `+++` toggles are balanced.

Fix before reporting success. **Never report "Updated successfully" without verification.**

**If verification fails:** Restore immediately from the pre-edit snapshot (`~/.codex/_edit_snapshots/{uuid}.md`). See `outline-wiki-editing/references/edit-snapshot.md` for the full recovery procedure.

---

## Curl Fallback (if MCP unavailable)

**Base URL:** `https://wiki.int.callbox.net/api`
**Auth:** `source ~/.codex/.env && curl -H "Authorization: Bearer $OUTLINE_API_KEY"`
**Anchor format:** `#h-section-name` (not `#section-name`)

---

## Toggle Block Syntax

Outline's collapsible/toggle block uses `+++` markers (NOT `:::details` or `<details>`):

```markdown
+++
Toggle title here
Body content (any blocks: paragraphs, lists, code, etc.)
+++
```

- The **first child** (heading or paragraph) becomes the toggle title.
- Nested toggles use additional `+` characters: `++++`, `+++++`, etc.
- The `+++` markers must be on their own lines.

### TOC in Toggle Blocks

When the wiki-orchestrator TOC rule triggers (4+ H2/H3 headings), the TOC **must** be wrapped in a toggle block. See `outline-wiki-editing` skill for the full format.

**Detection for idempotency:** Before inserting, scan for a `+++` block whose first line contains `Table of contents` (case-insensitive). If found, update rather than duplicate.

---

## Table Column Widths Lost on API Update

ProseMirror stores column widths as metadata, not markdown. API updates reset all widths to auto.
Warn user before updating pages with custom column widths.

---

## Pre-Archive/Delete: Check Inbound Links

Before archiving or deleting, search for pages that link to the target:
```
search_documents_outline(query: "url-slug-here")
search_documents_outline(query: "Page Title Here")
```
If inbound links found → update referencing pages first OR get explicit user approval.

---

## Embeds Break on API Update

Outline document embeds are stored in ProseMirror metadata, NOT in markdown.
The API returns identical markdown whether an embed is working or broken.

**Detection:** Self-referential links where URL appears as both text and href:
`[https://wiki.int.callbox.net/doc/X](https://wiki.int.callbox.net/doc/X)`

**If detected:** Warn user that API update WILL break the embed. No workaround exists.
Embed must be manually re-added in Outline UI after API update.



## When to Use

- Automatically co-activated with wiki-orchestrator for ALL Outline wiki operations
- When constructing wiki URLs (use `url` field, not `urlId`)
- When debugging wiki link 404s or embed breakage
- This is a platform guardrail — wiki-orchestrator drives workflow

## Failure Modes

| Failure | Fix |
|---------|-----|
| Used `urlId` instead of `url` field — link 404s | Always extract `url` field from API response for user-facing links |
| Embed broke after API update | Warn user before updating pages with embeds — must re-add manually in UI |
| Table checkboxes rendered as `\[` | Use `Yes/No` or `✓/✗` instead of `[ ]` in table cells |
| Column widths reset after update | Warn user — ProseMirror metadata is lost on API update |
| Used `:::details` for toggle — not rendered | Use `+++` markers (Outline's actual toggle syntax) |
| TOC anchors use `#section` instead of `#h-section` | Always prefix anchors with `h-` for Outline |
| Duplicate TOC after re-run | Check for existing `+++` block with "Table of contents" before inserting |
| Bulk update truncated page content | Pre-edit snapshot + post-update length verification. Restore from `~/.codex/_edit_snapshots/` |

```bash
# Example: verify an Outline document URL is correct
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill outline-wiki-guardrails
```
