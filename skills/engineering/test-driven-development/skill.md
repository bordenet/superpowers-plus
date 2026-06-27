---
name: test-driven-development
source: superpowers-plus
augment_menu: true
# Override rationale: Condensed from 371→97 lines. Enforces strict Red→Green→
# Refactor cycle with explicit gates at each phase. Removes language-specific
# examples (handled by golden-agents language modules instead).
aliases: [TDD]
triggers: ["/sp-tdd", "write tests first", "TDD", "test-driven", "write failing test", "red green refactor", "implement with tests"]
anti_triggers: ["fix this bug", "debug this", "unexpected behavior", "error in production"]
description: Use when implementing any feature or bugfix, before writing implementation code
coordination:
  group: engineering
  order: 4
  requires: []
  enables: ["verification-before-completion"]
  escalates_to: []
  internal: false
composition:
  consumes: [goal, task-description]
  produces: [test-suite, implementation]
  capabilities: [generates-tests, enforces-tdd]
  priority: 10
---

# Test-Driven Development (TDD)

## When to Use

- Implementing any feature or bugfix — before writing implementation code
- User says "write tests first," "TDD," or "red green refactor"
- NOT for: debugging existing failures (`systematic-debugging`), reviewing others' code (`providing-code-review`)

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

> **Wrong skill?** Debugging existing failures → `systematic-debugging`. Reviewing others' code → `providing-code-review`.

```text
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over. No exceptions.

## Why Order Matters

RED must come before GREEN. Not as preference — as the entire mechanism.

1. **Test-before defines what the code should do.** Test-after verifies what the code already does. These are not the same thing. Writing tests after implementation is documentation, not TDD.
2. **If you haven't watched the test fail, you don't know it tests what you think.** A test that has never been red may pass because the feature exists, or because it's testing nothing, or because it's testing the wrong thing. You cannot tell. Only a prior red phase tells you.
3. **GREEN without RED is theater.** Any implementation will pass a test you wrote looking at the implementation. The discipline is writing the test before you know how it will be satisfied.
4. **The order is the method.** "I did TDD but in a different order" is not TDD. Skipping RED eliminates the only verification that your test is meaningful.

## Common Rationalizations

| Excuse | Why it's wrong |
|--------|----------------|
| "This code is too simple to need tests" | Simple code breaks too. The test takes 30 seconds. |
| "I'll write tests after to save time" | Tests-after verify what the code does. Tests-first define what it should do. |
| "I already know this works" | You know it works right now. Tests protect against future changes. |
| "Tests would be brittle for this code" | Write better tests. Don't skip them. |
| "The spec changes too often" | Tests catch spec divergence. That's the point. |
| "It's faster without TDD" | It's faster until you spend hours debugging a regression. |
| "I manually tested it" | Manual tests aren't repeatable. Write them down. |
| "TDD doesn't apply to this type of work" | Applies everywhere a future change can break current behavior. |

## Red-Green-Refactor

### RED — Write Failing Test

Write one minimal test showing what should happen. One behavior, clear name, real code (no mocks unless unavoidable).

```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };
  const result = await retryOperation(operation);
  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

### Verify RED — Watch It Fail (MANDATORY)

Run test. Confirm it fails for the expected reason (feature missing, not typo). Test passes? You're testing existing behavior — fix test.

### GREEN — Minimal Code

Write simplest code to pass. Don't add features, refactor, or "improve" beyond the test.

### Verify GREEN (MANDATORY)

Run test. Confirm it passes. Other tests still pass. Output pristine.

### REFACTOR — Clean Up

After green only: remove duplication, improve names, extract helpers. Keep tests green. Don't add behavior.

### Repeat

Next failing test for next feature.

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass, output pristine
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write wished-for API. Write assertion first. |
| Test too complicated | Design too complicated. Simplify interface. |
| Must mock everything | Code too coupled. Use dependency injection. |

## Red Flags — STOP and Start Over

Any of these means you are violating TDD:

- Writing implementation code before any failing test exists
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about the spirit, not the ritual"
- "This is different because..."
- "The test I would write is obvious"
- Reaching for GREEN before confirming RED (test must actually fail first)
- "I'll add tests in the refactor phase"

All of these mean: Delete code. Start over with TDD.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Wrote implementation before test | Delete implementation, write failing test first |
| Test passed immediately (no RED phase) | Test is wrong — it's testing existing behavior, not new behavior |
| Must mock everything to test | Code is too coupled — refactor to use dependency injection |

## Anti-Patterns

When adding mocks or test utilities, read @testing-anti-patterns.md to avoid: testing mock behavior instead of real behavior, adding test-only methods to production classes.

## Companion Skills

- `debate` — when test architecture decisions arise (≥3 approaches to test a complex feature)
- `systematic-debugging` — when tests fail for non-obvious reasons, switch to root-cause investigation
- `verification-before-completion` — after TDD cycle, verify ALL tests pass before claiming done
- **feature-development**: Full feature workflow
- **subagent-driven-development**: TDD within sub-agent tasks
- **quantitative-decision-gate**: Test strategy decisions
