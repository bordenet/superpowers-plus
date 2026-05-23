---
name: think-twice
source: superpowers-plus
augment_menu: true
triggers: ["/sp-rethink", "second opinion", "try a different approach", "phone a friend", "fresh sub-agent", "going in circles", "same error keeps happening", "stuck in a loop", "I keep getting the same", "use think-twice", "use think-twice as much as possible", "ask think-twice", "get a fresh perspective"]
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
composition:
  consumes: [challenge, problem-statement]
  produces: [fresh-perspective, decision-record]
  capabilities: [breaks-loops, fresh-analysis]
  priority: 5
---

# Think Twice

> **Wrong skill?** Research a topic → `perplexity-research`. Brainstorm solutions → `brainstorming`. Debug a specific error → `systematic-debugging`.
>
> **Break through blockers by consulting a fresh perspective.**

## How to Ask For It

Tell the user: *"You can invoke think-twice at any time — just say 'use think-twice' or 'get a fresh perspective.' For hard problems, try 'use think-twice as much as possible on this.'"*

You can also suggest it proactively when handing off work: *"This is a tricky one — if I get stuck, I'll automatically invoke think-twice, but you can also request it at any point."*

## When to Use

- You've tried the same approach 3+ times without progress
- You notice yourself using hedging language ("I'm not sure why")
- The same error keeps recurring after attempted fixes
- You catch yourself referencing your own failed output as evidence

## Process

Two invocation paths share steps 1, 3, 4, and 5. They differ only at step 2.

**Path A — Manual (user asked for think-twice or `/sp-rethink`):**

1. **Generate consultation prompt** (see `references/consultation-prompt-template.md`):
   Problem statement, technical context, what was tried + outcomes, exact error messages, minimal code snippet, constraints, specific ask. Must be self-contained, <2000 tokens.

2. **Ask user:** "Want to review the prompt before I dispatch, or send now?"

3. **Dispatch** (in priority order):
   - Sub-agent (`sub-agent-explore`, read-only) — free, instant; always available
   - Perplexity `reason` — only if `THINK_TWICE_USE_PERPLEXITY=true` in `.env` (~$0.01/query); at most 2 Perplexity calls per conversation proceed automatically. **Cap behavior differs by path:** Path A — on call 3 and every subsequent call, inform the user and ask "use Perplexity again?"; if the user says yes, make exactly that one call. The cap is NOT raised — calls 4, 5, … each require their own explicit consent. Path B — on call 3 and beyond, skip Perplexity silently and fall back to sub-agent (do not interrupt the task to ask).
   - Manual fallback — save prompt to file, user pastes into another LLM

4. **Score response:** Relevance (30%) + Novelty (25%) + Specificity (25%) + Feasibility (20%). Report score, key recommendations, suggested next step.

5. **If score <50:** Offer retry with refined prompt (max 1 retry) or proceed with best suggestion.

**Path B — Auto-detected (stuck signals reached threshold):**

Steps 1, 3, 4, 5 are identical. Skip step 2 — dispatch immediately without asking the user to review the prompt first. Announce to the user: "Stuck-signal threshold reached — dispatching think-twice sub-agent."

## Stuck-Signal Auto-Detection (HARD GATE)

> [!IMPORTANT]
> **This is not advisory. It is a mandatory stop.**
>
> Before issuing your next assistant message to the user, score your current session state using the table below. When cumulative score ≥ 7, **invoke think-twice before responding** — even mid-task, even if you think you know what to try next.
>
> **Event-count signals** (same fix, same error, exhaustion) are already quantified by their labels — score them as written. **The hedging pattern signal** (weight 2) applies only if it occurs on at least 2 consecutive turns or 3+ non-consecutive turns in the current conversation — a single hedge on a genuinely uncertain question does not count.

| Signal | Weight |
|--------|--------|
| Same fix tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error 3+ times after fixes | 3 |
| Exhaustion language ("I've tried everything") | 3 |
| Uncertainty hedging pattern — recurring across multiple steps | 2 |
| Approach change without rationale | 2 |

**In-context repetition rule:** If you have scored ≥ 7 on two consecutive turns and the situation has not improved, invoke immediately — the framing itself is stuck.

**When auto-detected, use Path B (defined in Process above).** Do not ask "should I think-twice?" — that IS a stuck behavior. Exception: if the user has explicitly said "skip think-twice" or "don't use think-twice" in the current conversation, honor that override for this turn.

