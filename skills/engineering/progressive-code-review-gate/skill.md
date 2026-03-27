---
name: progressive-code-review-gate
source: superpowers-plus
triggers: ["before commit", "ready to commit", "about to commit", "git commit", "committing", "push this", "before push", "ready to push", "commit and push", "code review before commit"]
description: "Use when: committing or pushing code changes. Mandatory progressive review loop via sub-agent-code-reviewer. Skip only when the user explicitly says to skip review."
summary: "Use when: committing or pushing code. Skip only when user explicitly says to skip."
coordination:
  group: commit-gates
  order: 3
  requires: ["enforce-style-guide"]
  enables: ["professional-language-audit"]
  escalates_to: []
  internal: false
---

# Progressive Code Review Gate

## When to Use

- Fires automatically before every commit or push of code changes
- NOT for: PR-level review of others' work (`providing-code-review`), file-protocol review (`code-review`)

**MANDATORY before every commit/push of code changes.**
Skip only when the human **explicitly** says to skip review.

## Procedure

### Step 1: Gather the diff

Determine what is being committed or pushed:

```bash
# For uncommitted changes (pre-commit):
git diff --staged                    # staged changes
git diff                             # unstaged changes

# For unpushed commits (pre-push):
git log --oneline @{u}..HEAD        # list unpushed commits
git diff @{u}..HEAD                 # diff of unpushed commits
```

If no diff exists in any of these, skip this gate.

### Step 2: Dispatch the reviewer

Invoke `sub-agent-code-reviewer` with a unique name per round (e.g., `review-round-1`):

```
Review the code changes in {repo_path}.
Run `cd {repo_path} && git diff` to see the diff.
(For pre-push: `git diff @{u}..HEAD`)

Be harsh and adversarial. Check for:
1. Logic errors, off-by-one, edge cases
2. Missing error handling or silent failures
3. Inconsistency with surrounding code patterns
4. Security issues (injection, secrets, unsafe operations)
5. Stale references (functions/variables that no longer exist)
6. Missing downstream changes (callers, tests, types, docs)
7. Style violations relative to the project's conventions

Classify each issue:
- MUST-FIX: Blocks commit (logic error, security, correctness)
- SHOULD-FIX: Strong recommendation (inconsistency, missing guard)
- NIT: Minor (won't block)

Verdict: PASS, PASS_WITH_NITS, or FAIL
If FAIL: list every MUST-FIX and SHOULD-FIX clearly.
```

### Step 3: Process results

| Verdict | Action |
|---------|--------|
| **PASS** | Proceed to commit/push |
| **PASS_WITH_NITS** | Proceed (fix nits if trivial) |
| **FAIL** | Fix MUST-FIX and SHOULD-FIX items, then go to step 2 |

### Step 4: Track rounds

- Round 1: Initial review
- Round 2+: Re-review after fixes
- Round 5: STOP. Tell the human: "5 review rounds without clean pass. Please review manually."

## What This Gate Does NOT Do

- Does not run lint/typecheck/tests (that's `pre-commit-gate`, order 1)
- Does not enforce style guides (that's `enforce-style-guide`, order 2 — runs before this gate so style-induced code changes are covered by this review)
- Does not handle PR-level review (that's `providing-code-review`)
- Does not scan for unprofessional language (that's `professional-language-audit`, order 4)

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Committing without review because "it's a small change" | Every code change gets reviewed |
| Skipping re-review after fixes | Fixes can introduce new issues. Always re-review |
| Running review only when human asks | Review is automatic. Human asks to SKIP, not to START |

## Commit Gate Chain

```
pre-commit-gate (1) → enforce-style-guide (2) → progressive-code-review-gate (3) → professional-language-audit (4) → public-repo-ip-audit (5)
```
