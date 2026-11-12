# Testing Standards

> **Priority**: HIGH - Apply to all code changes  
> **Source**: genesis, pr-faq-validator, bloginator, scripts AGENTS.md

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
3. **Test the code** - Do not claim done when tests were not run.
4. **Validate the code** - Type checking where applicable
5. **Verify variable exports** - Check exports when the project is a library.
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

---

## CLI integration tests

> Source: codebase-reviewer AGENTS.md

CLI tools need integration tests that verify:

| Aspect | Test Requirement |
|--------|------------------|
| Exit codes | 0 for success, non-zero for errors |
| Output format | Matches expected structure |
| Error messages | Helpful and actionable |
| Edge cases | Empty input, missing files, invalid args |

```bash
# Example CLI integration test (BATS)
@test "exits 0 on valid input" {
  run ./tool.sh valid-input.txt
  [ "$status" -eq 0 ]
}

@test "exits 1 on missing file" {
  run ./tool.sh nonexistent.txt
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}
```

## Pre-Push Audit Checklist

> Source: scripts/AGENTS.md

Before pushing to remote, verify ALL of these:

1. [ ] All new code has tests
2. [ ] All tests pass locally (`npm test`, `go test`, etc.)
3. [ ] Coverage hasn't decreased
4. [ ] Linting passes with zero warnings
5. [ ] Type checking passes (TypeScript/mypy)
6. [ ] Build succeeds (`go build`, `npm run build`)
7. [ ] No debug code left in (console.log, print, etc.)
8. [ ] No secrets or credentials in code
9. [ ] Commit messages are descriptive
10. [ ] Documentation updated if behavior changed

## Impact Analysis Before Changes

> Source: scripts/AGENTS.md

Before modifying shared code:

1. **Find all callers**: `grep -r "function_name" .`
2. **Identify downstream effects**: What breaks if this changes?
3. **Plan migration**: If signature changes, update all call sites
4. **Test affected code**: Run tests for all affected components

