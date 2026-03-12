---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["create wiki page", "update wiki", "document X in wiki", "write wiki documentation for", "publish to wiki"]
description: Use when creating or updating wiki pages — the default entry point for all wiki authoring. Automatically invokes de-duplication, link-verification, secret-scan, slop-detection, and fact-check as mandatory pipeline stages.
---

# Wiki Orchestrator

> **Purpose:** Enforce quality pipeline for ALL wiki authoring
> **Adapter:** See `skills/wiki/_adapters/` for platform-specific configuration
> **Philosophy:** Make quality control unavoidable, not optional

---

## ⚠️ THIS IS THE ENTRY POINT — NOT wiki-editing

<EXTREMELY_IMPORTANT>

**When you want to create or update wiki content:**
- ✅ Use `wiki-orchestrator` (this skill) — runs full quality pipeline
- ❌ Do NOT go directly to `wiki-editing` — bypasses quality gates

**`wiki-editing` is Stage 7 of THIS pipeline.** It should only be invoked BY this orchestrator, not directly.

If you find yourself about to invoke `wiki-editing` directly, STOP and use this skill instead.

</EXTREMELY_IMPORTANT>

---

## When to Use

**Automatic triggers:**
- "Create a wiki page about X"
- "Update the wiki page for Y"
- "Document X in the wiki"
- "Write wiki documentation for..."
- Any task involving wiki content creation or updates

**This skill is the DEFAULT ENTRY POINT for all wiki authoring.**

---

## ⛔ The Pipeline

<EXTREMELY_IMPORTANT>

**Every wiki operation MUST pass through this pipeline. No exceptions.**

```
┌─────────────────────────────────────────────────────────────────┐
│                    WIKI ORCHESTRATOR PIPELINE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. DE-DUPLICATION CHECK                              [WARN]    │
│     └─ Search for existing pages with similar title/topic      │
│                                                                 │
│  2. CONTENT GENERATION                                          │
│     └─ Apply wiki-authoring formatting rules                   │
│                                                                 │
│  3. LINK VERIFICATION                          [HARD GATE] ❌   │
│     └─ Verify ALL hyperlinks (internal wiki = BLOCK on fail)   │
│                                                                 │
│  4. SECRET SCAN                                [HARD GATE] ❌   │
│     └─ Block if credentials detected (see _shared/secret-detection.md) │
│                                                                 │
│  5. SLOP DETECTION                                    [ADVISORY]│
│     └─ Calculate slop score, suggest improvements              │
│                                                                 │
│  6. FACT-CHECK                                        [WARN]    │
│     └─ Count uncited claims, flag for attention                │
│                                                                 │
│  7. PUBLISH                                                     │
│     └─ Push via wiki-editing MCP tools                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Hard Gates (Publishing Blocked If Failed)

| Gate | Failure Condition | Why It Blocks |
|------|-------------------|---------------|
| **Link Verification** | Internal wiki link returns 404 | Readers get broken links |
| **Secret Scan** | Credentials detected in content | Security incident |

### Advisory Gates (Warning, Does Not Block)

| Gate | Condition | Action |
|------|-----------|--------|
| **De-duplication** | Similar page exists | Warn user, suggest update instead |
| **Slop Detection** | High slop score | Show score, suggest improvements |
| **Fact-Check** | Uncited claims found | List claims, suggest sources |

</EXTREMELY_IMPORTANT>

---

## Pipeline Execution

### Stage 1: De-Duplication Check

Before creating ANY new page, use your adapter's search operation:

```
# Use your adapter's search_pages operation
# See skills/wiki/_adapters/{platform}.md for specific tool
```

**If matches found:**
```
⚠️ DUPLICATE CHECK: Similar pages found

| Title | URL | Similarity |
|-------|-----|------------|
| Existing Page Name | /path/to/page | High |

**Options:**
1. Update existing page instead of creating new
2. Proceed with new page (confirm different scope)
3. Cancel and review existing content
```

### Stage 2: Content Generation

Invoke `wiki-authoring` principles:
- No H1 (most platforms show title in UI)
- Semantic headings (H2 → H3 → H4)
- Blank lines around tables, code blocks
- Platform-specific anchor format (see adapter)

### Stage 3: Link Verification

Invoke `link-verification` in batch mode:

**Extract all links from content, verify each:**

| Link Type | Verification Method | On Failure |
|-----------|---------------------|------------|
| Internal wiki links | Adapter's `get_page` | ❌ BLOCK |
| Repository links | Repo adapter verification | ❌ BLOCK |
| Issue tracker links | Issue adapter search | ⚠️ WARN |
| External URLs | `web-fetch` or `curl -I` | ⚠️ WARN |

**Output format:**
```
## Link Verification Report

| Link | Type | Status |
|------|------|--------|
| /path/to/page | Internal | ✅ PASS |
| /path/to/missing | Internal | ❌ FAIL |

**Gate Status:** ❌ BLOCKED (1 broken internal link)
```

### Stage 4: Secret Scan

Apply patterns from `skills/_shared/secret-detection.md`:

**Scan for HIGH-confidence patterns:**
- SQL connection strings (`Server=...;Password=xyz`)
- Database URLs with credentials (`postgres://user:pass@host`)
- Password assignments (`password: secret` or `PASSWORD=xyz`)
- API keys (AWS `AKIA...`, OpenAI `sk-...`, GitHub `ghp_...`, Slack `xoxb-...`)
- Platform-specific tokens (wiki, issue tracker, etc.)

