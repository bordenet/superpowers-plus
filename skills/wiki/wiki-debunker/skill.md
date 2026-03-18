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

---

## Orchestrator Integration

This skill is invoked by `wiki-orchestrator` as an **ADVISORY** check (warning, not blocking).

### Fact-Check Report Format

When called by orchestrator, produce this summary:

```
## Fact-Check Report

**Claims Analyzed:** 14
**Verified:** 8 (57%)
**Sourced but Unverified:** 2 (14%)
**Uncited:** 4 (29%)

### Sourced but Unverified (cite from wrong authority)

| # | Claim | Type | Source Used | Authoritative Source | Action |
|---|-------|------|------------|---------------------|--------|
| 1 | "Junyi's funnel metrics queries" | Task ownership | Wiki plan table | Issue tracker assignee | ⚠️🔄 Verify in Linear |
| 2 | "Ships in Sprint 2 per v1 Plan" | Timeline | Wiki roadmap | Git tags, CI deploys | ⚠️🔄 Check actual sprint |

### Uncited Claims (require attention)

| # | Claim | Type | Suggested Source | Action |
|---|-------|------|------------------|--------|
| 1 | "We decided to use Vendor X in Q4 2025" | Decision + Timeline | Issue Tracker, Git | ⚠️ Find ticket/PR |
| 2 | "Person proposed the WebSocket approach" | Attribution | PR #47 | ⚠️ Verify author |
| 3 | "Performance improved significantly" | Vague metric | Benchmarks | ⚠️ Add numbers |
| 4 | "Based on team discussion" | Meeting ref | Meeting transcript | ⚠️ Find transcript |

### Verified Claims

| # | Claim | Source | Citation |
|---|-------|--------|----------|
| 1 | Vendor A for telephony | [TICKET-89]([your-tracker-url]) | ✅ |
| 2 | Vendor B for STT | [PR #52]([your-repo-url]) | ✅ |
| ... | ... | ... | ... |

**Gate Status:** ⚠️ WARNING (4 uncited, 2 sourced-but-unverified)
**Recommendation:** Verify sourced-but-unverified claims against authoritative sources; add citations for uncited claims
```

### Citation Detection

Look for inline citations in these formats:
- `[text](url)` — markdown link
- `[[TICKET-123](url)]` — ticket reference
- `— Author, [Source](url)` — block quote attribution

### Uncited Claim Patterns

Flag these if no citation follows within 2 sentences:
- "We decided/chose/agreed..."
- "In [quarter/month/year]..."
- "[Person] proposed/suggested/built..."
- "After the [incident/meeting/discussion]..."
- Specific numbers without source
- **"[Person]'s [task/work]"** — possessive attribution (e.g., "Junyi's queries", "Thomas's fix")
- **"[Person] handles/owns/is responsible for [task]"** — task ownership claims
- **"assigned to [Person]" or "[Person] will do [task]"** — assignment claims from non-authoritative sources

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

**Git History:**
```bash
# Find commits mentioning topic
git log --all --grep="keyword" --oneline

# Find who changed a file
git blame path/to/file.ts

# Find commits in date range
git log --since="2026-01-01" --until="2026-02-01" --oneline
```

**Issue Tracker:**
```
# Use your issue tracker adapter
issue_search(query: "Find tickets mentioning 'migration'")
issue_get_comments(issue_id: "ISSUE-123")
```

**Repository:**
```
# Use your repository adapter to search commits
repo_search_commits(
  repository: "your-service"
  searchText: "websocket refactor"
)
```

**Meeting Transcripts (if available):**
```
# Use your meeting transcript adapter if configured
meeting_search(query: "KEYWORD")
```

### Step 4: Evaluate Match Quality

| Match | Confidence | Action |
|-------|------------|--------|
| **Exact quote found** | ✅ HIGH | Add citation |
| **Paraphrase matches** | ✅ MEDIUM | Add citation, note "paraphrased" |
| **Topic discussed, different conclusion** | ⚠️ CONTRADICTION | Flag for review |
| **No relevant source found** | ❌ UNVERIFIED | Mark suspect or remove |

