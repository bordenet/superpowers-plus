---
name: wiki-content-coherence
source: superpowers-plus
triggers: ["check wiki page coherence", "refactor wiki page", "deduplicate wiki content", "audit wiki page structure", "wiki:coherence-check"]
description: Use when wiki pages have been edited multiple times and may contain duplicated sections, obsolete content, or structural defects. Runs as Stage 2.5 in wiki-orchestrator pipeline (between Content Generation and Link Verification). Also available standalone. Gate type is ADVISORY with escalation for HIGH severity.
coordination:
  group: wiki-pipeline
  order: 2.5
  requires: ["wiki-authoring"]
  enables: ["link-verification"]
  escalates_to: ["wiki-orchestrator"]
  internal: false
composition:
  consumes: [generated-content, existing-page-content]
  produces: [coherence-report, content-inventory]
  capabilities: [analyzes-content, suggests-refactoring]
  priority: 15
  optional: true
---

# Wiki Content Coherence

> **Purpose:** Detect content duplication and structural defects in wiki pages.
> **Gate:** ADVISORY (HIGH severity → user review before publish).
> **Pipeline:** Stage 2.5 in wiki-orchestrator (between Content Generation and Link Verification).

## Checks

### Duplication (TF-IDF + Jaccard)

1. Parse page into sections (split on H2/H3), skip sections <50 words
2. Compute topic fingerprint per section: tokenize → remove stop words → filter <4 chars → top 8 by frequency
3. Compare all pairs: Jaccard = `|A ∩ B| / |A ∪ B|`

| Jaccard | Severity | Action |
|---------|----------|--------|
| 0.80+ | HIGH | Strong duplicate — consolidate |
| 0.60–0.79 | MEDIUM | Likely overlap — review |
| 0.40–0.59 | LOW | Informational |

### Structural Integrity

| Check | Flags When |
|-------|------------|
| Heading nesting | H2 → H4 jump (skipped H3) |
| Orphaned sections | H3 before any H2 |
| Length anomaly | Section >5× median or <20 words |
| Topic drift | Heading fingerprint vs body Jaccard <0.15 |

## Gate Decision

HIGH severity → present report, ask user before publishing. Otherwise → log and continue pipeline.

**Scope:** Single-page only. Skip pages <500 words. Abort >10,000 words.


## When to Use

- Automatically during wiki-orchestrator Stage 2.5 (between Content Generation and Link Verification)
- When reviewing a wiki page that was assembled from multiple sources
- When consolidating duplicate wiki pages into one

## Failure Modes

| Failure | Fix |
|---------|-----|
| Low similarity threshold misses near-duplicates | Tune Jaccard threshold — skill uses 0.40+ (LOW), 0.60+ (MEDIUM), 0.80+ (HIGH) |
| False positive on intentional repetition (e.g., repeated warnings) | Whitelist known repeated-by-design sections |
| Structural defects not caught by TF-IDF | Pair with manual review for layout/flow issues |

```bash
# Example: run coherence check on a wiki page
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill wiki-content-coherence
```
