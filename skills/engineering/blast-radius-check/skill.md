---
name: blast-radius-check
source: superpowers-plus
triggers: ["refactor", "modify existing", "change existing", "update function", "update method", "fix bug", "quick fix", "hotfix", "multi-component change", "cross-service change"]
anti_triggers: ["review this PR", "code review", "review these changes", "write new"]
description: Blast radius analysis - search for ALL usages before modifying any existing code. Prevents breaking unrelated consumers by scoping impact before scoping fix.
summary: "Use when: modifying existing code. Skip when: writing new isolated code."
coordination:
  group: engineering
  order: 2
  requires: []
  enables: ["field-rename-verification"]
  escalates_to: ["engineering-rigor"]
  internal: false
---

# Blast Radius Check

> **Wrong skill?** Pre-commit checks → `pre-commit-gate`. Field renames → `field-rename-verification`. Output inspection → `output-verification`.
>
> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## When to Use

- Before modifying any existing function, method, type, or API contract
- Refactoring shared utilities, base classes, or cross-cutting concerns
- Applying a "quick fix" or hotfix to production code
- Changing configuration, feature flags, or environment variables used by multiple services

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

## Blast Radius Check

> **Wrong skill?** Pre-commit checks → `pre-commit-gate`. Field renames → `field-rename-verification`. Output inspection → `output-verification`.list

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

```bash
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

## Companion Skills

- `pre-commit-gate` — Before committing changes
- `providing-code-review` — When reviewing others' PRs
- `engineering-rigor` — Philosophy and overview
- **autonomous-chain-controller**: Chain-aware refactoring

## Failure Modes

| Failure | Fix |
|---------|-----|
| Only checked direct callers, missed transitive consumers | Trace data flow through ALL paths (READ → STORE → PASS) |
| Skipped test impact analysis | Run full test suite, check for tests that exercise changed paths |
| Assumed internal function has no external consumers | Grep for ALL references — internal/external distinction is often wrong |
| Changed API contract without checking client services | Use `field-rename-verification` for cross-service contract changes |
