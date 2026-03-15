---
name: eliminating-ai-slop
source: superpowers-plus
triggers: ["remove AI slop", "fix slop", "rewrite without slop", "eliminate slop patterns", "make this less AI", "writing definitions", "tooltip text", "prose for documentation", "writing prose", "documentation text", "teams message", "slack message", "discord message", "chat message", "email draft", "email reply", "composing email", "linkedin post", "linkedin message", "twitter post", "social media post", "wiki page", "readme", "commit message", "pr description", "meeting notes", "status update", "ticket description", "jira ticket", "linear issue"]
description: Use when writing or editing ANY prose a human will read. Covers messaging (Teams, Slack, Discord), email, social/professional (LinkedIn, Twitter), documentation (wiki, README, commits, PRs), and business writing (meeting notes, status updates, tickets). Operates in interactive mode (confirms before rewriting) or automatic mode (GVR loop). Does NOT fire for AI-to-AI content (prompts, system instructions, agent config).
---

# Eliminating AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-03-13
> **See also:** [reference.md](./reference.md) (patterns), [examples.md](./examples.md) (usage)

## Overview

This skill actively rewrites text to eliminate AI slop patterns. It operates in two modes:

1. **Interactive Mode**: User provides existing text → skill confirms before rewriting
2. **Automatic Mode**: Skill prevents slop during prose generation using **GVR loop**

**Core principle:** Preserve meaning while increasing specificity and varying structure.

---

## When This Skill Fires

| Context Category | Examples | Fires? |
|------------------|----------|--------|
| **Messaging** | Teams, Slack, Discord, chat | ✅ Yes |
| **Email** | Drafts, replies, forwards | ✅ Yes |
| **Social/Professional** | LinkedIn posts, Twitter, social media | ✅ Yes |
| **Documentation** | Wiki pages, READMEs, commit messages, PR descriptions | ✅ Yes |
| **Business Writing** | Meeting notes, status updates, ticket descriptions | ✅ Yes |
| **Any human-readable prose** | Tooltips, definitions, announcements | ✅ Yes |

---

## When This Skill Does NOT Fire

| Context | Why Excluded |
|---------|--------------|
| **Prompts for AI agents** | AI-to-AI communication optimizes for clarity and precision, not natural flow |
| **System prompts** | Structured instructions benefit from explicit phrasing |
| **Agent configuration** | Technical directives, not prose |
| **Tool/function parameters** | Machine-readable, not human-readable |
| **Few-shot examples in prompts** | Intentional patterns for model guidance |

**Rationale:** Slop patterns like "It's important to note" are problematic for human readers but may be neutral or useful in agent prompts where explicit signaling aids comprehension.

---

## Generate-Verify-Refine (GVR) Loop

The core architecture for automatic slop elimination.

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

### GVR Thresholds

| Metric | Pass Threshold | Action if Failed |
|--------|----------------|------------------|
| Lexical patterns | 0 in output | Rewrite flagged phrases |
| Sentence length σ | ≥15.0 | Vary sentence lengths |
| Paragraph SD | ≥25 | Vary paragraph lengths |
| TTR | 0.50-0.70 | Diversify vocabulary |
| Hapax rate | ≥40% | Add unique words |

### GVR Transparency Report

After generation: `[GVR: 2 iterations | removed 8 patterns | σ: 7.2→16.4]`

---

## Interactive Mode

Activate when user provides existing text with an edit request.

### Confirmation Workflow

```
Found 5 slop patterns in your text:

1. "incredibly powerful" [Generic booster]
   → Suggest: delete, or specify what makes it powerful

2. "it's important to note" [Filler phrase]
   → Suggest: delete, start with the actual point

Options:
- "Rephrase all" → I'll rewrite all 5
- "Keep all" → Leave text unchanged
- "List them" → I'll ask about each one
- "Rephrase 1,3,5" → Rewrite specific patterns only
```

### User Response Options

| Response | Action |
|----------|--------|
| "Rephrase all" | Rewrite all flagged patterns |
| "Keep all" | Return original text unchanged |
| "List them" | Present each pattern for individual approval |
| "Rephrase 1,3" | Rewrite only specified patterns |
| "Add X to exceptions" | Add pattern to dictionary exceptions |

---

## Automatic Mode

Activate when user requests prose generation (blog posts, wikis, READMEs).

| Context | Activation |
|---------|------------|
| Blog post, wiki, README, documentation | Auto-activate |
| Code blocks, functions, classes | Auto-deactivate |
| JSON, YAML, config files | Auto-deactivate |
| User says "disable slop prevention" | Manual deactivate |

---

## Rewriting Guidelines

### 1. Preserve Meaning
Never change what the text says—only how it says it.

### 2. Increase Specificity
| Before | After |
|--------|-------|
| "incredibly powerful" | "handles 10K concurrent connections" |
| "comprehensive solution" | "covers auth, billing, and notifications" |

### 3. Vary Structure
Break uniform sentence patterns.

### 4. Delete Over Replace
When a phrase adds no meaning, delete it entirely.

### 5. Commit to Positions
| Before | After |
|--------|-------|
| "It depends on various factors" | "Use X for <1000 users, Y for more" |
| "Both options have merits" | "Use Postgres. SQLite if prototyping." |

---

## User Feedback Integration

### Adding Patterns

```
User: "This is slop: 'at the intersection of'"
Skill: Added to dictionary. Rescanning... Found 2 instances. Rephrase? [Yes/No]
```

### Marking Exceptions

```
User: "Don't flag 'leverage' - I use it intentionally"
Skill: Added to permanent exceptions. Won't flag in future.
```

---

## Dictionary Management

**Location:** `{workspace_root}/.slop-dictionary.json`

This skill owns dictionary mutations. The detecting-ai-slop skill reads; this skill writes.

### Commands

| Command | Action |
|---------|--------|
| "Add [phrase] to slop dictionary" | Add pattern, rescan |
| "Never flag [phrase]" | Add to permanent exceptions |
| "Keep [phrase]" | Document-only exception |
| "Show my top slop patterns" | Display by frequency |
| "Show dictionary stats" | Display counts |

---

## Self-Check Before Publishing

| Check | Question |
|-------|----------|
| Meaning preserved? | Does the rewrite say the same thing? |
| Specificity added? | Are vague claims now concrete? |
| Length reasonable? | Shorter (deleted fluff) or longer (added detail)? |
| Voice consistent? | Does it match the document's tone? |
| No new slop? | Did I introduce patterns while rewriting? |
| GVR thresholds met? | Are stylometric metrics in target range? |

---

## Related Skills

- **detecting-ai-slop**: Analysis and scoring (read-only)
- **professional-language-audit**: Profanity and inappropriate language detection
