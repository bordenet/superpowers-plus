---
name: typescript-project-conventions
source: superpowers-plus
triggers: ["import order wrong", "file too long", "should I use @/ or relative", "Biome import error", "split this file"]
description: Use when Biome reports import ordering issues, when files exceed 300 lines, when choosing between relative imports and @/ path aliases, or when writing error handling.
---

# typescript-project-conventions

---

> **Source:** `YourProduct/your-shared-lib/.cursor/rules/code-standards.mdc`
> **Derived From:** Cursor IDE rules, converted to Claude/Augment superpowers skill
> **Git History:** Commits `22b0087` and `5ac4a89` (PR 24021: Refactor YourProduct Shared)

---

## Trigger Conditions

Invoke this skill when:

- Biome reports import ordering issues
- Files exceed 300 lines
- Deciding between relative imports and `@/` path aliases
- Writing error handling code
- Organizing a new TypeScript file
- Starting work in the YourProduct repository

---

## Path Aliases (REQUIRED)

**Always use `@` path aliases - NEVER use relative imports:**

```typescript
// ✅ CORRECT - Path aliases
import { DeepgramSTTAdapter } from '@adapters/stt/deepgram-stt.adapter'
import { env } from '@utils/env'
import type { CallContext } from '@types/call-context'
import { createMockWebSocket } from '@test/helpers/mocks'

// ❌ WRONG - Relative imports
import { DeepgramSTTAdapter } from '../../src/adapters/stt/deepgram-stt.adapter'
import { env } from '../utils/env'
```

**Available aliases:**
- `@/*` - src/ root
- `@adapters/*` - src/adapters/
- `@services/*` - src/services/
- `@types/*` - src/types/
- `@utils/*` - src/utils/
- `@test/*` - test/ (tests only)
- `@test-setup` - vitest.setup.ts (tests only)

---

## Import Order (Biome Enforces)

```typescript
// 1. Type imports first
import type { LiveTranscriptionEvent } from '@deepgram/sdk'
import type { CallContext } from '@types/call-context'

// 2. Node built-in modules (with node: prefix)
import { Buffer } from 'node:buffer'
import { randomUUID } from 'node:crypto'

// 3. External dependencies
import { WebSocket } from 'ws'
import { StandardUnit } from '@aws-sdk/client-cloudwatch'

// 4. Internal imports (path aliases)
import { DeepgramSTTAdapter } from '@adapters/stt/deepgram-stt.adapter'
import { env } from '@utils/env'

// 5. Test imports (tests only)
import { createEventHandlerCapture } from '@test-setup'
import { describe, expect, it, vi } from 'vitest'
```

---

## Directory Structure

```
src/
├── servers/           # Network layer (HTTP, WebSocket servers)
├── orchestration/     # Coordination layer (orchestrators)
├── services/          # Business logic layer (domain services)
├── adapters/          # External API layer (provider implementations)
├── middleware/        # Express middleware
├── types/             # TypeScript type definitions
├── utils/             # Pure functions, stateless helpers
├── webhook-main.ts    # Webhook service entry point
└── media-main.ts      # Media service entry point
```

**Dependency Flow:**
```
Servers → Orchestration → Services → Adapters → Utils
```

Dependencies flow downward only. No circular dependencies.

---

## Naming Conventions

**Variables and Functions:**
```typescript
const conversationHistory = []  // ✅ Descriptive
const convHist = []              // ❌ Abbreviations

function processTranscript() {} // ✅ Verbs
function handleClick() {}       // ✅ handle prefix for events
```

**Classes and Interfaces:**
```typescript
class ConversationStateService {}  // ✅ Descriptive, domain-focused
class StateManager {}               // ❌ Too generic
```

**Constants:**
```typescript
const MAX_RETRIES = 3    // UPPER_SNAKE_CASE for true constants
const config = { ... }   // camelCase for const objects
```

---

## Error Handling

**Structured Errors:**
```typescript
// ✅ Structured error with context
throw new Error(`Failed to synthesize speech for call ${callId}: ${error.message}`)

// ✅ Custom error classes (if needed)
class TTSTimeoutError extends Error {
  constructor(callId: string, duration: number) {
    super(`TTS timeout for ${callId} after ${duration}ms`)
    this.name = 'TTSTimeoutError'
  }
}
```

**Try-Catch:**
```typescript
// ✅ Catch specific errors, handle appropriately
try {
  await ttsService.speak(callId, text)
} catch (error) {
  logger.error('TTS failed, trying fallback', { callId, error })
  await ttsService.speakWithAzure(callId, text)
}

// ❌ Silent failures
try { await operation() } catch { /* Nothing */ }
```

---

## Comment Anti-Patterns (BANNED)

**If the comment wouldn't make sense to someone who never saw the previous version, delete it.**

```typescript
// ❌ BAD - References absence (meaningless without history)
// Uses raw types directly - no transforms
// Does not cache results

// ❌ BAD - References historical changes
// Now uses the new API format
// Simplified from the old nested structure

// ✅ OK - Explains WHY
// Fetch with 3-second delay to debounce spurious interim results
```

---

## Verification

```bash
pnpm typecheck  # No TypeScript errors
pnpm lint       # No Biome errors (import order, etc.)
```

A task is NOT complete until both pass.

