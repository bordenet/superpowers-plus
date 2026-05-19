---
name: brainstorming
source: superpowers-plus
augment_menu: true
# Override rationale: Condensed from 164→96 lines for LLM context efficiency.
# Adds anti_triggers, mandatory announce-at-start, and structured output format.
# Base version is narrative-heavy; this version is procedural and gate-enforced.
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

Turn ideas into fully formed designs through collaborative dialogue. Understand context, ask questions one at a time, present design, get approval.

> **Wrong skill?** Bug fixing → `systematic-debugging`. Extracting existing knowledge → `expert-interviewer`. Choosing between known options → `debate`.

### Ensemble Mode (Multi-Perspective)

For broad, ambiguous, or high-impact prompts, brainstorming can activate **ensemble mode** — dispatching parallel perspective lenses (Product, Architecture, Reliability, Security, Simplicity, Contrarian) for richer exploration. See `references/ensemble-mode.md` for full protocol.

**Activation:** Apply `skills/_shared/multi-agent-activation-rubric.md`. Score ≥ 6 → ensemble. Score = 5 → ask user. Score < 5 → single-agent (this checklist).
**Cost cap:** 1.5× single-agent tokens. **Max lenses:** 4.

<HARD-GATE>
Do NOT write any code or take implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Checklist (complete in order)

1. **Explore project context** — check files, docs, recent commits
2. **Assess scope** — if multiple independent subsystems, decompose first
3. **Ask clarifying questions** — one at a time, prefer multiple choice, understand purpose/constraints/success criteria
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections scaled to complexity, get approval after each section
6. **Write design doc** — save to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`, commit
7. **Spec review loop** — dispatch spec-document-reviewer subagent; fix issues; max 3 iterations then escalate to human
8. **User reviews written spec** — ask user to review before proceeding
9. **Transition** — invoke `plan-and-execute` skill (or `debate` first if ≥3 viable approaches need formal comparison)

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

## After the Design

1. Write spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
2. Run spec review loop (subagent reviewer, max 3 iterations)
3. User reviews written spec
4. **If ≥3 viable approaches emerged** — invoke `debate` to formally compare and red-team the already-surfaced approaches (NOT to generate new ones)
5. Invoke `plan-and-execute` skill for implementation plan

## Key Principles

- **One question at a time** — don't overwhelm
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always 2-3 approaches
- **Incremental validation** — present, approve, move on

## Example: Design Spec Output

```markdown
# Design: Feature Name
## Approach: [Selected approach with rationale]
## Components: [Architecture, data flow, interfaces]
## Testing: [Strategy, edge cases]
## Status: Approved → invoke writing-plans
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Started coding before design approval | Delete code, restart from checklist step 3 |
| Presented one approach as fait accompli | Back up, generate 2-3 alternatives with trade-offs |
| Skipped spec review loop | Dispatch spec-document-reviewer sub-agent before proceeding |
