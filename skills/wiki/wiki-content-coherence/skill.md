---
name: wiki-content-coherence
source: superpowers-plus
triggers: ["check wiki page coherence", "refactor wiki page", "deduplicate wiki content", "audit wiki page structure", "wiki:coherence-check"]
anti_triggers: ["verify wiki facts", "fact-check", "check claims accuracy", "verify wiki", "reorganize wiki pages", "wiki overhaul"]
description: Use when wiki pages have been edited multiple times and may contain duplicated sections, obsolete content, or structural defects. Runs as Stage 2.5 in wiki-orchestrator pipeline (between Content Generation and Link Verification). Also available standalone. Gate type is ADVISORY with escalation for HIGH severity.
summary: "Use when: editing wiki pages that cross-reference other pages."
coordination:
  group: wiki-pipeline
  order: 2.5
  requires: ["wiki-orchestrator"]
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

# wiki-content-coherence

Detect duplication and structural drift in a single wiki page. Stage 2.5 in
`wiki-orchestrator` (between content generation and link verification).
Advisory gate; HIGH severity → user review before publish.

## When to Use

- When asked to check a single wiki page for duplication, redundant sections, or structural drift
- Triggered by: `check wiki page coherence`, `refactor wiki page`, `deduplicate wiki content`, `audit wiki page structure`, `wiki:coherence-check`
- Stage 2.5 in `wiki-orchestrator`; HIGH severity findings block publish until reviewed
- Wrong skill? Multi-page refactor → `wiki-refactor` · Fact accuracy → `wiki-verify`

## Scope

Single page only. Skip pages <500 words. Abort >10,000 words.

## Procedure

### 1 — Fetch and split

```bash
tools/wiki-read.sh get "$PAGE_ID" | jq -r '.text' > page.md
# Split on H2/H3; keep sections ≥50 words
```

### 2 — Duplication check (Jaccard on top-8 tokens per section)

Tokenize each section → drop stop-words → drop tokens <4 chars → take top 8 by
frequency → compare all pairs: `J = |A ∩ B| / |A ∪ B|`.

| Jaccard | Severity | Action |
|---------|----------|--------|
| ≥ 0.80 | HIGH | Consolidate into a single section |
| 0.60–0.79 | MEDIUM | Merge unique details or differentiate |
| 0.40–0.59 | LOW | Log only |

### 3 — Structural integrity

| Check | Flag when |
|-------|-----------|
| Heading nesting | H2 → H4 jump (H3 skipped) |
| Orphaned section | H3 appears before any H2 |
| Length anomaly | Section >5× median or <20 words |
| Topic drift | Heading-fingerprint vs body Jaccard <0.15 |

### 4 — Report + gate decision

```markdown
## Coherence Report — <title>
| # | Section A | Section B | Jaccard | Severity |
|---|-----------|-----------|---------|----------|
| 1 | Overview  | Summary   | 0.85    | HIGH     |
Structural: 1 heading skip (H2→H4), 1 length anomaly
Gate: HIGH finding → user review required
```

HIGH → halt pipeline, present report, wait for user. Otherwise log and continue.

### 5 — Remediate duplicates (when confirmed)

1. Pick the section with richer content; keep it
2. Merge unique details from the weaker section into it
3. Delete the weaker section
4. Re-run heading hierarchy check

## Failure modes

| Failure | Fix |
|---------|-----|
| Threshold too low, misses near-duplicates | Tune: 0.40 LOW · 0.60 MEDIUM · 0.80 HIGH |
| False positive on intentional repetition | Whitelist repeat-by-design sections (warnings, license blocks) |
| Structural defects missed by Jaccard | Pair with manual review for layout/flow |
| "All duplicates are intentional" | If two sections say the same, readers are confused |

## Companion skills

wiki-orchestrator (Stage 2.5) · link-verification (Stage 3) · wiki-debunker
