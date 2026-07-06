---
name: eliminating-ai-slop
source: superpowers-plus
augment_menu: true
triggers: ["/sp-write", "remove AI slop", "fix slop", "rewrite without slop", "eliminate slop patterns", "make this less AI", "write prose for docs", "draft a message", "compose an email", "write a post", "edit this writing", "review my prose"]
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
> **Last Updated:** 2026-07-05
> **See also:** [reference.md](./reference.md) (patterns), [examples.md](./examples.md) (usage)
>
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
6. **Ground claims in the source of truth** — Before writing any claim about team, product, or project state, check the authoritative source (ticket tracker, project wiki, or version-controlled docs). Never infer current state from old drafts, prior summaries, or training priors. Never invent "open questions" or "next steps" for closed topics.
7. **Never resurrect corrected claims** — If the author struck or corrected a phrasing earlier in the document or session, it stays out. Sweep for previously corrected claims before every edit pass; do not restore them from stale drafts or summaries.

## Dictionary

**Location:** `{workspace_root}/.slop-dictionary.json` — this skill writes, `detecting-ai-slop` reads.
Commands: "Add [phrase] to slop dictionary" | "Never flag [phrase]" | "Show my top slop patterns"

## Quick-Reference: Common Patterns

| Slop Pattern | Better Alternative |
|-------------|-------------------|
| "It's worth noting that..." | (delete — just state it) |
| "In order to..." | "To..." |
| "Leveraging/utilizing" | "Using" |
| "A comprehensive solution" | (describe what it actually does) |
| "Incredibly powerful" | (specific metric or capability) |
| "Seamless integration" | "Connects to X via Y" |
| "It's important to understand" | (delete — just explain) |
| "The frame" / "the lens" / "the narrative" | Name the specific concept |
| "Pivotal" / "crucial" / "essential" | State why, or delete |
| "Impactful" / "meaningful" / "compelling" | Quantify or drop |
| "Harness" / "elevate" / "enhance" | Use the plain verb ("use", "improve") |
| "It's not about X. It's about Y." | Make the direct claim instead |
| "In today's ever-evolving world" | (delete — ground in the specific situation) |
| "In conclusion" / "In summary" | (delete — if it's not adding, cut the whole paragraph) |
| "Game-changer" / "revolutionary" / "unprecedented" | Describe the specific difference |
| "Data-driven" / "customer-centric" | Show the data or customer evidence |
| "End-to-end" / "holistic" / "seamless experience" | Name the actual scope or flow |
| En-dash or em-dash as pacing punctuation | Comma, semicolon, colon, or parentheses (en-dash stays in numeric/date ranges) |
| "Failure mode" / "failure class" / "failure pattern" | Name the actual problem: "defect", "bug family", or the specific behavior |
| "A minor X in the scheme of things, but a real one" | State the miss plainly, once, without the symmetric qualifier |
| "Framed through [Framework]: A, B, C" | Delete, or replace with the concrete claim the framework was standing in for |
| Funnel/activity metrics in a results line | Lead with the outcome ("all four hires made, each bar-raising"); move activity counts to an appendix or cut them |

See `reference.md` for the full pattern catalog.

## Structural Contrast Rewrites

These slogan-like forms signal AI generation even with clean vocabulary.

| Slop Form | Rewrite Approach |
|-----------|-----------------|
| "It's not about X. It's about Y." | Drop the contrast — state Y directly |
| "No X. No Y. Just Z." | State Z with evidence |
| "X is not just A; it's B." | Lead with B and prove it |
| "The more you X, the more you Y." | Replace with a specific example |
| One-sentence paragraphs for emphasis | Fold into adjacent prose or support with evidence |
| Random bolded mid-sentence phrases | Bold only genuine call-outs; remove decorative bolding |

## Self-Check

Before publishing: meaning preserved? specificity added? voice consistent? no new slop introduced? GVR thresholds met? state claims checked against the source of truth? no previously corrected claims reintroduced?

## Companion Skills

`detecting-ai-slop` (analysis, read-only) | `professional-language-audit` (profanity detection)

- **detecting-ai-slop**: Read-only analysis (this skill is the active rewriter)
- **readme-authoring**: Slop prevention in READMEs
- **incorporating-research**: Clean up pasted research text
- **markdown-table-discipline**: Slop prevention in table content

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
| Resurrecting a claim the author already corrected | Sweep for previously struck phrasings before each edit; never restore from stale drafts or summaries |
| Fabricating state (open questions, owners, timelines) for closed topics | Check the source of truth (ticket tracker, project wiki) before asserting anything about current state |

```bash
# Example: invoke slop detection
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill eliminating-ai-slop
```
