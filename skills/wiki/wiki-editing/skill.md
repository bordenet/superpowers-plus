---
name: wiki-editing
source: superpowers-plus
triggers: ["wiki-editing:execute", "delete wiki page"]
description: "INTERNAL SKILL — Invoked by wiki-orchestrator as Stage 7. Do NOT invoke directly. Enforces download-before-edit pattern, MCP-first tooling, and write scope restrictions. Platform-specific setup in skills/wiki/_adapters/."
---

# Wiki Editing

> **Adapter:** See `skills/wiki/_adapters/` for platform-specific configuration (Outline, Notion, Confluence, etc.)
> **See also:** [reference.md](./reference.md) (patterns), [examples.md](./examples.md) (incidents)

## Setup

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `WIKI_PLATFORM` | Your wiki platform: `outline`, `notion`, `confluence` |

**Platform-specific variables:** See your adapter file in `skills/wiki/_adapters/`.

---

<EXTREMELY_IMPORTANT>
## ⚠️ ORCHESTRATOR BYPASS DETECTION — CHECK FIRST

**Before executing ANY create/update operation, ask:**

> "Did this request come through `wiki-orchestrator`?"

### If YES (Orchestrator Invoked This Skill)

✅ Proceed — quality pipeline already ran.

### If NO (Direct Invocation)

Display warning and ask user to confirm. See [examples.md](./examples.md) for warning message.
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## 🎯 PREFER MCP TOOLS OVER CURL

**ALWAYS use your platform's MCP tools first** — they handle authentication, error handling, and JSON escaping automatically.

| When | Use |
|------|-----|
| **Default** | MCP tools |
| MCP fails | API fallback |
| Debugging | API (for raw response) |

**See `skills/wiki/_adapters/{platform}.md` for your platform's MCP tool mappings.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## ⛔ WIKI WRITE SCOPE RESTRICTION

**Before ANY write operation, verify the target is within allowed scope.**

Configure `WIKI_ALLOWED_ROOTS` in your adapter with document/collection IDs that permit writes.

### Scope Verification

1. Get target document info via adapter's `get_page`
2. Check if document ID OR any parent matches an allowed root
3. **IN SCOPE** → proceed
4. **OUT OF SCOPE** → STOP, display warning, ask for confirmation

**Read operations remain unrestricted.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## ALWAYS Download Before Editing

Before making ANY edit to a wiki page, you MUST:

1. **Fetch current document state** via adapter's `get_page`
2. **Use that fetched content as the base** for all edits
3. **Verify** local temp files reflect current wiki state

**Violating this rule risks overwriting another agent's or user's work.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## 🚨 Check for Duplicates Before Creating

**BEFORE calling `create_page`, ALWAYS check if page with same title exists.**

1. Use adapter's `list_pages` to get children of parent
2. Check if any child has the same title
3. If title exists → use `update_page` instead
4. If doesn't exist → safe to call `create_page`

**This check is MANDATORY. Duplicate pages were created because this was skipped.**
</EXTREMELY_IMPORTANT>

---

<EXTREMELY_IMPORTANT>
## 🛡️ MANDATORY Pre-Deletion Backup

**Before calling `delete_page` or `archive_page`, you MUST create a local backup.**

### Required Steps

1. Fetch full document via adapter's `get_page`
2. Save backup to `$HOME/.wiki-backups/{YYYY-MM-DD}_{id}_{slug}.md`
3. Include YAML frontmatter (document_id, title, url, deleted_at)
4. **Verify backup file exists BEFORE proceeding**
5. Only then call `delete_page`

**Deletion without backup = policy violation.**
</EXTREMELY_IMPORTANT>

---

## Checklist

### Before Creating New Pages
- [ ] 🚨 **FIRST: Used adapter's `list_pages` to check for duplicates**
- [ ] 🔒 **SECRET SCAN** — Scanned content for credentials
- [ ] Only then called `create_page`

### Before Editing/Pushing
- [ ] **Used MCP tools** (not API) unless unavailable
- [ ] Fetched current state via `get_page`
- [ ] Used fetched content as base
- [ ] 🔒 **SECRET SCAN** — Scanned for credentials
- [ ] 🔗 **VERIFIED ALL LINKS**
- [ ] Pushed via `update_page`

### Before Deleting
- [ ] 🛡️ **Fetched full content via `get_page`**
- [ ] Created backup at `$HOME/.wiki-backups/`
- [ ] **Verified backup exists**
- [ ] Only then called `delete_page`

---

## 🔒 Secret Detection (MANDATORY)

<EXTREMELY_IMPORTANT>

**Search for:** `password`, `pwd`, `secret`, `token`, `api_key`, `credential`, `private_key`

**If real value found:** 🛑 STOP — remove or redact

**Safe alternatives:**
- Environment variable: `${DB_PASSWORD}`
- Redacted marker: `[REDACTED: production password]`

**See:** `_shared/secret-detection.md` for full pattern list.
</EXTREMELY_IMPORTANT>

---

## 🔗 Link Verification (MANDATORY)

<EXTREMELY_IMPORTANT>

**Before pushing, verify ALL links:**

| Link Type | How to Verify |
|-----------|---------------|
| Internal wiki | Adapter's `get_page` |
| External URLs | `curl -s -o /dev/null -w "%{http_code}"` |
| Repository | Repo adapter verification |

**Invoke `superpowers:link-verification` skill if adding multiple links.**
</EXTREMELY_IMPORTANT>

---

## ⚠️ Table Column Widths May Be Lost

Some platforms store table widths as editor metadata, not markdown. Warn user before updating pages with tables.

---

## Related Skills

- **wiki-orchestrator**: Full quality pipeline
- **wiki-authoring**: Content formatting
