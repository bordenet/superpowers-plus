---
name: exhaustive-audit-validation
source: superpowers-plus
triggers: ["audit complete", "done with refactoring", "finished updating", "all skills fixed", "bulk edit done"]
description: Use BEFORE claiming any audit, refactoring, or bulk-edit task is complete. Enforces exhaustive scope enumeration, item-by-item tracking, automated validation, and coverage metrics. Prevents incomplete work from being marked as done.
---

# Exhaustive Audit Validation

> **Purpose:** Prevent "first-pass complete" followed by "found 12 more issues"
> **Root Cause:** Agent claimed audit complete without exhaustive validation
> **Incident:** 2026-02-28 — "First-pass audit" missed 12 of 27 skills needing fixes

---

## The Problem This Skill Solves

**Pattern observed:**
1. Agent claims audit/refactoring "complete"
2. Commits and pushes
3. Immediately discovers obvious gaps in a "second pass"
4. User loses trust

**Root cause:** No systematic validation BEFORE claiming done.

---

## Mandatory Pre-Completion Protocol

<EXTREMELY_IMPORTANT>

Before claiming ANY audit, bulk-edit, or refactoring task is complete, execute ALL of these steps:

### Phase 1: Define Exhaustive Scope

**Before starting work**, enumerate ALL items that need review:

```bash
# Example: Skill trigger audit
find skills -name "skill.md" | wc -l
# Result: 27 skills

# Example: Test file updates
find . -name "*.test.ts" | wc -l
# Result: 43 test files
```

**Record in task list:**
> "Auditing exactly N items: [list or reference]"

### Phase 2: Track Each Item

Maintain a checklist showing status of EVERY item:

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | resume-screening/skill.md | ✅ Fixed | Added triggers |
| 2 | phone-screen-prep/skill.md | ✅ Fixed | Added triggers |
| 3 | vitest-testing-patterns/skill.md | ❌ TODO | Missing YAML |
| ... | ... | ... | ... |

**Status options:**
- ✅ Fixed/Updated
- ⏭️ Skipped (with reason)
- ❌ TODO/Not started
- 🚫 N/A (with reason)

### Phase 3: Run Automated Validation

Execute verification commands that would catch the gaps:

```bash
# Example: Check for missing YAML frontmatter
grep -L "^---" skills/*/skill.md skills/*/*/skill.md 2>/dev/null

# Example: Check for skills without "Use when" pattern
grep -L "Use when" skills/*/skill.md skills/*/*/skill.md 2>/dev/null

# Example: Check for skills without "Triggers on" pattern  
grep -L "Triggers on" skills/*/skill.md skills/*/*/skill.md 2>/dev/null

# Example: Count skills with proper frontmatter
grep -l "^---" skills/*/skill.md skills/*/*/skill.md 2>/dev/null | wc -l
```

**If validation finds issues → FIX THEM before claiming done**

### Phase 4: Report Coverage Metrics

Before marking complete, state:

```
## Pre-Completion Validation Report

**Scope:** Audited X of Y items (100%)
**Validation checks passed:**
- ✅ All skills have YAML frontmatter
- ✅ All skills have "Use when" pattern
- ✅ All skills have "Triggers on" phrases

**Remaining gaps:** None

**Ready to claim complete:** YES
```

If gaps remain:
```
**Remaining gaps:** 3 skills still need triggers
**Ready to claim complete:** NO — fix gaps first
```

</EXTREMELY_IMPORTANT>

---

## Validation Commands by Task Type

| Task Type | Validation Commands |
|-----------|---------------------|
| Skill trigger audit | `grep -L "Triggers on" skills/*/*/skill.md` |
| YAML frontmatter | `grep -L "^---" skills/*/*/skill.md` |
| Test coverage | `npm run test:coverage` |
| Lint fixes | `npm run lint` with zero errors |
| Type errors | `npm run typecheck` with zero errors |
| Import updates | `grep -r "old-import" src/` returns empty |

---

## Integration with `verification-before-completion`

This skill extends `superpowers:verification-before-completion`:

1. **verification-before-completion** — General "did I do everything?"
2. **exhaustive-audit-validation** — Specific audit/bulk-edit checklist

When both apply, run this skill FIRST, then verification-before-completion.

---

## Failure Mode

If this skill is skipped:
1. Work marked "complete" with hidden gaps
2. Second-pass discovery embarrasses agent
3. User has to explicitly ask for re-audit
4. Trust eroded

**This skill exists because the agent claimed "first-pass complete" on 2026-02-28 while 12 of 27 skills were unfixed.**
