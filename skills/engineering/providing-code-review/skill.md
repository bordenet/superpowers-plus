---
name: providing-code-review
source: superpowers-plus
triggers: ["review this PR", "review these changes", "code review", "provide feedback", "check this implementation", "ready for review", "needs review", "look at this PR"]
description: Code review gate - apply engineering rigor when reviewing PRs. Trace data flow, check blast radius, verify integration points.
---

# Providing Code Review

> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## The Rule

**The same engineering rigor that applies to your own work applies when reviewing others' work.**

When reviewing a PR, check changes, or provide feedback on someone else's implementation, apply the same analytical rigor — not rubber-stamp approval.

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

```
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

## The Review Gate Function

```
BEFORE approving any PR:

1. DATA FLOW: Did I trace where new fields/params flow FROM and TO?
2. BLAST RADIUS: Did I check for usages OUTSIDE the diff?
3. INTEGRATION: Did I verify the changes work at service boundaries?
4. TESTS: Are there tests for the new functionality?
5. BUILD: Is CI passing? (Not just "mergeable" — actually green)

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

## Related Skills

- `pre-commit-gate` — Before committing changes
- `blast-radius-check` — Before modifying existing code
- `engineering-rigor` — Philosophy and overview

