---
name: typescript-strict-mode
source: superpowers-plus
triggers: ["noExplicitAny error", "strictNullChecks", "should I use any here", "non-null assertion", "unknown vs any"]
description: Use when TypeScript/Biome reports type errors (noExplicitAny, strictNullChecks), when deciding how to handle null/undefined, or when reviewing code with any, !, or unknown.
---

# typescript-strict-mode

---

> **Source:** `YourProduct/your-shared-lib/.cursor/rules/code-standards.mdc`
> **Derived From:** Cursor IDE rules, converted to Claude/Augment superpowers skill
> **Git History:** Commits `22b0087` and `5ac4a89` (PR 24021: Refactor YourProduct Shared)

---

## Trigger Conditions

Invoke this skill when:

- TypeScript compiler reports `noImplicitAny` or `strictNullChecks` errors
- Biome warns: `noExplicitAny`
- Code review finds `any`, `!`, or `unknown` types
- You're deciding how to type a value or handle nullability
- Error message contains "Type 'any' is not assignable"

---

## ⛔ BANNED PATTERNS

### 1. `any` Type (BANNED - No Exceptions)

```typescript
// ❌ NEVER use any
function process(data: any) {
  return data.someProperty // No type safety
}

// ✅ Use proper types
function process(data: CallContext) {
  return data.call.callId // Type-safe
}

// ✅ If type truly unknown, use unknown + narrowing
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'callId' in data) {
    return (data as { callId: string }).callId
  }
  throw new Error('Invalid data shape')
}
```

**Why banned:**
- Defeats TypeScript's purpose
- Hides bugs at compile time
- Makes refactoring dangerous
- No IDE autocomplete

**Tests follow the same standard. No exceptions.**

---

### 2. Non-Null Assertion `!` (BANNED)

```typescript
// ❌ NEVER use ! assertion
const value = map.get(key)!  // Assumes exists, crashes if not

// ✅ Handle null explicitly
const value = map.get(key)
if (!value) {
  throw new Error(`Key ${key} not found`)
}
// Now value is narrowed to non-null

// ✅ Or use nullish coalescing
const value = map.get(key) ?? defaultValue

// ✅ Or early return
const value = map.get(key)
if (!value) return
// Now TypeScript knows value is defined
```

**Why banned:**
- Crashes at runtime if assumption wrong
- Hides potential bugs
- Makes code brittle

---

### 3. `unknown` Type (AVOID - Use Real Types)

```typescript
// ❌ AVOID unknown (lazy typing)
function handle(event: unknown) {
  // Requires type guards everywhere
}

// ✅ Define proper interface
interface TelnyxWebhookEvent {
  data: {
    event_type: string
    payload: { /* ... */ }
  }
}

function handle(event: TelnyxWebhookEvent) {
  // Type-safe, no guards needed
}
```

**When `unknown` IS acceptable:**
- Parsing external JSON (before validation)
- Error handling (`catch (error: unknown)`)
- Then immediately narrow or validate

```typescript
try {
  await operation()
} catch (error: unknown) {
  // Narrow immediately
  if (error instanceof Error) {
    logger.error('Operation failed', { error: error.message })
  } else {
    logger.error('Unknown error', { error: String(error) })
  }
}
```

---

## Type Safety Best Practices

**Define interfaces for everything:**

```typescript
// ✅ Gold standard - union types for exhaustive matching
type AgentApiEvent =
  | AgentApiMessageEvent
  | AgentApiPauseEvent
  | AgentApiContextEvent

// TypeScript ensures all cases handled, no runtime surprises
```

**Use TypeScript features:**

```typescript
// Type narrowing
if (typeof x === 'string') { /* x is string here */ }

// Union types
type Status = 'pending' | 'active' | 'completed'

// Generics
Map<CallId, CallOrchestrator>
```

---

## When in Doubt

**NEVER:**
- Use `any` to make TypeScript errors go away
- Use `!` because "I'm sure it exists"
- Use `unknown` instead of defining proper interface

**INSTEAD:**
- Ask team: "What should this type be?"
- Add proper null check or refactor
- Define the interface based on actual data shape

---

## Verification

```bash
pnpm typecheck  # No TypeScript errors
pnpm lint       # No Biome errors (noExplicitAny)
```

A task is NOT complete until both pass.

