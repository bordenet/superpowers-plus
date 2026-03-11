---
name: professional-language-audit
source: superpowers-plus
triggers: ["before wiki update", "before commit", "check for profanity", "scan for unprofessional language", "language audit", "professional language check"]
description: "HARD GATE — Scans content for profanity and unprofessional language before publishing to wiki or committing user-facing documentation."
---

# Professional Language Audit

> **Last Updated:** 2026-03-11
> **Incident:** Profanity found in documentation during audit. AI slop skills didn't catch it.

## Overview

This skill scans content for profanity and unprofessional language BEFORE it reaches user-facing documentation. It operates as a **HARD GATE** — content with profanity cannot be published.

**This skill fires AUTOMATICALLY before:**
- Wiki updates (any wiki platform)
- Git commits of user-facing docs (README.md, skill.md, `*.md` in skills/)

---

## When to Invoke Manually

- "Check this document for profanity"
- "Scan for unprofessional language"
- "Run language audit on README"
- Before publishing any user-facing content

---

## HARD GATE Behavior

### Gate Status: 🚫 BLOCKED

If profanity is detected, the operation is **BLOCKED**:

```
⛔ PROFESSIONAL LANGUAGE AUDIT FAILED

Gate Status: 🚫 BLOCKED — Cannot publish
Violations Found: 3

| Line | Text | Category | Suggestion |
|------|------|----------|------------|
| 47 | "[crude] experience" | profanity | "frustrating experience" |
| 112 | "[expletive] broken" | profanity | "completely broken" |
| 156 | "this is [expletive]" | profanity | "this is unacceptable" |

ACTION REQUIRED:
1. Replace all flagged terms
2. Re-run audit: "check for profanity"
3. Only then proceed with publish/commit
```

### Gate Status: ✅ PASS

If no profanity is detected:

```
✅ PROFESSIONAL LANGUAGE AUDIT PASSED

Gate Status: ✅ PASS — Ready to publish
Scanned: 1,247 words across 3 files
Profanity matches: 0

Proceed with wiki update/commit.
```

---

## Detection Patterns

### Pattern Loading

Patterns are loaded from `.profanity-patterns.txt` (in `scripts/` or repo root).

**Pattern structure:** `\b(pattern1|pattern2|pattern3|...)\b`

**Matching is:**
- Case-insensitive
- Word-boundary constrained (won't match "class" when looking for a substring)

### Categories

| Category | Severity | Action |
|----------|----------|--------|
| Explicit/sexual terms | HIGH | BLOCK |
| Scatological terms | HIGH | BLOCK |
| Religious profanity | HIGH | BLOCK |
| Body vulgarities | HIGH | BLOCK |
| Gendered slurs | HIGH | BLOCK |
| Internet shorthand | MEDIUM | BLOCK |
| Crude expressions | LOW | FLAG for review |

**FLAG vs BLOCK:**
- **BLOCK** = Cannot proceed until fixed
- **FLAG** = Warning, context determines appropriateness (e.g., "dumb terminal" is technical)

---

## Integration Points

### Pre-Wiki Update Gate

BEFORE publishing to any wiki:

1. Extract the content to be published
2. Run profanity regex against content
3. If matches found → BLOCK and report
4. If clean → proceed with API call

### Pre-Commit Gate

BEFORE committing files matching:
- `README.md`
- `*.md` in `skills/` directory
- Wiki content files

**Run the audit on staged changes:**

```bash
# Get staged markdown files
git diff --cached --name-only | grep -E '\.(md)$'

# For each file, scan for profanity
node scripts/slop-dictionary.js scan-profanity FILE.md
```

### Integration with pre-commit-gate skill

This skill extends the pre-commit-gate workflow:

```
Pre-Commit Gate Checklist:
1. ✅ Lint (shellcheck, biome)
2. ✅ Typecheck (tsc)
3. ✅ Test (vitest/bats)
4. 🆕 ✅ Professional language audit  ← NEW STEP
5. ✅ Commit
```

---

## Replacement Suggestions

| Pattern Type | Professional Alternative |
|--------------|--------------------------|
| [crude]-[negative] | unrewarding, frustrating, problematic |
| [expletive] broken | completely broken, non-functional |
| this is [expletive] | this is unacceptable, this doesn't work |
| [profane] difficult | extremely difficult, challenging |
| [crude] code | poor quality code, problematic code |
| what the [expletive] | what happened, unexpectedly |
| [angry expletive] | frustrated, upset |

---

## Audit Commands

**Single file:**
```bash
node scripts/slop-dictionary.js scan-profanity FILE.md
```

**Seed profanity patterns to dictionary:**
```bash
node scripts/slop-dictionary.js seed-profanity
```

**List profanity patterns:**
```bash
node scripts/slop-dictionary.js list profanity
```

---

## Related Skills

- **detecting-ai-slop** — Now includes profanity as Category 9 (HARD BLOCK)
- **pre-commit-gate** — Integrates this skill into commit workflow

