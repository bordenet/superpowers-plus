---
name: wiki-refactor
source: superpowers-plus
triggers: ["refactor wiki", "restructure wiki", "deduplicate wiki", "wiki overhaul", "reorganize wiki pages", "wiki:refactor"]
anti_triggers: ["edit single wiki page", "write wiki page", "update wiki content", "wiki:edit"]
description: Conductor skill for full wiki refactoring. Orchestrates a 7-phase pipeline — discovery, deduplication, information architecture, writing plan, progressive rewrite + review, quality metrics, and safe delivery. Enforces PRD protection (hard gate), human checkpoint after planning, scope caps, and content snapshot/drift detection.
summary: "Use when: a wiki needs structural overhaul, not single-page edits."
composition:
  consumes: [wiki-seed-url]
  produces: [refactored-wiki-directory, migration-guide, refactor-report]
  capabilities: [crawls-wiki, deduplicates-content, rewrites-pages, reviews-content]
  priority: 50
coordination:
  group: wiki-pipeline
  order: 0
  requires: []
  enables: [link-verification, wiki-secret-audit]
  escalates_to: []
  internal: false
---

# Wiki Refactor — Conductor

> **Purpose:** Orchestrate a complete wiki refactor: eliminate duplication, improve structure, elevate prose quality.
> **Gate:** HARD — PRD protection enforced at 3 checkpoints. Human approval required after Phase 4.
> **Input:** `{{wiki_seed_url}}` — the root page whose descendant tree will be refactored.
> **Output:** `wiki/` directory on a Dev feature branch with all refactored pages + migration guide.

> **Wrong skill?** Single page edit → `wiki-orchestrator`. Content coherence check → `wiki-content-coherence`. Link verification → `link-verification`.

## 🔴 PRD PROTECTION (NON-NEGOTIABLE)

PRD documents are **atomic and immutable** during refactoring. The moment a PRD is modified, the pipeline HALTS.

**Detection (case-insensitive):** Any file where:
- Filename/title contains "PRD" (case-insensitive: `prd`, `Prd`, `PRD`)
- Content contains a header matching "Product Requirements Document" (case-insensitive)
- Content contains an H1/H2 that is exactly "PRD" (case-insensitive)
- File is in an operator-supplied PRD include list (if provided)

**Checkpoints:**
1. **After Phase 1:** Quarantine all PRD pages found in inventory. Record in `prd-quarantine-list`.
2. **Before each Phase 5 write:** Check target path against quarantine list. If match → HALT.
3. **After Phase 7:** Final diff confirms zero PRD files in changeset. If any → HALT.

**On HALT:** Full stop. No "fix and continue." Operator must re-invoke with PRDs explicitly excluded from scope.

## Procedure

### Pre-flight
1. Validate `{{wiki_seed_url}}` is reachable
2. Create feature branch: `feat/wiki-refactor-{{date}}`
3. Initialize artifact directory: `wiki-refactor-artifacts/`

### Phase 1: Discovery → [phase-1-discovery.md](references/phase-1-discovery.md)
- Crawl descendant page tree from seed URL
- Snapshot all page content at crawl time
- Output: `wiki-inventory.md`
- **Scope cap:** If >100 pages or >50k words → warn + request confirmation before continuing
- **Early exit:** Zero pages found → abort with "wiki unreachable or empty"
- **🔴 PRD checkpoint 1:** Quarantine all PRD pages. Record in `prd-quarantine-list`.

### Phase 2: Deduplication → [phase-2-deduplication.md](references/phase-2-deduplication.md)
- Analyze all content for duplication patterns
- Output: `dedup-analysis.md`
- **Zero duplicates:** Skip consolidation work but continue to Phase 3 (IA/structure improvements may still apply). Only exit early if Phase 3 also finds no structural issues.

### Phase 3: Information Architecture → [phase-3-information-architecture.md](references/phase-3-information-architecture.md)
- Design optimal new wiki structure
- Output: `new-wiki-structure.md`

### Phase 4: Writing Plan → [phase-4-writing-plan.md](references/phase-4-writing-plan.md)
- Map source pages → target pages with section structures
- Output: `wiki-writing-plan.md`

### ⏸️ HUMAN CHECKPOINT
**HALT.** Present `wiki-writing-plan.md` to operator. Do NOT proceed to Phase 5 until operator explicitly approves the plan. Display:
- Total pages to rewrite
- Pages to merge (with source list)
- Pages to delete (with justification)
- Pages to create (new)
- Estimated word count delta
- PRD quarantine list (confirm none are in rewrite scope)

### Phase 5: Rewrite + Review → [phase-5-rewrite-and-review.md](references/phase-5-rewrite-and-review.md)
- Rewrite pages in priority order (core concepts first)
- Each page passes 3-round progressive review with 5 wiki-specific reviewers
- **🔴 PRD checkpoint 2:** Before each page write, check against quarantine list.
- Output: `refactored-wiki/*.md`

### Phase 6: Quality Metrics → [phase-6-quality-metrics.md](references/phase-6-quality-metrics.md)
- Compute dedup reduction, consolidation %, review pass %, orphan resolution %
- Confirm zero PRDs touched
- Output: `wiki-refactor-report.md`

### Phase 7: Safe Delivery → [phase-7-safe-delivery.md](references/phase-7-safe-delivery.md)
- Package into `wiki/` directory on feature branch
- Generate migration guide (old → new URL mapping)
- **Snapshot diff:** Compare Phase 1 snapshot against current wiki. If drift detected → warn operator, present options: overwrite / merge / abort.
- **🔴 PRD checkpoint 3:** Final diff confirms zero PRD files in changeset.
- Invoke `link-verification` on all internal links
- Invoke `wiki-secret-audit` on all content
- Output: ready-to-merge feature branch

## Success Criteria

| Metric | Threshold |
|--------|-----------|
| Duplicate content resolved | ≥80% |
| Core concepts with single source | ≥90% |
| Pages passing 3-round review | ≥70% |
| PRD documents touched | **Zero** |
| Navigation depth to any concept | ≤3 clicks |

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| PRD checkpoint fires | PRD in rewrite scope | HALT — full stop, no recovery |
| Phase 1 returns zero pages | Bad URL, auth, or empty wiki | Abort with diagnostic message |
| Phase 2 finds zero duplicates | No content duplication | Skip consolidation; continue to Phase 3 for IA review |
| Scope cap exceeded (>100 pages) | Large wiki | Warn operator, request scope narrowing or confirmation |
| Snapshot drift detected in Phase 7 | Wiki edited during refactor | Present diff, operator chooses: overwrite / merge / abort |
| 3-round review fails after 5 rounds | Quality won't converge | Escalate page to human for manual rewrite |

## Companion Skills

- **progressive-harsh-review** — review engine used in Phase 5
- **link-verification** — invoked in Phase 7 for cross-reference validation
- **wiki-secret-audit** — invoked in Phase 7 for credential scanning
- **wiki-content-coherence** — lighter-weight alternative for single-page edits
- **writing-skills** — prose standards applied in Phase 5 rewrites
