---
name: wiki-debunker
source: superpowers-plus
triggers: ["verify these claims", "fact-check this", "is this accurate", "cite sources for", "find evidence for"]
description: Use when wiki content contains factual claims about decisions, timelines, who-said-what, or technical facts that could be fabricated. Verifies against git history, issue tickets, Fathom transcripts, and PRs. Invoked by wiki-orchestrator as ADVISORY gate.
---

# Wiki Debunker

> **Purpose:** Detect and prevent hallucinated facts in wiki documentation
> **Scope:** Claims about what happened, when, who decided, why — NOT version numbers (see wiki-verify)
> **Last Updated:** 2026-02-28

---

## Orchestrator Integration

This skill is invoked by `wiki-orchestrator` as an **ADVISORY** check (warning, not blocking).

### Fact-Check Report Format

When called by orchestrator, produce this summary:

```
## Fact-Check Report

**Claims Analyzed:** 12
**With Citations:** 8 (67%)
**Uncited Claims:** 4

### Uncited Claims (require attention)

| # | Claim | Type | Suggested Source | Action |
|---|-------|------|------------------|--------|
| 1 | "We decided to use Telnyx in Q4 2025" | Decision + Timeline | Issue Tracker, Git | ⚠️ Find ticket/PR |
| 2 | "Matt proposed the WebSocket approach" | Attribution | PR #47 | ⚠️ Verify author |
| 3 | "Performance improved significantly" | Vague metric | Benchmarks | ⚠️ Add numbers |
| 4 | "Based on team discussion" | Meeting ref | Fathom | ⚠️ Find transcript |

### Verified Claims

| # | Claim | Source | Citation |
|---|-------|--------|----------|
| 1 | Vendor A for telephony | [TICKET-89]([your-tracker-url]) | ✅ |
| 2 | Vendor B for STT | [PR #52]([your-repo-url]) | ✅ |
| ... | ... | ... | ... |

**Gate Status:** ⚠️ WARNING (4 uncited claims)
**Recommendation:** Add citations or mark claims as speculative
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
| Decision made | issue ticket, PR, meeting notes | Query issue tracker API, git log, Fathom |
| Timeline/date | Git commits, deploy logs | `git log --since --until` |
| Attribution | PR author, ticket assignee | Git blame, issue assignee field |
| Quote | Meeting transcript, ticket comment | Fathom API, issue comment |
| Incident reference | Incident doc, postmortem | Wiki search, git history |

**If you cannot find a source, the claim is SUSPECT until verified.**

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
│ Verbal agreement    │ Fathom transcript   │ none*      │
│ Incident details    │ postmortem doc      │ wiki hist  │
└─────────────────────────────────────────────────────────┘
* Verbal claims without recording = UNVERIFIABLE
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

**issue tracker API:**
```
issue tracker query: "Find tickets mentioning 'Telnyx migration'"
issue tracker query: "Get comments on DEL-123"
```

**Azure DevOps:**
```
repo_search_commits_azure-devops
  project: "Your Project"
  repository: "voice-service"
  searchText: "websocket refactor"
```

**Fathom (when available):**
```bash
curl -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?include_transcript=true" | \
  jq '.items[] | .transcript[] | select(.text | test("KEYWORD"; "i"))'
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
```bash
# Get PR info from Azure DevOps
repo_get_pull_request_by_id_azure-devops
  repositoryId: "voice-service"
  pullRequestId: 47

# Get PR threads (discussion)
repo_list_pull_request_threads_azure-devops
  repositoryId: "voice-service"
  pullRequestId: 47
```

---

## Issue Tracker Verification

Use when claims involve feature decisions, bug reports, or team agreements.

### Query Patterns

```
# Find ticket by topic
issue tracker query: "Search issues mentioning 'Telnyx' in Your Team"

# Get specific ticket with comments
issue tracker query: "Get issue DEL-123 with all comments"

# Find decisions in comments
issue tracker query: "Get comments on DEL-89 containing 'decided'"
```

### Citation Format

