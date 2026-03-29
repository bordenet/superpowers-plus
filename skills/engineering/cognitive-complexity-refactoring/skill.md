---
name: cognitive-complexity-refactoring
source: superpowers-plus
triggers: ["cognitive complexity too high", "too many nested ifs", "refactor this function", "Biome complexity error", "simplify this logic"]
anti_triggers: ["add biome-ignore", "suppress lint warning"]
description: Use when Biome reports noExcessiveCognitiveComplexity, when functions have deeply nested conditionals (3+ levels), or when refactoring large functions.
summary: "Use when: Biome reports noExcessiveCognitiveComplexity or functions have 3+ nesting levels."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# cognitive-complexity-refactoring

## Trigger Conditions

Invoke this skill when:

- Biome reports: `noExcessiveCognitiveComplexity`
- Function has 3+ levels of nesting
- You're reviewing a function >30 lines
- Code has multiple nested if/else chains
- You need to simplify complex logic

---

## CRITICAL RULE: NO biome-ignore

**`biome-ignore` comments are BANNED in new code.**

When Biome reports an error:

1. **REQUIRED:** Refactor the code to fix the actual issue
2. **REQUIRED:** Extract functions, simplify logic, reduce nesting
3. **BANNED:** Adding `// biome-ignore` to suppress the warning

```typescript
// ❌ NEVER DO THIS
// biome-ignore lint/complexity/noExcessiveCognitiveComplexity: complex
function handleMessage(data: Buffer): void {
  // 25 lines of nested if/else statements
}

// ✅ ALWAYS DO THIS - Extract to smaller functions
function handleMessage(data: Buffer): void {
  const message = parseMessage(data)
  if (message.type === 'partial') {
    handlePartialResult(message)
  } else if (message.type === 'final') {
    handleFinalResult(message)
  }
}

function handlePartialResult(message: Message): void {
  if (!message.text) return
  const event = createResultEvent(message, false)
  emitResult(event)
}
```

---

## What is Cognitive Complexity?

**Measures how hard a function is to understand.**

Calculates based on:

- Nesting depth (each level adds complexity)
- Control flow structures (if, for, while, switch)
- Logical operators (&&, ||)
- Recursion

**Threshold:** Maximum 15 (configured in biome.json)

---

## Refactoring Patterns

### Pattern 1: Extract Nested Logic

```typescript
// ✅ Complexity reduced by extraction
function processCoordinates() {
  for (let x = 0; x < 10; x++) {
    for (let y = 0; y < 10; y++) {
      processPoint(x, y)
    }
  }
}

function processPoint(x: number, y: number) {
  if (x % 2 !== 0) return
  if (y % 2 !== 0) return
  const max = x > y ? x : y
  console.log(max)
}
```

### Pattern 2: Early Returns

```typescript
// ✅ Complexity: 3
function validate(data: Data | null): boolean {
  if (!data) return false
  if (!data.isValid) return false
  if (!data.hasRequiredFields()) return false
  return true
}

// vs ❌ Complexity: 6
function validate(data: Data | null): boolean {
  if (data) {
    if (data.isValid) {
      if (data.hasRequiredFields()) {
        return true
      }
    }
  }
  return false
}
```

### Pattern 3: Extract Conditions

```typescript
// ✅ Reduce nesting
const canProcess = isActive && hasPermission && !isBlocked
if (!canProcess) return
processItem()

// vs ❌ Nested ifs
if (isActive) {
  if (hasPermission) {
    if (!isBlocked) {
      processItem()
    }
  }
}
```

---

## File Size Limits

**Standard:** <300 lines per file
**Exception:** Cohesive state machines (~350 lines acceptable)

If file >300 lines: Refactor into smaller focused files.

---

## Verification

```bash
pnpm lint  # No Biome complexity warnings
```

A task is NOT complete until this passes.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Over-refactor | New bugs introduced | Run tests after each extraction |
| Wrong extraction boundary | Makes code harder to follow | Keep related logic together |
| Extracting too aggressively | Many tiny functions obscure flow | Balance complexity score with readability |
