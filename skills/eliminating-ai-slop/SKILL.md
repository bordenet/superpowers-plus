---
name: eliminating-ai-slop
description: Use when writing or editing prose to actively prevent and remove AI slop patterns - operates in interactive mode (confirms before rewriting user text) or automatic mode (silently prevents slop during generation using GVR loop)
---

# Eliminating AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-25

## Overview

This skill actively rewrites text to eliminate AI slop patterns. It operates in two modes:

1. **Interactive Mode**: User provides existing text → skill confirms before rewriting
2. **Automatic Mode**: Skill prevents slop during prose generation using **GVR loop** → no confirmation needed

**Core principle:** Preserve meaning while increasing specificity and varying structure.

---

## Generate-Verify-Refine (GVR) Loop

The GVR loop is the core architecture for automatic slop elimination.

### How It Works

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  GENERATE   │────▶│   VERIFY    │────▶│   REFINE    │
│  Raw draft  │     │  Analyze    │     │  Fix issues │
└─────────────┘     └─────────────┘     └──────┬──────┘
                           │                    │
                           │ Pass               │ Fail
                           ▼                    │
                    ┌─────────────┐             │
                    │   RETURN    │◀────────────┘
                    │ Clean output│    (max 3 iterations)
                    └─────────────┘
```

### GVR Phases

**Phase 1: GENERATE**
- Produce raw draft based on user request
- No filtering during generation

**Phase 2: VERIFY**
- Analyze draft against slop dictionary
- Calculate stylometric metrics:
  - Sentence length σ (target: >15.0)
  - Paragraph length SD (target: >25)
  - TTR (target: 0.50-0.70)
  - Hapax rate (target: >40% or user baseline)
- Flag patterns and threshold violations

**Phase 3: REFINE**
- Issue specific refinement commands for flagged issues
- Rewrite affected sections only
- Preserve semantic meaning

**Phase 4: RETURN or ITERATE**
- If all thresholds met → Return clean output
- If thresholds missed → Iterate (max 3 times)
- If max iterations reached → Return with remaining issues noted

### GVR Thresholds

| Metric | Pass Threshold | Action if Failed |
|--------|----------------|------------------|
| Lexical patterns | 0 in output | Rewrite flagged phrases |
| Sentence length σ | ≥15.0 | Vary sentence lengths |
| Paragraph SD | ≥25 | Vary paragraph lengths |
| TTR | 0.50-0.70 | Diversify vocabulary |
| Hapax rate | ≥40% (or calibrated) | Add unique words |

### GVR Iteration Limits

- **Maximum iterations:** 3
- **Early exit:** All thresholds pass
- **Timeout:** If 3 iterations insufficient, return with notes

### GVR Transparency Report

After generation, report GVR activity:

```
[GVR: 2 iterations | removed 8 patterns | σ: 7.2→16.4 | TTR: 0.42→0.56]
```

Detailed report available on request: "Show GVR details"

---

## When to Use

- Clean up AI-assisted drafts before publishing
- Rewrite marketing copy to remove buzzwords
- Edit documentation to be more concrete
- Background prevention during blog posts, wikis, READMEs
- Add patterns to your personal slop dictionary

---

## Interactive Mode

### Trigger Conditions

Activate interactive mode when user provides existing text with an edit request:

- "Clean up this paragraph: [text]"
- "Remove the AI patterns from this: [text]"
- "Make this less robotic: [text]"
- "Rewrite this to sound human: [text]"

### Confirmation Workflow

**Step 1:** Detect patterns in provided text.

**Step 2:** Present findings with options:

```
Found 5 slop patterns in your text:

1. "incredibly powerful" [Generic booster]
   → Suggest: delete, or specify what makes it powerful

2. "it's important to note" [Filler phrase]
   → Suggest: delete, start with the actual point

3. "comprehensive solution" [Buzzword]
   → Suggest: specify what it covers

4. "leverage" [Buzzword]
   → Suggest: use "use" instead

5. "In today's fast-paced world" [Filler phrase]
   → Suggest: delete entirely

