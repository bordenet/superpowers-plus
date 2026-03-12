---
name: pre-commit-gate
source: superpowers-plus
triggers: ["before commit", "ready to commit", "about to commit", "git commit", "committing", "push this", "before push", "ready to push"]
description: Pre-commit quality gate - run lint, typecheck, test LOCALLY before committing. Prevents wasted CI time and embarrassing build failures.
---

# Pre-Commit Quality Gate

> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## The Rule

**RUN THESE LOCALLY BEFORE EVERY `git commit`.** Not after CI fails — BEFORE you commit.

## Required Order: Lint → Typecheck → Test → Commit → Push

```bash
# 1. Lint (MUST pass with zero errors)
npm run lint    # or: pnpm run lint, biome check .

# 2. Typecheck (MUST pass with zero errors)
npm run typecheck    # or: tsc --noEmit

# 3. Test (MUST pass — excluding known infrastructure failures)
npm test    # or: vitest --run

# 4. ONLY IF ALL ABOVE PASS:
git add -A && git commit -m "message"

# 5. Push
git push origin <branch>
```

## Why This Gate Exists

> **Common failure:** Pushing code without running local checks, then debugging CI failures. Lint errors, type errors, and test failures are all detectable locally. Instead of running checks locally first, developers push, wait for CI, read logs, fix, push again — wasting multiple CI cycles that could have been zero.

## Pre-Commit Checklist

- [ ] `npm run lint` — zero errors (warnings OK if project allows)
- [ ] `npm run typecheck` — zero errors
- [ ] `npm test` — all tests pass (or only pre-existing failures)
- [ ] Reviewed staged changes (`git diff --staged`)

**Skip any step = wasted CI time + embarrassing build failures**

## Acceptable vs. Not Acceptable

| Acceptable | Not Acceptable |
|------------|----------------|
| Pre-existing infrastructure test failures (e.g., lockfile conflict) | New failures you introduced |
| Lint warnings if project config allows them | Lint errors |
| Skipped tests marked `@skip` | Tests you broke |

## The Gate Function

```
BEFORE EVERY COMMIT:

1. Did I run `npm run lint`? (zero errors)
2. Did I run `npm run typecheck`? (zero errors)  
3. Did I run `npm test`? (all pass or only pre-existing failures)
4. Did I review staged changes? (`git diff --staged`)

If NO to any → DO NOT COMMIT
```

## Post-Commit: Verify Build Status

**DO NOT update ticket status or claim "done" until ALL builds pass.**

```bash
# Check CI status for your PR
# Look for: all checks passing
# NOT just merge status (that only means merge is possible)
```

| Check | Required Before "Done" |
|-------|------------------------|
| PR created/merged | ✅ Yes |
| Build triggered | ✅ Yes |
| Build result = succeeded | ✅ Yes |
| No lint/test failures in CI logs | ✅ Yes |

**If build fails after push:**
1. Check pipeline logs immediately
2. Fix the issue locally
3. Push fix to branch
4. Verify new build passes
5. THEN update ticket status

## Related Skills

- `blast-radius-check` — Before modifying existing code
- `providing-code-review` — When reviewing others' PRs
- `engineering-rigor` — Philosophy and overview
