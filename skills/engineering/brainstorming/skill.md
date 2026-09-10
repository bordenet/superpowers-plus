---
name: brainstorming
source: superpowers-plus
augment_menu: true
# Override rationale: Condensed from 164→96 lines for LLM context efficiency.
# Adds anti_triggers, mandatory announce-at-start, and structured output format.
# Base version is narrative-heavy; this version is procedural and gate-enforced.
# 2026-09: ported the obra/superpowers v6.3.0 spike/bounded/architectural
# three-path router in condensed form — see "Three Paths" below.
triggers: ["/sp-brainstorm", "brainstorm", "design a feature", "build a new", "create a new", "add functionality", "plan a feature", "explore approaches", "design this"]
anti_triggers: ["radical improvement", "10x improvement", "paradigm shift", "moonshot", "step-change", "comparing design options", "choose between design approaches", "three design options", "red-team design approaches", "formally compare approaches"]
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
summary: "Use when: starting creative work. Explores intent and design before implementation."
coordination:
  group: thinking
  order: 1
  requires: []
  enables: ["debate"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  produces: [design-options, risk-surface, brainstorm-output]
  consumes: [task-description, system-context]
  capabilities: [generates-ideas, multi-perspective-ideation]
  priority: 3
  optional: false
  requires_all: false
---

# Brainstorming Ideas Into Designs

## When to Use

- Before any creative work: creating features, building components, adding functionality, or modifying behavior
- User says "design a feature," "build a new," "explore approaches"
- NOT for: bug fixing (`systematic-debugging`), extracting existing knowledge (`expert-interviewer`), choosing between known options (`debate`)

Classify the request first, then work through the matching path below: understand context, refine the idea, present a design, get approval. Ceremony scales with the task; the approval gate never does.

> **Wrong skill?** Bug fixing → `systematic-debugging`. Extracting existing knowledge → `expert-interviewer`. Choosing between known options → `debate`.

### Ensemble Mode (Multi-Perspective)

For broad, ambiguous, or high-impact prompts on the **architectural** path, brainstorming can activate **ensemble mode** — dispatching parallel perspective lenses (Product, Architecture, Reliability, Security, Simplicity, Contrarian) for richer exploration. See `references/ensemble-mode.md` for full protocol.

**Activation:** Apply `skills/_shared/multi-agent-activation-rubric.md`. Score ≥ 6 → ensemble. Score = 5 → ask user. Score < 5 → single-agent (this checklist).
**Cost cap:** 1.5× single-agent tokens. **Max lenses:** 4.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented your intent and the user has approved it. This applies to EVERY path below and EVERY project regardless of perceived simplicity — the ceremony scales, the approval gate never does.
</HARD-GATE>

## Three Paths

Classify before your first question and say the classification out loud —
"this looks bounded, so I'll present a short design here rather than write
a spec" — so the user can override it:

- **Spike** — a feasibility question ("can we...", "is it possible...",
  "quick and dirty is fine") whose output is an answer, not code you keep.
  Present the question and probe plan in 2-3 sentences, get a nod, then
  investigate as cheaply as correctness allows. No design doc, no spec
  file. Report findings as a recommendation; anything you built stays
  labeled throwaway.
- **Bounded** — a well-scoped change to code that already exists in this
  repo: a new flag, a small endpoint, a one-file fix. Understanding the
  kind of app is not enough — bounded means the flow you're changing is
  already here to read. No existing flow to change means the task is
  architectural, not bounded. Ask the clarifying questions that matter,
  present a short design IN CHAT (a few sentences to a few short
  paragraphs), and STOP. No spec file, no plan document — implementation
  starts only after an explicit yes to that design.
- **Architectural** — new projects, new subsystems, changes that
  restructure how components fit together or alter interfaces others
  depend on. Follow the full checklist below: questions, 2-3 approaches,
  sectioned design, written spec, spec review loop, then
  `plan-and-execute`.

When in doubt between two paths, take the heavier one. The ratchet is
one-way: hidden complexity discovered mid-task upgrades the path — stop,
say so, and step up. Nothing downgrades mid-task.

## Checklist (complete in order)

**Spike:**

1. Explore project context — enough to frame the probe
2. Present question + probe plan (2-3 sentences)
3. Get approval — a nod is enough
4. Investigate — as cheaply as correctness allows
5. Report findings — a recommendation; label anything built as throwaway

**Bounded:**

1. Explore project context — check files, docs, recent commits
2. Ask clarifying questions — one at a time, prefer multiple choice
3. Present short design in chat — approach, files touched, testing
4. Get approval — STOP and wait for an explicit yes; presenting the
   design and starting in the same breath skips the gate
5. Implement via the normal development workflow (TDD applies) — no plan
   document

**Architectural:**

1. **Explore project context** — check files, docs, recent commits
2. **Assess scope** — if multiple independent subsystems, decompose first
3. **Ask clarifying questions** — one at a time, prefer multiple choice, understand purpose/constraints/success criteria
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections scaled to complexity, get approval after each section
6. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, commit
7. **Spec review loop** — dispatch spec-document-reviewer subagent; fix issues; max 3 iterations then escalate to human
8. **User reviews written spec** — ask user to review before proceeding
9. **Transition** — invoke `plan-and-execute` skill (or `debate` first if ≥3 viable approaches need formal comparison)

The sections below (**Understanding the Idea** onward) are
architectural-path depth. A spike stops at "present the probe, get a
nod"; bounded work stops at context + a few questions + a short in-chat
design.

## Understanding the Idea

- Check current project state first (files, docs, commits)
- If project too large for single spec, help decompose into sub-projects
- Ask one question per message
- Focus on: purpose, constraints, success criteria

## Exploring Approaches

- Propose 2-3 different approaches with trade-offs
- Lead with your recommendation and explain why

## Presenting the Design

- Scale each section to its complexity
- Ask after each section whether it looks right
- Cover: architecture, components, data flow, error handling, testing
- Design for isolation: smaller units with clear purpose and well-defined interfaces

## Working in Existing Codebases

- Explore current structure before proposing changes — follow existing patterns
- Include targeted improvements for problems affecting the current work
- Don't propose unrelated refactoring

## After the Design (architectural path)

1. Write spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
2. Run spec review loop (subagent reviewer, max 3 iterations)
3. User reviews written spec
4. **If ≥3 viable approaches emerged** — invoke `debate` to formally compare and red-team the already-surfaced approaches (NOT to generate new ones). `debate` expects to be handed the spec written in step 1 rather than re-deriving requirements itself.
5. Invoke `plan-and-execute` skill for implementation plan

## Key Principles

- **One question at a time** — don't overwhelm
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always 2-3 approaches
- **Incremental validation** — present, approve, move on

## Example: Design Spec Output (architectural path)

```markdown
# Design: Feature Name
## Approach: [Selected approach with rationale]
## Components: [Architecture, data flow, interfaces]
## Testing: [Strategy, edge cases]
## Status: Approved → invoke writing-plans
```

## Visual Companion

Offer to render diagrams just-in-time, not upfront. Do not offer at the start of a brainstorm — wait until there is something worth visualizing.

**When to offer:**
- After presenting 3+ options: "Want me to render a comparison diagram?"
- When showing a decision tree or flow: "I can render this as a flowchart if that would help"
- When the user seems to be processing complex relationships — offer once; do not repeat if declined.

**Per-question rule:**
- If the user is in a browser context (Claude.ai, web app): offer SVG/visual rendering
- If the user is in a terminal context (CLI, IDE): offer ASCII diagram or skip the offer

**Never:**
- Offer visual rendering before any ideas have been explored
- Offer repeatedly if the user declines
- Render a diagram without offering first (unless user explicitly asks)

**Fallback:** If visual rendering is unavailable or declined, proceed without it — the brainstorm output is the deliverable, not the diagram.

The skill has a visual-companion.md reference file — use it for the rendering implementation details.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Started coding before design approval | Delete code, restart from checklist step 3 |
| Presented one approach as fait accompli | Back up, generate 2-3 alternatives with trade-offs |
| Skipped spec review loop | Dispatch spec-document-reviewer sub-agent before proceeding |
| Called it "bounded" to skip the design step | Reaching for a label to dodge ceremony IS the doubt — take the heavier path |
| Presented a bounded design and started before hearing yes | The gate is the approval, not the design's length — stop and wait |
| Called it bounded because you know this kind of app | Bounded measures the repo, not your familiarity — no existing flow to change means architectural |
| Kept a spike's throwaway code without re-classifying | A spike's output is an answer; keeping the code is a new request — classify it |
| Task grew mid-implementation, kept going on the old path | Hidden complexity upgrades the path — stop, say so, step up |
