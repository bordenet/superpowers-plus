# Phase 1: Wiki Discovery

> **Purpose:** Crawl the full descendant page tree from the seed URL, capture content, and build a complete inventory.
> **Input:** `{{wiki_seed_url}}`
> **Output:** `wiki-inventory.md` + content snapshot directory
> **Timebox:** 15 minutes

## Protocol

1. **Fetch seed page.** Retrieve full content of `{{wiki_seed_url}}`. If unreachable → abort with diagnostic.
2. **Extract internal links.** Find all links pointing to pages within the same wiki domain/path prefix.
3. **Recursive crawl.** For each discovered internal link, fetch content and extract further links. Track visited URLs to avoid cycles. Continue until no new pages are discovered.
4. **Content snapshot.** Save each page's full text content to `wiki-refactor-artifacts/snapshots/{{page-id}}.md` with a YAML header containing `url`, `title`, `slug`, and `timestamp`. Use the platform's stable page ID (e.g., Outline document ID, Confluence page ID) as the filename — NOT the slug, since sibling pages under different parents can share slugs. Maintain a manifest at `wiki-refactor-artifacts/snapshot-manifest.json` mapping `{ pageId → { url, title, slug, snapshotFile } }`. This snapshot set is the source of truth for all subsequent phases and is used for drift detection in Phase 7.
5. **Build inventory.** For each page, record:

| Field | Description |
|-------|-------------|
| URL | Full page URL |
| Title | Page title / H1 |
| Parent | Parent page URL (if known from breadcrumb or tree) |
| Depth | Levels from seed page (seed = 0) |
| Word count | Total words on page |
| Internal links out | Count of links to other wiki pages |
| Internal links in | Count of links from other wiki pages to this one |
| PRD? | `YES` if filename/title contains "PRD" (case-insensitive) OR content contains "Product Requirements Document" header (case-insensitive) OR H1/H2 is exactly "PRD" (case-insensitive) OR page is in operator-supplied PRD include list |

6. **Detect broken internal links.** Any link pointing to a wiki page that returned 404 or is unreachable.

## Output Format: `wiki-inventory.md`

```markdown
# Wiki Inventory

**Seed URL:** {{wiki_seed_url}}
**Crawl date:** {{timestamp}}
**Total pages:** {{count}}
**Total words:** {{word_count}}
**Max depth:** {{max_depth}}
**Broken internal links:** {{broken_count}}
**PRD pages (quarantined):** {{prd_count}}

## Page Tree

- [Page Title](url) — {{word_count}} words, depth {{n}}
  - [Child Page](url) — {{word_count}} words, depth {{n+1}}
    - ...

## Broken Links

| Source page | Broken link | Target |
|------------|-------------|--------|
| ... | ... | ... |

## PRD Quarantine List

| Page | URL | Reason |
|------|-----|--------|
| ... | ... | Filename/title/header match (case-insensitive) or operator PRD list |
```

## Scope Cap

After inventory is complete, check:
- If total pages > 100 → warn: `⚠️ SCOPE: {{count}} pages exceeds 100-page threshold. Estimated refactor time: {{estimate}}. Narrow scope or confirm to continue.`
- If total words > 50,000 → warn: `⚠️ SCOPE: {{word_count}} words exceeds 50k threshold.`

Operator must explicitly confirm before proceeding to Phase 2.

## Early Exit

- Zero pages found → abort: `❌ Wiki unreachable or empty. Verify URL and authentication.`
- Only PRD pages found → abort: `❌ All pages are quarantined PRDs. Nothing to refactor.`

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| Crawl returns partial results | Auth required for some pages | Report partial inventory, flag inaccessible pages |
| Infinite crawl loop | Circular wiki links | URL dedup prevents revisiting; max depth cap at 10 |
| Snapshot directory already exists | Re-run without cleanup | Warn and overwrite with confirmation |