Options:
- "Rephrase all" → I'll rewrite all 5
- "Keep all" → Leave text unchanged
- "List them" → I'll ask about each one
- "Rephrase 1,3,5" → Rewrite specific patterns (keep 2,4)
```

**Step 3:** Execute based on user response.

### User Response Options

| Response | Action |
|----------|--------|
| "Rephrase all" | Rewrite all flagged patterns |
| "Keep all" | Return original text unchanged |
| "List them" | Present each pattern for individual approval |
| "Rephrase 1,3" | Rewrite only specified patterns |
| "Keep 2,4" | Keep specified patterns, rewrite others |
| "Add X to exceptions" | Add pattern to dictionary exceptions |

---

## Automatic Mode

### Trigger Conditions

Activate automatic mode when user requests prose generation:

- "Write a blog post about..."
- "Draft a wiki page for..."
- "Create a README for..."
- "Write documentation for..."
- "Summarize this article..."

### GVR Behavior

1. **Generate** content normally
2. **Verify** output against patterns and stylometric thresholds
3. **Refine** if thresholds missed (max 3 iterations)
4. **Return** clean output with transparency summary

### Transparency Reporting

After generation, report what was prevented:

```
[GVR: 2 iterations | removed 8 patterns (5 lexical, 2 structural, 1 semantic) | σ: 6.8→17.2]
```

User can request details:
- "Show what slop you removed" → Display before/after for each pattern
- "Show GVR details" → Full iteration breakdown
- "Why did you change X?" → Explain specific rewrite

### Activation Control

| Context | Activation |
|---------|------------|
| Blog post, wiki, README, documentation | Auto-activate |
| Code blocks, functions, classes | Auto-deactivate |
| JSON, YAML, config files | Auto-deactivate |
| Technical specs with required terminology | Auto-deactivate |
| User says "disable slop prevention" | Manual deactivate |
| User says "enable slop prevention" | Manual activate |

---

## Rewriting Guidelines

When rewriting flagged patterns, follow these principles:

### 1. Preserve Meaning

Never change what the text says—only how it says it.

**Wrong:** "The system is fast" → "The system is slow but reliable"
**Right:** "The system is fast" → "The system responds in <50ms"

### 2. Increase Specificity

Replace vague claims with concrete details.

| Before | After |
|--------|-------|
| "incredibly powerful" | "handles 10K concurrent connections" |
| "comprehensive solution" | "covers auth, billing, and notifications" |
| "significant improvements" | "40% faster than v2.1" |
| "many companies" | "Stripe, Shopify, and Square" |

### 3. Vary Structure

Break uniform sentence patterns.

**Before (uniform):**
> "The system provides fast responses. Users can expect reliable performance. The team worked hard on optimization."

**After (varied):**
> "Response time: <50ms. We spent three weeks on the caching layer—worth it."

### 4. Delete Over Replace

When a phrase adds no meaning, delete it entirely.

| Pattern | Action |
|---------|--------|
| "It's important to note that" | Delete |
| "Let's dive into" | Delete |
| "In today's fast-paced world" | Delete |
| "At the end of the day" | Delete |

### 5. Commit to Positions

Replace hedging with clear statements.

| Before | After |
|--------|-------|
| "It depends on various factors" | "Use X for <1000 users, Y for more" |
| "Both options have merits" | "Use Postgres. SQLite if you're prototyping." |
| "Results may vary" | "Expect 20-40% improvement based on workload" |

---

## User Feedback Integration

### Adding Patterns (with Immediate Rescan)

When user flags a missed pattern:

```
User: "This is slop: 'at the intersection of'"
```

**Workflow:**

1. Extract phrase from user message
2. Add to dictionary:
   - `pattern`: "at the intersection of"
   - `category`: "chatgpt-cliche"
   - `weight`: 1.0
   - `count`: 1
   - `timestamp`: now
   - `source`: "user-added"
   - `exception`: false
3. Confirm addition
4. **Immediately rescan current document**
5. Report if pattern found and offer to refine

**Response:**

```
Added "at the intersection of" to slop dictionary (chatgpt-cliche).

Rescanning current document...
Found 2 instances:
- Line 12: "Acme Corp sits at the intersection of AI and automotive"
- Line 45: "at the intersection of technology and customer service"

Rephrase these? [Yes/No]
```

### Marking False Positives

```
User: "Don't flag 'leverage' - I use it intentionally"
```

**Workflow:**

1. Update dictionary entry: `exception: true` or add to exceptions list
2. Set scope (permanent or document-only)
3. Confirm

**Response:**

```
Added "leverage" to permanent exceptions.
Won't flag in future documents.

