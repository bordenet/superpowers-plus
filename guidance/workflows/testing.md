# Testing Standards

> **Priority**: HIGH - Apply to all code changes  
> **Source**: genesis, pr-faq-validator, bloginator, scripts Agents.md

## Coverage Requirements by Language

| Language | Minimum Coverage | Target |
|----------|-----------------|--------|
| Go | 80% | 85%+ |
| JavaScript | 85% | 90%+ |
| Python | 50% | 70%+ |
| Shell | N/A (validation) | 100% functions tested |

## Pre-Commit Validation Checklist

Before committing, verify:

1. **VERIFY STYLE_GUIDE.md compliance** - DO THIS FIRST
2. **Lint the code** - No errors allowed
3. **Test the code** - MANDATORY, all tests pass
4. **Validate the code** - Type checking where applicable
5. **Verify variable exports** - CRITICAL FOR LIBRARIES
6. **Handle edge cases** - Empty inputs, missing files
7. **Error handling** - All errors caught and handled
8. **Input validation** - All user inputs validated

## Pre-Push Audit Checklist

Before pushing, verify:

1. All new code has tests
2. All tests pass locally
3. Coverage hasn't decreased
4. Linting passes
5. Types check (TypeScript/mypy)
6. Documentation updated
7. Commit messages are descriptive
8. No debug code left in
9. No secrets in code
10. Changelog updated (if applicable)

## Test-Driven Development

For new features, follow TDD:
1. Write failing test first
2. Implement minimum code to pass
3. Refactor while keeping tests green
4. Repeat

## Never Skip Tests

- NEVER use `--skip-tests` flags
- NEVER comment out failing tests
- NEVER reduce coverage thresholds to pass CI
- Fix the code, not the tests

