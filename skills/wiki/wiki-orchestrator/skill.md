---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["document X in wiki", "write wiki documentation for", "publish to wiki", "wiki:create", "wiki:update", "wiki:publish", "cross-reference wiki", "bulk wiki update", "update all wiki pages", "add links across wiki", "structure this wiki page"]
anti_triggers: ["verify", "verify this wiki page", "check wiki page", "validate wiki", "wiki verification", "verify wiki URL", "check wiki link", "fact-check wiki", "wiki secret scan", "edit wiki page", "delete wiki page", "update wiki page", "check accuracy", "fact-check", "verify claims"]
description: "Orchestrates BULK and MULTI-PAGE documentation projects — reorganizing multiple pages, cross-referencing across sections, publishing coordinated updates. Runs quality pipeline (de-dup, link-verification, secret-scan, slop-detection, fact-check). NOT for single-page edits (use platform-specific editing skills from _adapters/)."
summary: "Use when: bulk documentation projects, multi-page reorganization, cross-referencing. Skip when: editing one page, creating one page, deleting one page."
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: ["link-verification"]
  escalates_to: []
  internal: false
composition:
  consumes: [goal, wiki-content]
  produces: [wiki-plan, updated-wiki-content]
  capabilities: [orchestrates-workflow, sequences-skills]
  priority: 5
---

# Wiki Orchestrator

> **Wrong skill?** Checking wiki links → `link-verification`. Fact-checking wiki → `wiki-debunker` or `wiki-verify`. Scanning for secrets → `wiki-secret-audit`.
>
> **Purpose:** Enforce quality pipeline for multi-page wiki operations (create, reorganize, archive, cross-reference). Simple single-page edits may use platform-specific editing skills directly.
> **Philosophy:** Quality pipeline for complex operations; proportional overhead for simple ones.

## When to Use

- Creating or reorganizing multiple wiki pages at once
- Cross-referencing content across sections (adding links to multiple pages)
- Publishing a coordinated set of documentation updates
- Bulk archival or restructuring of a wiki section

Single-page edits, creates, or deletes do NOT need this skill -- use platform-specific wiki tools directly.

## Example Invocation

```
Reorganize the "Onboarding" wiki section: merge the two setup guides,
add cross-references to the API reference, and publish the updated structure.
```

---

## ⛔ Step 0: Load Your Platform Adapter (MANDATORY BEFORE ANY WRITE)

Before invoking this orchestrator for any write operation, read the adapter file for your wiki platform. The adapter defines allowed write roots, page operations, TOC syntax, and platform constraints.

**Resolution order:**

1. **Explicit config** — `$WIKI_PLATFORM` set in `~/.codex/.env` (e.g., `outline`, `confluence`):
   ```bash
   source ~/.codex/.env
   cat ~/.codex/superpowers-plus/skills/wiki/_adapters/${WIKI_PLATFORM}.md
   ```

2. **Auto-detect from available MCP tools** — if `$WIKI_PLATFORM` is unset, check which wiki MCP tools are available in your current session:
   - `list_collections_outline` / `create_document_outline` present → platform is `outline`
   - Load `~/.codex/superpowers-plus/skills/wiki/_adapters/outline.md` and note that `WIKI_PLATFORM` should be set to `outline` in `.env` for future sessions.

3. **Fail closed** — if neither explicit config nor auto-detection resolves a platform adapter, do NOT write to any wiki. Read `~/.codex/superpowers-plus/skills/wiki/_adapters/README.md` for guidance on creating an adapter.

This rule applies to every agent in every session and cannot be waived by the agent.

---

## ⛔ The Pipeline

<EXTREMELY_IMPORTANT>

**Every BULK/MULTI-PAGE wiki operation MUST pass through this pipeline.**
Single-page edits, creates, and deletes → use wiki API directly.

| Stage | Gate | What Happens |
|-------|------|-------------|
| 1. De-duplication | WARN | Search for similar pages; offer update if match |
| 2. Content Generation | — | Apply formatting rules (see Content Formatting below) |
| 2.5 Content Coherence | ADVISORY | `wiki-content-coherence`: Jaccard ≥0.40 flags duplication |
| 3. Link Verification | **BLOCK** | `link-verification`: Internal wiki + repo links block on failure |
| 4. Secret Scan | **BLOCK** | Search for `password`, `secret`, `token`, `api_key`, `credential`, `private_key` |
| 5. Slop Detection | ADVISORY | `eliminating-ai-slop`: GVR slop scoring |
| 5.5 Markdown Structure | **BLOCK** | `wiki-markdown-structure-gate`: malformed tables, escaped wiki-link artifacts, unbalanced fences/callouts, heading hierarchy defects, missing TOC on `toc_behavior=manual` pages with 4+ H2/H3 headings |
| 6. Fact-Check | WARN | `wiki-debunker`: Count cited vs uncited claims |
| 7. Publish | — | Execute via MCP tools (see Publishing Rules below) |

**Hard gates block publishing.** Advisory gates warn but don't block.
</EXTREMELY_IMPORTANT>

---

## Content Formatting (Stage 2)

