# JavaScript/TypeScript Coding Conventions

> **Priority**: HIGH - Apply to all JS/TS projects  
> **Source**: genesis, architecture-decision-record, strategic-proposal Agents.md

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
    // CRITICAL: Use **/ prefix for nested directories
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

