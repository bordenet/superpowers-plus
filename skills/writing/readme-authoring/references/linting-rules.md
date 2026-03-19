# README Authoring — Linting Rules

> Reference material for the `readme-authoring` skill.
> See `skill.md` for core agent guidance.

## Markdown Linting (REQUIRED)

**Before committing ANY markdown changes, run the linter.**

### Common Lint Errors

| Rule | Error | Fix |
|------|-------|-----|
| MD058 | Tables need blank lines | Add blank line before AND after every table |
| MD009 | Trailing spaces | Remove trailing whitespace |
| MD012 | Multiple blank lines | Use single blank lines only |
| MD022 | Headers need blank lines | Add blank line before AND after headers |
| MD031 | Fenced code needs blank lines | Add blank line before AND after code blocks |
| MD032 | Lists need blank lines | Add blank line before AND after lists |
| MD047 | File should end with newline | Add trailing newline |

### Pre-Commit Check

```bash
# If markdownlint-cli2 is available
npx markdownlint-cli2 "README.md"

# Or with markdownlint
npx markdownlint README.md --fix
```

### Table Formatting (MD058)

**Wrong:**

```markdown
Some text
| Column | Column |
|--------|--------|
| data   | data   |
More text
```

**Correct:**

```markdown
Some text

| Column | Column |
|--------|--------|
| data   | data   |

More text
```

### Self-Check Before Commit

1. Run linter: `npx markdownlint-cli2 "README.md"`
2. Fix all errors (no exceptions)
3. Verify CI will pass

**If you skip linting, you WILL break CI.**

