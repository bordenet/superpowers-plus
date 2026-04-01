---
name: innovation
source: superpowers-plus
triggers: ["innovate", "innovation mode", "what's the smartest addition", "most impactful thing I could build", "10x this", "what if we started from scratch", "step-change improvement", "what's the boldest move"]
anti_triggers: ["fix this bug", "small refactor", "add this field", "update the docs", "incremental improvement", "quick win", "minor change", "cleanup", "fix our CI", "best practice", "refactor", "moonshot refactor", "reimagine the docs"]
description: "Use when: user wants a single high-conviction innovation answer — the smartest, most radically innovative, accretive, useful, and compelling addition to this project right now. Skip when: incremental ideas (brainstorming), bug fixes (systematic-debugging), implementation planning (plan-and-execute), or ops/repair tasks."
summary: "Use when: single high-conviction innovation answer. Skip when: incremental ideas, bug fixes, or implementation planning."
version: 3.0
coordination:
  group: thinking
  order: 5
  requires: []
  enables: ["brainstorming", "plan-and-execute", "think-twice"]
  escalates_to: []
  internal: false
---

# Innovation

> **Core question:** What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?

That question IS this skill. Everything below exists to answer it well.

**Wrong skill?** Incremental feature ideas → `brainstorming`. Bug fixes → `systematic-debugging`. Cleanup → `engineering-rigor`.

## When to Use

- You want a single high-conviction innovation answer, not a list of options
- The user asks "what's the boldest move", "10x this", or "what if we started from scratch"
- You want to move beyond incremental improvements to identify a step-change

## Example Invocation

```
Innovation mode: I've read the codebase and open issues.
What's the single most impactful addition we could make right now?
```

## How This Works

You are not generating a list. You are not filling out a rubric. You are answering ONE question with genuine depth, conviction, and specificity. The answer must be:

- **Smart** — not obvious; demonstrates understanding of the domain
- **Radically innovative** — 10x, not 10%; changes the category, not just the feature set
- **Accretive** — builds on what exists; amplifies current strengths rather than starting over
- **Useful** — solves a real problem for real users, not technically impressive for its own sake
- **Compelling** — the user reads it and thinks "yes, obviously, why aren't we doing this already?"

## The Process

<HARD-GATE>
Do NOT answer the core question until Phase 2 is complete. Shallow context produces shallow answers. No exceptions.
</HARD-GATE>

### Phase 1: Understand What Exists (mandatory)

Before you can propose what to add, you must deeply understand what's there.

1. **Read the project.** README, package manifests, directory structure, recent commits/issues. Use `codebase-retrieval` aggressively. Spend real time here.
2. **Read the pain.** Open issues, tech debt, user complaints, TODO comments. What's broken? What's slow? What do users work around?
3. **Read the market.** If applicable, invoke `perplexity-research` to understand what competitors and adjacent domains are doing. What's the state of the art?

### Phase 2: Ask the User (mandatory — 3 questions max)

Ask these. One per message.

| # | Question | Why |
|---|----------|-----|
| 1 | **What's the single biggest pain point or missed opportunity you see right now?** | Grounds your answer in their reality, not your assumptions |
| 2 | **Who benefits most from this project, and what do they wish it did?** | Forces user-centric thinking |
| 3 | **What constraints should I respect?** (team size, timeline, tech stack, politics) | Keeps "radical" from becoming "impossible" |

If the user already answered any of these in their prompt, confirm rather than re-ask.

**Fallback for non-answers:** Do not deadlock waiting for answers that aren't coming. One retry per question is the maximum; after that, move on.

| User Response | Action |
|---------------|--------|
| Silence (no reply after retry) | Proceed with Phase 1 context only. State assumptions. |
| "Just answer" / "you decide" | Proceed immediately. State assumptions explicitly. |
| Partial answer | Accept what's given, note what's missing, proceed. |
| Off-topic or echo | Rephrase once. If still off-topic, proceed with Phase 1 context. |
| Contradictory answer | Surface the contradiction, ask to clarify once, then pick the interpretation most consistent with Phase 1 context. |

When proceeding without full Phase 2 input, prefix your answer with: *"Based on Phase 1 research and the following assumptions: [list]. Confidence is lower than it would be with direct user input."*

### Phase 3: Think Deeply, Then Answer

Now answer the core question. ONE answer. Not three. Not five. ONE.

Your answer must include:

1. **The idea** — stated in one clear sentence
2. **Why this, why now** — what makes this the smartest move given everything you learned in Phase 1-2; why it's better than the obvious alternatives
3. **How it's accretive** — specifically what existing strengths, infrastructure, or user behaviors it builds on
4. **What it unlocks** — the second-order effects; what becomes possible once this exists
5. **The hard parts** — honest assessment of risks, unknowns, and what could go wrong
6. **First move** — the concrete thing you'd build THIS WEEK to validate the idea (not a plan; an action)

See `references/output-template.md` for format.

### Phase 4: Offer to Go Deeper

After presenting your answer:

> "Want me to: (a) draft an RFC for this, (b) prototype the first move right now, (c) challenge this idea with `think-twice` to stress-test it, (d) generate alternatives via `brainstorming`, or (e) turn this into a phased execution plan via `plan-and-execute`?"

## Principles

- **One answer, not a menu.** Having conviction is the skill. If you can't pick one, you don't understand the project well enough — go back to Phase 1.
- **Accretive over greenfield.** The best innovations amplify what already works. "Start over" is almost never the answer.
- **Concrete over clever.** If you can't describe the first week of work, the idea isn't real yet.
- **User pain over technical elegance.** The smartest addition solves the problem users actually have, not the one that's most fun to engineer.

## Failure Modes

| Failure | What Went Wrong | Fix |
|---------|----------------|-----|
| Generated a list instead of an answer | Avoided having conviction | Pick one. Justify why it beats the others. |
| Idea is technically impressive but useless | Skipped understanding user pain (Phase 1 step 2) | Go back, read issues and complaints |
| Idea is obvious / incremental | Didn't research the market (Phase 1 step 3) | Invoke `perplexity-research`, look at adjacent domains |
| Idea ignores constraints | Skipped Phase 2 question 3 | Ask about constraints before answering |
| Idea doesn't build on existing strengths | Didn't understand the codebase (Phase 1 step 1) | Read more code, understand the architecture |
| "First move" is actually a 3-month plan | Confused planning with prototyping | Describe what you'd build in ≤5 days |

## Companion Skills

- **brainstorming** — for when the user wants quantity of ideas, not depth on one
- **think-twice** — to stress-test your answer if it feels too easy
- **perplexity-research** — for market/domain context during Phase 1
- **plan-and-execute** — after user approves the idea, to execute on it
