# Phase 4: Writing Plan

> **Purpose:** Create a detailed per-page rewrite plan to guide Phase 5 execution.
> **Input:** `new-wiki-structure.md` + content snapshots
> **Output:** `wiki-writing-plan.md`
> **Timebox:** 20 minutes
> **⏸️ HUMAN CHECKPOINT follows this phase.** The conductor HALTs after this output. Operator must approve before Phase 5.

## Protocol

For each page in the new wiki structure, produce:

### 1. Page Card

```markdown
### {{page-slug}}.md
**Purpose:** One sentence describing what this page teaches or documents.
**Type:** Overview | Reference | Procedure | Troubleshooting | Decision Record
**Priority:** P1 (core concept) | P2 (supporting detail) | P3 (nice-to-have)
**Source pages:** [Page A](url), [Page B](url) section 3
**Operation:** Merge | Consolidate | Move | New | Unchanged (PRD)
**Estimated words:** {{count}}
**PRD?:** No | 🔒 Yes — SKIP (immutable)
```

### 2. Section Outline

For each non-PRD page, define the target heading structure:

```markdown
**Sections:**
1. H1: {{page title}}
2. H2: Overview — what and why
3. H2: Prerequisites — what you need before starting
4. H2: {{main content section}} — core information
5. H2: {{secondary section}} — additional detail
6. H2: See Also — links to parent, siblings, related pages
```

### 3. Cross-Reference Plan

For each page, list:

- **Links TO:** pages this page should link to (parent, children, related concepts)
- **Links FROM:** pages that should link to this page (update existing cross-references)
- **Redirects needed:** old URLs that should redirect to this new page

### 4. Content Decisions

For each merge or consolidation:

- Which source page's wording is canonical?
- What content is dropped and why?
- Are there contradictions to resolve? Which version is correct?

## Rewrite Priority Order

Phase 5 rewrites pages in this order:

1. **P1 — Core concepts.** Overview pages and foundational references. These are linked by everything else.
2. **P2 — Supporting detail.** Procedures, troubleshooting, secondary references.
3. **P3 — Nice-to-have.** Supplementary pages, edge case documentation.

Within each priority tier, parents are written before children (ensures cross-references are valid).

## Output Format: `wiki-writing-plan.md`

```markdown
# Wiki Writing Plan

**Total pages to write:** {{count}}
**Pages to merge:** {{merge_count}} (from {{source_count}} sources)
**Pages to delete:** {{delete_count}}
**New pages:** {{new_count}}
**PRD pages (skipped):** {{prd_count}}
**Estimated total words:** {{word_count}}
**Estimated word delta:** {{delta}} ({{percent}}% {{increase/decrease}})

## Rewrite Queue (Priority Order)

### P1 — Core Concepts
1. [Page card for page 1]
2. [Page card for page 2]
...

### P2 — Supporting Detail
...

### P3 — Nice-to-Have
...

## Deletion List

| Page | Justification | Content preserved in |
|------|---------------|---------------------|
| ... | ... | ... |

## Redirect Map

| Old URL | New page |
|---------|----------|
| ... | ... |
```

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| Page card missing source pages | Gap in content mapping | Go back to Phase 3, verify mapping completeness |
| Contradictory content in sources | Wiki has conflicting information | Flag in page card; resolve by checking source code or config |
| PRD page appears in rewrite queue | PRD checkpoint missed | HALT — PRD violation |
| Too many P1 pages (>20) | Over-classification | Demote supporting pages to P2; P1 is only true foundational content |
