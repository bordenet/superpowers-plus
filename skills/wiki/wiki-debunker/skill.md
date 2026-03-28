---
name: wiki-debunker
source: superpowers-plus
triggers: ["verify these claims", "fact-check this", "is this accurate", "cite sources for", "find evidence for"]
anti_triggers: ["write wiki page", "edit wiki", "update wiki content"]
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

> **Wrong skill?** Editing wiki content → `wiki-orchestrator`. Checking links → `link-verification`. Scanning for secrets → `wiki-secret-audit`.

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

## Scope Exclusions

- Editing wiki content → `wiki-orchestrator`
- Checking version drift / stale tech specs → `wiki-verify`
- Checking broken links → `link-verification`
- Scanning for exposed secrets → `wiki-secret-audit`

## Hallucination Red Flags

| Red Flag | Example | Verification |
|----------|---------|-------------|
| Precise date, no evidence | "Decided on Jan 15" | `git log --after=2026-01-14 --before=2026-01-16` |
| "We decided" without reference | "We decided to use Redis" | Search tickets/PRs for the decision |
| Possessive attribution from wiki | "Junyi's queries" | Check issue tracker assignee |
| Exact percentages, no data source | "Reduced errors by 43%" | Find the measurement commit/ticket |
| Causal language without evidence | "This caused the outage" | Check incident reports |

## References

- [`references/report-format.md`](references/report-format.md) — Report template, citation formats
- [`references/verification-commands.md`](references/verification-commands.md) — Verification commands


## Companion Skills

- **wiki-verify**: Broader wiki page verification
- **link-verification**: Checking links within wiki pages
- **wiki-content-coherence**: Checking for content duplication

- **issue-comment-debunker**: Debunking issue comments (this is wiki)
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
