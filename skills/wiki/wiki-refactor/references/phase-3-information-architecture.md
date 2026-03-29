# Phase 3: Information Architecture

> **Purpose:** Design the optimal new wiki structure based on deduplication findings.
> **Input:** `wiki-inventory.md` + `dedup-analysis.md`
> **Output:** `new-wiki-structure.md`
> **Timebox:** 25 minutes

## Protocol

### 1. Define Page Types

Classify every page in the new structure as one of:

| Type | Naming convention | Purpose |
|------|-------------------|---------|
| **Overview** | Noun phrase (`Authentication`) | Introduce a concept area, link to detail pages |
| **Reference** | Noun phrase (`API Error Codes`) | Authoritative lookup — tables, schemas, configs |
| **Procedure** | Verb phrase (`Configure SSO`) | Step-by-step instructions for a task |
| **Troubleshooting** | "Troubleshooting: {{topic}}" | Symptoms → causes → fixes |
| **Decision Record** | "ADR: {{title}}" | Why a decision was made (immutable after approval) |

### 2. Build Hierarchy

Design parent-child relationships following these rules:
- **Max depth: 3 levels.** Any concept must be reachable in ≤3 clicks from the wiki root.
- **Single parent.** Every page has exactly one parent. No page appears in multiple locations.
- **Overview → Detail.** Parent pages are overviews; children are specifics.
- **One concept per page.** If a page covers two unrelated concepts, split it.
- **Consolidation over scattering.** Prefer fewer, richer pages over many thin pages.

### 3. Map Content

For each page in the new structure, document:
- **Source pages:** Which current pages contribute content
- **Merge/split operations:** What gets combined or separated
- **Deletions:** Pages removed entirely (with justification — must be redundant, not just short)
- **New pages:** Pages created from scratch (must cite gap in current content)

### 4. Navigation Design

- **Index page:** Top-level landing page linking to all top-level overviews.
- **Breadcrumbs:** Every page shows its path from root.
- **See Also:** Every page links to its siblings and parent.
- **No orphans:** Every page is reachable from the index.

### 5. PRD Exclusion

Quarantined PRD pages are placed in the new tree as-is — same location, same content, no changes. They appear in the structure diagram marked with `🔒 PRD — immutable`.

## Output Format: `new-wiki-structure.md`

```markdown
# New Wiki Structure

**Total pages:** {{count}} ({{new}} new, {{merged}} merged, {{deleted}} deleted, {{prd}} PRD immutable)
**Max depth:** {{depth}}
**Navigation:** ≤{{n}} clicks to any concept

## Structure

index.md — Wiki landing page
├── overview-topic-a.md — Topic A overview
│   ├── configure-topic-a.md — Setup procedure
│   ├── topic-a-reference.md — Config reference
│   └── troubleshooting-topic-a.md — Common issues
├── overview-topic-b.md — Topic B overview
│   └── ...
└── 🔒 prd-feature-x.md — PRD (immutable, not refactored)

## Content Mapping

| New page | Type | Sources | Operation |
|----------|------|---------|-----------|
| `overview-topic-a.md` | Overview | Page A, Page D (intro section) | Merge |
| `configure-topic-a.md` | Procedure | Page B, Page C (steps 1-5) | Consolidate |
| `topic-a-reference.md` | Reference | Page E | Move (no content change) |
| — | Deleted | Page F | Redundant — content fully covered by `overview-topic-a.md` |

## Deletions

| Page | Justification |
|------|---------------|
| Page F | 100% content overlap with Topic A overview; zero unique information |

## New Pages

| Page | Justification |
|------|---------------|
| `index.md` | No landing page existed; needed for navigation |
```

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| Depth exceeds 3 levels | Complex topic hierarchy | Flatten by merging leaf pages into their parent |
| Too many pages deleted | Aggressive consolidation | Verify each deletion preserves all unique content |
| Orphan pages remain | Missing parent links | Add to nearest topical overview as child |
| PRD appears in merge target | Refactoring would modify PRD | HALT — PRD checkpoint violation |
