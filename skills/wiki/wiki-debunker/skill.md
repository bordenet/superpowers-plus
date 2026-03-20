---
name: wiki-debunker
source: superpowers-plus
triggers: ["verify these claims", "fact-check this", "is this accurate", "cite sources for", "find evidence for"]
description: Use when wiki content contains factual claims about decisions, timelines, who-said-what, or technical facts that could be fabricated. Verifies against git history, issue tickets, meeting transcripts, and PRs. Invoked by wiki-orchestrator as ADVISORY gate.
composition:
  consumes: [markdown-content]
  produces: [verified-facts]
  capabilities: [validates-facts]
  priority: 30
  optional: true
---

# Wiki Debunker

> **Purpose:** Detect and prevent hallucinated facts in wiki documentation
> **Scope:** Claims about what happened, when, who decided, who owns what — NOT version numbers (see wiki-verify)
> **Last Updated:** 2026-03-18

## When to Use

- Wiki content contains factual claims about decisions, timelines, or who-said-what
- Reviewing documentation that cites meetings, PRs, or architectural decisions
- Any wiki edit where fabricated history could mislead future readers

---

## Orchestrator Integration

This skill is invoked by `wiki-orchestrator` as an **ADVISORY** check (warning, not blocking).

### Fact-Check Report Format

See `references/report-format.md` for the full report template and citation formats.

**Verification statuses:** ✅ VERIFIED | ⚠️🔄 SOURCED BUT UNVERIFIED | ⚠️ UNCITED | ❌ CONTRADICTED

### Uncited Claim Patterns

Flag if no citation within 2 sentences: "We decided/chose/agreed...", "In [quarter/year]...", "[Person] proposed/built...", "[Person]'s [task]" (possessive attribution), "[Person] handles/owns [task]", specific numbers without source.

---

## When to Use

Invoke when wiki content contains:

- Claims about decisions ("We decided to use X")
- Attributions ("Matt proposed Y")
- Timelines ("In Q4 2025 we shipped Z")
- Quotes ("As discussed in the meeting...")
- Causal claims ("Because of incident X, we changed to Y")
- Historical facts ("The system was redesigned after...")

**NOT for:** Version drift, config values, link verification (use wiki-verify, link-verification)

---

## ⛔ The Iron Rule

<EXTREMELY_IMPORTANT>

**NO CLAIM WITHOUT CITATION. Evidence before assertion.**

| Claim Type | Required Source | How to Verify |
|------------|-----------------|---------------|
| Decision made | issue ticket, PR, meeting notes | Query issue tracker API, git log, meeting adapter |
| Timeline/date | Git commits, deploy logs | `git log --since --until` |
| Attribution | PR author, ticket assignee | Git blame, issue assignee field |
| **Task ownership** | **Issue tracker assignee field** | **Query issue tracker for current assignee — wiki plan tables are NOT authoritative** |
| Quote | Meeting transcript, ticket comment | Meeting adapter, issue comment |
| Incident reference | Incident doc, postmortem | Wiki search, git history |

**If you cannot find a source, the claim is SUSPECT until verified.**

</EXTREMELY_IMPORTANT>

---

## ⚠️ Source Authority Matrix

<EXTREMELY_IMPORTANT>

**Not all citations are equal.** A claim can be "sourced" from a wiki page and still be wrong. The source must be **authoritative for the specific type of claim** being made.

### The Problem: Source Laundering

When content from one system (e.g., a wiki planning table) is treated as fact in another system (e.g., a new wiki page), the original source's limitations are erased. The claim gains the appearance of being verified simply because it has a provenance — even though that provenance isn't authoritative.

**Real incident (2026-03-18):** A wiki Pilot Operational Plan contained a day-by-day table with `Day 2 | Junyi | Write SQL queries for funnel metrics`. This was an EM's aspirational plan, not a current assignment. An agent read this table and wrote "Junyi's funnel metrics queries (Pilot Plan Week 1 Day 2)" in a new wiki page. The claim appeared sourced (it referenced the Pilot Plan), but the Pilot Plan is not authoritative for who currently owns what — Linear is.

### The Matrix

| Claim Type | Authoritative Source | NON-Authoritative (requires verification) |
|------------|---------------------|-------------------------------------------|
| **Task ownership / assignment** | Issue tracker assignee field | Wiki plan tables, meeting notes, sprint schedules |
| **Code authorship** | `git blame`, PR author | Wiki mentions, verbal claims, plan tables |
| **Decision made** | Issue ticket, PR description, meeting transcript | Wiki summaries, secondhand accounts |
| **Timeline / shipping date** | Git tags, deploy logs, CI timestamps | Wiki plan schedules, roadmap tables |
| **Current system state** | Live config, API response, dashboard | Wiki architecture docs (may be stale) |

### Verification Status Categories

| Status | Meaning | Report Symbol |
|--------|---------|---------------|
| **VERIFIED** | Claim confirmed against authoritative source | ✅ |
| **SOURCED BUT UNVERIFIED** | Claim references a source, but that source is not authoritative for this claim type | ⚠️🔄 |
| **UNCITED** | No source referenced at all | ⚠️ |
| **CONTRADICTED** | Authoritative source contradicts the claim | ❌ |

### When You See "SOURCED BUT UNVERIFIED"

The claim isn't necessarily wrong — but it hasn't been verified against the right system. Actions:

