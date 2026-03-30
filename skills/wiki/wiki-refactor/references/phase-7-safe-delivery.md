# Phase 7: Safe Delivery

> **Purpose:** Package refactored wiki for deployment, detect wiki drift, and generate migration guide.
> **Input:** `refactored-wiki/*.md` + all prior artifacts
> **Output:** `wiki/` directory on feature branch + migration guide
> **Timebox:** 10 minutes

## Protocol

### 1. Snapshot Drift Detection

Compare Phase 1 content snapshots against the current live wiki:

```text
For each page in snapshot:
  1. Fetch current live content
  2. Diff against snapshot
  3. If delta exists → flag as DRIFTED
```

**If drift detected:**

- Present drifted pages with diff to operator
- Operator chooses per page:
  - **Overwrite:** Use refactored version (discard live edits)
  - **Merge:** Incorporate live edits into refactored version (manual)
  - **Abort:** Do not deploy this page; keep live version

If >30% of pages have drifted → warn: `⚠️ Significant wiki drift detected. Consider re-running from Phase 1.`

### 2. Package Directory

Build the final `wiki/` directory:

```markdown
wiki/
├── index.md                    # Landing page with structure overview + links
├── {{page-slug}}.md            # All refactored pages (flat or nested per structure)
├── migration-guide.md          # Old → new URL mapping
└── refactor-summary.md         # Executive summary of changes
```

### 3. Generate `migration-guide.md`

```markdown
# Migration Guide

**Generated:** {{timestamp}}
**Refactor scope:** {{seed_url}} ({{page_count}} pages)

## URL Redirects

| Old URL | New page | Status |
|---------|----------|--------|
| {{old_url}} | {{new_slug}}.md | Redirect |
| {{old_url}} | — | Deleted (content in {{target}}) |
| — | {{new_slug}}.md | New page |

## Pages Unchanged

| Page | Reason |
|------|--------|
| {{prd_page}} | 🔒 PRD — immutable |
| {{page}} | No changes needed |

## Deployment Steps

1. Review all pages in `wiki/` directory
2. For each "Redirect" entry, configure redirect from old URL to new page
3. For each "Deleted" entry, redirect to the page that absorbed the content
4. Verify all redirects resolve correctly
5. Remove old pages only after redirects are confirmed working
```

### 4. Generate `refactor-summary.md`

```markdown
# Refactor Summary

**Date:** {{timestamp}}
**Status:** {{PASS/PARTIAL/FAIL}} (from Phase 6 report)

## Key Changes
- {{win 1 — e.g., "Consolidated 12 authentication pages into 3"}}
- {{win 2 — e.g., "Eliminated 8,000 words of duplicate content (32% reduction)"}}
- {{win 3 — e.g., "Reduced max navigation depth from 5 to 3 clicks"}}

## Metrics
| Metric | Before | After |
|--------|--------|-------|
| Total pages | {{n}} | {{n}} |
| Total words | {{n}} | {{n}} |
| Duplicate groups | {{n}} | {{n}} |
| Max nav depth | {{n}} | {{n}} |
| Orphan pages | {{n}} | 0 |
| Broken links | {{n}} | 0 |

## PRD Protection
{{n}} PRD pages identified and protected. Zero PRDs modified.
```

### 5. Quality Gates (before commit)

Run these checks on the packaged `wiki/` directory:

1. **`link-verification`** — validate all internal cross-references resolve to existing pages
2. **`wiki-secret-audit`** — scan all content for credentials, API keys, tokens
3. **🔴 PRD checkpoint 3** — `git diff` confirms zero PRD files in changeset

If any gate fails → fix before committing. If PRD gate fails → HALT.

### 6. Commit

```bash
git add wiki/
git commit -m "refactor(wiki): restructure {{scope}} — {{page_count}} pages, {{dedup_percent}}% dedup reduction"
```

Do NOT push without operator approval.

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| >30% pages drifted | Wiki heavily edited during refactor | Recommend re-running from Phase 1 |
| Link verification fails | Cross-references point to old page names | Fix slugs in refactored pages; re-run verification |
| Secret audit finds credentials | Source wiki had exposed secrets | Remove credentials; flag to operator as separate security issue |
| PRD checkpoint 3 fails | PRD slipped through Phase 5 | HALT — non-recoverable |
