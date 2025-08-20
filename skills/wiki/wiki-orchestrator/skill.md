---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["create wiki page", "update wiki", "document X in wiki", "write wiki documentation for", "publish to wiki", "wiki:create", "wiki:update", "wiki:publish", "cross-reference wiki", "bulk wiki update", "update all wiki pages", "add links across wiki", "fix wiki formatting", "structure this wiki page", "improve readability", "Outline markdown rules", "update wiki page", "push to outline", "edit wiki", "create wiki document", "delete wiki page"]
description: "Unified wiki skill — the ONLY entry point for all wiki authoring, editing, and publishing. Runs quality pipeline (de-dup, link-verification, secret-scan, slop-detection, fact-check) then publishes. Replaces wiki-editing, wiki-authoring, and outline-wiki-editing."
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: ["link-verification"]
  escalates_to: []
  internal: false
---

# Wiki Orchestrator

> **Purpose:** Enforce quality pipeline for ALL wiki authoring, editing, and publishing.
> **Philosophy:** Make quality control unavoidable, not optional.

---

## ⛔ The Pipeline

<EXTREMELY_IMPORTANT>

**Every wiki operation MUST pass through this pipeline. No exceptions.**

| Stage | Gate | What Happens |
|-------|------|-------------|
| 1. De-duplication | WARN | Search for similar pages; offer update if match |
| 2. Content Generation | — | Apply formatting rules (see Content Formatting below) |
| 2.5 Content Coherence | ADVISORY | `wiki-content-coherence`: Jaccard ≥0.40 flags duplication |
| 3. Link Verification | **BLOCK** | `link-verification`: Internal wiki + repo links block on failure |
| 4. Secret Scan | **BLOCK** | Search for `password`, `secret`, `token`, `api_key`, `credential`, `private_key` |
| 5. Slop Detection | ADVISORY | `eliminating-ai-slop`: GVR slop scoring |
| 5.5 Table Discipline | ADVISORY | `markdown-table-discipline` |
| 6. Fact-Check | WARN | `wiki-debunker`: Count cited vs uncited claims |
| 7. Publish | — | Execute via MCP tools (see Publishing Rules below) |

**Hard gates block publishing.** Advisory gates warn but don't block.
</EXTREMELY_IMPORTANT>

---

## Content Formatting (Stage 2)

- **No H1** — Outline renders title in UI. Start body with `##` or summary paragraph.
- **Anchors:** `#h-section-name` (not `#section-name`) — Outline-specific format.
- **No HTML** — `<details>`, `&nbsp;`, callouts (`> [!info]`), inline HTML all break.
- **Tables:** Keep narrow (<80 chars). Column widths are ProseMirror metadata — lost on API update.
- **Code blocks:** Always specify language.
- **Table cells:** No `[ ]` checkboxes (escaped to `\[`), no `&nbsp;` (rendered as literal text). Use `Yes/No` or `✓/✗`.
- **Heading hierarchy:** H1 once (title only), then H2/H3. Max depth H3 for readability.

---

## Publishing Rules (Stage 7)

<EXTREMELY_IMPORTANT>

### MCP Tools First
Always use `get_document_outline`, `update_document_outline`, `create_document_outline`. Curl is fallback only.

### Download Before Editing
Fetch current state via `get_document_outline` BEFORE any edit. Never use memory or stale files. This prevents overwriting concurrent edits. **Also applies when correcting mistakes** — user may have already fixed the issue.

### Write Scope Restriction
Only write to allowed roots. Walk the parent chain to verify:
- `matt-bordenet-OUENQSb8BE` (Matt Bordenet personal)
- `team-delta-[product]-phone-assist-PmmvNP0Pha` (Team Delta)
- `[product]-WaniaoGMuW` ([Product] product pages)

If out of scope → STOP and ask user. Do NOT assume a parent is in-scope just because its title sounds relevant.

### Check for Duplicates Before Creating
`list_documents_outline(parentDocumentId)` → check if child with same title exists → use `update` if so.

### Pre-Deletion Backup
Before `delete`/`archive`: fetch full document → save to `_deleted_backups/{YYYY-MM-DD}_{id}_{slug}.md` with YAML frontmatter → verify backup exists → only then delete.

### Post-Update Verification
After every update, fetch the document again. Scan for `\[`, `\]`, literal `&nbsp;`, empty hrefs, malformed tables. Fix before reporting success.
</EXTREMELY_IMPORTANT>

---

## Checklists

**Before Creating:** Check duplicates → Verify write scope → Secret scan → Verify links → `create_document_outline`
**Before Editing:** Fetch current state → Use as base → Secret scan → Verify links → Warn about column widths → `update_document_outline` → Verify result
**Before Deleting:** Fetch full content → Backup with frontmatter → Verify backup → Search for inbound links → Delete

---

## Failure Recovery

- **Context exhausted mid-pipeline:** Task list preserves state. Resume from last completed stage.
- **Hard gate blocks:** Fix the issue (broken link, secret), re-run from that stage. Do NOT skip.

## Batch Operations

**3+ pages:** Discover → Plan → Execute in chunks → Verify. Always fetch FRESH content before editing. See `references/batch-operations.md`.

## Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "Quick update, skip verification" | Quick updates break links too |
| "I know the links are correct" | Memory is unreliable, verify anyway |
| "I'll verify after publishing" | That's backwards — verify BEFORE |

## Related Skills

| Skill | Role |
|-------|------|
| `wiki-content-coherence` | Stage 2.5: Duplication detection |
| `link-verification` | Stage 3: URL verification (HARD GATE) |
| `eliminating-ai-slop` | Stage 5: Prose quality |
| `wiki-debunker` | Stage 6: Fact-checking |
| `wiki-verify` | Post-publish: Version drift |

## Reference Files

- [`references/stage-output-examples.md`](references/stage-output-examples.md) — Output templates
- [`references/batch-operations.md`](references/batch-operations.md) — Multi-page edit workflow
