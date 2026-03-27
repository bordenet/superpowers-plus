---
name: progressive-code-review-gate
source: superpowers-plus
triggers: ["code review before commit", "review my code changes", "harsh code review", "adversarial review", "review my diff"]
anti_triggers: ["lint before commit", "run tests before commit", "pre-commit check"]
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

**If `code-review-battery` skill is available** (preferred — parallel specialized review):

Follow the `code-review-battery` SKILL.md procedure:
1. Triage the diff → select relevant reviewers
2. Dispatch activated reviewers in parallel (each gets the full diff inline)
3. Aggregate findings into unified report

Map battery output to gate verdicts:

| Battery Severity | Gate Classification | Gate Verdict |
|-----------------|---------------------|-------------|
| **Critical** | MUST-FIX | FAIL |
| **Important** | SHOULD-FIX | FAIL (if ≥2) or PASS_WITH_NITS (if 1) |
| **Minor** | NIT | PASS_WITH_NITS |
| All clean (✅) | — | PASS |

On re-review rounds (Round 2+): skip triage, re-dispatch the SAME reviewers from Round 1.

**Otherwise** (fallback — monolithic review):

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
| **PASS_WITH_NITS** | Fix the nits, then go to Step 3a (targeted re-review) |
| **FAIL** | Fix MUST-FIX and SHOULD-FIX items, then go to Step 2 (full re-review) |

### Step 3a: Targeted re-review (PASS_WITH_NITS loop)

After fixing nits, run a **targeted** battery round:

1. **Scope**: Only the files touched by the nit fixes (not the full original diff)
2. **Reviewers**: Only the reviewer(s) that produced the nits in the previous round
3. **Dispatch**: Re-capture `git diff` for just the fixed files, dispatch the scoped reviewers
4. **Verdict mapping**: Same table as Step 2
5. **Exit conditions**:
   - PASS → proceed to commit/push
   - PASS_WITH_NITS → fix and repeat Step 3a (counts toward Round 5 cap)
   - FAIL → fix and go to Step 2 (full re-review — nit fix introduced a real issue)

**Why targeted, not full**: Nit fixes are low-risk by definition. Re-reviewing the entire diff wastes time. But nit fixes *can* introduce new issues, so the affected reviewer must verify.

### Step 4: Track rounds

- Round 1: Initial review (Step 2)
- Round 2+: Re-review after fixes (Step 2 for FAIL, Step 3a for PASS_WITH_NITS)
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

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| Review loop (5+ rounds) | Each fix introduces new findings | Stop at Round 5. Tell the human. The change may need a different approach |
| Stale diff after fixes | Reviewer sees old diff because changes weren't staged | Re-run `git diff` or `git diff --staged` each round — never reuse prior output |
| Fix-induced regression | Round N fix breaks something Round N-1 passed | Reviewer must re-check ALL prior-passing areas, not just the new changes |
| Reviewer scope creep | Flagging pre-existing code not in the diff | Restrict to changed lines and their direct callers. Pre-existing issues are INFO at most |
| Skipping for "small changes" | One-line fix committed without review | Size doesn't determine risk. See Anti-Patterns table above |

## Commit Gate Chain

```
pre-commit-gate (1) → enforce-style-guide (2) → progressive-code-review-gate (3) → professional-language-audit (4) → public-repo-ip-audit (5)
```
