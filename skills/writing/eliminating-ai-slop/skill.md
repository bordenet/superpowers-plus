---
name: eliminating-ai-slop
source: superpowers-plus
triggers: ["remove AI slop", "fix slop", "rewrite without slop", "eliminate slop patterns", "make this less AI", "write prose for docs", "draft a message", "compose an email", "write a post", "edit this writing", "review my prose"]
anti_triggers: ["write code", "implement function", "create test", "fix bug", "system prompt", "agent instructions"]
description: Use when writing or editing ANY prose a human will read. Covers messaging (Teams, Slack, Discord), email, social/professional (LinkedIn, Twitter), documentation (wiki, README, commits, PRs), and business writing (meeting notes, status updates, tickets). Operates in interactive mode (confirms before rewriting) or automatic mode (GVR loop). Does NOT fire for AI-to-AI content (prompts, system instructions, agent config).
summary: "Use when: writing or editing prose a human will read. Skip when: writing AI-to-AI content."
composition:
  consumes: [markdown-content]
  produces: [quality-prose]
  capabilities: [eliminates-slop]
  priority: 35
coordination:
  group: writing
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Eliminating AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-03-13
> **See also:** [reference.md](./reference.md) (patterns), [examples.md](./examples.md) (usage)

> **Wrong skill?** Analyzing/scoring text (read-only) → `detecting-ai-slop`. Profanity/inappropriate language → `professional-language-audit`.

## Scope

**Fires for:** All human-readable prose — messaging, email, social/professional, documentation, business writing.
**Does NOT fire for:** AI-to-AI content (prompts, system instructions, agent config, tool parameters, few-shot examples).

## Two Modes

1. **Interactive** — User provides text → show flagged patterns with suggestions → user picks: "Rephrase all", "Keep all", "List them", or "Rephrase 1,3,5"
2. **Automatic (GVR Loop)** — Generate → Verify (check patterns + stylometrics) → Refine (max 3 iterations). Report: `[GVR: 2 iterations | removed 8 patterns | σ: 7.2→16.4]`

### GVR Thresholds

| Metric | Pass | Action if Failed |
|--------|------|------------------|
| Lexical patterns | 0 | Rewrite flagged phrases |
| Sentence length σ | ≥15.0 | Vary sentence lengths |
| TTR | 0.50-0.70 | Diversify vocabulary |

## Rewriting Guidelines

1. **Preserve meaning** — Change how, not what
2. **Increase specificity** — "incredibly powerful" → "handles 10K concurrent connections"
3. **Vary structure** — Break uniform patterns
4. **Delete over replace** — If a phrase adds nothing, cut it
5. **Commit to positions** — "It depends" → "Use X for <1000 users, Y for more"

## Dictionary

**Location:** `{workspace_root}/.slop-dictionary.json` — this skill writes, `detecting-ai-slop` reads.
Commands: "Add [phrase] to slop dictionary" | "Never flag [phrase]" | "Show my top slop patterns"

## Self-Check

Before publishing: meaning preserved? specificity added? voice consistent? no new slop introduced? GVR thresholds met?

## Companion Skills

`detecting-ai-slop` (analysis, read-only) | `professional-language-audit` (profanity detection)


## When to Use

- When authoring any human-readable prose (docs, email, messages, tickets)
- When wiki-orchestrator pipeline triggers slop detection stage
- When reviewing AI-generated content before publishing

## Failure Modes

| Failure | Fix |
|---------|-----|
| Over-correction strips personality from writing | Preserve author voice — only target known slop patterns |
| False positive on legitimate hedging language | Context matters — "it's worth noting" in a risk section is fine |
| Slop patterns evolve faster than the deny list | Update pattern list quarterly from real examples |

```bash
# Example: invoke slop detection
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill eliminating-ai-slop
```
