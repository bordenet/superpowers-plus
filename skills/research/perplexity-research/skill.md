---
name: perplexity-research
source: superpowers-plus
triggers: ["research this", "use perplexity", "I'm stuck", "need to research", "look this up"]
description: Invoke when stuck (2+ failed attempts, uncertainty, or guessing) OR manually to research technical/domain questions via Perplexity MCP. ALWAYS announce invocation and track stats.
---

# Perplexity Research

> **Purpose**: Get unstuck by dispatching research queries to Perplexity AI
> **Trigger**: Automatic (2+ failures, uncertainty) OR manual invocation
> **Stats**: `~/.codex/perplexity-stats.json`

## When to Invoke (Automatic Triggers)

You MUST invoke this skill when ANY of these conditions are met:

| Trigger | Description |
|---------|-------------|
| **2+ Failed Attempts** | Same operation failed twice with different approaches |
| **Uncertainty/Guessing** | You're unsure and would otherwise guess at an answer |
| **Cutting Corners** | About to do something that violates AGENTS.md guidance |
| **Hallucination Risk** | Making claims about APIs, libraries, or facts you're not certain about |
| **Outdated Knowledge** | Question involves tools/frameworks potentially released after training |
| **Unknown Errors** | Encountering error messages you can't interpret |

**Personal preference matters?** → Ask the user instead
**Broader/extrinsic research needed?** → Invoke this skill

## Manual Invocation

User can always force invocation with:
- "Use Perplexity to research X"
- "Get unstuck on X"  
- "Research X via Perplexity"

## Invocation Protocol

### Step 0: Try Free Tools First (MANDATORY)

<EXTREMELY_IMPORTANT>
**Before ANY Perplexity call, you MUST try free alternatives first.**

1. **Use `web-search`** for the query
2. **Use `web-fetch`** to read any promising URLs
3. **Evaluate**: Did you find what you need? If YES → STOP (no Perplexity needed)
4. **Only escalate** if results are ≥50% worse than expected

**You MUST state explicitly before calling Perplexity:**
> "web-search returned [X]. This is insufficient because [reason]. Escalating to Perplexity."

**Never use Perplexity for:**
- Simple company lookups
- Checking if a URL is live
- Finding a company's website
- Basic fact-checking
- Reading documentation pages
</EXTREMELY_IMPORTANT>

### Step 1: Announce

**ALWAYS** announce before invoking:

```
🔍 **Consulting Perplexity**: [Brief description of what I'm researching]
Reason: [Which trigger condition was met]
Free tools tried: [web-search result summary]
Why escalating: [specific insufficiency]
```

### Step 2: Generate Rich Prompt

Craft a detailed prompt for Perplexity that includes:
- **Context**: What you're trying to accomplish
- **Specific question**: The exact information needed
- **Constraints**: Any requirements (language, version, platform)
- **What you've tried**: Failed approaches (if applicable)
- **What web-search found**: Summary of free tool results

### Step 3: Dispatch to Perplexity

Use the Perplexity MCP tools:

| Query Type | Tool |
|------------|------|
| Quick fact | `perplexity_search_perplexity` |
| How-to question | `perplexity_ask_perplexity` |
| Deep research | `perplexity_research_perplexity` |
| Complex reasoning | `perplexity_reason_perplexity` |

### Step 4: Report Results (Preliminary)

After receiving response, report what you learned:

```
📋 **Perplexity Response**: [Summary of findings]

Key insights:
- [insight 1]
- [insight 2]

**Attempting to apply**: [specific action you'll take based on this]
```

### Step 5: Apply the Information

Actually USE the information from Perplexity:
- Run the suggested command
- Implement the suggested fix
- Apply the recommended approach
- Test the solution

**DO NOT record stats yet.** You must evaluate whether it helped first.

### Step 6: Evaluate Helpfulness (CRITICAL)

After attempting to apply the Perplexity response, explicitly evaluate:

```
📊 **Perplexity Evaluation**:
- Applied: [what you tried]
- Outcome: [SUCCESS | PARTIAL | FAILURE]
- Reason: [why it helped or didn't help]
```

**Evaluation criteria**:

| Outcome | Criteria | Record As |
|---------|----------|-----------|
| **SUCCESS** | Problem solved, unblocked, or gained actionable insight | `successful: true` |
| **PARTIAL** | Some useful info but needed additional work | `successful: true` |
| **FAILURE** | Information was wrong, irrelevant, or didn't help | `successful: false` |

