---
name: typescript-strict-mode
source: superpowers-plus
triggers: ["noExplicitAny error", "strictNullChecks", "should I use any here", "non-null assertion", "unknown vs any"]
anti_triggers: ["python type hints", "go types", "rust types"]
description: Use when TypeScript or Biome reports type errors (noExplicitAny, strictNullChecks), when deciding how to handle null or undefined, or when reviewing code with any, !, or unknown.
summary: "Use when: enabling or fixing TypeScript strict mode issues."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# typescript-strict-mode

## Trigger Conditions

Invoke this skill when:

- TypeScript compiler reports `noImplicitAny` or `strictNullChecks` errors
- Biome warns: `noExplicitAny`
- Code review finds `any`, `!`, or `unknown` types
- You are deciding how to type a value or handle nullability

---

## BANNED PATTERNS

### 1. `any` Type (BANNED — No Exceptions)

```typescript
// ❌ NEVER use any
function process(data: any) {
  return data.someProperty
}

// ✅ Use proper types
function process(data: RequestContext) {
  return data.request.requestId
}

// ✅ If type truly unknown, use unknown + narrowing
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'id' in data) {
    return (data as { id: string }).id
  }
  throw new Error('Invalid data shape')
}
```

**Tests follow the same standard. No exceptions.**

---

### 2. Non-Null Assertion `!` (BANNED)

```typescript
// ❌ NEVER use ! assertion
const value = map.get(key)!

// ✅ Handle null explicitly
const value = map.get(key)
if (!value) {
  throw new Error(`Key ${key} not found`)
}

// ✅ Or use nullish coalescing
const value = map.get(key) ?? defaultValue

// ✅ Or early return
const value = map.get(key)
if (!value) return
```

---

### 3. `unknown` Type (AVOID — Use Real Types)

```typescript
// ❌ AVOID unknown (lazy typing)
function handle(event: unknown) { /* guards everywhere */ }

// ✅ Define proper interface
interface WebhookEvent {
  data: {
    event_type: string
    payload: Record<string, unknown>
  }
}
function handle(event: WebhookEvent) { /* type-safe */ }
```

**When `unknown` IS acceptable:**
- Parsing external JSON (before validation)
- Error handling (`catch (error: unknown)`)
- Then immediately narrow or validate

```typescript
try {
  await operation()
} catch (error: unknown) {
  if (error instanceof Error) {
    logger.error('Operation failed', { error: error.message })
  } else {
    logger.error('Unknown error', { error: String(error) })
  }
}
```

---

## Type Safety Best Practices

```typescript
// ✅ Union types for exhaustive matching
type AgentEvent =
  | MessageEvent
  | PauseEvent
  | ContextEvent

// ✅ Type narrowing
if (typeof x === 'string') { /* x is string here */ }

// ✅ Typed collections
Map<RequestId, RequestHandler>
```

---

## When in Doubt

- **NEVER** use `any` to silence TypeScript errors
- **NEVER** use `!` because "I'm sure it exists"
- **INSTEAD** define the interface based on actual data shape

---

## Verification

```bash
pnpm typecheck  # No TypeScript errors
pnpm lint       # No Biome errors (noExplicitAny)
```

A task is NOT complete until both pass.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Suppress with biome-ignore | Type safety lost | Fix actual type issue |
| Type assertion overuse | Fixing strict errors with 'as any' | Use proper type narrowing |
| Ignoring test files | Tests with loose types | Same strict rules for tests |