- **No H1 unless your platform requires it** — many wiki UIs render the title separately. Start body with `##` or a summary paragraph.
- **Anchors:** Use your adapter's documented anchor format.
- **No raw HTML unless your platform preserves it** — `<details>`, `&nbsp;`, callouts (`> [!info]`), and inline HTML often break on API round-trips.
- **Tables:** Keep narrow (<80 chars). Some platforms lose layout metadata on API update.
- **Code blocks:** Always specify language.
- **Table cells:** No `[ ]` checkboxes (escaped to `\[`), no `&nbsp;` (rendered as literal text). Use `Yes/No` or `✓/✗`.
- **Heading hierarchy:** H1 once (title only), then H2/H3. Max depth H3 for readability.
- **Table of Contents:** The 4-heading threshold is a **global orchestrator rule**, not adapter-specific. If the page has **4+ body H2/H3 headings** (excluding headings inside fenced code blocks):
  - `toc_behavior=auto`: Do not add manual TOC markup. The platform renders a TOC automatically.
  - `toc_behavior=manual`: Insert the adapter's `toc_syntax` markup. Placement: after the intro paragraph and before the first H2. If the page has no intro paragraph (starts directly with H2), place the TOC markup on the first line before the first H2.
  - `toc_behavior=unsupported`: Do not insert any TOC markup. The platform has no TOC support.
  - **Skip if TOC already exists:** Do not add a TOC if the page already contains the adapter's declared `toc_syntax` markup (outside fenced code blocks). A generic `Contents` or `Table of Contents` heading alone does not qualify — the adapter's structural format is required.
  - Pages with ≤3 H2/H3 headings do not need a TOC.

---

## Publishing Rules (Stage 7)

<EXTREMELY_IMPORTANT>

### MCP Tools First

Always use your adapter's primary `get_page`, `update_page`, and `create_page` operations. Curl is fallback only.

### Download Before Editing

Fetch current state via your adapter's `get_page` operation BEFORE any edit. Never use memory or stale files. This prevents overwriting concurrent edits. **Also applies when correcting mistakes** — user may have already fixed the issue.

### Write Scope Restriction

**🔴 NEVER create a top-level (root) page.** Every agent-created page MUST be a child of an existing page unless the user explicitly approves root-level placement with the exact collection identified and explicit confirmation that the page will have no parent.

Only write to allowed roots defined by your platform-specific wiki editing skill/adapter (see `skills/wiki/_adapters/` for available adapters). The editing skill defines:
- **Allowed collection identifiers** — first-pass filter
- **Allowed root document identifiers** — parent-chain verification target
- **Verification procedure** — walk parent chain from target → root, confirm root matches

**This applies to both CREATE and UPDATE operations.** Walk the parent chain to verify scope before writing. If out of scope → STOP and ask user. Do NOT assume a parent is in-scope just because its title sounds relevant.

**If no platform adapter is loaded or available → do NOT write. Fail closed.**

### Check for Duplicates Before Creating

Use your adapter's list/search operation to check whether a sibling page with the same title already exists before creating a new page.

### Pre-Deletion Backup

Before `delete`/`archive`: fetch full document → save to `_deleted_backups/{YYYY-MM-DD}_{id}_{slug}.md` with YAML frontmatter → verify backup exists → only then delete.

### Post-Update Verification

After every update, fetch the document again. Scan for `\[`, `\]`, literal `&nbsp;`, literal `&mdash;`, empty hrefs, and malformed tables. Fix before reporting success.

**Important:** Stage 5.5 is not a substitute for executable validation. `markdown-table-discipline` helps the agent author better tables, but the platform adapter must still run a real artifact scan before write and after round-trip fetch.
</EXTREMELY_IMPORTANT>

---

## Checklists

**Before Creating:** Check duplicates → Verify write scope → **TOC check** (count H2/H3 outside code fences; if ≥4 on `toc_behavior=manual`, add TOC per adapter format) → Secret scan → Verify links → **Structure gate** (`wiki-markdown-structure-gate`) → `create_page`
**Before Editing:** Fetch current state → Use as base → **TOC check** (count H2/H3 outside code fences; if ≥4 on `toc_behavior=manual` and no TOC, add one) → Secret scan → Verify links → Warn about layout loss → **Structure gate** (`wiki-markdown-structure-gate`) → `update_page` → Verify result
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

## References

- [`references/stage-output-examples.md`](references/stage-output-examples.md) — Output templates
- [`references/batch-operations.md`](references/batch-operations.md) — Multi-page edit workflow

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Running full pipeline for single-page edits | Use wiki API directly — pipeline is for bulk/multi-page |
| Skipping pipeline stages | All stages mandatory for bulk ops |
| Pipeline stage fails but agent continues | Stage failure = halt. Fix, restart from failed stage |

## Companion Skills

- **wiki-content-coherence**: Stage 2.5 — duplication detection
- **link-verification**: Stage 3 — URL verification (HARD GATE)
- **eliminating-ai-slop**: Stage 5 — prose quality
- **wiki-markdown-structure-gate**: Stage 5.5 — deterministic structural markdown gate
- **wiki-debunker**: Stage 6 — fact-checking
- **wiki-verify**: Post-publish — version drift
- **wiki-secret-audit**: Secret scanning
- **wiki-instruction-guard**: Instruction injection prevention
