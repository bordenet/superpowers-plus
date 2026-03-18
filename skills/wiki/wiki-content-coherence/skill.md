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

> **Purpose:** Detect content duplication, obsolescence, and structural defects in wiki pages
> **Gate type:** ADVISORY with escalation (HIGH severity → user review before publish)
> **Spec:** See your organization's wiki for the skill specification

---

## When to Use

- After AI-assisted edits that added new sections to an existing page
- When a page has been edited 3+ times without a structural review
- Before publishing a major wiki update through the orchestrator pipeline
- On-demand: "Check this wiki page for duplicated content"

---

## Pipeline Integration (Stage 2.5)

```
1. De-duplication → 2. Content Generation → 2.5. CONTENT COHERENCE →
3. Link Verification → 4. Secret Scan → 5. Slop Detection →
6. Fact-Check → 7. Publish
```

**Why here:** Coherence fixes happen before link verification because restructuring may add/remove links. Fixing coherence after slop detection would require re-running slop detection.

---

## The Checks

### Check 1: Intra-Page Duplication (TF-IDF + Jaccard)

Detects two or more sections covering substantially the same topic.

**Algorithm:**

1. Parse page into sections (split on H2/H3 headings)
2. Skip sections under 50 words (too short for meaningful comparison)
3. For each section, compute a **topic fingerprint:**
   - Tokenize: split on whitespace, lowercase all tokens
   - Remove stop words: the, a, an, is, are, was, were, be, been, being, have, has, had, do, does, did, will, would, shall, should, may, might, can, could, of, in, to, for, with, on, at, by, from, as, into, through, during, before, after, above, below, between, and, but, or, nor, not, so, yet, both, either, neither, each, every, all, any, few, more, most, other, some, such, no, only, own, same, than, too, very, just, because, about, it, its, this, that, these, those, which, who, whom, what, when, where, how, if, then, also, up, out, their, there, they, them, we, our, us, he, she, him, her, my, your, i, you, me
   - Filter tokens under 4 characters
   - Select top 8 tokens by frequency as the fingerprint
4. Compare all section pairs using Jaccard similarity: `|A ∩ B| / |A ∪ B|`
5. Flag pairs exceeding threshold

**Thresholds:**

| Jaccard Score | Severity | Action |
|---------------|----------|--------|
| 0.80+ | HIGH | Strong duplicate — consolidation recommended |
| 0.60–0.79 | MEDIUM | Likely overlap — review recommended |
| 0.40–0.59 | LOW | Minor overlap — informational only |
| Below 0.40 | — | No flag |

**Optional LLM enrichment** for borderline pairs (0.50–0.65): prompt at temperature=0: *"Are these two sections about the same topic? Section A: [heading]. Section B: [heading]. Answer yes/no with one sentence."* Cost: ~30 tokens per borderline pair.

### Check 3: Structural Integrity (Rule-Based)

Detects measurable structural defects. No LLM needed for checks 3a–3c.

| Check | Detects | Flags When |
|-------|---------|------------|
| **3a: Heading nesting** | Skipped heading levels | H2 → H4 jump (no H3 between) |
| **3b: Orphaned sections** | Headings without proper parent | H3 appears before any H2 |
| **3c: Section length anomaly** | Unbalanced page structure | Any section exceeds 5× median word count, or is under 20 words |
| **3d: Topic drift** | Section content mismatches heading | Heading fingerprint vs body fingerprint Jaccard below 0.15 |

---

## Execution Procedure

When this skill fires (via pipeline or standalone):

### Step 1: Parse Page Structure

```
Split content on lines matching: ^#{2,3}\s
Build section list: [{heading, level, startLine, body, wordCount}]
```

### Step 2: Run Check 1 (Duplication)

```
For each section with wordCount >= 50:
  fingerprint = top8_tfidf_tokens(section.body)

For each pair (i, j) where i < j:
  jaccard = |fingerprint_i ∩ fingerprint_j| / |fingerprint_i ∪ fingerprint_j|
  if jaccard >= 0.40: flag(i, j, jaccard)
```

