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
Try `web-search` + `web-fetch` first. Only escalate if ≥50% worse than expected.
State: "web-search returned [X]. Insufficient because [reason]. Escalating."
Never use Perplexity for: simple lookups, URL checks, basic fact-checking, reading docs.
</EXTREMELY_IMPORTANT>

### Step 1: Announce + Prompt

Announce: research topic, trigger, free tools tried, why escalating.
Prompt: context + specific question + constraints + what you've tried + web-search results.

### Step 2: Dispatch

| Quick fact | `perplexity_search_perplexity` | Deep research | `perplexity_research_perplexity` |
|------------|------|---------------|------|
| How-to | `perplexity_ask_perplexity` | Complex reasoning | `perplexity_reason_perplexity` |

### Step 3: Apply + Evaluate

Report findings → apply (run command/implement fix/test) → evaluate BEFORE recording stats.

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


## "I'm Stuck" Escalation Path

Default order: `think-twice` (free, reasoning) → `perplexity-research` (paid, knowledge).
See `references/escalation.md` for the full decision tree.

## References

- [`references/cost-reference.md`](references/cost-reference.md) — High/low-value use cases, efficiency tactics, cost-conscious decision framework
- [`references/escalation.md`](references/escalation.md) — "I'm stuck" decision tree for think-twice vs perplexity-research

## Companion Skills

- **expert-interviewer**: For structured domain expert interviews
- **incorporating-research**: Merging Perplexity findings into docs
- **think-twice**: When stuck — Perplexity is an escalation target
