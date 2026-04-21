---
name: wiki-refactor
source: superpowers-plus
triggers: ["refactor wiki", "restructure wiki", "deduplicate wiki", "wiki overhaul", "reorganize wiki pages", "wiki:refactor", "reorganize all wiki pages"]
anti_triggers: ["edit single wiki page", "write wiki page", "update wiki content", "wiki:edit", "refactor wiki page", "deduplicate wiki content"]
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

# wiki-refactor — conductor

Full-wiki refactor: eliminate duplication, improve IA, elevate prose quality.
HARD gate with 3 PRD checkpoints and a human checkpoint after Phase 4.
Wrong skill? Single-page edit → `wiki-orchestrator` · Content coherence →
`wiki-content-coherence` · Link check → `link-verification`. Background:
`rationale.md`.

## 🔴 PRD protection (non-negotiable)

Detect PRD pages (case-insensitive): filename/title contains `PRD`; body H1/H2
exactly `PRD`; body header `Product Requirements Document`; or operator include
list. **Detection → HALT.** Operator must re-invoke with PRDs scoped out.

| Checkpoint | When | Action |
|------------|------|--------|
| PRD-1 | After Phase 1 inventory | Quarantine matches in `prd-quarantine-list` |
| PRD-2 | Before every Phase 5 write | Match quarantine → HALT |
| PRD-3 | After Phase 7 diff | Any PRD in changeset → HALT |

## Pre-flight

```bash
: "${WIKI_SEED_URL:?}"
git checkout -b "feat/wiki-refactor-$(date +%F)"
mkdir -p wiki-refactor-artifacts
```

## Phases (each references the detailed runbook)

| # | Phase | Runbook | Output |
|---|-------|---------|--------|
| 1 | Discovery — crawl descendants, snapshot content | [phase-1-discovery.md](references/phase-1-discovery.md) | `wiki-inventory.md` |
| 2 | Deduplication — analyze duplication patterns | [phase-2-deduplication.md](references/phase-2-deduplication.md) | `dedup-analysis.md` |
| 3 | Information Architecture — new structure | [phase-3-information-architecture.md](references/phase-3-information-architecture.md) | `new-wiki-structure.md` |
| 4 | Writing plan — source→target page map | [phase-4-writing-plan.md](references/phase-4-writing-plan.md) | `wiki-writing-plan.md` |
| 5 | Rewrite + 3-round progressive review | [phase-5-rewrite-and-review.md](references/phase-5-rewrite-and-review.md) | `refactored-wiki/*.md` |
| 6 | Quality metrics | [phase-6-quality-metrics.md](references/phase-6-quality-metrics.md) | `wiki-refactor-report.md` |
| 7 | Safe delivery — branch, migration guide, final checks | [phase-7-safe-delivery.md](references/phase-7-safe-delivery.md) | Ready-to-merge branch |

### Phase 1 scope cap

>100 pages OR >50k words → warn operator + require confirmation. Zero pages →
abort with "wiki unreachable or empty." PRD-1 runs on the full inventory.

### ⏸️ Human checkpoint (after Phase 4)

Present `wiki-writing-plan.md` (pages to rewrite / merge / delete / create,
word-count delta, PRD quarantine list). **Do not proceed to Phase 5 without
explicit operator approval.**

### Phase 5 write loop

For each target page, before invoking `tools/wiki-write.sh`:
1. PRD-2 check against quarantine list
2. 3-round progressive review (use `progressive-harsh-review`)
3. Stage 5.5 structure gate (`node tools/wiki-markdown-validate.js`)
4. `tools/wiki-write.sh update --doc $ID --content page.md` (exit `0` or halt)

### Phase 7 delivery

1. Package refactored pages into `wiki/` on the feature branch
2. Emit migration guide (old-slug → new-slug)
3. Diff Phase-1 snapshot vs current wiki → on drift, present overwrite / merge / abort
4. Run `use-skill link-verification` (exit 0 required) and `use-skill wiki-secret-audit` (empty findings)
5. PRD-3 check: final diff contains zero PRD files

## Failure modes

| Symptom | Cause | Response |
|---------|-------|----------|
| PRD checkpoint fires | PRD in rewrite scope | HALT — no recovery path |
| Phase 1 returns zero pages | Bad URL, auth, empty wiki | Abort with diagnostic |
| Phase 2 zero duplicates | No duplication | Continue; Phase 3 may still apply |
| Scope cap exceeded | >100 pages or >50k words | Warn operator; narrow scope |
| Phase 7 snapshot drift | Wiki edited during refactor | Present diff; operator picks overwrite/merge/abort |
| 3-round review won't converge | Quality blocker | Escalate page to human |

Success criteria and PRD-protection rationale: `rationale.md`.
