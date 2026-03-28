---
name: wiki-debunker
source: superpowers-plus
triggers: ["verify these claims", "fact-check this", "is this accurate", "cite sources for", "find evidence for"]
description: Use when wiki content contains factual claims about decisions, timelines, who-said-what, or technical facts that could be fabricated. Verifies against git history, issue tickets, meeting transcripts, and PRs. Invoked by wiki-orchestrator as ADVISORY gate.
summary: "Use when: posting comments or updates to wiki pages. Evidence before assertion."
composition:
  consumes: [markdown-content]
  produces: [verified-facts]
  capabilities: [validates-facts]
  priority: 30
  optional: true
coordination:
  group: wiki
  order: 2
  requires: []
  enables: []
  escalates_to: ['wiki-orchestrator']
  internal: false
---

# Wiki Debunker

> **NO CLAIM WITHOUT CITATION. Evidence before assertion.**
> Scope: Claims about decisions, timelines, who-said-what, task ownership. NOT version drift (use wiki-verify).

## Source Authority Matrix

<EXTREMELY_IMPORTANT>

**Not all citations are equal.** The source must be authoritative for the claim type.

| Claim Type | Authoritative Source | NOT Authoritative |
|------------|---------------------|-------------------|
| Task ownership | Issue tracker assignee | Wiki plan tables, meeting notes |
| Code authorship | `git blame`, PR author | Wiki mentions, verbal claims |
| Decision made | Issue ticket, PR, meeting transcript | Wiki summaries, secondhand accounts |
| Timeline/date | Git tags, deploy logs | Wiki roadmap tables |
| Current state | Live config, API response | Wiki architecture docs (may be stale) |

**Source laundering:** Wiki plan tables describe *intent*. Issue tracker describes *current state*. When writing about who owns what, verify against current state.

</EXTREMELY_IMPORTANT>

## Process

1. **Extract claims** — flag statements with dates, names, decisions, causal language, quotes
2. **Check authority** — is the source authoritative for this claim type?
3. **Query source** — git log, issue tracker, meeting transcript (see `references/verification-commands.md`)
4. **Mark result:** ✅ VERIFIED | ⚠️🔄 SOURCED BUT UNVERIFIED | ⚠️ UNCITED | ❌ CONTRADICTED

## Hallucination Red Flags

- Precise date but no commit/ticket from that date
- "We decided" without ticket/PR reference
- Possessive attribution from wiki plan ("Junyi's queries") — verify in issue tracker
- Exact percentages without data source

## References

- [`references/report-format.md`](references/report-format.md) — Report template, citation formats
- [`references/verification-commands.md`](references/verification-commands.md) — Verification commands


## When to Use

- When wiki content includes decisions, timelines, or attribution ("X decided", "on date Y")
- When wiki-orchestrator pipeline triggers fact-check stage
- When reviewing pages that reference meetings, PRs, or historical context

## Failure Modes

| Failure | Fix |
|---------|-----|
| No authoritative source found for a claim | Mark as UNVERIFIED with citation-needed tag — don't guess |
| Git history doesn't go back far enough | Check meeting transcripts (Fathom), ticket history, PR comments |
| Agent fabricates a plausible-sounding citation | Every citation must include a verifiable URL or commit SHA |

```bash
# Example: invoke debunker on a wiki page
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill wiki-debunker
```
