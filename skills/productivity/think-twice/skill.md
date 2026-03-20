---
name: think-twice
source: superpowers-plus
triggers: ["think twice", "you're stuck", "you're looping", "you're going in circles", "stuck in a loop", "spiraling", "stop and think", "fresh perspective", "second opinion", "try a different approach", "stuck:reasoning", "stuck:perspective"]
description: Helps the AI coding assistant break out of spirals and stuck loops. Auto-detects circular reasoning, repeated failures, or exhaustion signals. When triggered (by user or self-detection), pauses to consult a fresh sub-agent with zero shared context.
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

## Reference Files

- `references/consultation-prompt-template.md` — Prompt template
- `references/scoring-rubric.md` — Scoring dimensions
- `prompts/consultant-persona.md` — Sub-agent persona
