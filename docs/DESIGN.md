# Design Document: AI Slop Detection and Elimination Skills

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-24
> **Status:** Revised for two-skill architecture
> **Author:** Matt J Bordenet

## Purpose

Technical design for two complementary skills:
- **detecting-ai-slop**: Read-only analysis producing bullshit factor scores
- **eliminating-ai-slop**: Active rewriting with interactive and automatic modes

See [Vision_PRD.md](./Vision_PRD.md) for high-level requirements.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER WORKFLOWS                          │
├─────────────────┬─────────────────────┬─────────────────────────┤
│ "Score this CV" │ "Clean up my draft" │ "Write a blog post"     │
│                 │                     │                         │
│   ▼             │        ▼            │           ▼             │
│ DETECTOR        │    ELIMINATOR       │      ELIMINATOR         │
│ (read-only)     │  (interactive)      │     (automatic)         │
└────────┬────────┴──────────┬──────────┴────────────┬────────────┘
         │                   │                       │
         ▼                   ▼                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                    SHARED INFRASTRUCTURE                         │
│  ┌───────────────────┐  ┌──────────────────┐                     │
│  │ Pattern Dictionary│  │ Metrics Store    │                     │
│  │ (workspace root)  │  │ (workspace root) │                     │
│  └───────────────────┘  └──────────────────┘                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## Skill 1: detecting-ai-slop

### Purpose

Analyze text and produce a bullshit factor score (0-100) with detailed breakdown.

### Invocation

```
User: "What's the bullshit factor on this CV?"
User: "Score this draft for AI patterns"
User: "How much slop is in this document?"
```

### Output Format

```
Bullshit Factor: 73/100

Breakdown:
├── Lexical:      28/40  (14 patterns in 500 words)
├── Structural:   18/25  (formulaic intro, template sections)
├── Semantic:     12/20  (3 hollow examples, 1 absolute claim)
└── Stylometric:  15/15  (low sentence variance, flat TTR)

Top Offenders (showing 10 of 23):
 1. Line 12: "incredibly powerful" [Generic booster]
 2. Line 34: "leverage synergies" [Buzzword cluster]
 3. Line 56: "it's important to note" [Filler phrase]
 4. Line 78: "In this document, we will explore" [Signposting]
 5. Line 92: "comprehensive solution" [Vague quality]
 ...

Stylometric Measurements:
├── Sentence length SD: 2.3 words (flag: <5 indicates AI)
├── Type-token ratio: 0.38 (flag: <0.4 indicates AI)
└── Hapax rate: 31% (flag: <40% indicates AI)
```

### Scoring Algorithm

| Dimension | Max Points | Calculation |
|-----------|------------|-------------|
| Lexical | 40 | `min(40, pattern_count * 2)` |
| Structural | 25 | `5 * structural_patterns_found` |
| Semantic | 20 | `5 * semantic_patterns_found` |
| Stylometric | 15 | `5 * stylometric_flags` |

**Total:** Sum of dimensions, capped at 100.

### Detection Logic

The skill contains embedded detection patterns (migrated from reviewing-ai-text):

1. **Lexical patterns** (100+ phrases across 5 categories)
2. **Structural patterns** (formulaic intros, templates, signposting)
3. **Semantic patterns** (hollow specificity, symmetry, absent constraints)
4. **Stylometric heuristics** (sentence variance, TTR, hapax rate)

### Skill File Structure

```
skills/detecting-ai-slop/SKILL.md
├── YAML frontmatter
├── Overview (when to use, what it produces)
├── Scoring Explanation
├── Pattern Reference
│   ├── Lexical Patterns (5 categories, 100+ phrases)
│   ├── Structural Patterns
│   ├── Semantic Patterns
│   └── Stylometric Thresholds
├── Output Format Specification
└── Examples (sample inputs with expected scores)
```

---

## Skill 2: eliminating-ai-slop

### Purpose

Actively rewrite text to eliminate detected slop patterns. Operates in two modes:
- **Interactive**: User provides text, skill confirms before rewriting
- **Automatic**: Skill prevents slop during generation (background mode)

### Mode 1: Interactive Rewriting

**Trigger:** User provides existing text with edit/review request.

```
User: "Clean up this paragraph: [text]"
User: "Remove the AI patterns from this: [text]"
```

**Workflow:**
1. Skill detects patterns in provided text
2. Skill presents findings with confirmation prompt
3. User approves/rejects per pattern or batch
4. Skill rewrites approved patterns

**Confirmation Prompt Format:**
```
Found 5 slop patterns in your text:

1. "incredibly powerful" [Generic booster]
   → Suggest: delete, or specify what makes it powerful

2. "it's important to note" [Filler phrase]
   → Suggest: delete, start with the actual point

3. "comprehensive solution" [Vague quality]
   → Suggest: specify what it covers

Options:
- "Rephrase all" - I'll rewrite all 5
- "Keep all" - Leave text unchanged
- "List them" - I'll ask about each one
- "Rephrase 1,2" - Rewrite specific patterns
```

### Mode 2: Automatic Prevention

**Trigger:** User requests prose generation (blog post, wiki, README).

**Behavior:** Skill operates silently during generation:
1. Generate content
2. Detect slop patterns in output
3. Rewrite to eliminate patterns
4. Return clean output

