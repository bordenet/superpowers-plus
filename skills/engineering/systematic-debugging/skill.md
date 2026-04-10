---
name: systematic-debugging
source: superpowers-plus
overrides: superpowers/systematic-debugging
# Override rationale: Condensed from 296→88 lines. Focuses on root-cause-first
# discipline with explicit "NO FIXES WITHOUT INVESTIGATION" gate. Removes
# verbose examples; adds structured hypothesis/evidence tracking format.
triggers: ["debug this", "test failure", "unexpected behavior", "build failure", "not working", "investigate error", "root cause"]
anti_triggers: ["write tests first", "TDD", "implement feature", "create new"]
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
coordination:
  group: engineering
  order: 3
  requires: []
  enables: ["investigation-state", "think-twice"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  consumes: [challenge, code-changes]
  produces: [root-cause, investigation-log]
  capabilities: [debugs-issues, analyzes-code]
  priority: 10
---

# Systematic Debugging

## When to Use

- Any bug, test failure, or unexpected behavior — before proposing fixes
- Build failures, runtime errors, or flaky tests
- NOT for: feature design (`brainstorming`), code review (`providing-code-review`)

**Core principle:** ALWAYS find root cause before attempting fixes.

> **Wrong skill?** Feature design → `brainstorming`. Code review → `providing-code-review`.

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## The Four Phases

### Phase 1: Root Cause Investigation

BEFORE attempting ANY fix:

1. **Read Error Messages Carefully** — stack traces completely, note line numbers, file paths, error codes
2. **Reproduce Consistently** — exact steps, every time? If not reproducible, gather more data, don't guess
3. **Check Recent Changes** — git diff, recent commits, new dependencies, config changes
4. **Gather Evidence in Multi-Component Systems** — for each component boundary: log what enters, log what exits, verify env/config propagation. Run once to find WHERE it breaks.
5. **Trace Data Flow** — where does bad value originate? Trace up the call stack to find the source. Fix at source, not symptom. See `root-cause-tracing.md` for complete technique.

### Phase 2: Pattern Analysis

1. **Find working examples** in same codebase — what works that's similar to what's broken?
2. **Compare against references** — read reference implementations COMPLETELY, don't skim
3. **Identify differences** — list every difference, don't assume "that can't matter"
4. **Understand dependencies** — components, settings, config, environment, assumptions

### Phase 3: Hypothesis and Testing

1. **Form single hypothesis** — "I think X is the root cause because Y"
2. **Test minimally** — smallest possible change, one variable at a time
3. **Verify** — worked → Phase 4. Didn't work → new hypothesis, don't stack fixes.

### Phase 4: Implementation

1. **Create failing test case** — use `superpowers:test-driven-development` skill
2. **Implement single fix** — ONE change, no "while I'm here" improvements
3. **Verify** — test passes, no other tests broken
4. **If 3+ fixes failed** — STOP. Question the architecture. Each fix revealing new problems in different places = wrong architecture, not wrong fix. Discuss with human before continuing.

## Red Flags — STOP, Return to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see"
- Proposing solutions before tracing data flow
- "One more fix attempt" after 2+ failures

## Recovery: After 2+ Failed Fix Attempts

When fixes keep failing, the problem is usually misdiagnosed. Don't try a third fix — escalate:

1. **Invoke `think-twice`** — verbalize what you've tried and why each failed
2. **Question the layer** — are you fixing the right component? Check one layer up and one layer down
3. **Check assumptions** — list every assumption you've made. Test the least-certain one first
4. **Ask the human** — "I've tried X and Y, both failed because Z. My current hypothesis is W — does that match your understanding?"

If 3+ fixes in different locations: the architecture is wrong, not your fix. Stop patching and discuss with the human.

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| Wrong layer | Fix works locally but breaks integration | Check one layer up: is the caller sending wrong data? |
| Confirmation bias | Only testing the happy path after fix | Write a test for the original failure case first |
| Environment mismatch | Works on your machine, fails in CI/prod | Compare env vars, dependency versions, OS differences. Don't assume equivalence |

## Supporting Techniques

- `root-cause-tracing.md` — trace bugs backward through call stack
- `defense-in-depth.md` — add validation at multiple layers
- `condition-based-waiting.md` — replace arbitrary timeouts with condition polling

## Companion Skills

- `investigation-state` — persist debugging context across sessions for multi-day bugs
- `think-twice` — dispatch fresh sub-agent when stuck in a hypothesis loop
- `adversarial-search` — search for the WRONG value when symptoms contradict expectations
- **investigation-state**: Complex multi-session debugging
- **adversarial-search**: When debugging hits confirmation bias
- **think-twice**: Escalation when debugging is stuck
- **receiving-code-review**: Responding to review feedback
- **failure-autopsy**: Post-mortem on failed approaches
