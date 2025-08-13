# Eliminating AI Slop - Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

This file contains detailed pattern reference and domain-specific rewriting strategies.

---

## Pattern Reference

For detection categories and pattern lists, see `detecting-ai-slop` skill.

### Lexical Patterns (delete or specify)

| Category | Examples | Action |
|----------|----------|--------|
| Generic boosters | incredibly, extremely, highly | Quantify or delete |
| Buzzwords | leverage, synergy, robust | Use plain language |
| Filler phrases | it's important to note | Delete |
| Hedge patterns | might, could, potentially | Commit to position |
| Sycophantic phrases | great question | Delete |
| Transitional filler | let's dive into | Delete |

### Structural Patterns (vary or restructure)

| Pattern | Slop Example | Fix |
|---------|--------------|-----|
| Formulaic intro | "In today's..." | Start with the point |
| Template sections | Uniform bullet weight | Vary emphasis |
| Over-signposting | "First...Second...Third..." | Mix transitions |
| Staccato paragraphs | All 2-sentence paragraphs | Vary length |
| Symmetric coverage | Every point equal weight | Prioritize ruthlessly |

### Semantic Patterns (add substance or cut)

| Pattern | Problem | Solution |
|---------|---------|----------|
| Hollow specificity | "industry standards" | Name the standards |
| Absent constraints | No tradeoffs mentioned | Add limitations |
| Balanced to a fault | "Both have merits" | Make a recommendation |
| Circular reasoning | Restates without adding | Add new information |

### Typographic Patterns (replace punctuation)

**Em-dash (—) - HIGH PRIORITY:**
- Parenthetical → parentheses: "the project (started in 2024) succeeded"
- Contrast → semicolon: "it worked; the maintenance burden compounded"
- List intro → colon: "three things: speed, quality, cost"
- Simple pause → comma: "it worked, but barely"

---

## Domain-Specific Rewriting

### Technical Writing

| Slop | Rewrite Strategy |
|------|------------------|
| "robust solution" | Name what makes it robust: "handles null inputs, network timeouts, and partial failures" |
| "highly scalable" | Quantify: "tested to 50K concurrent users" |
| "best practices" | Name them: "uses parameterized queries, input validation, and rate limiting" |
| "industry-standard" | Cite the standard: "follows OAuth 2.0 + PKCE" |

### Marketing Copy

| Slop | Rewrite Strategy |
|------|------------------|
| "revolutionary" | State the innovation: "first to combine X with Y" |
| "cutting-edge" | Date the technology: "uses 2024 transformer architecture" |
| "world-class" | Provide evidence: "used by 3 Fortune 500 companies" |
| "seamless integration" | List what integrates: "connects to Salesforce, HubSpot, and Zendesk via API" |

### Academic/Formal Writing

| Slop | Rewrite Strategy |
|------|------------------|
| "it should be noted" | Delete; start with the point |
| "a number of" | Use actual number: "seven participants" |
| "in terms of" | Rewrite directly: "performance improved by 12%" |
| "the fact that" | Delete; rephrase sentence |

---

## Time Estimates (Deflation Required)

AI-generated documentation defaults to pre-AI manual labor timeframes. With modern tooling and AI assistants, most tasks take 3-5x less time than stated.

**The Deflation Rule:**
1. Is this based on manual work from 2020?
2. With AI assistance + modern scripts, what's the ACTUAL time?
3. If estimate is >3x realistic, deflate it.

| Task Type | Slop Range | Realistic Range |
|-----------|------------|-----------------|
| Clone + install script | 10-15 min | **3-5 min** |
| WSL first-time setup | 30-45 min | **5-10 min** |
| API key configuration | 15-30 min | **2-5 min** |
| Single feature | 4-8 hours | **30 min - 2 hours** |
| Bug fix with clear repro | 2-4 hours | **15-60 min** |
| Documentation page | 1-2 hours | **15-30 min** |

---

## Content-Type-Specific Strategies

| Content Type | Strategy |
|--------------|----------|
| Document | Standard rewriting |
| Email | Lead with the ask, trim pleasantries |
| LinkedIn | Remove engagement bait, authentic voice |
| SMS | Match conversational register |
| Teams/Slack | Direct and immediate |
| CLAUDE.md | Make rules actionable |
| README | Quickstart first, trim marketing |
| PRD | Add acceptance criteria |
| Design Doc | Recommend with rationale |
| Test Plan | Add expected results |
| CV/Resume | **Detect-only** (candidate content) |
| Cover Letter | **Detect-only** (candidate content) |

---

## Redundancy Elimination ("Chattering Parrot" Problem)

Before writing or editing prose, scan ±50 lines for similar phrasing.

**Detection:**
1. Search for 3+ word phrases that appear multiple times
2. Check if you're about to echo something you just wrote
3. For related documents, verify you're not copy/pasting

**Elimination strategies:**
- Same phrase twice → Rewrite one instance with different words
- Parallel structure overuse → Mix transitions
- Cross-document duplication → Summarize differently
- Bullet point echo → Consolidate or differentiate

**Example:**
```
BEFORE (parrot):
- Architecture first, AI second
- Define structure upfront, let AI handle implementation
- Architecture-first design beats conformity tooling

AFTER (varied):
- Architecture first, AI second
- Let AI handle implementation once structure is defined
- Upfront design outperforms post-hoc conformity tools
```

---

## Dictionary Schema (v2)

```json
{
  "version": "2.0",
  "last_modified": "2026-01-25T10:30:00Z",
  "patterns": {
    "leverage": {
      "pattern": "leverage",
      "category": "buzzword",
      "weight": 1.0,
      "count": 47,
      "timestamp": "2026-01-25T10:30:00Z",
      "source": "built-in",
      "exception": false
    }
  },
  "exceptions": {
    "robust": {
      "pattern": "robust",
      "scope": "permanent",
      "added": "2026-01-23T09:15:00Z",
      "reason": "Technical term in my domain"
    }
  },
  "calibration": {
    "samples_provided": 3,
    "baseline_ttr": 0.58,
    "baseline_hapax": 0.45,
    "baseline_sentence_sd": 12.3,
    "calibrated_at": "2026-01-20T16:00:00Z"
  }
}
```