**Transparency:** After generation, skill reports summary:
```
[Slop prevention: removed 8 patterns (5 lexical, 2 structural, 1 semantic)]
```

User can request details: "Show what slop you removed"

### Activation Control

| Context | Activation |
|---------|------------|
| Blog post, wiki, README | Auto-activate |
| Code blocks | Auto-deactivate |
| JSON, YAML, config files | Auto-deactivate |
| User says "disable slop detection" | Manual deactivate |
| User says "enable slop detection" | Manual activate |

### Dictionary Management

This skill owns dictionary mutations:

```
User: "Add 'synergize' to the slop dictionary"
Skill: Added 'synergize' to Buzzwords category. Count: 1.

User: "Never flag 'leverage' - I use it intentionally"
Skill: Added 'leverage' to exceptions. Won't flag in future.

User: "Show my top slop patterns"
Skill: [displays dictionary sorted by frequency]
```

### Skill File Structure

```
skills/eliminating-ai-slop/SKILL.md
├── YAML frontmatter
├── Overview (when to use, two modes)
├── Interactive Mode
│   ├── Trigger conditions
│   ├── Confirmation workflow
│   └── User response options
├── Automatic Mode
│   ├── Activation triggers
│   ├── Deactivation triggers
│   └── Transparency reporting
├── Rewriting Guidelines
│   ├── Preserve meaning
│   ├── Increase specificity
│   └── Vary structure
├── Dictionary Management
│   ├── Add patterns
│   ├── Remove patterns
│   └── Query dictionary
└── Pattern Reference (same as detector, for rewrite guidance)
```

---

## Shared Infrastructure

### Pattern Dictionary

**Location:** `{workspace_root}/.slop-dictionary.json`

**Format:**
```json
{
  "version": "1.0",
  "patterns": [
    {
      "phrase": "incredibly",
      "category": "generic-booster",
      "count": 47,
      "added": "2026-01-24",
      "source": "built-in"
    }
  ],
  "exceptions": [
    {
      "phrase": "leverage",
      "scope": "permanent",
      "added": "2026-01-25"
    }
  ]
}
```

**Behavior:**
- Detector reads dictionary, does not write
- Eliminator reads and writes dictionary
- Both fall back to built-in patterns if dictionary missing
- Auto-add to .gitignore if git repo detected

### Metrics Store

**Location:** `{workspace_root}/.slop-metrics.json`

**Format:**
```json
{
  "version": "1.0",
  "detection": {
    "documents_analyzed": 42,
    "total_patterns_found": 387,
    "by_category": {
      "generic-booster": 89,
      "buzzword": 67,
      "filler-phrase": 112
    },
    "average_bullshit_factor": 58.3
  },
  "elimination": {
    "documents_processed": 31,
    "patterns_fixed": 298,
    "user_kept": 23,
    "false_positives_reported": 5
  }
}
```

---

## Design Decisions

### D1: Two Skills vs. One

**Decision:** Two separate skills.

**Rationale:**
- Three distinct use cases (score external docs, clean my drafts, prevent during generation)
- Detector is read-only; eliminator mutates
- User can invoke just what they need
- Each skill stays focused (<400 lines)

### D2: Shared Detection Logic

**Decision:** Both skills contain identical detection patterns.

**Rationale:**
- Superpowers framework doesn't support skill imports
- Duplication acceptable for consistency
- Single source of truth: reviewing-ai-text patterns migrated to both

**Maintenance:** When updating patterns, update both skills.

### D3: Dictionary Ownership

**Decision:** Eliminator owns dictionary writes; detector reads only.

**Rationale:**
- Detector is analysis tool; shouldn't mutate state
- Eliminator handles user feedback (add/remove patterns)
- Clear ownership prevents conflicts

### D4: Scoring Weights

**Decision:** Lexical 40%, Structural 25%, Semantic 20%, Stylometric 15%.

**Rationale:**
- Lexical patterns most reliable and numerous
- Structural patterns strong signal but fewer instances
- Semantic patterns require judgment
- Stylometric patterns experimental, lower weight

### D5: Confirmation Default

**Decision:** Interactive mode requires confirmation; automatic mode does not.

**Rationale:**
- User-provided text: user may have intentional patterns
- Generated text: skill is preventing its own slop, no confirmation needed
- Safe default: if unclear, treat as user-provided (confirm)

---

## Migration from reviewing-ai-text

### What Moves Where

| Current Content | Destination |
|-----------------|-------------|
| Lexical patterns (180+ phrases) | Both skills |
| Domain-specific patterns | Both skills |
| Stylometric heuristics | Both skills |
| Detection heuristics | Both skills |
| Rewrite process | eliminating-ai-slop only |
| JSON output schema | detecting-ai-slop (modified for scoring) |
| Self-check checklist | eliminating-ai-slop only |

### Deprecation Plan

1. Mark reviewing-ai-text as deprecated in SKILL.md header
2. Add pointer to new skills in overview
3. Keep in install.sh for 30 days
4. Remove after validation complete

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [Vision_PRD.md](./Vision_PRD.md) - High-level requirements
- [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md) - Detector requirements
- [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md) - Eliminator requirements
- [TEST_PLAN.md](./TEST_PLAN.md) - Test plan

