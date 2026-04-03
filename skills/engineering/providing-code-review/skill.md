---
name: providing-code-review
source: superpowers-plus
triggers: ["review this PR", "review these changes", "code review", "provide feedback", "check this implementation", "ready for review", "needs review", "look at this PR"]
anti_triggers: ["send to reviewer agent", "execute reviewer findings", "pre-commit check", "I am the reviewer agent"]
description: Code review gate - apply engineering rigor when reviewing PRs. Trace data flow, check blast radius, verify integration points.
summary: "Use when: reviewing someone else's PR. Skip when: reviewing your own code."
coordination:
  group: code-quality
  order: 3
  requires: [code-review]
  enables: [receiving-code-review]
  escalates_to: [code-review-battery]
  internal: false
---

# Providing Code Review

> **Wrong skill?** File-protocol review → `code-review-respond`. Pre-commit review → `progressive-code-review-gate`. Processing feedback you received → `receiving-code-review`.
>
> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## The Rule

**The same engineering rigor that applies to your own work applies when reviewing others' work.**

When reviewing a PR, check changes, or provide feedback on someone else's implementation, apply the same analytical rigor — not rubber-stamp approval.

## When to Use

- Reviewing a PR, merge request, or diff someone else authored
- Asked to "check," "review," or "approve" code changes
- Pair-reviewing changes before merge in a shared branch workflow
- Evaluating a dependency upgrade or third-party contribution

## Why This Gate Exists

**Failure Pattern:** Reviewing PRs superficially because "it's their code" — looking at the diff in isolation without:

- Tracing the full data flow
- Checking blast radius of changes
- Verifying integration points
- Running the actual changes locally

This allows the same bugs to slip through that engineering-rigor prevents in your own work.

## Code Review Checklist

BEFORE approving or providing feedback:

### 1. Data Flow Analysis

```text
For each changed function/component:
  WHERE does the input come from?
  WHERE does the output go?
  WHAT transforms happen in between?
```

If the PR adds a new field or parameter:

- Does it flow through ALL intermediate components?
- Are there "silent pass-through" files that need updating?
- Does the field reach its final destination?

### 2. Blast Radius Verification

```bash
# Search for OTHER usages of modified functions
grep -rn "functionName" --include="*.ts" .

# Check if changes break existing callers
# Are ALL callers updated?
# Are tests updated for changed signatures?
```

**Questions to answer:**

- How many places call this code?
- Did the PR update ALL of them?
- Are there cross-repo consumers not in this diff?

### 3. Integration Point Check

| Integration | Question to Ask |
|-------------|-----------------|
| API boundaries | Do request/response types match across services? |
| Database | Are schema changes applied? Migrations needed? |
| External APIs | Does the external service accept these changes? |
| Config | Are config changes applied? |
| UI | Does the admin UI expose new fields? |

### 4. CI/Build Verification

- Is CI actually passing? (Not just "mergeable" — actually green)
- Are there test failures being ignored?
- Did lint pass?

### 5. Factual Claims Verification

If the PR or associated documentation makes claims about external system state, **verify each claim against the system of record.** Do not treat metadata as stylistic — it is falsifiable.

| Claim Type | Verification Method |
|------------|---------------------|
| PR/merge status | Query your PR platform's API — verify the status field, not preview artifacts |
| "Tests pass" | Check CI run status, not just the author's word |
| Deployment state | Query pipeline or environment APIs |
| Ticket/issue state | Query issue tracker API |
| URLs and links | Fetch or query to confirm they resolve |
| Dependency versions | Check lockfile or manifest directly |

**PR platform gotcha:** Some PR platforms (e.g., Azure DevOps) generate a preview merge commit for every open PR. This does NOT mean the PR is merged. Always check the PR status field via the API before concluding a merge occurred.

## The Review Gate Function

```python
BEFORE approving any PR:

1. DATA FLOW: Did I trace where new fields/params flow FROM and TO?
2. BLAST RADIUS: Did I check for usages OUTSIDE the diff?
3. INTEGRATION: Did I verify the changes work at service boundaries?
4. TESTS: Are there tests for the new functionality?
5. BUILD: Is CI passing? (Not just "mergeable" — actually green)
6. FACTS: Did I verify every claim about external state (PR status, deploy status, ticket state, URLs)?

If I can't answer YES to all → don't approve, ask questions or flag gaps
```

## Red Flags to Watch For

| Pattern | Risk |
|---------|------|
| New field added to type but not passed through routers | Data loss / silent failure |
| Parameter added to function but only some callers updated | Runtime errors in untouched code |
| Changes in one repo without corresponding changes in dependent repos | Integration failure |
| Tests pass but only mock the changed component | Real integration may fail |
| "Rough draft" or "WIP" language but submitted for review | Incomplete work |

## Output Format for Code Review

When providing code review, structure feedback as:

```markdown
## Code Review: [PR Title]

### ✅ What's Good
- [Specific strength]

### ⚠️ Questions / Concerns
- [Question about data flow]
- [Missing integration check]

### 🚫 Must Fix Before Merge
- [Blocker issue]

### 📊 Engineering Rigor Check
- [ ] Data flow traced end-to-end
- [ ] Blast radius verified (checked for usages outside diff)
- [ ] Integration points verified
- [ ] CI passing (actual green, not just mergeable)
- [ ] Tests cover new functionality
```

**If you can't check off all boxes, the review is incomplete.**

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Rubber-stamp approval | No substantive comments | Find ≥1 concern per review |
| Style-only focus | All comments are formatting | Check logic, edge cases, security first |
| Nitpick avalanche | >10 minor findings, 0 critical | Prioritize: critical → important → minor |
| Context-free review | Comments without understanding intent | Read PR description + linked issues first |
| Drive-by "LGTM" | Single word approval | Requires ≥3 substantive observations |

## Failure Modes

| Failure | Fix |
|---------|-----|
| Rubber-stamp approval without tracing data flow | Use the 6-point gate function checklist — if any box unchecked, don't approve |
| Reviewing diff in isolation without blast radius | Run grep for all callers of modified functions before approving |
| Trusting PR metadata claims without verification | Use Factual Claims Verification table — one API call catches stale status |

## Companion Skills

- **code-review-battery**: Parallel specialist reviews (heavier than this checklist)
- **receiving-code-review**: How the PR author should process your feedback
- **progressive-code-review-gate**: Pre-commit gate (uses this checklist internally)
- **code-review**: File-protocol review (requesting side)
- **code-review-respond**: File-protocol review (reviewer side)
- **micro-harsh-review**: Per-batch review (lighter)