```markdown
Decision: Use Telnyx WebSocket API [[DEL-89](https://[your-tracker]/DEL-89)]
```

**Verify before citing:**
- Does ticket exist?
- Does it actually contain the claimed decision?
- Is the attribution correct (assignee vs commenter)?

---

## Azure DevOps Verification

Use when claims involve builds, deployments, work items, or PR decisions.

### Work Item Queries

```
wit_get_work_item_azure-devops
  id: 1234
  project: "Your Project"

wit_list_work_item_comments_azure-devops
  project: "Your Project"
  workItemId: 1234
```

### Build/Deploy History

```
# Search commits
repo_search_commits_azure-devops
  project: "Your Project"
  repository: "voice-service"
  searchText: "deploy"

# Find PR by branch
repo_list_pull_requests_by_repo_or_project_azure-devops
  project: "Your Project"
  repositoryId: "voice-service"
  sourceRefName: "refs/heads/feature/websocket-refactor"
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
| "After extensive discussion..." | Was there a meeting? Check Fathom |
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

---

## Fathom Transcript Verification

Use when claims reference meeting discussions, verbal agreements, or spoken quotes.

### API Access

```bash
# Set API key (from superpowers-plus/.env or a.Technology/backups/.env)
export FATHOM_API_KEY="your-key-here"

# List recent meetings with transcripts
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=10&include_transcript=true" | jq '.'

# Search transcript for keyword (client-side filter)
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?include_transcript=true" | \
  jq '.items[] | {title, share_url, matches: [.transcript[]? | select(.text | test("KEYWORD"; "i"))]} | select(.matches | length > 0)'
```

### Timestamp Deep Links

Fathom supports timestamp anchors using `#t={seconds}` format:

```
share_url#t=645  →  jumps to 10:45 in recording
```

**Conversion:** `HH:MM:SS` → `HH*3600 + MM*60 + SS` = seconds

Example: `00:10:45` → `10*60 + 45` = `645`

### Citation Formats

**Inline:**
```markdown
As discussed in the [Your Team Triage @ 10:45](https://fathom.video/share/xyz#t=645) ⏵
```

**Block quote:**
```markdown
> "Let's prioritize the Telnyx integration first."
> — Matt Bordenet, [Your Team Triage @ 10:45](https://fathom.video/share/xyz#t=645) ⏵
```

### Share URL Accessibility

**TESTED 2026-02-19:** Share URLs require Fathom authentication.

| URL Type | Behavior |
|----------|----------|
| `share_url` | Redirects to sign-in with share token |
| `url` (direct) | Requires Fathom account |

**Implication:** Share links work for team members with Fathom access. External readers without Fathom accounts cannot view.

### Red Flags

| Signal | Action |
|--------|--------|
| Claim about meeting >30 days ago | May exceed Fathom retention — verify |
| Quote but no transcript match | Possible fabrication — search all meetings |
| Speaker attribution mismatch | Cross-check `speaker.display_name` in API |
| Meeting "discussed X" but no transcript hit | May be paraphrased or wrong meeting |

### Transcript Structure

```json
{
  "transcript": [
    {
      "speaker": { "display_name": "Matt Bordenet" },
      "timestamp": "00:10:45",
      "text": "Let's prioritize the Telnyx integration first."
    }
  ]
}
```

---

## Verification Checklist

- [ ] **Extract claims** — List all factual assertions
- [ ] **Categorize** — Decision? Timeline? Attribution? Quote?
- [ ] **Identify source** — Git, issue tracker, ADO, Fathom, wiki?
- [ ] **Query source** — Use appropriate API/command
- [ ] **Evaluate match** — Exact? Paraphrase? Contradiction?
- [ ] **Add citation** — Inline link to source
- [ ] **Flag unverified** — Mark suspect claims with ⚠️

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
2. SOURCE — What primary source would contain evidence?
3. QUERY — Search that source for corroboration
4. CITE — Add inline citation or flag as unverified
5. MARK — If unverifiable, add ⚠️ UNVERIFIED tag
```