> **Required announcement (Path B only):** Your next message MUST begin with this exact text:
> *"Stuck-signal threshold reached — dispatching think-twice sub-agent."*

**Rationalization traps — these thoughts mean invoke NOW:**
- "I know what's wrong, I just need X" → This IS the circular reasoning signal (score +3).
- "The next attempt will be different" → It won't be without a fresh frame.
- "The user wants me to keep pushing" → They want results. Think-twice produces results.
- "This is a permission/tooling problem, not a reasoning problem" → Tooling blockers frequently ARE reasoning problems in disguise — the framing itself is a stuck signal.

## Escalation Path

| Problem Type | First | Escalate To |
|-------------|-------|-------------|
| Reasoning (logic, approach, design) | `think-twice` | `perplexity-research` |
| Knowledge (API docs, error codes, facts) | `perplexity-research` | `think-twice` for fresh reasoning |
| Both (stuck + need facts) | `think-twice` | `perplexity-research` with refined query |

> ⚠️ **Cost gate:** `perplexity-research` calls a paid API. Before escalating, confirm the knowledge gap cannot be resolved with a web search or by re-reading existing context. If escalating: inform the user a paid API call is being made.

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

All three files exist in the skill directory. Use the Read tool to load each one before executing step 1:

- `references/consultation-prompt-template.md` — Prompt template for consultation prompt generation
- `references/scoring-rubric.md` — Scoring rubric for evaluating the sub-agent response
- `prompts/consultant-persona.md` — Persona prompt for the dispatched sub-agent

## Failure Modes

| Failure | Fix |
|---------|-----|
| Sub-agent inherits same flawed assumptions | Provide raw symptoms only, not prior conclusions |
| Agent ignores stuck signals and keeps looping | Enforce cumulative score threshold — 7+ is mandatory |
| Fresh perspective is too shallow | Sub-agent must produce root-cause hypothesis, not just "try X" |
| Hard gate fires on normal uncertainty (false positive) | User says "skip think-twice" or "don't use think-twice" — the agent must honor this override for the current turn. If false positives are systemic, the threshold may need raising or signal weights recalibrating. |
| Auto-dispatch surprises user mid-task | Announce before dispatching: "Stuck-signal threshold reached — dispatching think-twice sub-agent." |

```bash
# Example: invoke think-twice when stuck
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill think-twice
```

## Acceptance Criteria

These scenarios define correct behavior for this skill:

| Scenario | Expected behavior |
|----------|------------------|
| User invokes `/sp-rethink` | Path A: load refs, generate prompt, ask user before dispatching |
| Agent detects "same fix tried 3+ times" (score = 3) | No invoke — threshold not reached |
| Agent detects "same error 3+ times" + "circular reasoning" (score = 6) | No invoke — threshold not reached |
| Agent detects "same fix 3+ times" + "same error 3+ times" (score = 6) | No invoke — threshold not reached |
| Agent detects "same fix 3+ times" + "circular reasoning" (score = 6) + single hedge | Single hedge does not add to score — no invoke |
| Agent detects "same fix 3+ times" + "circular reasoning" + hedging pattern on 2 consecutive turns (score = 8) | **Invoke, Path B.** First message = announcement text, then dispatch |
| Agent detects exhaustion language + approach-change-without-rationale + uncertainty hedging (score = 7) | **Invoke, Path B.** First message = announcement text |
| User says "skip think-twice" after threshold fires | Honor override for this turn — do not invoke |
| Third Perplexity call attempted via Path A | Block — ask user "use Perplexity again?"; if YES, make exactly that one call. Cap is not raised; call 4 again requires explicit consent |
| Third Perplexity call would fire via Path B (auto-detected) | Skip Perplexity silently; dispatch sub-agent instead — do not interrupt the task |

## Companion Skills

- **perplexity-research**: Escalation target for knowledge problems
- **systematic-debugging**: For specific error debugging
- **brainstorming**: For generating alternative approaches
- **adversarial-search**: Confirmation bias prevention
- **investigation-state**: When investigation hits a wall
- **issue-comment-debunker**: Debunking suspicious issue claims
- **experimental-self-prompting**: Self-directed exploration
- **quantitative-decision-gate**: Quantitative decision-making
- **failure-autopsy**: Post-mortem analysis
- **micro-harsh-review**: Per-batch code review
