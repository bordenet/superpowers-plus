# Eliminating AI Slop - Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-07-05

This file contains detailed pattern reference and domain-specific rewriting strategies.

---

## Pattern Reference

For detection categories and pattern lists, see `detecting-ai-slop` skill.

### Lexical Patterns (delete or specify)

| Category | Examples | Action |
|----------|----------|--------|
| Generic boosters | incredibly, extremely, highly | Quantify or delete |
| Buzzwords | leverage, synergy, robust, elevate, harness, pivotal, impactful | Use plain language |
| Filler phrases | it's important to note, in today's ever-evolving world, in conclusion | Delete |
| Hedge patterns | might, could, potentially | Commit to position |
| Sycophantic phrases | great question | Delete |
| Transitional filler | let's dive into, however, indeed, furthermore | Delete or use plain connector |
| Vague abstraction | the frame, the lens, the narrative, the space | Name the specific noun |
| AI jargon | failure mode, failure class, failure pattern, failure category, error class, defect pattern (singular and plural) | See "AI Jargon Replacement Guide" below. Default: name the actual problem. |

#### AI Jargon Replacement Guide: failure mode / failure class / failure pattern / failure category / error class / defect pattern

**Do not replace:**
- Structural section contracts: headings, FMEA column headers, SRE section titles, bold labels in non-prose contexts, list-item labels where the jargon term is immediately followed by a colon or dash (`- failure mode: X`, `- failure mode - X`). A list item that starts with the term and continues as a prose sentence (`- failure mode is the most common...`) is free-running prose; do not exempt it.
- Direct quotations from external sources.
- Term in a sentence describing a code construct by name ("catch the correct error class", "Python's BaseException class hierarchy"). This exemption applies to all six terms; "error class" is simply the most frequent case. The other five are rare in code contexts but treated identically.

**If none of the above exemptions apply, free-running prose only:**

Apply in order, stop at first match:

1. **Categorical veto (check this first):** Is the author formally enumerating a named category of failures that recurs across separate instances, where "bug" or "defect" would collapse a meaningful structural distinction? Detection signals: numbered modes listed by name ("Mode 1: X; Mode 2: Y"), FMEA-style tables with a Failure Mode column, or a section heading that names the category. Absent one of these signals, treat as non-categorical and proceed to step 2. If categorical signals are present, leave it unchanged. Legitimate example: a postmortem with a named section listing "Mode 1: sensor saturation (occurs under sustained load); Mode 2: clock drift (occurs after failover)"; "defect" would erase the structural distinction between modes.

2. **Single-event test:** Does "what went wrong", "the problem", or "what to watch out for" substitute cleanly? If yes, replace. Slop examples: "the failure mode here was skipping code review" becomes "the problem was skipping code review"; "the failure mode for most teams is X" becomes "what most teams get wrong is X" (rhetorical generalization, not a formal category); "this approach has a defect pattern where X" becomes "this approach tends to X."

3. **Default when uncertain:** Replace with the named problem ("the bug was X", "what typically goes wrong is Y", "the risk is Z").

### Structural Patterns (vary or restructure)

| Pattern | Slop Example | Fix |
|---------|--------------|-----|
| Formulaic intro | "In today's..." | Start with the point |
| Template sections | Uniform bullet weight | Vary emphasis |
| Over-signposting | "First...Second...Third..." | Mix transitions |
| Staccato paragraphs | All 2-sentence paragraphs | Vary length |
| Symmetric coverage | Every point equal weight | Prioritize ruthlessly |
| Contrast slogans | "It's not about X. It's about Y." | State the direct claim |
| Hedged concessions | "A minor miss in the scheme of things, but a real one" | State the miss plainly, once |
| Staccato fragments | "Fast. Reliable. Secure." | Merge into a sentence with evidence |
| Rhetorical bridge | "What does this mean for you?" | Answer it or cut the question |
| Random bolding | Mid-sentence **bolding** for rhythm | Bold only genuine call-outs |
| Decorative line breaks | Single sentences as standalone paragraphs | Fold into surrounding prose |

### Semantic Patterns (add substance or cut)

| Pattern | Problem | Solution |
|---------|---------|----------|
| Hollow specificity | "industry standards" | Name the standards |
| Absent constraints | No tradeoffs mentioned | Add limitations |
| Balanced to a fault | "Both have merits" | Make a recommendation |
| Circular reasoning | Restates without adding | Add new information |
| Framework name-dropping | "Framed through Growth Mindset: People, Process, Technology" says nothing | State the concrete claim, or delete the sentence |
| Fabricated open questions | Inventing "needs an owner and a timeline" for a closed product | Check the source of truth; assert only sourced unresolved items |
| Process metrics as results | "30 candidates, 29 screens, 4 debriefs" burying "4 bar-raising hires" | Lead with the outcome; move or cut activity counts |
| Resurrected corrected claims | Restoring a phrase the author already struck | Sweep for prior corrections before each edit pass |

### Typographic Patterns (replace punctuation)

**Em-dash (—) and en-dash (–) - HIGH PRIORITY:**

- Parenthetical → parentheses: "the project (started in 2024) succeeded"
- Contrast → semicolon: "it worked; the maintenance burden compounded"
- List intro → colon: "three things: speed, quality, cost"
- Simple pause → comma: "it worked, but barely"
- En-dash gets the same treatment as em-dash; it is the substitution agents reach for when told to avoid em-dashes. Keep it in ranges ("pp. 3–7", "Mar–Apr") and compound connections between independent nouns ("New York–London flight", "client–server model").

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
| "game-changer" | Describe the specific change: "cuts deployment time from 2 hours to 8 minutes" |
| "future-proof" / "future-ready" | Name what it supports: "ships with v4 API and backward-compat v3 adapter" |
| "data-driven" | Show the data or the decision loop that uses it |
| "customer-centric" | Name the customer behavior the design is based on |
| "end-to-end" | List the actual start and end points |
| "the frame" / "the lens" / "the narrative" | Replace with the specific noun: "our pricing model", "the error rate" |
| "impactful" / "meaningful" / "compelling" | Quantify or replace with what actually happened |

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

## Fabricated Calendar Timelines (Elimination)

When you catch yourself writing "Phase 2 (Weeks 1-2)" or "Sprint 1" or "Target: Q3":

**STOP.** You have no basis for calendar assignments. Replace with dependency ordering:

| Slop | Fix |
|------|-----|
| "Phase 2 (Weeks 1-2): Build schema docs" | "Phase 2: Build schema docs — **depends on**: nothing, can start immediately. **Exit criterion**: docs exist for all 9 tables." |
| "Sprint 1: Extract schema" | "Step 1: Extract schema — **exit criterion**: `CREATE TABLE`-equivalent docs generated for all target tables" |
| "Timeline: 4-6 weeks" | *(delete — you don't know)* |
| "By Week 3, validation complete" | "Validation — **depends on**: schema docs complete. **Exit criterion**: AI reviewer flags synthetic test PR correctly." |

**The rule:** Express *what depends on what* and *what "done" looks like*. Never express *when*.

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

```javascript
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