1. **Query the authoritative source** (e.g., check Linear for task assignment)
2. **If confirmed:** Upgrade to VERIFIED and optionally add authoritative citation
3. **If contradicted:** Flag as CONTRADICTED — the non-authoritative source is stale
4. **If unverifiable:** Remove the attribution or add qualifier: "per wiki plan, unverified in Linear"

### Detection Patterns for Source Laundering

Flag these as "SOURCED BUT UNVERIFIED" when the source is a wiki plan/schedule:

- "[Person]'s [task]" where ownership comes from a wiki plan table, not issue tracker
- "assigned to [Person] (per [Plan Page])" — plan pages describe intent, not current state
- "[Person] will [do task] by [date]" sourced from a schedule, not an active ticket
- "per the sprint plan / operational plan / roadmap" used as authority for who owns what

</EXTREMELY_IMPORTANT>

---

## Verification Process

### Step 1: Extract Claims

Parse wiki content for verifiable claims. Flag any statement containing:

- Specific dates, quarters, or timeframes
- Named individuals
- Decision language ("decided", "agreed", "chose", "proposed")
- Causal language ("because", "due to", "after", "led to")
- Quotes or paraphrases

### Step 2: Categorize & Route

```
┌─────────────────────────────────────────────────────────┐
│ CLAIM TYPE          │ PRIMARY SOURCE      │ FALLBACK   │
├─────────────────────┼─────────────────────┼────────────┤
│ Code decision       │ PR description      │ git log    │
│ Architecture choice │ ADR, issue ticket  │ meeting    │
│ Timeline/shipping   │ git tags, deploys   │ Issues     │
│ Task ownership      │ Issue tracker       │ wiki plan* │
│ Verbal agreement    │ Meeting transcript  │ none**     │
│ Incident details    │ postmortem doc      │ wiki hist  │
└─────────────────────────────────────────────────────────┘
*  Wiki plan tables are NOT authoritative for task ownership — verify in issue tracker
** Verbal claims without recording = UNVERIFIABLE
```

### Step 3: Query Sources

Use git, issue tracker, repository, and meeting adapters. See `references/verification-commands.md` for all commands.

### Step 4: Evaluate & Cite

| Match | Action |
|-------|--------|
| Exact quote found | ✅ Add citation |
| Paraphrase matches | ✅ Add citation, note "paraphrased" |
| Topic discussed, different conclusion | ⚠️ Flag CONTRADICTION |
| No relevant source found | ❌ Mark UNVERIFIED |

See `references/report-format.md` for citation formats.

---

## Hallucination Red Flags

| Signal | Action |
|--------|--------|
| Precise date but no commit/ticket from that date | ⚠️ Verify date |
| Quote without attribution | ⚠️ Find transcript or remove |
| "We decided" without ticket/PR reference | ⚠️ Find decision record |
| Exact percentages without data source | ⚠️ Find benchmark |
| "After extensive discussion..." / "Based on testing..." | ⚠️ Find meeting/test results |
| Possessive attribution from wiki plan ("Junyi's queries") | ⚠️🔄 Verify in issue tracker |

### Source Laundering (Most Dangerous)

Wiki plan tables describe *intent*. Issue tracker assignee fields describe *current state*. When writing about who owns what, verify against current state — not wiki plans.

See `references/verification-commands.md` for meeting transcript verification, git commands, and issue tracker queries.

---

## Verification Checklist

- [ ] **Extract claims** — List all factual assertions
- [ ] **Categorize** — Decision? Timeline? Attribution? Task ownership? Quote?
- [ ] **Check source authority** — Is the source authoritative for this claim type? (see [Source Authority Matrix](#h-source-authority-matrix))
- [ ] **Identify authoritative source** — Git, issue tracker, meeting transcript? (NOT wiki plan tables for ownership)
- [ ] **Query source** — Use appropriate adapter/API
- [ ] **Evaluate match** — Exact? Paraphrase? Contradiction? Sourced-but-unverified?
- [ ] **Add citation** — Inline link to authoritative source
- [ ] **Flag appropriately** — ⚠️ UNCITED, ⚠️🔄 SOURCED BUT UNVERIFIED, or ❌ CONTRADICTED

---

## Quick Reference

Before writing ANY factual claim: **IDENTIFY** type → **AUTHORITY** check (wiki plan ≠ authoritative for ownership) → **SOURCE** primary evidence → **QUERY** that source → **CITE** inline → **MARK** (✅/⚠️🔄/⚠️/❌)

## Related Skills

- **wiki-verify**: Version/config drift | **link-verification**: URL hallucination | **verification-before-completion**: General verification

## Common Failure Modes

- **Source laundering:** Citing an AI-generated summary as "evidence" — always trace to primary source (git log, PR, meeting transcript)
- **Confirmation search:** Looking only for evidence that supports the claim instead of also searching for contradictions
- **Skipping git history:** Accepting "we decided X in Q4" without checking git blame or commit messages for that timeframe

## Example: Verification Query

```bash
# Verify a "decided in Sprint 23" claim
git log --since="2026-01-15" --until="2026-01-29" --grep="feature-name" --oneline
# Cross-check with issue tracker
search_issues_linear(query: "feature-name", status: "Done")
```


## Reference Files

- [`references/report-format.md`](references/report-format.md) — Full fact-check report template, citation formats
- [`references/verification-commands.md`](references/verification-commands.md) — Git, issue tracker, repository, and meeting transcript verification commands
