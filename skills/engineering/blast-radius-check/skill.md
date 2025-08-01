---
name: blast-radius-check
source: superpowers-plus
triggers: [
  "refactor", "refactoring", "modify existing", "change existing",
  "update function", "update method", "update class",
  "change behavior", "update behavior",
  "fix bug", "fix issue", "fix error",
  "quick fix", "hotfix", "patch",
  "multi-component change", "cross-service change"
]
description: |
  Blast radius analysis: Search for ALL usages before modifying any existing code.
  Prevents breaking unrelated consumers by scoping impact before scoping fix.
---

# Blast Radius Check

> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## The Rule

**SCOPE YOUR IMPACT BEFORE YOU SCOPE YOUR FIX.**

Before modifying ANY existing code, determine the full blast radius — every caller, consumer, and dependent that could be affected.

## Why This Gate Exists

> **Common failure:** Making changes without checking blast radius. The "fix" breaks multiple unrelated consumers because you only looked at the immediate problem, not the full dependency graph. Never assume a change is isolated without proving it.

## Step 1: Search for ALL Usages

```bash
# Search ALL repos for the function/class/field you're modifying
grep -rn "functionName\|ClassName\|fieldName" --include="*.ts" .

# Check for imports
grep -rn "import.*functionName\|from.*moduleName" --include="*.ts" .

# Check for interface implementations
grep -rn "implements InterfaceName\|extends BaseClass" --include="*.ts" .
```

## Step 2: Categorize Dependents

| Dependent Type | Count | Impact if Changed |
|----------------|-------|-------------------|
| Direct callers | | |
| Subclasses/implementations | | |
| Test files | | |
| Config/types | | |

## Step 3: Ask the Hard Questions

- Is this a **shared utility** (many consumers) or **single-use code** (one caller)?
- If shared: Do ALL consumers need this change, or just ONE?
- If one: Should I modify the shared code, or create a new variant?

## Blast Radius Checklist

- [ ] How many files/functions call this code? (`grep -c` to count)
- [ ] Is this a shared utility or single-use code?
- [ ] Will this change require updates to OTHER components I'm not planning to touch?
- [ ] What's the worst-case impact if I get this wrong?
- [ ] Have I searched ALL repos, not just the one I'm working in?

## Decision Matrix

| Blast Radius | Action |
|--------------|--------|
| 1 caller | Safe to modify directly |
| 2-5 callers | Review each caller's usage before modifying |
| 5+ callers | Consider adding new function/parameter instead of modifying |
| Shared utility | Almost NEVER modify — extend or create variant instead |

**If you can't answer "How many things use this?" — STOP and find out.**

## Data Flow Tracing

For multi-component changes, trace the full data flow BEFORE implementing:

```
Data/Control Flow Diagram:
SOURCE → STORAGE → ROUTER → CONSUMER → EXTERNAL
```

### Enumerate ALL Touchpoints

| Layer | File(s) | Change Required |
|-------|---------|-----------------|
| Schema | | |
| Storage | | |
| Router | | |
| Consumer | | |
| External | | |

**Fill this table BEFORE implementing.** Every empty row is a potential bug.

### Identify "Silent" Pass-Through Points

These are files that receive data and pass it along WITHOUT using it locally. They're easy to miss because:
- No TypeScript errors (field is optional or `any`)
- No test failures (tests mock inputs)
- No lint errors (code is valid)

**Question to ask:** "Does this component TRANSFORM the data before passing it?"

If yes → that transform must include new fields.

## Post-Implementation Verification

After implementing, verify with cross-repo grep:

```bash
# Search ALL repos for the new field/function
grep -rn "newFieldName" --include="*.ts" --include="*.js" repo1/ repo2/ repo3/

# Include snake_case, camelCase, UPPER_CASE variants
grep -rn "new_field_name\|NewFieldName\|NEW_FIELD_NAME" .
```

## Related Skills

- `pre-commit-gate` — Before committing changes
- `providing-code-review` — When reviewing others' PRs
- `engineering-rigor` — Philosophy and overview

