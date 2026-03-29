---
name: git-branch-conventions
source: superpowers-[company]
triggers: ["git checkout -b", "git switch -c", "git branch <name>", "git worktree add -b", "create a work branch", "name this branch", "new branch name", "what should I call this branch"]
description: Use when running git checkout -b, git switch -c, git worktree add -b, or any command that creates a new work branch — enforces semantic prefix naming.
summary: "Use when: creating a new git work branch. Enforces semantic prefix naming (feat/, fix/, exp/, doc/, perf/, chore/)."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# git-branch-conventions

---

> **Source:** [Company] engineering convention (2026-03)
> **Scope:** New work branches only — not permanent branches (`main`, `master`, `develop`), release branches, or sync branches. Repos may have their own branch policies that take precedence.

---

## When to Use

Invoke this skill when:

- Running `git checkout -b`, `git switch -c`, `git branch <name>`, or `git worktree add -b`
- Choosing a name for a new work branch

---

## Semantic Branch Prefixes (REQUIRED)

New work branches MUST start with one of these prefixes:

| Prefix | Use For | Examples |
|--------|---------|----------|
| `feat/` | New features, user-facing functionality | `feat/scheduler-v3`, `feat/outbound-calling` |
| `fix/` | Bug fixes, defect corrections | `fix/memory-leak-tts`, `fix/delta-1189-null-check` |
| `exp/` | Experimental, spike, or throwaway work | `exp/grpc-prototype`, `exp/redis-caching-spike` |
| `doc/` | Documentation updates only | `doc/api-reference-update`, `doc/onboarding-guide` |
| `perf/` | Performance and optimization work | `perf/query-optimization`, `perf/reduce-cold-start` |
| `chore/` | Non-feature maintenance — deps, CI, config, refactors, test harness, repo housekeeping | `chore/bump-deps-march`, `chore/ci-pipeline-fix`, `chore/extract-helper-class` |

### Decision Guide

```
Is it throwaway / exploratory?              → exp/
Is it a bug fix?                            → fix/
Is it only documentation?                   → doc/
Is it only performance / optimization?      → perf/
Is it a new feature or behavior change?     → feat/
Everything else (deps, CI, refactor, tests) → chore/
```

**Mixed-purpose branches:** Use the prefix that describes the primary intent. A bug fix that also improves performance is `fix/`. A feature that includes a refactor is `feat/`.

---

## Branch Name Format

```
{prefix}/{short-description}
```

**Rules:**
- Lowercase only
- Hyphens between words (not underscores)
- Descriptive but concise
- Include ticket ID when relevant: `fix/delta-1189-null-config`

```bash
# ✅ CORRECT
git checkout -b feat/outbound-calling
git checkout -b fix/delta-1189-null-config
git checkout -b exp/grpc-spike
git checkout -b chore/bump-node-22
git checkout -b chore/refactor-auth-module
git checkout -b doc/update-api-reference

# ❌ WRONG — missing prefix
git checkout -b outbound-calling

# ❌ WRONG — non-standard prefix (use the six canonical prefixes above)
git checkout -b feature/outbound         # Use feat/
git checkout -b bugfix/null-check        # Use fix/
git checkout -b refactor/auth-module     # Use chore/
git checkout -b test/add-unit-tests      # Use chore/
git checkout -b ci/update-pipeline       # Use chore/
git checkout -b hotfix/urgent-patch      # Use fix/

# ❌ WRONG — formatting
git checkout -b FEAT/OUTBOUND           # Uppercase
git checkout -b feat/outbound_calling   # Underscores
```

---

## Verification

After creating a branch, confirm the name matches all format rules:

```bash
branch=$(git branch --show-current)
if echo "$branch" | grep -qE '^(feat|fix|exp|doc|perf|chore)/[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "✅ Valid: $branch"
else
  echo "❌ Invalid: $branch"
  echo "  Required: {prefix}/{lowercase-hyphenated-description}"
  echo "  Prefixes: feat/ fix/ exp/ doc/ perf/ chore/"
fi
```

This checks prefix, lowercase, hyphens-only, and non-empty description. A branch is not ready to push until it passes.

---

## Common Failure Modes

- **Using non-standard prefixes:** `feature/`, `bugfix/`, `hotfix/`, `refactor/`, `test/`, `ci/` — use the six canonical prefixes instead
- **Skipping prefix on "quick" branches:** Every work branch gets a prefix, no exceptions
- **Wrong prefix for refactors:** Refactors go under `chore/`, not `feat/` (no new behavior) and not a made-up `refactor/` prefix

---

## Integration

**Pairs with:**
- The upstream `using-git-worktrees` skill (obra/superpowers) — Apply these prefixes when creating worktree branches

**Known upstream inconsistency:** The obra/superpowers `using-git-worktrees` skill shows `feature/auth` in its example. That prefix is non-canonical per this convention — use `feat/auth` instead. This skill takes precedence for branch naming.

**Standalone:** This skill defines naming conventions only. No other skill currently consumes the prefix programmatically.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Non-compliant branch name | PR rejected by CI | Follow type/description pattern |
