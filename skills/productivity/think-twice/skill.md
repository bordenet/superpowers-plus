---
name: think-twice
source: superpowers-plus
triggers: ["second opinion", "try a different approach", "phone a friend", "fresh sub-agent", "going in circles", "same error keeps happening", "stuck in a loop", "I keep getting the same"]
anti_triggers: ["use perplexity", "research this", "Perplexity API"]
description: Helps the AI coding assistant break out of spirals and stuck loops. Routed to by thinking-orchestrator for stuck-loop and circular-reasoning triggers. When triggered (by user or self-detection), pauses to consult a fresh sub-agent with zero shared context.
summary: "Use when: stuck in a loop, circular reasoning, or same error 3+ times."
coordination:
  group: stuck-escalation
  order: 1
  requires: []
  enables: []
  escalates_to: ["perplexity-research"]
  internal: false
---

# Think Twice

> **Break through blockers by consulting a fresh perspective.**

## Process

1. **Generate consultation prompt** (see `references/consultation-prompt-template.md`):
   Problem statement, technical context, what was tried + outcomes, exact error messages, minimal code snippet, constraints, specific ask. Must be self-contained, <2000 tokens.

2. **Ask user:** "Want to review the prompt before I dispatch, or send now?"

3. **Dispatch** (in priority order):
   - Sub-agent (`sub-agent-explore`) — free, instant
   - Perplexity `reason` — only if `THINK_TWICE_USE_PERPLEXITY=true` in `.env` (~$0.01/query)
   - Manual fallback — save prompt to file, user pastes into another LLM

4. **Score response:** Relevance (30%) + Novelty (25%) + Specificity (25%) + Feasibility (20%). Report score, key recommendations, suggested next step.

5. **If score <50:** Offer retry with refined prompt (max 1 retry) or proceed with best suggestion.

## Escalation Path

**Reasoning problem** (logic, approach, design) → think-twice first → escalate to perplexity-research.
**Knowledge problem** (API docs, error codes, facts) → perplexity-research first → think-twice for fresh reasoning.

## References

- `references/consultation-prompt-template.md` — Prompt template
- `references/scoring-rubric.md` — Scoring dimensions
- `prompts/consultant-persona.md` — Sub-agent persona


## When to Use

- When cumulative stuck-signal score reaches 7+ (see auto-detection table)
- When the same fix has been tried 3+ times without resolution
- When the agent says "I've tried everything" or "I'm not sure why"
- When user says: "think twice", "get unstuck", "fresh eyes", "phone a friend"

## Failure Modes

| Failure | Fix |
|---------|-----|
| Sub-agent inherits same flawed assumptions | Provide raw symptoms only, not prior conclusions |
| Agent ignores stuck signals and keeps looping | Enforce cumulative score threshold — 7+ is mandatory |
| Fresh perspective is too shallow | Sub-agent must produce root-cause hypothesis, not just "try X" |

```bash
# Example: invoke think-twice when stuck
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill think-twice
```
