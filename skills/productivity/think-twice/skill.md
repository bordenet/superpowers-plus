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

> **Wrong skill?** Research a topic → `perplexity-research`. Brainstorm solutions → `brainstorming`. Debug a specific error → `systematic-debugging`.

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

## Stuck-Signal Auto-Detection

Continuously monitor for these signals. When cumulative score ≥ 7, invoke think-twice **automatically**:

| Signal | Weight |
|--------|--------|
| Same fix tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error 3+ times after fixes | 3 |
| Exhaustion language ("I've tried everything") | 3 |
| Uncertainty hedging ("I'm not sure why") | 2 |
| Approach change without rationale | 2 |

## Escalation Path

| Problem Type | First | Escalate To |
|-------------|-------|-------------|
| Reasoning (logic, approach, design) | `think-twice` | `perplexity-research` |
| Knowledge (API docs, error codes, facts) | `perplexity-research` | `think-twice` for fresh reasoning |
| Both (stuck + need facts) | `think-twice` | `perplexity-research` with refined query |

## Consultation Prompt Quality

The prompt sent to the sub-agent determines outcome quality. MUST include:

| Element | Required? | Why |
|---------|-----------|-----|
| Problem statement | ✅ | What's broken or stuck |
| Technical context | ✅ | Stack, versions, constraints |
| What was tried + outcomes | ✅ | Prevents re-trying failed approaches |
| Exact error messages | ✅ | Enables pattern matching |
| Minimal code snippet | ✅ | Concrete not abstract |
| Constraints | ✅ | What CAN'T change |
| Specific ask | ✅ | "What else could cause X?" not "help" |

**Total:** <2000 tokens. Self-contained. No references to "above" or "earlier."

## References

- `references/consultation-prompt-template.md` — Prompt template
- `references/scoring-rubric.md` — Scoring dimensions
- `prompts/consultant-persona.md` — Sub-agent persona

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


## Scope Exclusions

- Specific bug investigation → `systematic-debugging`
- Creative ideation → `brainstorming`
- Design evaluation → `design-triad`

## Companion Skills

- **perplexity-research**: Escalation target for knowledge problems
- **systematic-debugging**: For specific error debugging
- **brainstorming**: For generating alternative approaches