**If detected:**
```
🛑 SECRET DETECTED — Publishing blocked

| Line | Pattern | Match |
|------|---------|-------|
| 47 | SQL Password | Password=j69K... |

**Action Required:** Remove or redact before publishing
```

### Stage 5: Slop Detection

Apply GVR principles from `eliminating-ai-slop`:

**Calculate:**
- Sentence length variance
- Slop phrase count
- Specificity score

**Output:**
```
## Slop Analysis

**Score:** 23/100 (Good)
**Flagged phrases:** 2

| Phrase | Line | Suggestion |
|--------|------|------------|
| "leveraging cutting-edge" | 15 | State specific technology |
| "industry best practices" | 28 | Name the practices |

**Gate Status:** ⚠️ ADVISORY (minor suggestions)
```

### Stage 6: Fact-Check

Invoke `wiki-debunker` analysis:

**Output:**
```
## Fact-Check Summary

**Claims:** 8 total | 6 cited | 2 uncited

**Uncited claims requiring attention:**
1. "We decided to use Telnyx in Q4" — needs ticket/PR reference
2. "Performance improved by 40%" — needs benchmark source

**Gate Status:** ⚠️ WARNING (2 uncited claims)
```

### Stage 7: Publish

If all hard gates pass:

```
# Confirm with user
Ready to publish with warnings:
- 2 uncited claims (advisory)
- 1 slop phrase (advisory)

Proceed? [Y/n]
```

Then invoke `wiki-editing`:
- Use adapter's `update_page` for existing pages
- Use adapter's `create_page` for new pages

---

## Decision Flowchart

```dot
digraph wiki_orchestrator {
    rankdir=TB;
    node [shape=box];

    start [label="User: Create/Update Wiki Page" shape=ellipse];
    dedup [label="1. De-duplication Check"];
    dedup_result [label="Similar page exists?" shape=diamond];
    confirm_new [label="User confirms new page"];
    content [label="2. Generate Content\n(wiki-authoring)"];
    links [label="3. Link Verification"];
    links_fail [label="Internal link broken?" shape=diamond];
    block_links [label="❌ BLOCKED\nFix broken links" shape=box style=filled fillcolor=lightcoral];
    secrets [label="4. Secret Scan"];
    secrets_fail [label="Secrets detected?" shape=diamond];
    block_secrets [label="❌ BLOCKED\nRemove credentials" shape=box style=filled fillcolor=lightcoral];
    slop [label="5. Slop Detection\n(advisory)"];
    facts [label="6. Fact-Check\n(advisory)"];
    summary [label="7. Summary + Confirm"];
    publish [label="8. Publish via MCP"];
    done [label="✅ Published" shape=ellipse];

    start -> dedup;
    dedup -> dedup_result;
    dedup_result -> confirm_new [label="yes"];
    dedup_result -> content [label="no"];
    confirm_new -> content;
    content -> links;
    links -> links_fail;
    links_fail -> block_links [label="yes"];
    links_fail -> secrets [label="no"];
    block_links -> links [label="fixed"];
    secrets -> secrets_fail;
    secrets_fail -> block_secrets [label="yes"];
    secrets_fail -> slop [label="no"];
    block_secrets -> secrets [label="fixed"];
    slop -> facts;
    facts -> summary;
    summary -> publish;
    publish -> done;
}
```

---

## Quick Reference

### Pipeline Summary

| Stage | Skill/Module | Gate | Action on Failure |
|-------|--------------|------|-------------------|
| 1 | De-duplication | WARN | Suggest update instead |
| 2 | wiki-authoring | — | Format guidance |
| 3 | link-verification | **BLOCK** | Fix links |
| 4 | secret-detection | **BLOCK** | Remove secrets |
| 5 | eliminating-ai-slop | ADVISORY | Suggestions |
| 6 | wiki-debunker | WARN | Flag uncited |
| 7 | wiki-editing | — | Publish |

### Commands

```bash
# Full orchestrated workflow (default)
"Create a wiki page about the auth middleware"

# Skip to specific stage (for debugging)
"Verify links in this wiki content"  # link-verification only
"Fact-check this wiki page"          # wiki-debunker only
```

---

## Related Skills

| Skill | Role in Pipeline |
|-------|------------------|
| `wiki-authoring` | Stage 2: Content structure & formatting |
| `link-verification` | Stage 3: URL verification (HARD GATE) |
| `secret-detection` | Stage 4: Credential scanning (HARD GATE) |
| `eliminating-ai-slop` | Stage 5: Prose quality |
| `wiki-debunker` | Stage 6: Fact-checking |
| `wiki-editing` | Stage 7: MCP publish |
| `wiki-verify` | Post-publish: Version drift |

---

## Failure Recovery

### If Context Exhausted Mid-Pipeline

The task list preserves state. Resume by:
1. Check task list for last completed stage
2. Resume from that stage forward
3. Content is NOT lost (still in context or temp file)

### If Hard Gate Blocks

1. Fix the blocking issue (broken link, secret)
2. Re-run from that stage
3. Do NOT skip the gate — it exists for a reason

---

## Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "This is a quick update, skip verification" | Quick updates break links too |
| "I already know the links are correct" | Memory is unreliable, verify anyway |
| "Fact-checking is overkill for this page" | Every page can have hallucinations |
| "The slop score is just advisory" | Advisory means "read it, not ignore it" |
| "I'll verify links after publishing" | That's backwards — verify BEFORE |

**If you think any skill doesn't apply, you're wrong. Run the full pipeline.**
