---
name: perplexity-research
source: superpowers-plus
triggers: ["research this", "use perplexity", "I'm stuck", "need to research", "look this up", "stuck:research", "stuck:knowledge"]
anti_triggers: ["incorporate research", "merge research into doc", "add research findings"]
description: Invoke when stuck (2+ failed attempts, uncertainty, or guessing) OR manually to research technical/domain questions via Perplexity MCP. ALWAYS announce invocation and track stats.
summary: "Use when: stuck after 2+ failed attempts or need technical research via Perplexity."
coordination:
  group: stuck-escalation
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Perplexity Research

> **Purpose**: Get unstuck by dispatching research queries to Perplexity AI
> **Trigger**: Automatic (2+ failures, uncertainty) OR manual invocation
> **Cost**: Perplexity API calls are paid — use judiciously

> **Wrong skill?** Incorporating research into existing docs → `incorporating-research`. General reasoning/stuck → `think-twice`. Design exploration → `brainstorming`.


## When to Use

- Research questions requiring current, cited sources
- When web-search returns insufficient or outdated results
- Technical comparisons needing multiple authoritative sources
- When you need citation URLs to verify claims

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

## Invocation Protocol

User can force invocation with: "Use Perplexity to research X", "Get unstuck on X", "Research X via Perplexity".

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

### Step 7: Record Outcome (After Evaluation)

**ONLY after Step 6**, log the research outcome for future reference:

- **Trigger**: What caused the research (failed_attempts, uncertainty, etc.)
- **Tool used**: ask, search, or reason
- **Query summary**: Brief description
- **Outcome**: SUCCESS, PARTIAL, or FAILURE
- **Reason**: Why it helped or didn't

> Record outcomes in conversation context or TODO notes — this helps calibrate when Perplexity is worth the cost.

**The evaluation loop**:
1. Receive Perplexity response → Report (Step 4)
2. Apply the information → Act (Step 5)
3. Evaluate outcome → Judge (Step 6)
4. Record outcome → Track (Step 7)


## Example

```bash
# Invoke Perplexity via API
source ~/.codex/.env
curl -s -H "Authorization: Bearer $PERPLEXITY_API_KEY"   -H "Content-Type: application/json"   -d '{"model":"sonar","messages":[{"role":"user","content":"query"}]}'   https://api.perplexity.ai/chat/completions | jq '.choices[0].message.content'
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Using Perplexity when web-search would suffice — cost waste | Always complete Step 0 (free tools first) and state what they returned |
| Treating Perplexity response as authoritative without cross-verification | Perplexity can hallucinate too — verify key claims against primary sources |
| Not recording outcome, preventing future calibration | Always complete Step 7 (record outcome) even when the answer was unhelpful |
| Prompt too vague — getting generic response | Include context, constraints, what you tried, and what web-search found |

## Skill Connections

- **superpowers:systematic-debugging**: Invoke Perplexity when debugging hits a wall
- **superpowers:brainstorming**: Use for research during design exploration
- **superpowers:verification-before-completion**: Verify facts before claiming done
- **incorporating-research**: Use AFTER Perplexity returns results and user wants to merge findings into an existing document. Handles triage, voice-matching, and artifact stripping.

## Cost Efficiency

> ⚠️ **Perplexity API calls cost real money.** Always try free tools first (Step 0).
> See `references/cost-reference.md` for high/low-value use cases, efficiency tactics, and the full cost-conscious decision framework.

## Key Principles

1. **FREE FIRST** - Always try web-search and web-fetch before Perplexity
2. **ALWAYS announce** - User must know when Perplexity is being consulted
3. **Justify escalation** - State what web-search found and why it's insufficient
4. **Track everything** - Stats enable tuning and improvement
5. **Rich prompts** - Better prompts = better results
6. **Low threshold** - 2 failures is enough; don't struggle unnecessarily
7. **Cost awareness** - Perplexity costs real money; use only when free tools fail

---

## "I'm Stuck" Escalation Path

Default order: `think-twice` (free, reasoning) → `perplexity-research` (paid, knowledge).
See `references/escalation.md` for the full decision tree.

## References

- [`references/cost-reference.md`](references/cost-reference.md) — High/low-value use cases, efficiency tactics, cost-conscious decision framework
- [`references/escalation.md`](references/escalation.md) — "I'm stuck" decision tree for think-twice vs perplexity-research


## Scope Exclusions

- Quick web search → use `web-search` tool directly
- Structured domain interviews → `expert-interviewer`
- Code search → use `codebase-retrieval` tool

## Companion Skills

- **expert-interviewer**: For structured domain expert interviews
- **incorporating-research**: Merging Perplexity findings into docs
- **think-twice**: When stuck — Perplexity is an escalation target
