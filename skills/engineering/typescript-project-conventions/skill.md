---
name: typescript-project-conventions
source: superpowers-plus
triggers: ["import order wrong", "file too long", "should I use @/ or relative", "Biome import error", "split this file"]
anti_triggers: ["python imports", "go imports", "rust imports"]
description: Use when Biome reports import ordering issues, when files exceed 300 lines, when choosing between relative imports and path aliases, or when writing error handling.
summary: "Use when: working in TypeScript projects. Enforces project conventions."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# typescript-project-conventions

## When to Use

Invoke this skill when:

- Biome reports import ordering issues
- Files exceed 300 lines
- Deciding between relative imports and `@/` path aliases
- Writing error handling code
- Organizing a new TypeScript file

---

## Path Aliases (REQUIRED)

**Always use `@` path aliases — NEVER use relative imports:**

```typescript
// ✅ CORRECT - Path aliases
import { UserService } from '@services/user.service'
import { env } from '@utils/env'
import type { AppContext } from '@types/context'

// ❌ WRONG - Relative imports
import { UserService } from '../../src/services/user.service'
import { env } from '../utils/env'
```

**Common aliases** (configure via `tsconfig.json` paths):
- `@/*` — src/ root
- `@services/*` — src/services/
- `@types/*` — src/types/
- `@utils/*` — src/utils/
- `@test/*` — test/ (tests only)

---

## Import Order (Biome Enforces)

```typescript
// 1. Type imports first
import type { WebhookEvent } from 'external-sdk'
import type { AppContext } from '@types/context'

// 2. Node built-in modules (with node: prefix)
import { Buffer } from 'node:buffer'
import { randomUUID } from 'node:crypto'

// 3. External dependencies
import { WebSocket } from 'ws'
import { S3Client } from '@aws-sdk/client-s3'

// 4. Internal imports (path aliases)
import { UserService } from '@services/user.service'
import { env } from '@utils/env'

// 5. Test imports (tests only)
import { describe, expect, it, vi } from 'vitest'
```

---

## Naming Conventions

```typescript
const conversationHistory = []  // ✅ Descriptive
const convHist = []              // ❌ Abbreviations

function processRequest() {}     // ✅ Verbs
function handleClick() {}        // ✅ handle prefix for events
class ConversationStateService {} // ✅ Descriptive, domain-focused
class StateManager {}             // ❌ Too generic
const MAX_RETRIES = 3             // UPPER_SNAKE_CASE for true constants
```

---

## Error Handling

```typescript
// ✅ Structured error with context
throw new Error(`Failed to process request ${requestId}: ${error.message}`)

// ✅ Try-catch with fallback
try {
  await primaryService.execute(requestId, payload)
} catch (error) {
  logger.error('Primary failed, trying fallback', { requestId, error })
  await fallbackService.execute(requestId, payload)
}

// ❌ Silent failures
try { await operation() } catch { /* Nothing */ }
```

---

## Comment Anti-Patterns (BANNED)

```typescript
// ❌ BAD - References absence (meaningless without history)
// Uses raw types directly - no transforms
// Does not cache results

// ❌ BAD - References historical changes
// Now uses the new API format

// ✅ OK - Explains WHY
// Fetch with 3-second delay to debounce spurious interim results
```

---

## File Size Limits

**Standard:** <300 lines per file
**Exception:** Cohesive state machines (~350 lines acceptable)

If file >300 lines: Refactor into smaller focused files.

---

## Verification

```bash
pnpm typecheck  # No TypeScript errors
pnpm lint       # No Biome errors (import order, etc.)
```

A task is NOT complete until both pass.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Import from wrong path | Module not found | Use configured path aliases |
| File too large | Hard to navigate | Split into focused modules |
| Silent catch blocks | Hidden bugs | Always log or rethrow |
