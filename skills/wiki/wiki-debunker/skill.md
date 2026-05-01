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

# wiki-debunker

Fact-check wiki claims about decisions, timelines, who-said-what, and task
ownership. **NO CLAIM WITHOUT CITATION.** Wrong skill? Version / config /
file-path drift → `wiki-verify` · Edit pipeline → `wiki-orchestrator` · Links
→ `link-verification`.

## When to Use

- When asked to fact-check, verify claims, or find evidence for a wiki page's assertions
- Triggered by: `verify these claims`, `fact-check this`, `is this accurate`, `cite sources for`
- Wrong skill? Version/file-path drift → `wiki-verify` · Edit pipeline → `wiki-orchestrator` · Links → `link-verification`

## Source authority matrix

| Claim type | Authoritative | NOT authoritative |
|------------|---------------|-------------------|
| Task ownership | Issue tracker assignee | Wiki plan tables, meeting notes |
| Code authorship | `git blame`, PR author | Wiki mentions, verbal claims |
| Decision made | Issue ticket, PR, meeting transcript | Wiki summaries, secondhand accounts |
| Timeline / date | Git tags, deploy logs | Wiki roadmap tables |
| Current state | Live config, API response | Wiki architecture docs (may be stale) |

**Source laundering:** Wiki plan tables describe *intent*; issue tracker
describes *current state*. Always verify ownership claims against current state.

## Procedure

### 1 — Fetch and extract claims

```bash
tools/wiki-read.sh get "$PAGE_ID" | jq -r '.text' > page.md
# Extract candidate lines: dates, names, "decided", "caused", quotes, %
grep -nE '[0-9]{4}-[0-9]{2}-[0-9]{2}|\b(decided|caused|owns|authored|[0-9]+%)\b|"[^"]{10,}"' page.md
```

### 2 — Verify each claim against authoritative source

| Claim pattern | Verification command |
|---------------|----------------------|
| Date `YYYY-MM-DD` decision | `git log --after=<date-1> --before=<date+1> --all` |
| "We decided to ..." | `gh issue list --search "<keywords>" --state all` |
| "X owns Y" | Issue tracker assignee query (`gh`, Linear, Jira) |
| "PR #NNN did X" | `gh pr view NNN` |
| "Reduced by N%" | Find the measurement commit or ticket |
| "Caused the outage" | Incident report + postmortem |

Per `references/verification-commands.md` for platform-specific recipes.

### 3 — Mark each claim

`✅ VERIFIED` · `⚠️🔄 SOURCED BUT UNVERIFIED` · `⚠️ UNCITED` · `❌ CONTRADICTED`.

### 4 — Report (template in `references/report-format.md`)

Every citation must include a verifiable URL, commit SHA, or ticket ID. No
prose-only citations. `❌ CONTRADICTED` findings → halt Stage 6 and ask user
before publish.

## Hallucination red flags

| Red flag | Example | Verify via |
|----------|---------|------------|
| Precise date, no evidence | "Decided on Jan 15" | Git log bracketed by that date |
| "We decided" without reference | "We decided to use Redis" | Ticket / PR search |
| Possessive attribution from wiki | "Junyi's queries" | Issue tracker assignee |
| Exact percentage, no data source | "Reduced errors by 43%" | Measurement ticket / commit |
| Causal language without evidence | "This caused the outage" | Incident report |

## Failure modes

| Failure | Fix |
|---------|-----|
| No authoritative source found | Mark UNVERIFIED + `citation-needed` tag; do not guess |
| Git history too shallow | Fall back to meeting transcripts, ticket history, PR comments |
| Fabricated plausible citation | Every citation MUST carry URL, commit SHA, or ticket ID |

## Companion skills

wiki-verify · link-verification · wiki-content-coherence ·
issue-comment-debunker · wiki-orchestrator (invokes this as Stage 6)
