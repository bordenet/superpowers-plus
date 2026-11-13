---
applyTo: "**/*.{js,ts,jsx,tsx}"
---

# JavaScript/TypeScript Coding Conventions

> **Priority**: HIGH - Apply to all JS/TS projects  
> **Source**: genesis, architecture-decision-record, strategic-proposal AGENTS.md

## Code Quality Requirements

- **Linting**: ESLint (9.x flat config preferred)
- **Coverage**: ≥85% minimum, 90%+ target
- **Formatting**: Consistent style enforced by config

## Style Variations

**Note**: Quote style varies by project. Check existing code:

```javascript
// genesis-tools pattern (single quotes)
const message = 'Hello, world';

// Other projects may use double quotes
const message = "Hello, world";
```

Common conventions:
- **Indentation**: 2 spaces
- **Semicolons**: Required
- **Trailing commas**: ES5-compatible (arrays, objects)

## ESLint 9.x Flat Config

```javascript
// eslint.config.js
import js from '@eslint/js';
import globals from 'globals';

export default [
  js.configs.recommended,
  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node }
    },
    rules: {
      'no-unused-vars': 'error',
      'no-console': 'warn'
    }
  },
  {
    // Use a **/ prefix so nested directories match
    ignores: ['**/node_modules/**', '**/dist/**', '**/build/**']
  }
];
```

## Testing Patterns

```javascript
describe('Processor', () => {
  describe('process()', () => {
    it('should handle valid input', () => {
      const result = processor.process('input');
      expect(result).toBe('expected');
    });
    
    it('should throw on invalid input', () => {
      expect(() => processor.process(null)).toThrow();
    });
  });
});
```

## Commands

```bash
# Lint
npm run lint

# Test with coverage
npm test -- --coverage

# Security scan
npm audit
```

## ⚠️ Fix Linting Issues Immediately

NEVER defer linting fixes. Fix them before committing.

---

## UI/Web Application Patterns

> Source: genesis-tools AGENTS.md

### Click handlers

Give each clickable element a working event handler.

```javascript
// ✅ CORRECT - event handler attached
button.addEventListener('click', handleSubmit);

// ❌ WRONG - element exists but does nothing
const button = document.createElement('button');
// No event handler = stillborn element
```

**Before claiming UI work complete:**
1. Click every button - verify response
2. Submit every form - verify processing
3. Check every link - verify navigation

### UI Workflow Principles

1. **Never assume linear behavior** - Users skip steps, go back, refresh
2. **State survives refresh** - Save to storage, restore on load
3. **Errors are visible** - Show user-facing messages, not console.log
4. **Loading states exist** - Show spinners during async operations

### Dark Mode Requirements

For web tools requiring dark mode:

```css
:root {
  --bg-primary: #1a1a2e;
  --text-primary: #eee;
  --accent: #4a90d9;
}

body {
  background: var(--bg-primary);
  color: var(--text-primary);
}
```

### Clipboard Operations Pattern

```javascript
// ✅ CORRECT - throw on error, user sees failure
async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    showNotification('Copied!');
  } catch (err) {
    showNotification('Copy failed - check permissions', 'error');
    throw err; // Don't silently fail
  }
}
```


<!-- golden-agents:generated -->
