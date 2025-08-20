---
name: eliminating-ai-slop
source: superpowers-plus
triggers: ["remove AI slop", "fix slop", "rewrite without slop", "eliminate slop patterns", "make this less AI", "writing definitions", "tooltip text", "prose for documentation", "writing prose", "documentation text", "teams message", "slack message", "discord message", "chat message", "email draft", "email reply", "composing email", "linkedin post", "linkedin message", "twitter post", "social media post", "wiki page", "readme", "commit message", "pr description", "status update", "ticket description", "jira ticket", "linear issue"]
description: Use when writing or editing ANY prose a human will read. Covers messaging (Teams, Slack, Discord), email, social/professional (LinkedIn, Twitter), documentation (wiki, README, commits, PRs), and business writing (meeting notes, status updates, tickets). Operates in interactive mode (confirms before rewriting) or automatic mode (GVR loop). Does NOT fire for AI-to-AI content (prompts, system instructions, agent config).
composition:
  consumes: [markdown-content]
  produces: [quality-prose]
  capabilities: [eliminates-slop]
  priority: 35
---

# Eliminating AI Slop

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-03-13
> **See also:** [reference.md](./reference.md) (patterns), [examples.md](./examples.md) (usage)

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

## Related Skills

`detecting-ai-slop` (analysis, read-only) | `professional-language-audit` (profanity detection)
