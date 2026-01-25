---
name: eliminating-ai-slop
description: Use when writing or editing prose to actively prevent and remove AI slop patterns - operates in interactive mode (confirms before rewriting user text) or automatic mode (silently prevents slop during generation)
---

# Eliminating AI Slop

## Overview

This skill actively rewrites text to eliminate AI slop patterns. It operates in two modes:

1. **Interactive Mode**: User provides existing text → skill confirms before rewriting
2. **Automatic Mode**: Skill prevents slop during prose generation → no confirmation needed

**Core principle:** Preserve meaning while increasing specificity and varying structure.

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

### Behavior

1. Generate content normally
2. Scan output for slop patterns
3. Rewrite to eliminate patterns before returning
4. Append transparency summary

### Transparency Reporting

After generation, report what was prevented:

```
[Slop prevention: removed 8 patterns (5 lexical, 2 structural, 1 semantic)]
```

User can request details:
- "Show what slop you removed" → Display before/after for each pattern
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

## Dictionary Management

This skill owns dictionary mutations. The detecting-ai-slop skill reads from the dictionary; this skill writes to it.

### Add Patterns

```
User: "Add 'synergize' to the slop dictionary"
Skill: Added 'synergize' to Buzzwords category. Count: 1.

User: "Flag 'game-changing' as slop"
Skill: Added 'game-changing' to Generic Boosters. Count: 1.
```

### Add Exceptions

```
User: "Never flag 'leverage' - I use it intentionally"
Skill: Added 'leverage' to exceptions. Won't flag in future.

User: "Keep 'comprehensive' - it's accurate here"
Skill: Added 'comprehensive' to exceptions (this session only).
```

### Query Dictionary

```
User: "Show my top slop patterns"
Skill: [displays patterns sorted by frequency]

User: "What's in my exceptions list?"
Skill: [displays all permanently excepted phrases]
```

### Dictionary Location

**File:** `{workspace_root}/.slop-dictionary.json`

Auto-added to `.gitignore` if git repo detected.

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

## Metrics Contribution

After each session, this skill updates `{workspace_root}/.slop-metrics.json`:

- Patterns eliminated (count by category)
- User approvals vs. rejections
- Exception patterns added
- Documents processed

Metrics inform detection algorithm refinement over time.
