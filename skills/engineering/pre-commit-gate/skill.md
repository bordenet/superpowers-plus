---
name: pre-commit-gate
source: superpowers-plus
triggers: ["before commit", "ready to commit", "about to commit", "git commit", "committing", "push this", "before push", "ready to push", "commit:pre-check", "commit:gate"]
description: Pre-commit quality gate - run lint, typecheck, test LOCALLY before committing. Prevents wasted CI time and embarrassing build failures.
summary: "Use when: about to commit code. Skip when: drafting or exploring."
coordination:
  group: commit-gates
  order: 1
  requires: []
  enables: ["enforce-style-guide"]
  escalates_to: []
  internal: false
---

# Pre-Commit Quality Gate

> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## When to Use

- Before every `git commit` — run local lint, typecheck, and tests first
- Before pushing to any remote branch (CI should confirm, not discover)
- After resolving merge conflicts to verify nothing broke
- When preparing a hotfix under time pressure (especially then)

## The Rule

**RUN THESE LOCALLY BEFORE EVERY `git commit`.** Not after CI fails — BEFORE you commit.

## This Gate's Checks: Safety Scan → Lint → Typecheck → Test

```bash
# 0. Dangerous pattern scan (MUST pass if .sh files are staged)
~/.codex/superpowers-plus/tools/dangerous-pattern-scan.sh

# 1. Lint (MUST pass with zero errors)
npm run lint    # or: pnpm run lint, biome check .

# 2. Typecheck (MUST pass with zero errors)
npm run typecheck    # or: tsc --noEmit

# 3. Test (MUST pass — excluding known infrastructure failures)
npm test    # or: vitest --run
```

**After this gate passes, the remaining commit gates run in order:**
enforce-style-guide (2) → progressive-code-review-gate (3) → professional-language-audit (4) → public-repo-ip-audit (5) → commit → push.

> **Step 0** only runs when `.sh` files are staged. It detects unguarded `rm -rf`,
> `chmod 777`, `curl | bash`, and other destructive patterns. Hardcoded safe paths
> (e.g., `rm -rf ~/.codex/something`) produce warnings, not blocks. <!-- doctor-ignore -->
> Use `--all` flag to scan the entire repo: `dangerous-pattern-scan.sh --all`

## Why This Gate Exists

> **Common failure:** Pushing code without running local checks, then debugging CI failures. Lint errors, type errors, and test failures are all detectable locally. Instead of running checks locally first, developers push, wait for CI, read logs, fix, push again — wasting multiple CI cycles that could have been zero.

## Pre-Commit Checklist

- [ ] `dangerous-pattern-scan.sh` — no blocked patterns (if .sh files staged)
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

0. Did I run `dangerous-pattern-scan.sh`? (if .sh files staged — zero blocked patterns)
1. Did I run `npm run lint`? (zero errors)
2. Did I run `npm run typecheck`? (zero errors)
3. Did I run `npm test`? (all pass or only pre-existing failures)
4. Did I review staged changes? (`git diff --staged`)

If NO to any → DO NOT COMMIT
```

## Chain to Next Gate

**When this gate passes, IMMEDIATELY load the next gate in the chain:**

```
use-skill enforce-style-guide
```

Then continue: `progressive-code-review-gate` → `professional-language-audit` → `public-repo-ip-audit` (gates 4–5 when applicable). Do NOT commit between gates.

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

---

## Commit Gate Coordination

Multiple skills fire on "before commit". Execute in this order:

| Order | Skill | Purpose | Scope |
|-------|-------|---------|-------|
| 0 | **pre-commit-gate** (this skill) | Dangerous pattern scan | Commits with `.sh` files |
| 1 | **pre-commit-gate** (this skill) | Build, lint, typecheck, test | All commits |
| 2 | `enforce-style-guide` | Code style compliance | All commits |
| 3 | **progressive-code-review-gate** | Harsh adversarial code review loop | All code commits |
| 4 | `professional-language-audit` | Profanity/language check | User-facing docs |
| 5 | `public-repo-ip-audit` | Proprietary content check | Public repos only |

**Rationale:** Safety scan first (catches catastrophic risk), then technical checks (fast feedback), then style enforcement (may change code), then adversarial review (covers all code changes including style fixes), then content gates.