Current exceptions (8 total):
- leverage (permanent)
- robust (permanent - technical term)
- comprehensive (document-only)
...
```

### Feedback Recognition Patterns

| User Says | Action |
|-----------|--------|
| "This is slop: [phrase]" | Add to dictionary, rescan |
| "Flag [phrase] as slop" | Add to dictionary, rescan |
| "[phrase] sounds AI-generated" | Add to dictionary, rescan |
| "Don't flag [phrase]" | Add to exceptions |
| "Keep [phrase]" | Document-only exception |
| "[phrase] is intentional" | Permanent exception |

---

## Dictionary Management

This skill owns dictionary mutations. The detecting-ai-slop skill reads from the dictionary; this skill writes to it.

### Dictionary Location

**File:** `{workspace_root}/.slop-dictionary.json`

Auto-added to `.gitignore` if git repo detected.

### Dictionary Schema (v2)

```json
{
  "version": "2.0",
  "last_modified": "2026-01-25T10:30:00Z",
  "patterns": {
    "leverage": {
      "pattern": "leverage",
      "category": "buzzword",
      "weight": 1.0,
      "count": 47,
      "timestamp": "2026-01-25T10:30:00Z",
      "source": "built-in",
      "exception": false
    }
  },
  "exceptions": {
    "robust": {
      "pattern": "robust",
      "scope": "permanent",
      "added": "2026-01-23T09:15:00Z",
      "reason": "Technical term in my domain"
    }
  },
  "calibration": {
    "samples_provided": 3,
    "baseline_ttr": 0.58,
    "baseline_hapax": 0.45,
    "baseline_sentence_sd": 12.3,
    "calibrated_at": "2026-01-20T16:00:00Z"
  }
}
```

### Add Patterns

```
User: "Add 'synergize' to the slop dictionary"
Skill: Added 'synergize' to Buzzwords category.
       Weight: 1.0 | Count: 1 | Source: user-added
       Rescanning current document... No instances found.

User: "Flag 'game-changing' as slop"
Skill: Added 'game-changing' to Generic Boosters.
       Rescanning... Found 1 instance at line 34.
       Rephrase? [Yes/No]
```

### Add Exceptions

```
User: "Never flag 'leverage' - I use it intentionally"
Skill: Added 'leverage' to permanent exceptions. Won't flag in future.

User: "Keep 'comprehensive' - it's accurate here"
Skill: Added 'comprehensive' to exceptions (this document only).
```

### Query Dictionary

```
User: "Show my top slop patterns"
Skill: [displays patterns sorted by count]

User: "What's in my exceptions list?"
Skill: [displays all excepted phrases with scope]

User: "Show dictionary stats"
Skill:
  Dictionary Statistics:
  ├── Total patterns: 312
  ├── Built-in: 265
  ├── User-added: 47
  ├── Exceptions: 8 (6 permanent, 2 document)
  └── Last modified: 2026-01-25T10:30:00Z
```

### Adjust Pattern Weight

```
User: "Make 'leverage' a high-priority pattern"
Skill: Updated 'leverage' weight: 1.0 → 1.5
       This pattern will now contribute 50% more to the slop score.

User: "Lower priority for 'furthermore'"
Skill: Updated 'furthermore' weight: 1.0 → 0.5
       This pattern will contribute half as much to the slop score.
```

---

## Calibration Mode

Calibrate thresholds using your own human-written samples.

### Invoke Calibration

```
User: "Calibrate slop detection with my writing"
[Paste 3-5 samples of your authentic writing, 300+ words each]
```

### Calibration Process

1. Analyze each sample for stylometric measurements
2. Calculate your personal baselines:
   - Sentence length σ (your natural variance)
   - TTR range (your vocabulary diversity)
   - Hapax rate (your unique word frequency)
3. Store baselines in dictionary calibration section
4. Adjust future GVR thresholds to your personal baseline

### Calibration Output

```
Calibration Complete

Your Writing Profile:
├── Sentence length σ: 12.3 words (default threshold: <15)
├── TTR range: 0.55-0.62 (default threshold: <0.50)
├── Hapax rate: 45% (default threshold: <40%)
└── Paragraph variance: High (characteristic of your style)

Adjusted GVR Thresholds:
├── Sentence σ target: >10 (personalized from your 12.3 baseline)
├── TTR target: >0.52 (personalized from your 0.55 low)
└── Hapax target: >42% (personalized from your 45% baseline)

