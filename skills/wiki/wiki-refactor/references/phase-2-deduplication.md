# Phase 2: Content Deduplication

> **Purpose:** Identify all instances of duplicated, overlapping, or redundant content across the wiki.
> **Input:** `wiki-inventory.md` + content snapshots
> **Output:** `dedup-analysis.md`
> **Timebox:** 20 minutes

## Protocol

For every page in the inventory (excluding quarantined PRDs), analyze content for:

### 1. Concept Duplication
Same concept defined or explained in 3+ different places with wording variations.

**Detection:** Look for:
- Same term defined in multiple glossary sections or inline definitions
- Same process described with different step counts or ordering
- Same architecture component explained at different levels of detail on different pages

### 2. Procedure Repetition
Same procedure (setup steps, configuration, troubleshooting) repeated across pages.

**Detection:** Look for:
- Sequential instructions with >60% step overlap
- Same CLI commands or code snippets on multiple pages
- "See also" links that duplicate rather than reference

### 3. Scattered Definitions
Same term or concept defined inconsistently across pages.

**Detection:** Look for:
- Contradictory definitions of the same term
- Different default values stated for the same config parameter
- Conflicting version requirements

### 4. Overlapping Examples
Same or near-identical examples appearing on multiple pages.

**Detection:** Look for:
- Code samples with >80% similarity
- Screenshots or diagrams showing the same workflow
- Identical table data on multiple pages

### 5. Redundant Warnings
Same gotcha, caveat, or warning repeated across pages.

**Detection:** Look for:
- Identical "Note:" or "Warning:" blocks
- Same failure mode described in multiple troubleshooting sections

## Output Format: `dedup-analysis.md`

```markdown
# Deduplication Analysis

**Pages analyzed:** {{count}} ({{prd_count}} PRDs excluded)
**Duplicate groups found:** {{group_count}}
**Total redundant words:** {{word_count}} ({{percent}}% of total)

## Duplicate Groups

### Group 1: {{concept name}}
**Type:** Concept duplication | Procedure repetition | Scattered definition | ...
**Severity:** HIGH | MEDIUM | LOW
**Instances:**
1. [Page A](url) — lines {{n-m}}: "{{excerpt}}"
2. [Page B](url) — lines {{n-m}}: "{{excerpt}}"
3. [Page C](url) — lines {{n-m}}: "{{excerpt}}"

**Resolution:** Consolidate into [recommended target page]. Keep instance {{n}} as canonical. Replace others with cross-reference links.

**Contradictions:** {{any conflicting facts between instances}}

### Group 2: ...
```

## Resolution Recommendations

For each duplicate group, recommend ONE of:
- **Consolidate:** Merge all instances into single authoritative page. Replace others with links.
- **Canonicalize:** Pick one instance as canonical. Update others to reference it.
- **Extract:** Factor shared content into a new dedicated page. Link from all current locations.
- **Delete:** Remove redundant instances entirely (content adds no value beyond the canonical).

## Early Exit

Zero duplicate groups found → report: `✅ Wiki content is clean — no duplication detected. Skipping to Phase 6.`

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| Everything looks duplicated | Pages share a common template or boilerplate | Exclude template content from analysis; focus on substantive body content |
| Contradictory definitions found | Wiki has conflicting information | Flag as HIGH severity; resolution must pick correct version (verify against source code/config) |
| Borderline duplicates | Similar but not identical explanations | Use MEDIUM severity; recommend consolidation only if overlap >60% |
