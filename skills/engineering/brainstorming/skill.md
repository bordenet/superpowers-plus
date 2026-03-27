---
name: brainstorming
source: superpowers-plus
overrides: superpowers/brainstorming
# Override rationale: Condensed from 164→96 lines for LLM context efficiency.
# Adds anti_triggers, mandatory announce-at-start, and structured output format.
# Base version is narrative-heavy; this version is procedural and gate-enforced.
triggers: ["brainstorm", "design a feature", "build a new", "create a new", "add functionality", "plan a feature", "explore approaches", "design this"]
anti_triggers: ["fix bug", "debug", "write test", "refactor"]
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---

# Brainstorming Ideas Into Designs

## When to Use

- Before any creative work: creating features, building components, adding functionality, or modifying behavior
- User says "design a feature," "build a new," "explore approaches"
- NOT for: bug fixing (`systematic-debugging`), extracting existing knowledge (`expert-interviewer`), choosing between known options (`design-triad`)

Turn ideas into fully formed designs through collaborative dialogue. Understand context, ask questions one at a time, present design, get approval.

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
9. **Transition** — invoke `writing-plans` skill (the ONLY next skill)

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
4. Invoke `writing-plans` skill for implementation plan

## Key Principles

- **One question at a time** — don't overwhelm
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always 2-3 approaches
- **Incremental validation** — present, approve, move on

## Example: Design Spec Output

```markdown
# Design: Retry Logic for API Client
## Approach A (recommended): Exponential backoff with jitter
  - Trade-off: More complex, but prevents thundering herd
## Approach B: Fixed-interval retry
  - Trade-off: Simpler, but causes coordinated retry storms
## Selected: A — backoff with jitter
## Components: RetryPolicy class wrapping HttpClient, configurable max retries
## Testing: Unit tests for retry count, backoff timing, jitter range
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Started coding before design approval | Delete code, restart from checklist step 3 |
| Presented one approach as fait accompli | Back up, generate 2-3 alternatives with trade-offs |
| Skipped spec review loop | Dispatch spec-document-reviewer sub-agent before proceeding |
| Invented requirements not stated by user | Ask: "Is [requirement] important to you?" Don't assume |
| Overdesigned beyond what was asked | Apply YAGNI — cut every feature the user didn't request |
