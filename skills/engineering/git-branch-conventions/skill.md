---
name: git-branch-conventions
source: superpowers-plus
triggers: ["git checkout -b", "git switch -c", "git branch <name>", "git worktree add -b", "create a work branch", "name this branch", "new branch name", "what should I call this branch"]
anti_triggers: ["merge branch", "delete branch", "list branches"]
description: Use when running git checkout -b, git switch -c, git worktree add -b, or any command that creates a new work branch — enforces semantic prefix naming.
summary: "Use when: creating a new git work branch. Enforces semantic prefix naming (feat/, fix/, exp/, doc/, perf/, chore/)."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [branch-intent]
  produces: [branch-name]
  capabilities: [enforces-conventions]
  priority: 40
---

# git-branch-conventions

> **Scope:** New work branches only — not permanent branches (`main`, `master`, `develop`), release branches, or sync branches. Repos may have their own branch policies that take precedence.

## When to Use

- Running `git checkout -b`, `git switch -c`, `git branch <name>`, or `git worktree add -b`
- Choosing a name for a new work branch

## Semantic Branch Prefixes (REQUIRED)

New work branches MUST start with one of these prefixes:

| Prefix | Use For | Examples |
|--------|---------|----------|
| `feat/` | New features, user-facing functionality | `feat/scheduler-v3`, `feat/outbound-calling` |
| `fix/` | Bug fixes, defect corrections | `fix/memory-leak-tts`, `fix/null-check-handler` |
| `exp/` | Experimental, spike, or throwaway work | `exp/grpc-prototype`, `exp/redis-caching-spike` |
| `doc/` | Documentation updates only | `doc/api-reference-update`, `doc/onboarding-guide` |
| `perf/` | Performance and optimization work | `perf/query-optimization`, `perf/reduce-cold-start` |
| `chore/` | Non-feature maintenance — deps, CI, config, refactors, test harness, repo housekeeping | `chore/bump-deps-march`, `chore/ci-pipeline-fix` |

### Decision Guide

```
Is it throwaway / exploratory?              → exp/
Is it a bug fix?                            → fix/
Is it only documentation?                   → doc/
Is it only performance / optimization?      → perf/
Is it a new feature or behavior change?     → feat/
Everything else (deps, CI, refactor, tests) → chore/
```

**Mixed-purpose branches:** Use the prefix that describes the primary intent.

---

## Branch Name Format

```
{prefix}/{short-description}
```

**Rules:**
- Lowercase only
- Hyphens between words (not underscores)
- Descriptive but concise
- Include ticket ID when relevant: `fix/PROJ-1189-null-config`

```bash
# ✅ CORRECT
git checkout -b feat/outbound-calling
git checkout -b fix/PROJ-1189-null-config
git checkout -b exp/grpc-spike
git checkout -b chore/bump-node-22
git checkout -b chore/refactor-auth-module

# ❌ WRONG — missing prefix
git checkout -b outbound-calling

# ❌ WRONG — non-standard prefix
git checkout -b feature/outbound         # Use feat/
git checkout -b bugfix/null-check        # Use fix/
git checkout -b refactor/auth-module     # Use chore/
git checkout -b test/add-unit-tests      # Use chore/
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

---

## Integration

**Note:** The obra/superpowers `using-git-worktrees` skill shows `feature/auth` in its example. That prefix is non-canonical per this convention — use `feat/auth` instead. This skill takes precedence for branch naming.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Non-compliant branch name | PR rejected by CI | Follow type/description pattern |
| Non-standard prefix used | Confusion in branch listing | Use the six canonical prefixes |
| Skipping prefix on quick branches | Inconsistent repo | Every work branch gets a prefix |