Calibration saved. GVR loop now uses your personalized thresholds.
```

---

## Domain-Specific Rewriting

### Technical Writing

| Slop | Rewrite Strategy |
|------|------------------|
| "robust solution" | Name what makes it robust: "handles null inputs, network timeouts, and partial failures" |
| "highly scalable" | Quantify: "tested to 50K concurrent users" or "horizontal scaling via stateless workers" |
| "best practices" | Name them: "uses parameterized queries, input validation, and rate limiting" |
| "industry-standard" | Cite the standard: "follows OAuth 2.0 + PKCE" |

### Marketing Copy

| Slop | Rewrite Strategy |
|------|------------------|
| "revolutionary" | State the innovation: "first to combine X with Y" |
| "cutting-edge" | Date the technology: "uses 2024 transformer architecture" |
| "world-class" | Provide evidence: "used by 3 Fortune 500 companies" |
| "seamless integration" | List what integrates: "connects to Salesforce, HubSpot, and Zendesk via API" |

### Academic/Formal Writing

| Slop | Rewrite Strategy |
|------|------------------|
| "it should be noted" | Delete; start with the point |
| "a number of" | Use actual number: "seven participants" |
| "in terms of" | Rewrite directly: "for performance" → "performance improved by 12%" |
| "the fact that" | Delete; rephrase sentence |

### CV/Resume (Detect-Only)

When processing resumes, **detect but do not rewrite**. Resumes are external materials.

```
User: "Analyze this resume for AI slop"
Skill: [Uses detecting-ai-slop, returns slop score and flags]
       Note: Resume is external content. Displaying analysis only, no rewrites offered.
```

### Cover Letter (Detect-Only)

Same as CV/Resume—detect patterns but don't offer rewrites for external materials.

---

## Content-Type-Specific Strategies

| Content Type | Rewriting Strategy |
|--------------|-------------------|
| Document | Standard rewriting |
| Email | Lead with the ask, trim pleasantries |
| LinkedIn | Remove engagement bait, authentic voice |
| SMS | Match conversational register |
| Teams/Slack | Direct and immediate |
| CLAUDE.md | Make rules actionable |
| README | Quickstart first, trim marketing |
| PRD | Add acceptance criteria |
| Design Doc | Recommend with rationale |
| Test Plan | Add expected results |
| CV/Resume | **Detect-only** (candidate content) |
| Cover Letter | **Detect-only** (candidate content) |

---

## Self-Check Before Publishing

Before returning rewritten text, verify:

| Check | Question |
|-------|----------|
| Meaning preserved? | Does the rewrite say the same thing? |
| Specificity added? | Are vague claims now concrete? |
| Length reasonable? | Is it shorter (deleted fluff) or longer (added detail)? |
| Voice consistent? | Does it match the document's tone? |
| No new slop? | Did I introduce patterns while rewriting? |
| GVR thresholds met? | Are stylometric metrics in target range? |

---

## Pattern Reference

For detection categories and pattern lists, see `detecting-ai-slop` skill.

**Quick reference for rewriting:**

### Lexical Patterns (delete or specify)
- **Generic boosters**: incredibly, extremely, highly → quantify or delete
- **Buzzwords**: leverage, synergy, robust → use plain language
- **Filler phrases**: it's important to note → delete
- **Hedge patterns**: might, could, potentially → commit to position
- **Sycophantic phrases**: great question → delete
- **Transitional filler**: let's dive into → delete

### Structural Patterns (vary or restructure)
- **Formulaic intro**: "In today's..." → Start with the point
- **Template sections**: Uniform bullet weight → Vary emphasis
- **Over-signposting**: "First...Second...Third..." → Use varied transitions
- **Staccato paragraphs**: All 2-sentence paragraphs → Vary length
- **Symmetric coverage**: Every point equal weight → Prioritize ruthlessly

### Semantic Patterns (add substance or cut)
- **Hollow specificity**: "industry standards" → Name the standards
- **Absent constraints**: No tradeoffs mentioned → Add limitations
- **Balanced to a fault**: "Both have merits" → Make a recommendation
- **Circular reasoning**: Restates without adding → Add new information

### Typographic Patterns (replace punctuation)
- **Em-dash (—)**: HIGH PRIORITY. Replace with comma, semicolon, colon, or parentheses
  - Parenthetical → parentheses: "the project (started in 2024) succeeded"
  - Contrast → semicolon: "it worked; the maintenance burden compounded"
  - List intro → colon: "three things: speed, quality, cost"
  - Simple pause → comma: "it worked, but barely"
- **Clichés**: "state of the art", "game changer" → use direct language or delete

### Redundancy Patterns (the "chattering parrot" problem)

Before writing or editing prose, scan ±50 lines for similar phrasing. Repetition damages credibility.

**Detection:**
1. Search for 3+ word phrases that appear multiple times
2. Check if you're about to echo something you just wrote
3. For related documents, verify you're not copy/pasting

**Elimination strategies:**
- **Same phrase twice**: Rewrite one instance with different words
- **Parallel structure overuse**: Vary sentence openings ("First... Second... Third..." → mix with other transitions)
- **Cross-document duplication**: When successor docs reference originals, summarize differently rather than copying
- **Bullet point echo**: If bullets sound alike, consolidate or differentiate

**Example:**
```
BEFORE (parrot):
- Architecture first, AI second
- Define structure upfront, let AI handle implementation
- Architecture-first design beats conformity tooling