### Step 7: Update Stats (After Evaluation)

**ONLY after Step 6**, use the helper script to update stats:

```bash
~/.codex/perplexity-stats.sh add \
  --trigger=<trigger> \
  --tool=<tool> \
  --query="<brief query summary>" \
  --outcome=<SUCCESS|PARTIAL|FAILURE> \
  --reason="<why it helped or didn't>"
```

**Example:**
```bash
~/.codex/perplexity-stats.sh add \
  --trigger=failed_attempts \
  --tool=ask \
  --query="ESLint 9.x flat config ignore patterns" \
  --outcome=SUCCESS \
  --reason="Fixed the ignore pattern issue"
```

> ⚠️ **DO NOT manually edit `~/.codex/perplexity-stats.json`** - this causes JSON corruption.
> Always use the helper script which handles atomic updates safely.

**The evaluation loop**:
1. Receive Perplexity response → Report (Step 4)
2. Apply the information → Act (Step 5)
3. Evaluate outcome → Judge (Step 6)
4. Record stats → Track (Step 7) via `perplexity-stats.sh add`

## Stats Commands

View stats: `~/.codex/perplexity-stats.sh show`

Reset stats: `~/.codex/perplexity-stats.sh reset`

## Integration with Other Skills

- **superpowers:systematic-debugging**: Invoke Perplexity when debugging hits a wall
- **superpowers:brainstorming**: Use for research during design exploration
- **superpowers:verification-before-completion**: Verify facts before claiming done

## Cost Efficiency (CRITICAL)

> ⚠️ **Perplexity API calls are NOT free.** Use efficiently but DO use when confident it will help.

### High-Value Use Cases (DO use Perplexity)

| Use Case | Why It's Worth It |
|----------|-------------------|
| **Deep research before major feature work** | Prevents costly rework |
| **PRD/design review and refinement** | High-value feedback on architecture |
| **State-of-the-art research in specialized domains** | Training data may be outdated |
| **Validating architectural decisions** | Industry standards evolve |
| **Complex debugging after 2+ failures** | Time saved > API cost |

### Low-Value Use Cases (Use alternatives instead)

| Use Case | Better Alternative |
|----------|-------------------|
| Simple factual lookups | `web-search` tool |
| Code examples | `codebase-retrieval` or documentation |
| General knowledge questions | Rely on training data |
| Iterative refinement | Batch questions into single call |

### Efficiency Tactics

1. **Batch related questions** - Combine multiple questions into one call
2. **Use `strip_thinking: true`** - Reduces token usage for research/reason tools
3. **Choose the right tool**:
   - `perplexity_search_perplexity` - Quick facts (cheapest)
   - `perplexity_ask_perplexity` - How-to questions (moderate)
   - `perplexity_research_perplexity` - Deep dives (expensive)
   - `perplexity_reason_perplexity` - Complex reasoning (most expensive)
4. **Fallback to web-search** - When Perplexity is unavailable or for simple lookups

### Decision Framework (Cost-Conscious)

```
Step 1: Try web-search first (FREE)
├── Found what I need? → STOP (no Perplexity)
└── Insufficient? → Continue

Step 2: Try web-fetch on promising URLs (FREE)
├── Found what I need? → STOP (no Perplexity)
└── Still insufficient? → Continue

Step 3: Evaluate - Is this a high-value use case?
├── NO → Use alternative (codebase-retrieval, training data)
└── YES → State: "web-search returned [X]. Insufficient because [Y]. Escalating."
          └── Use appropriate Perplexity tool
```

### API Unavailability

If Perplexity returns 401/403/5xx errors:
1. **Limit retries to 1** - Preserve time for alternative approaches
2. **Fallback to `web-search`** - Often sufficient for targeted queries
3. **Use `web-fetch`** - To get full content from authoritative sources
4. **Inform user** - "Perplexity unavailable, using web search fallback"

## Key Principles

1. **FREE FIRST** - Always try web-search and web-fetch before Perplexity
2. **ALWAYS announce** - User must know when Perplexity is being consulted
3. **Justify escalation** - State what web-search found and why it's insufficient
4. **Track everything** - Stats enable tuning and improvement
5. **Rich prompts** - Better prompts = better results
6. **Broad scope** - Technical AND domain questions are valid
7. **Low threshold** - 2 failures is enough; don't struggle unnecessarily
8. **Cost awareness** - Perplexity costs real money; use only when free tools fail

