# Design Document: reviewing-ai-text Skill Enhancement

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-24
> **Status:** Draft
> **Author:** Matt J Bordenet

## Purpose

Technical design for enhancing the `reviewing-ai-text` skill per [PRD.md](./PRD.md) requirements.

---

## Current State

The existing skill (`skills/reviewing-ai-text/SKILL.md`) contains:

| Component | Current | Target |
|-----------|---------|--------|
| Lexical patterns | ~30 phrases | 100+ phrases |
| Domain patterns | 0 | 3 domains |
| Detection heuristics | 5 | 10+ |
| Stylometric detection | 0 | 3 metrics |

---

## Design Decisions

### D1: Skill File Organization

**Decision:** Keep all content in single SKILL.md file.

**Rationale:** 
- Superpowers framework loads single SKILL.md per skill
- No external file imports supported
- User reads skill in context, not as reference doc

**Consequence:** Skill file will be 400-600 lines. Use clear section headers.

### D2: Pattern Storage Format

**Decision:** Use markdown tables for pattern storage.

**Format:**
```markdown
| Pattern | Category | Severity | Replacement |
|---------|----------|----------|-------------|
| incredibly | booster | high | [delete] or use specific metric |
```

**Rationale:**
- Scannable during review
- Sortable by category or severity
- Copy-paste friendly

### D3: Domain Pattern Sections

**Decision:** Separate sections per domain, not mixed tables.

**Structure:**
```markdown
## Technical Documentation Slop
[patterns specific to tech docs]

## Marketing/Business Slop
[patterns specific to marketing]

## Academic/Research Slop
[patterns specific to academic writing]
```

**Rationale:** User reviews one domain at a time.

### D4: Stylometric Detection Approach

**Decision:** Provide manual heuristics, not automated calculations.

**Rationale:**
- Skill runs in Claude context without tooling
- User can eyeball sentence variance
- Exact metrics require external tools

**Heuristics provided:**
1. **Sentence variance:** "If most sentences are 15-22 words, flag."
2. **Vocabulary diversity:** "If same adjectives repeat 3+ times, flag."
3. **Hapax check:** "In 500 words, expect 40-60% unique words."

---

## Implementation Plan

### Phase 2: Expanded Word Lists (REQ-001)

**Location:** Add after current "Kill on Sight" table in SKILL.md

**New sections:**
1. Expanded boosters table (~30 entries)
2. Buzzwords table (~25 entries)
3. Glue phrases table (~25 entries)
4. Hedge patterns table (~15 entries)
5. Sycophantic phrases table (~10 entries)

**Format per table:**
```markdown
### Boosters - Kill or Justify

| Phrase | Replacement | Note |
|--------|-------------|------|
| incredibly | [delete] | Never adds meaning |
| extremely | [delete] or "more than X" | Quantify instead |
```

### Phase 3: Domain Patterns (REQ-002)

**Location:** New major section after word lists

**Per domain:**
- 10 domain-specific patterns
- 2-3 examples each
- Rewrite guidance

**Technical docs patterns include:**
- "This function/method/class..." (passive opener)
- "Simply call..." (dismissive)
- "Easy to use" (subjective)

**Marketing patterns include:**
- "Industry-leading" (unsubstantiated)
- "Seamless integration" (meaningless)
- "Transform your..." (hype)

**Academic patterns include:**
- "The literature suggests..." (vague attribution)
- "It is well known that..." (appeal to authority)
- "Further research is needed" (boilerplate)

### Phase 4: Stylometric Detection (REQ-004, REQ-005)

**Location:** New major section "Stylometric Red Flags"

**Content:**
1. Sentence length variance test (with example)
2. Type-token ratio heuristic
3. Hapax legomena check
4. Zipf deviation explanation (conceptual only)
5. Entropy pattern heuristic

**Format:**
```markdown
### Sentence Length Variance Test

**Heuristic:** Count words in 5 consecutive sentences. 
If all are within ±3 words of each other, flag.

**AI pattern:** 18, 19, 17, 20, 18 (variance ~2)
**Human pattern:** 8, 24, 12, 31, 5 (variance ~10)
```

---

## File Structure After Enhancement

```
skills/reviewing-ai-text/SKILL.md
├── YAML frontmatter
├── Overview
├── Quick Reference Tables (existing, expanded)
│   ├── Kill on Sight (~30 → 100+ entries)
│   ├── Glue Phrase Killers (expanded)
│   └── Hedge Patterns (expanded)
├── Detection Heuristics (existing, enhanced)
├── NEW: Domain-Specific Patterns
│   ├── Technical Documentation
│   ├── Marketing/Business
│   └── Academic/Research
├── NEW: Stylometric Red Flags
│   ├── Sentence Variance
│   ├── Vocabulary Diversity
│   └── Entropy Signals
├── The Rewrite Process (existing)
├── Advanced Detection (existing)
├── JSON Output Schema (existing)
└── Self-Check Checklist (existing, updated)
```

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [PRD.md](./PRD.md) - Requirements
- [TEST_PLAN.md](./TEST_PLAN.md) - Test plan
- [skills/reviewing-ai-text/SKILL.md](../skills/reviewing-ai-text/SKILL.md) - Skill file

