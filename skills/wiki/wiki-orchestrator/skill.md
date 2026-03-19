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

## Stage Details

| Stage | Skill | Gate | Notes |
|-------|-------|------|-------|
| 1 | De-duplication | WARN | Search for similar pages; offer update if match |
| 2 | `wiki-authoring` | — | No H1, semantic headings, platform anchors |
| 2.5 | `wiki-content-coherence` | ADVISORY | Jaccard ≥0.40 flags duplication; HIGH → user review |
| 3 | `link-verification` | **BLOCK** | Internal wiki + repo links block on failure |
| 4 | `secret-detection` | **BLOCK** | Block if credentials detected |
| 5 | `eliminating-ai-slop` | ADVISORY | GVR slop scoring |
| 5.5 | `markdown-table-discipline` | ADVISORY | Table format checks |
| 6 | `wiki-debunker` | WARN | Count cited vs uncited claims |
| 7 | `wiki-editing` | — | Confirm with user, then publish via MCP |

> See `references/stage-output-examples.md` for output templates.

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

- [`references/stage-output-examples.md`](references/stage-output-examples.md) — Output templates for all pipeline stages
- [`references/batch-operations.md`](references/batch-operations.md) — Multi-page edit workflow, chunking rules, anti-patterns
