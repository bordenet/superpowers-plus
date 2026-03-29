# Phase 6: Quality Metrics + Gap Analysis

> **Purpose:** Compute refactor quality metrics and identify any remaining gaps.
> **Input:** All prior phase artifacts + `refactored-wiki/*.md`
> **Output:** `wiki-refactor-report.md`
> **Timebox:** 15 minutes

## Protocol

### 1. Compute Metrics

| Metric | Calculation | Threshold |
|--------|------------|-----------|
| **Duplicate content resolved** | (duplicate groups resolved / total duplicate groups from Phase 2) × 100 | ≥80% |
| **Word reduction** | (original total words − new total words) / original total words × 100 | Report only (no threshold) |
| **Concepts consolidated** | (concepts with single authoritative page / total concepts identified) × 100 | ≥90% |
| **Pages passing review** | (pages that passed 3-round review / total pages rewritten) × 100 | ≥70% |
| **Orphan pages resolved** | (orphans with parents assigned / total orphans from Phase 1) × 100 | 100% |
| **Broken links resolved** | (broken links fixed / broken links from Phase 1) × 100 | 100% |
| **Navigation depth** | Max clicks from index to any page | ≤3 |
| **PRD documents touched** | Count of PRD files in changeset | **Zero** |

### 2. Gap Analysis

For each metric below threshold:
- Identify which pages or content groups are responsible
- Classify gap as:
  - **Addressable:** Can be fixed within timebox → fix now
  - **Deferred:** Requires operator input or external verification → document for follow-up
  - **Accepted:** Intentional (e.g., a page failed review because source material is ambiguous → needs SME)

### 3. PRD Protection Confirmation

Enumerate every quarantined PRD from Phase 1 and confirm:
- [ ] Not present in `refactored-wiki/` as a modified file
- [ ] Not referenced as a merge source in any rewritten page
- [ ] Original content unchanged in wiki

If ANY check fails → HALT. This is a non-recoverable error.

### 4. Content Preservation Audit

Verify that no unique content was lost during refactoring:
- For each deleted page from Phase 3, confirm its unique content appears in the designated target page
- For each merged page, confirm all non-duplicate content from all sources appears in the merged result
- Flag any content that was in the original wiki but does not appear in the refactored wiki

## Output Format: `wiki-refactor-report.md`

```markdown
# Wiki Refactor Report

**Date:** {{timestamp}}
**Seed URL:** {{wiki_seed_url}}
**Status:** PASS | PARTIAL | FAIL

## Metrics

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Duplicate content resolved | {{n}}% | ≥80% | ✅/❌ |
| Word reduction | {{n}}% | — | — |
| Concepts consolidated | {{n}}% | ≥90% | ✅/❌ |
| Pages passing review | {{n}}% | ≥70% | ✅/❌ |
| Orphan pages resolved | {{n}}% | 100% | ✅/❌ |
| Broken links resolved | {{n}}% | 100% | ✅/❌ |
| Navigation depth | {{n}} | ≤3 | ✅/❌ |
| PRD documents touched | {{n}} | 0 | ✅/❌ |

## Overall: {{PASS/PARTIAL/FAIL}}

- **PASS:** All metrics meet thresholds
- **PARTIAL:** Some metrics below threshold; gaps documented
- **FAIL:** PRD touched OR <50% on any critical metric

## Gaps

| Gap | Metric | Current | Target | Classification | Action |
|-----|--------|---------|--------|---------------|--------|
| ... | ... | ... | ... | Addressable/Deferred/Accepted | ... |

## Content Preservation Audit

| Deleted page | Unique content preserved in | Verified |
|-------------|---------------------------|----------|
| ... | ... | ✅/❌ |

## PRD Protection Confirmation

| PRD page | Not modified | Not merged | Original intact | Status |
|----------|-------------|------------|-----------------|--------|
| ... | ✅ | ✅ | ✅ | ✅ |
```

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| PRD protection check fails | PRD was modified in Phase 5 | HALT — non-recoverable |
| Content preservation audit finds missing content | Phase 5 dropped content during merge | Restore from snapshot; re-merge |
| Multiple metrics below threshold | Insufficient refactoring quality | Address Addressable gaps; document Deferred gaps |
