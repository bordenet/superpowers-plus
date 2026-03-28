---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["document X in wiki", "write wiki documentation for", "publish to wiki", "wiki:create", "wiki:update", "wiki:publish", "cross-reference wiki", "bulk wiki update", "update all wiki pages", "add links across wiki", "structure this wiki page"]
anti_triggers: ["verify wiki URL", "check wiki link", "fact-check wiki", "wiki secret scan", "edit wiki page", "delete wiki page", "update wiki page", "check accuracy", "fact-check", "verify claims"]
description: "Orchestrates BULK and MULTI-PAGE documentation projects — reorganizing multiple pages, cross-referencing across sections, publishing coordinated updates. Runs quality pipeline (de-dup, link-verification, secret-scan, slop-detection, fact-check). NOT for single-page edits (use platform-specific editing skills like outline-wiki-editing)."
summary: "Use when: bulk documentation projects, multi-page reorganization, cross-referencing. Skip when: editing one page, creating one page, deleting one page."
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: ["link-verification"]
  escalates_to: []
  internal: false
---

# Wiki Orchestrator

> **Wrong skill?** Checking wiki links → `link-verification`. Fact-checking wiki → `wiki-debunker` or `wiki-verify`. Scanning for secrets → `wiki-secret-audit`.

> **Purpose:** Enforce quality pipeline for multi-page wiki operations (create, reorganize, archive, cross-reference). Simple single-page edits may use platform-specific editing skills directly.
> **Philosophy:** Quality pipeline for complex operations; proportional overhead for simple ones.

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
| 5.5 Table Discipline | ADVISORY | `markdown-table-discipline` |
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
  - **Skip if TOC already exists:** Do not add a TOC if the page already contains the adapter's `toc_syntax` markup, or a heading matching `Contents` or `Table of Contents` (case-insensitive).
  - Pages with ≤3 H2/H3 headings do not need a TOC.

---

## Publishing Rules (Stage 7)

<EXTREMELY_IMPORTANT>

### MCP Tools First
Always use your adapter's primary `get_page`, `update_page`, and `create_page` operations. Curl is fallback only.

### Download Before Editing
Fetch current state via your adapter's `get_page` operation BEFORE any edit. Never use memory or stale files. This prevents overwriting concurrent edits. **Also applies when correcting mistakes** — user may have already fixed the issue.

### Write Scope Restriction
Only write to allowed roots defined by the current workspace or local overlay. Walk the parent chain to verify scope before writing.

If out of scope → STOP and ask user. Do NOT assume a parent is in-scope just because its title sounds relevant.

### Check for Duplicates Before Creating
Use your adapter's list/search operation to check whether a sibling page with the same title already exists before creating a new page.

### Pre-Deletion Backup
Before `delete`/`archive`: fetch full document → save to `_deleted_backups/{YYYY-MM-DD}_{id}_{slug}.md` with YAML frontmatter → verify backup exists → only then delete.

### Post-Update Verification
After every update, fetch the document again. Scan for `\[`, `\]`, literal `&nbsp;`, empty hrefs, malformed tables. Fix before reporting success.
</EXTREMELY_IMPORTANT>

---

## Checklists

**Before Creating:** Check duplicates → Verify write scope → Secret scan → Verify links → `create_page`
**Before Editing:** Fetch current state → Use as base → Secret scan → Verify links → Warn about layout loss → `update_page` → Verify result
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

## Pipeline Skills

| Skill | Role |
|-------|------|
| `wiki-content-coherence` | Stage 2.5: Duplication detection |
| `link-verification` | Stage 3: URL verification (HARD GATE) |
| `eliminating-ai-slop` | Stage 5: Prose quality |
| `wiki-debunker` | Stage 6: Fact-checking |
| `wiki-verify` | Post-publish: Version drift |

- **wiki-verify**: Post-write verification
- **wiki-secret-audit**: Secret scanning of wiki content
- **wiki-instruction-guard**: Instruction injection prevention
- **link-verification**: Link checking within wiki pages
- **wiki-content-coherence**: Checking for content duplication
## References

- [`references/stage-output-examples.md`](references/stage-output-examples.md) — Output templates
- [`references/batch-operations.md`](references/batch-operations.md) — Multi-page edit workflow


## When to Use

- For ALL wiki authoring, editing, and publishing operations — no exceptions
- When creating new wiki pages from scratch
- When updating existing wiki content
- When reviewing wiki pages for quality

```bash
# Example: create a wiki page through the orchestrator pipeline
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill wiki-orchestrator
```

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Running full pipeline for single-page edits | Single-page create/edit doesn't need the pipeline. Use wiki API directly. |
| Skipping pipeline stages (especially link-verification) | All stages are mandatory for bulk/multi-page operations |
| Pipeline stage fails but agent continues | Stage failure = pipeline halt. Fix the issue, then restart from failed stage. |

## Companion Skills

- **link-verification**: Link existence checks within wiki pages
- **wiki-verify**: Post-hoc wiki claim verification
- **wiki-instruction-guard**: Instruction injection protection
- **wiki-secret-audit**: Secret scanning in wiki content
- **wiki-content-coherence**: Wiki page coherence checks