### Step 3: Run Check 3 (Structural Integrity)

```
3a: Walk heading list. If level[n] - level[n-1] > 1 → flag
3b: If first heading is H3+ (no preceding H2) → flag
3c: median = median(wordCounts). For each section:
      if wordCount > 5 * median → flag
      if wordCount < 20 and wordCount > 0 → flag
3d: For each section:
      heading_fp = top8_tfidf_tokens(heading_text, min_length=3)
      body_fp = top8_tfidf_tokens(body_text)
      if jaccard(heading_fp, body_fp) < 0.15 and len(body) > 100 → flag
```

### Step 4: Generate Output

Produce the Content Inventory Table and Coherence Report (see Output Format below).

### Step 5: Gate Decision

```
if any issue.severity == HIGH:
  PRESENT report to user before publishing
  User may override with explicit acknowledgment
else:
  LOG report, continue to Stage 3 (link-verification)
```

---

## Output Format

### Content Inventory Table

```markdown
## Content Inventory: [Page Title]

| # | Section | Topic Fingerprint | Words | Issues |
|---|---------|-------------------|-------|--------|
| 1 | ## Overview | [service, architecture, purpose] | 120 | — |
| 2 | ## Configuration | [configure, service, settings, environment] | 85 | DUPLICATE → #3 (0.72) |
| 3 | ## Setup | [install, configure, setup, environment] | 95 | DUPLICATE → #2 (0.72) |
| 4 | ## API Reference | [endpoint, request, response, auth] | 340 | — |
| 5 | ## Troubleshooting | [error, fix, debug] | 18 | SHORT (18 words) |
```

### Coherence Report

```markdown
## Coherence Report

**Page:** [Title] | **Sections:** 5 | **Issues:** 3

| # | Check | Severity | Detail | Suggested Action |
|---|-------|----------|--------|------------------|
| 1 | Duplication | MEDIUM | §2 "Configuration" ↔ §3 "Setup" (Jaccard: 0.72) | Consolidate into single section |
| 2 | Structural 3c | LOW | §5 "Troubleshooting" — 18 words (median: 120) | Expand or merge into another section |
| 3 | Structural 3a | LOW | §4 jumps H2 → H4 (skipped H3) | Fix heading hierarchy |

**Gate:** ADVISORY — no HIGH severity issues. Continuing to link-verification.
```

### Agent Action After Report

```
IF HIGH severity present:
  → Present report to user
  → Ask: "Fix these before publishing?"
  → If yes: apply fixes, re-run Stages 2.5–7
  → If no: publish with override noted

IF no HIGH severity:
  → Log report
  → Continue pipeline
```

---

## Re-Run Policy

If the agent restructures content based on coherence findings:

1. Apply restructuring changes to content
2. Re-run Stages 2.5 through 7 only (skip Stages 1–2)
3. If downstream gates fail: report, ask user
4. If all pass: publish

---

## Scope and Limits

**In scope:** Single-page analysis. Sections defined by H2/H3 headings.

**Out of scope (future v2/v3):**
- Check 2 (obsolescence/contradiction detection) — requires before/after diff
- Cross-page overlap — requires fetching sibling pages
- Auto-fix — skill suggests only, never auto-applies

**Performance envelope:**
- Token cost: 0–60 tokens per page (TF-IDF is free; LLM enrichment optional)
- Skip pages under 500 words (not enough content for meaningful analysis)
- Abort on pages over 10,000 words (too large for reliable analysis)

---

## Related Skills

| Skill | Relationship |
|-------|-------------|
| **wiki-orchestrator** | Parent pipeline — this is Stage 2.5 |
| **wiki-authoring** | Upstream — provides formatted content |
| **wiki-editing** | Downstream — publishes after coherence passes |
| **wiki-debunker** | Complementary — debunker checks facts; coherence checks structure |
| **eliminating-ai-slop** | Complementary — slop checks prose quality; coherence checks overlap |
| **link-verification** | Downstream — runs after coherence (restructuring may change links) |