### Step 5: Add Citations

**Inline citation format:**
```markdown
We decided to use Vendor A for telephony [[TICKET-89](https://[your-tracker]/TICKET-89)].
```

**Block citation for key decisions:**
```markdown
> "Let's go with Vendor A — their WebSocket API is cleaner."
> — Team Member, [PR #47]([your-repo-url]/pullrequest/47), 2026-01-15
```

---

## Hallucination Red Flags

| Signal | Action |
|--------|--------|
| Specific date but no commit/ticket from that date | ⚠️ Verify date |
| Quote attributed to someone but no source | ⚠️ Find transcript or remove |
| "We decided" without ticket/PR reference | ⚠️ Find decision record |
| Incident reference but no postmortem link | ⚠️ Find incident doc |
| Causal claim ("because X") without evidence | ⚠️ Verify causation |
| Highly specific details (exact percentages, counts) | ⚠️ Find data source |

---

## Git History Verification

Use when claims involve code changes, architecture decisions, or shipping dates.

### Commands

```bash
# Who introduced a concept?
git log --all --oneline --grep="websocket" | head -10

# When was file last changed?
git log -1 --format="%ci %an" -- src/telephony/websocket.ts

# What changed in a date range?
git log --since="2026-01-01" --until="2026-01-31" --oneline

# Who's responsible for specific lines?
git blame -L 50,60 src/config.ts

# Find merge commits (decisions)
git log --merges --oneline --since="2026-01-01"
```

### PR as Decision Record

PRs with descriptions are decision artifacts:
```
# Use your repository adapter to get PR details
repo_get_pull_request(
  repository: "your-service"
  pullRequestId: 47
)

# Get PR discussion threads
repo_get_pull_request_threads(
  repository: "your-service"
  pullRequestId: 47
)
```

---

## Issue Tracker Verification

Use when claims involve feature decisions, bug reports, or team agreements.

### Query Patterns

```
# Find ticket by topic
issue tracker query: "Search issues mentioning 'Telnyx' in Your Team"

# Get specific ticket with comments
issue tracker query: "Get issue TICKET-123 with all comments"

# Find decisions in comments
issue tracker query: "Get comments on TICKET-89 containing 'decided'"
```

### Citation Format

```markdown
Decision: Use Telnyx WebSocket API [[TICKET-89](https://[your-tracker]/TICKET-89)]
```

**Verify before citing:**
- Does ticket exist?
- Does it actually contain the claimed decision?
- Is the attribution correct (assignee vs commenter)?

---

## Work Item / Issue Verification

Use when claims involve builds, deployments, work items, or PR decisions.

### Work Item Queries

```
# Use your issue tracker adapter
issue_get(id: 1234)
issue_get_comments(id: 1234)
```

### Build/Deploy History

```
# Search commits using your repository adapter
repo_search_commits(
  repository: "your-service"
  searchText: "deploy"
)

# Find PR by branch
repo_list_pull_requests(
  repository: "your-service"
  sourceBranch: "feature/websocket-refactor"
)
```

---

## Hallucination Patterns to Detect

### Specific but Unverifiable Claims

| Pattern | Example | Red Flag |
|---------|---------|----------|
| Precise dates without source | "On January 15th, we decided..." | Query git/issue tracker for that date |
| Exact percentages | "Performance improved 47%" | Find benchmark data |
| Quote without attribution | '"This is the best approach"' | Who said it? When? |
| Unanimous agreement | "The team agreed unanimously" | Check for dissent in discussion |

### Common AI Fabrication Patterns

| Pattern | Reality Check |
|---------|---------------|
| "After extensive discussion..." | Was there a meeting? Check transcripts |
| "The team evaluated multiple options..." | Where's the comparison doc? |
| "Based on performance testing..." | Where are the test results? |
| "Following best practices..." | Which practices? Cite source |
| "Industry standard approach..." | Citation needed |

### Temporal Impossibilities

| Claim | Check |
|-------|-------|
| "In Q4 2025 we shipped X" | `git log --since=2025-10-01 --until=2026-01-01` |
| "After the January incident..." | Find incident doc from January |
| "We migrated from A to B" | Find commits removing A, adding B |

