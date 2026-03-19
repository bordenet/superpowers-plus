---
name: wiki-orchestrator
source: superpowers-plus
triggers: ["create wiki page", "update wiki", "document X in wiki", "write wiki documentation for", "publish to wiki", "wiki:create", "wiki:update", "wiki:publish", "cross-reference wiki", "bulk wiki update", "update all wiki pages", "add links across wiki"]
description: Use when creating or updating wiki pages — the default entry point for all wiki authoring. Automatically invokes de-duplication, link-verification, secret-scan, slop-detection, and fact-check as mandatory pipeline stages.
coordination:
  group: wiki-pipeline
  order: 1
  requires: []
  enables: ["link-verification", "wiki-editing"]
  escalates_to: []
  internal: false
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
│  2.5 CONTENT COHERENCE                             [ADVISORY]   │
│     └─ Detect intra-page duplication & structural defects      │
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
| **Content Coherence** | Duplicate sections or structural defects | Show report; HIGH severity → user review |
| **Slop Detection** | High slop score | Show score, suggest improvements |
| **Table Discipline** | Malformed or misused tables | Show violations, suggest fix |
| **Fact-Check** | Uncited claims found | List claims, suggest sources |

</EXTREMELY_IMPORTANT>

---

## Pipeline Execution

### Stage 1: De-Duplication Check

Search for existing pages with similar title/topic using adapter's search operation. If matches found, offer: update existing, proceed with new (confirm different scope), or cancel.

### Stage 2: Content Generation

Invoke `wiki-authoring`: no H1, semantic headings, blank lines around tables/code, platform-specific anchors.

### Stage 2.5: Content Coherence

Invoke `wiki-content-coherence` — TF-IDF fingerprints, Jaccard similarity ≥ 0.40 flags duplicates, checks heading nesting. HIGH severity → user review before continuing.

### Stage 3: Link Verification (HARD GATE)

Extract all links, verify each. Internal wiki + repo links → **BLOCK** on failure. Issue tracker + external → WARN.

### Stage 4: Secret Scan (HARD GATE)

Apply `skills/_shared/secret-detection.md` patterns. **BLOCK if detected.**

### Stage 5: Slop Detection (Advisory)

Apply GVR from `eliminating-ai-slop`. Advisory only.

### Stage 6: Fact-Check (Advisory)

Invoke `wiki-debunker`. Count cited vs uncited claims.

### Stage 7: Publish

Confirm with user (show advisory warnings), then invoke `wiki-editing`.

> See `references/stage-output-examples.md` for output templates for all stages.

---

## Decision Flowchart

See `references/decision-flowchart.md` for the full Graphviz DOT diagram showing the pipeline flow with decision points and blocking gates.

---

## Quick Reference

### Pipeline Summary

| Stage | Skill/Module | Gate | Action on Failure |
|-------|--------------|------|-------------------|
| 1 | De-duplication | WARN | Suggest update instead |
| 2 | wiki-authoring | — | Format guidance |
| 2.5 | wiki-content-coherence | ADVISORY | Show report; HIGH → user review |
| 3 | link-verification | **BLOCK** | Fix links |
| 4 | secret-detection | **BLOCK** | Remove secrets |
| 5 | eliminating-ai-slop | ADVISORY | Suggestions |
| 5.5 | markdown-table-discipline | ADVISORY | Fix tables |
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
| `wiki-content-coherence` | Stage 2.5: Duplication & structural defect detection |
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

## Batch Operations (Multi-Page Edits)

**When editing 3+ wiki pages in one task**, use the batch workflow (Discover → Plan → Execute in chunks → Verify). See `references/batch-operations.md` for the full workflow, key rules, and anti-patterns.

**Critical rule:** Always fetch FRESH content before editing — local sync is for discovery only.

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

## Reference Files

- [`references/stage-output-examples.md`](references/stage-output-examples.md) — Output templates for link verification, secret scan, slop detection, fact-check, and publish stages
- [`references/decision-flowchart.md`](references/decision-flowchart.md) — Graphviz DOT diagram of the full pipeline flow
- [`references/batch-operations.md`](references/batch-operations.md) — Multi-page edit workflow (Discover/Plan/Execute/Verify), chunking rules, anti-patterns
