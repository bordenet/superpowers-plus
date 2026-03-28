# Context Expansion (Phase 1.5)

Runs between triage (Phase 1) and dispatch (Phase 2). Builds a structured context package for all reviewers.

**Wall-clock cap:** 60s total. If exceeded, report partial context and continue to dispatch.

---

## Skip Conditions

- Diff changes only 1 file with <20 changed lines → skip (reviewers explore manually)
- No symbols extracted in Step 1 → skip Steps 2–4; Steps 5–6 may still run

## Step 1: Extract Changed Symbols

```bash
git diff <scope> | grep '^+' | grep -E '(function |class |export |def |const |interface |type )' \
  | sed 's/^+//' | head -50
```

## Step 2: Find Related Code (1-level grep)

For each changed symbol (cap: 10):

```bash
grep -rn '<symbol>' <repo> --include='*.ts' --include='*.js' --include='*.py' \
  --include='*.sh' --include='*.go' --include='*.jsx' --include='*.tsx' \
  | grep -v 'node_modules\|dist\|build' | head -20
```

Type/interface definitions:

```bash
grep -rn 'interface.*<TypeName>\|type.*<TypeName>' <repo> --include='*.ts' --include='*.d.ts' | head -10
```

## Step 3: Find Related Test Files

```bash
find <repo> \( -name '*test*' -o -name '*spec*' \) -type f \
  | xargs grep -l '<changed-file-basename>' 2>/dev/null
```

## Step 4: Recent File History (monolith context only)

```bash
git log --oneline -5 -- <changed-file>
```

## Step 5: Commit Messages

| Diff Scope | Log Command |
|-----------|-------------|
| `git diff --cached` | Skip (staged but uncommitted) |
| `git diff @{u}..HEAD` | `git log --format='%s' @{u}..HEAD \| head -20` |
| `git diff main..HEAD` | `git log --format='%s' main..HEAD \| head -20` |
| `git diff HEAD~1` | `git log --format='%s' -1 HEAD` |

## Step 6: Test Status (OPTIONAL — `--run-tests` only)

Skip by default. When enabled:

```bash
timeout 15 <test-command> 2>&1 | tail -20
```

## Context Package Format

```markdown
## Context Package

### Changed Symbols
- `parseConfig()` in src/config.ts:42 (modified)
  - Grep hits: src/app.ts:15, src/cli.ts:88, lib/init.ts:22
  - Test file hits: test/config.test.ts
  - Type hits: src/types.ts:31

### Recent History (monolith only)
- src/config.ts: "fix: handle nested YAML maps" (3d ago)

### Commit Messages
- "Add account deactivation flow with soft-delete"
```