### Source Laundering (Wiki-to-Wiki Attribution)

**This is the most dangerous pattern because the claim appears sourced.**

| Pattern | Example | Red Flag |
|---------|---------|----------|
| Possessive attribution from wiki plan | "Junyi's funnel metrics queries" | Does the issue tracker show Junyi assigned to this? |
| Task ownership from sprint schedule | "Thomas handles the businessHours fix (Day 2)" | Is this a current Linear assignment or an aspirational plan? |
| Timeline from roadmap table | "Ships in Sprint 2 per the v1 Plan" | Is this the current sprint assignment in the tracker, or a planning artifact? |
| Competence claim from plan | "Junyi will write the SQL queries" | Was this ever assigned, or is it a plan table entry? |

**Key principle:** Wiki plan tables, sprint schedules, and roadmaps describe *intent*. Issue tracker assignee fields describe *current state*. When writing about who owns what, verify against current state.

**Real incident (2026-03-18):**
- Wiki Pilot Plan table said: `Day 2 | Junyi | Write SQL queries for funnel metrics`
- Agent wrote in new wiki page: "Junyi's funnel metrics queries (Pilot Plan Week 1 Day 2)"
- Reality: No such task was assigned to Junyi in Linear
- Root cause: Agent treated wiki plan (aspirational) as authoritative for task ownership

---

## Meeting Transcript Verification

Use when claims reference meeting discussions, verbal agreements, or spoken quotes.

### Using Your Meeting Adapter

If you have a meeting transcript service (like Fathom, Otter, or similar), use your adapter:

```
# Use your meeting transcript adapter to search
meeting_search(query: "KEYWORD")
meeting_list(limit: 10, include_transcript: true)
```

### Timestamp Deep Links

Many transcript services support timestamp anchors using `#t={seconds}` format:

```
share_url#t=645  →  jumps to 10:45 in recording
```

**Conversion:** `HH:MM:SS` → `HH*3600 + MM*60 + SS` = seconds

Example: `00:10:45` → `10*60 + 45` = `645`

### Citation Formats

**Inline:**
```markdown
As discussed in the [Team Triage @ 10:45]([meeting-share-url]#t=645) ⏵
```

**Block quote:**
```markdown
> "Let's prioritize the vendor integration first."
> — Person Name, [Team Triage @ 10:45]([meeting-share-url]#t=645) ⏵
```

### Share URL Accessibility

Note: Meeting share URLs may require authentication.

| URL Type | Behavior |
|----------|----------|
| `share_url` | May redirect to sign-in |
| `direct_url` | Typically requires account |

**Implication:** Share links may only work for team members with meeting service access.

### Red Flags

| Signal | Action |
|--------|--------|
| Claim about meeting >30 days ago | May exceed transcript retention — verify |
| Quote but no transcript match | Possible fabrication — search all meetings |
| Speaker attribution mismatch | Cross-check `speaker` field in API |
| Meeting "discussed X" but no transcript hit | May be paraphrased or wrong meeting |

### Transcript Structure (Example)

```json
{
  "transcript": [
    {
      "speaker": { "display_name": "Person Name" },
      "timestamp": "00:10:45",
      "text": "Let's prioritize the vendor integration first."
    }
  ]
}
```

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

## Related Skills

- **wiki-verify**: Version/config drift verification
- **link-verification**: URL hallucination prevention  
- **verification-before-completion**: General verification discipline

---

## Quick Reference

```
Before writing ANY factual claim:

1. IDENTIFY — What type of claim is this?
2. AUTHORITY — Is my source authoritative for this claim type?
   (Wiki plan table ≠ authoritative for task ownership)
3. SOURCE — What PRIMARY source would contain evidence?
4. QUERY — Search that source for corroboration
5. CITE — Add inline citation or flag appropriately
6. MARK — ✅ VERIFIED, ⚠️🔄 SOURCED BUT UNVERIFIED, ⚠️ UNCITED, or ❌ CONTRADICTED
```