AFTER (varied):
- Architecture first, AI second
- Let AI handle implementation once structure is defined
- Upfront design outperforms post-hoc conformity tools
```

---

## Example: Full Interactive Workflow

**User provides:**
> "Our incredibly powerful platform leverages cutting-edge AI to deliver comprehensive solutions. It's important to note that we prioritize user experience above all else."

**Skill response:**
```
Found 5 slop patterns:

1. "incredibly powerful" [Generic booster]
   → Suggest: specify capability, e.g., "processes 1M requests/day"

2. "leverages" [Buzzword]
   → Suggest: use "uses"

3. "cutting-edge AI" [Buzzword cluster]
   → Suggest: name the technology, e.g., "GPT-4o with RAG"

4. "comprehensive solutions" [Buzzword]
   → Suggest: list what's covered

5. "It's important to note that" [Filler phrase]
   → Suggest: delete, start with "We prioritize..."

Options:
- "Rephrase all" → I'll rewrite all 5
- "Keep all" → Leave unchanged
- "List them" → One by one
- "Rephrase 1,3,5" → Specific patterns only
```

**User:** "Rephrase all"

**Skill rewrites:**
> "Our platform processes 1M requests/day using GPT-4o with retrieval-augmented generation. It covers intake, routing, and resolution. We prioritize user experience above all else."

---

## Example: GVR Loop in Action

**User:** "Write a blog post introduction about database indexing"

**GVR Iteration 1 (Generate):**
> "In today's data-driven world, database performance is incredibly important. Let's explore how indexing can significantly improve your query speeds and deliver robust solutions for your applications."

**GVR Iteration 1 (Verify):**
- Patterns found: 5 (In today's, incredibly, Let's explore, significantly, robust)
- Sentence σ: 4.2 (target: >15) ⚠️
- TTR: 0.48 (target: 0.50-0.70) ⚠️

**GVR Iteration 2 (Refine → Verify):**
> "Database indexing cut our query time from 340ms to 12ms. Here's what we learned after indexing 50M rows across three production systems."

- Patterns found: 0 ✓
- Sentence σ: 18.4 ✓
- TTR: 0.62 ✓

**GVR Return:**
> "Database indexing cut our query time from 340ms to 12ms. Here's what we learned after indexing 50M rows across three production systems."
>
> [GVR: 2 iterations | removed 5 patterns | σ: 4.2→18.4 | TTR: 0.48→0.62]

---

## Metrics Contribution

After each session, this skill updates `{workspace_root}/.slop-metrics.json`:

- Patterns eliminated (count by category)
- GVR iterations per document
- User approvals vs. rejections
- Exception patterns added
- Documents processed
- Stylometric improvements (before/after)

Metrics inform detection algorithm refinement over time.

---

## Cross-Machine Sync

Dictionary can be synchronized across machines using `slop-sync`:

```bash
slop-sync push    # Upload dictionary to GitHub
slop-sync pull    # Download latest dictionary
slop-sync status  # Show sync state
```

See `slop-sync` script in repository root for setup instructions.

---

## Related Skills

- **detecting-ai-slop**: Analysis and scoring (read-only)
- **reviewing-ai-text**: (Deprecated) Original combined skill
