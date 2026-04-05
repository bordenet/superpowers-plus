---
name: expert-interviewer
source: superpowers-plus
triggers: ["help me document", "capture what I know", "write up the problem space", "I need to explain this to the team", "domain interview"]
anti_triggers: ["design a feature", "build a component", "implement", "brainstorm approaches", "write code", "interview me about", "knowledge capture"]
description: "Use when extracting domain knowledge from a user through structured interviewing to produce a written artifact (wiki page, reference doc, problem space overview). NOT for feature design — use brainstorming for that."
coordination:
  group: research
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [challenge, domain-context]
  produces: [domain-knowledge, interview-artifact]
  capabilities: [extracts-knowledge, structures-interviews]
  priority: 10
---

# Expert Interviewer

Extract domain knowledge through structured questioning. Produce a reviewed, published artifact.

This is NOT brainstorming. Brainstorming explores design alternatives. Expert-interviewing extracts and organizes existing knowledge. Different failure modes, different process.

## When to Use

- Extracting domain knowledge from a subject matter expert
- Producing a wiki page, reference doc, or problem space overview from an interview
- Capturing institutional knowledge before a team member transitions out
- Documenting a domain you understand too shallowly to write about without expert input

<HARD-GATE>
Do NOT draft the artifact until Phase 4 (transition) criteria are met. Do NOT publish until the review pipeline (Phase 5) completes. No exceptions.
</HARD-GATE>

## Checklist (complete in order)

1. **Frame-setting** — 3 mandatory questions (Phase 1)
2. **Research integration** — as user provides external input (Phase 2)
3. **Domain interviewing** — 7-12 questions with synthesis checkpoint (Phase 3)
4. **Transition check** — confirm saturation before drafting (Phase 4)
5. **Draft + review pipeline** — write, review, revise, user approval (Phase 5)
6. **Publish** — save to target location (Phase 6)

## Phase 1: Frame-Setting (Non-Negotiable)

Before ANY domain questions, ask these three. One per message.

| # | Question | Prevents |
|---|----------|----------|
| F1 | **Who is the audience?** (product team, new hires, leadership, external) | Wrong depth/tone |
| F2 | **Who is the "customer" or primary stakeholder in this domain?** | Framing from wrong perspective |
| F3 | **What's the output?** (problem space overview, reference doc, decision record, training material) + what's explicitly in/out of scope | Scope drift, artifact mismatch |

If the user answered any of these before you ask (e.g., in their opening message), confirm rather than re-ask.

## Phase 2: Research Integration

When user provides external research (Perplexity output, articles, internal docs):

1. **Label it:** "Noting this as research on [topic]."
2. **Don't re-ask what it covers.** Focus questions on gaps.
3. **After 2-3 research blocks:** Synthesis checkpoint — "Here's what the research tells us: [bullets]. Does this match your experience?"
4. **During questions:** Reference it — "The research says X. Is that accurate in your context?"

Research is input to the mental model. The interview fills gaps research can't: institutional knowledge, priorities, edge cases, constraints.

## Phase 3: Domain Interviewing (7-12 questions)

- **One question per message.** Multiple choice preferred.
- **Reference prior answers:** "You said X. Building on that..."
- **State assumptions explicitly:** "I'm assuming Y because you said Z. Correct?"
- **Ask for examples and scenarios,** not abstractions.
- **After each answer,** summarize what you learned in 1-2 sentences.

### Mandatory Synthesis Checkpoint (Q7-8)

> "Before we go deeper, here's my understanding so far: [3-5 bullet summary]. Am I on the right track? What am I missing? What have I gotten wrong?"

This catches framing errors and scope drift while there's time to correct.

### Depth vs. Breadth Guard

After Q5, map remaining territory: "I see we're deep in [topic A]. What other major areas should we cover?" Allocate remaining questions across areas.

### Anti-Patterns

- **Interviewer bias:** After Q5, ask "What am I missing?" or "What would someone who disagrees say?"
- **Jargon trap:** When user introduces unfamiliar term, ask "How would you explain [term] to someone outside the domain?"
- **Re-asking answered questions:** If research or a prior answer covered it, don't ask again.

## Phase 4: Transition (When to Stop)

Stop interviewing when ALL of these are true:

1. You've covered the 5-7 core concepts/workflows
2. Last 2-3 questions produced no new information (saturation)
3. User confirmed the synthesis checkpoint ("yes, that's it" — not "mostly")
4. User hasn't added new scope in the last 3 questions
5. You can describe the output structure and user agrees

**Hard stop at Q15.** Transition to drafting regardless. You can interview more after user reviews the draft.

## Phase 5: Draft + Mandatory Review Pipeline

This pipeline is AUTOMATIC. Do not ask the user whether to run reviews.

```
1. [AGENT] Write tight first draft
   - Structure based on artifact frame (F3)
   - Every claim traceable to interview or research
   - Scope boundaries stated explicitly
   - Qualify inferences: "varies by [context]" not stated as universal fact

2. [AUTOMATED] Dispatch content-reviewer sub-agent
   Reviewer checks:
   - Scope discipline (flag sections with no interview/research source)
   - Verbosity (claims without supporting evidence from interview)
   - Overstated claims (stated as fact without qualification)
   - Internal consistency (constraints applied uniformly across sections)
   - Audience fit (tone and depth match F1)
   Max 2 revision cycles, then surface issues to human.

3. [USER] Final review before publish
   Structured prompt:
   "Draft is ready. Before I publish:
    - Does the framing match your intent?
    - What's missing?
    - What's overstated?"
   Wait for approval. Do not publish without it.
```

## Phase 6: Publish

Save to the location specified in F3. If wiki: create in specified collection/parent. If local: save to `docs/` with descriptive naming.

## Key Differences from Brainstorming

| Dimension | Brainstorming | Expert-Interviewer |
|---|---|---|
| Goal | Design a solution | Extract and organize knowledge |
| External research | Minor input | Major input alongside interview |
| Review focus | Design soundness, YAGNI | Factual accuracy, scope discipline, audience fit |
| Output | Design spec → implementation plan | Knowledge artifact → publish |
| Terminal state | `writing-plans` skill | Publish artifact |
