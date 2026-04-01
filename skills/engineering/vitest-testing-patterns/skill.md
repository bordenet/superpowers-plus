---
name: vitest-testing-patterns
source: superpowers-plus
triggers: ["mock this SDK", "vi.mock not working", "test is flaky", "capture event handler", "vitest constructor mock", "timing issue in test"]
anti_triggers: ["jest test", "mocha test", "cypress test"]
description: Use when mocking SDK constructors, when vi.mock() is not working, when tests are flaky or timing-dependent, or when capturing event handlers.
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

## When to Use

Invoke this skill when:

- Mocking SDK constructors (`new SomeClient()`)
- `vi.mock()` is not working as expected
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

---

## Pattern 1: SDK Constructor Mocking

```typescript
// 1. Create typed mock factory
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
  adapter = new AdapterUnderTest()
})
```

**Critical:** Must use `function` keyword (NOT arrow function) — Vitest needs `this` binding.

---

## Pattern 2: Mutable Mock State with vi.hoisted()

```typescript
const { mockEnv } = vi.hoisted(() => {
  return {
    mockEnv: {
      NODE_ENV: 'test' as 'test' | 'prod',
      LOG_LEVEL: 'silent' as const,
    },
  }
})

vi.mock('@/utils/env', () => ({ env: mockEnv }))

it('should behave differently in prod', () => {
  mockEnv.NODE_ENV = 'prod'
  // Test production behavior
})
```

---

## Pattern 3: Event Handler Capture

```typescript
type WebSocketEventHandler = (data: Buffer | Error | number) => void
let eventHandlers: Map<string, WebSocketEventHandler>

beforeEach(() => {
  eventHandlers = new Map()
  mockConnection.on.mockImplementation(
    (event: string, handler: WebSocketEventHandler) => {
      eventHandlers.set(event, handler)
      return mockConnection
    }
  )
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
beforeEach(() => { vi.useFakeTimers() })
afterEach(() => { vi.useRealTimers() })

it('should timeout after configured duration', async () => {
  const promise = adapter.connect({ timeout: 500 })
  vi.advanceTimersByTime(500)
  await expect(promise).rejects.toThrow('timeout')
})
```

---

## Verification

```bash
pnpm test      # All tests pass
pnpm lint      # No lint errors in test files
pnpm typecheck # No type errors in test files
```

Tests are NOT complete until all three pass.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Mock leaks between tests | Flaky suite | vi.restoreAllMocks() in afterEach |
| Async timing issues | Intermittent failures | Use fake timers or vi.advanceTimersByTime |
| Over-mocking | Tests pass but miss real bugs | Mock only external boundaries |
| Missing cleanup | Test pollution | Always restore in afterEach/afterAll |
