---
name: vitest-testing-patterns
source: superpowers-[company]
triggers: ["mock this SDK", "vi.mock not working", "test is flaky", "capture event handler", "vitest constructor mock", "timing issue in test"]
description: Use when mocking SDK constructors, when vi.mock() isn't working, when tests are flaky or timing-dependent, or when capturing event handlers.
summary: "Use when: writing Vitest tests. Enforces testing patterns and conventions."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# vitest-testing-patterns

---

> **Source:** `YourProduct/your-shared-lib/.cursor/rules/testing-standards.mdc`
> **Derived From:** Cursor IDE rules, converted to Claude/Augment superpowers skill
> **Git History:** Commit `5ac4a89` (PR 24021: Refactor YourProduct Shared)

---

## Trigger Conditions

Invoke this skill when:

- Mocking SDK constructors (`new SomeClient()`)
- `vi.mock()` isn't working as expected
- Tests are flaky or timing-dependent
- Capturing event handlers for manual triggering
- Using fake timers (`vi.useFakeTimers()`)
- Writing parameterized tests (`test.each`)
- Testing async operations or race conditions

---

## Code Standards in Tests

**Tests follow THE SAME strict standards as production code.**

```typescript
// ❌ NO 'any' types
let mock: any

// ✅ Define proper types
interface MockConnection {
  send: ReturnType<typeof vi.fn>
  on: ReturnType<typeof vi.fn>
}
let mock: MockConnection
```

```typescript
// ❌ NO '!' non-null assertions
const handler = handlers.get('event')!

// ✅ Proper null checking
const handler = handlers.get('event')
if (!handler) throw new Error('Handler not registered')
handler(data)
```

```typescript
// ❌ NO biome-ignore in tests
// biome-ignore lint/suspicious/noExplicitAny: needed for mock

// ✅ Fix the actual issue with proper typing
interface MockSDK { method: ReturnType<typeof vi.fn> }
let mock: MockSDK
```

---

## Pattern 1: SDK Constructor Mocking

**Challenge:** SDKs use `new Constructor()` which requires special mocking.

```typescript
// 1. Create typed mock factory (in test file, NOT in shared helpers)
function createMockSDKConnection() {
  return {
    send: vi.fn(),
    on: vi.fn(),
    close: vi.fn(),
  }
}

// 2. Module-level variable to control returned instance
let mockConnection: ReturnType<typeof createMockSDKConnection>

// 3. Mock with function keyword (required by Vitest)
vi.mock('external-sdk', () => ({
  SDKClient: vi.fn(function SDKClient() {
    return mockConnection
  }),
}))

// 4. Set instance BEFORE adapter instantiation
beforeEach(() => {
  mockConnection = createMockSDKConnection()
  adapter = new AdapterUnderTest() // Now uses our mock
})
```

**Critical requirements:**
- Must use `function` keyword (NOT arrow function) - Vitest needs `this` binding
- Mock factory in test file (SDK-specific, not generic)
- Set instance in `beforeEach` BEFORE creating adapter
- Module-level variable to control returned instance

---

## Pattern 2: Mutable Mock State with vi.hoisted()

**For mocks that need mutation during tests:**

```typescript
// ✅ CORRECT: Use vi.hoisted() for mutable mock state
const { mockEnv } = vi.hoisted(() => {
  return {
    mockEnv: {
      NODE_ENV: 'test' as 'test' | 'prod',
      LOG_LEVEL: 'silent' as const,
    },
  }
})

vi.mock('@/utils/env', () => ({ env: mockEnv }))

// Now mutate mockEnv in tests:
it('should behave differently in prod', () => {
  mockEnv.NODE_ENV = 'prod'
  // Test production behavior
})
```

---

## Pattern 3: Event Handler Capture

```typescript
// Define specific handler type (NO generic Function)
type WebSocketEventHandler = (data: Buffer | Error | number) => void

let eventHandlers: Map<string, WebSocketEventHandler>

beforeEach(() => {
  eventHandlers = new Map()
  mockConnection.on.mockImplementation((event: string, handler: WebSocketEventHandler) => {
    eventHandlers.set(event, handler)
    return mockConnection
  })
})

it('should handle message event', async () => {
  await adapter.connect()
  const handler = eventHandlers.get('message')
  if (!handler) throw new Error('Message handler not registered')
  handler(Buffer.from('test data'))
  expect(adapter.onMessage).toHaveBeenCalled()
})
```

---

## Pattern 4: Fake Timers

```typescript
beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers() // ALWAYS restore
})

it('should timeout after configured duration', async () => {
  const promise = adapter.connect({ timeout: 500 })
  vi.advanceTimersByTime(500)
  await expect(promise).rejects.toThrow('timeout')
})
```

---

## Quick Reference: More Patterns

See `references/advanced-patterns.md` for:
- Modern Vitest 3+ matchers (`toHaveBeenCalledExactlyOnceWith`, `toBeOneOf`, asymmetric matchers)
- Parameterized tests (`test.each`)
- Async testing (deferred promises)
- Configuration (pool selection, mock management)
- Anti-patterns to avoid

---

## Verification

```bash
pnpm test      # All tests pass
pnpm lint      # No lint errors in test files
pnpm typecheck # No type errors in test files
```

Tests are NOT complete until all three pass.

## When to Use

- Writing or reviewing Vitest test suites
- Setting up test infrastructure for a TypeScript/JavaScript project
- Debugging flaky or failing Vitest tests

## Common Failure Modes

- **Flaky async tests:** Not properly awaiting promises or using incorrect timer mocking
- **Over-mocking:** Mocking so much that tests pass but don't verify real behavior
- **Missing cleanup:** Forgetting afterEach/afterAll cleanup, causing test pollution

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Mock leaks between tests | Flaky suite | vi.restoreAllMocks() in afterEach |
| Async timing issues | Intermittent failures | Use fake timers or vi.advanceTimersByTime |
