---
name: wiki-content-coherence
source: superpowers-plus
triggers: ["check wiki page coherence", "refactor wiki page", "deduplicate wiki content", "audit wiki page structure", "wiki:coherence-check"]
anti_triggers: ["verify wiki facts", "fact-check", "check claims accuracy"]
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

# Wiki Content Coherence

> **Purpose:** Detect content duplication and structural defects in wiki pages.
> **Gate:** ADVISORY (HIGH severity → user review before publish).
> **Pipeline:** Stage 2.5 in wiki-orchestrator (between Content Generation and Link Verification).

> **Wrong skill?** Checking links → `link-verification`. Checking for secrets → `wiki-secret-audit`. Full wiki edit workflow → `wiki-orchestrator`.


## When to Use

- After bulk wiki updates across multiple pages
- When the same concept is documented in multiple places
- Before publishing a new wiki page that overlaps existing content
- When users report conflicting information across wiki pages

## Procedure

### Step 1: Fetch and Parse

1. Fetch page content via wiki adapter
2. Split into sections on H2/H3 boundaries
3. Skip sections <50 words (too short to analyze)

### Step 2: Duplication Check (TF-IDF + Jaccard)

For each section:
1. Tokenize → remove stop words → filter tokens <4 chars → take top 8 by frequency
2. Compare all section pairs using Jaccard similarity: `|A ∩ B| / |A ∪ B|`

| Jaccard | Severity | Action |
|---------|----------|--------|
| 0.80+ | HIGH | Strong duplicate — consolidate into single section |
| 0.60–0.79 | MEDIUM | Likely overlap — review and merge or differentiate |
| 0.40–0.59 | LOW | Informational — log, no action needed |

### Step 3: Structural Integrity Check

| Check | Flags When |
|-------|------------|
| Heading nesting | H2 → H4 jump (skipped H3) |
| Orphaned sections | H3 before any H2 |
| Length anomaly | Section >5× median or <20 words |
| Topic drift | Heading fingerprint vs body Jaccard <0.15 |

### Step 4: Report and Gate

Present findings in this format:

```
## Coherence Report: [Page Title]

| # | Section A | Section B | Jaccard | Severity |
|---|-----------|-----------|---------|----------|
| 1 | Overview  | Summary   | 0.85    | HIGH     |
| 2 | Setup     | Install   | 0.62    | MEDIUM   |

Structural: 1 heading skip (H2→H4), 1 length anomaly
Gate: ❌ BLOCKED (HIGH severity finding #1)
```

**Gate decision:** HIGH severity → present report, ask user before publishing. Otherwise → log and continue pipeline.

**Scope:** Single-page only. Skip pages <500 words. Abort >10,000 words.

### Step 5: Remediation

When duplicates are confirmed:
1. Identify which section has richer content — keep it
2. Merge unique details from the weaker section into the stronger one
3. Delete the weaker section
4. Re-check heading hierarchy after deletion


## Example

```bash
# Find potential duplicate content across wiki pages
grep -rn "authentication" wiki/ --include="*.md" -l | head -10
# Check for contradictions: same term defined differently
grep -rn "timeout.*=" wiki/ --include="*.md" | sort
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Low threshold misses near-duplicates | Tune Jaccard threshold — 0.40+ (LOW), 0.60+ (MEDIUM), 0.80+ (HIGH) |
| False positive on intentional repetition | Whitelist known repeated-by-design sections (e.g., repeated warnings) |
| Structural defects not caught by TF-IDF | Pair with manual review for layout/flow issues |
| Page was assembled from multiple sources — all duplicates are "intentional" | Question intent: if two sections say the same thing, the reader is confused |


## Scope Exclusions

- Editing wiki content → `wiki-orchestrator`
- Fact-checking claims → `wiki-debunker`
- Checking broken links → `link-verification`

## Companion Skills

- **wiki-orchestrator**: Full pipeline (this is Stage 2.5)
- **link-verification**: Stage 3 (runs after this skill)
- **wiki-debunker**: Fact-checking wiki claims
