---
name: professional-language-audit
source: superpowers-plus
triggers: ["before wiki update", "check for profanity", "scan for unprofessional language", "language audit", "professional language check", "commit:language", "commit:profanity"]
description: "HARD GATE — Scans content for profanity and unprofessional language before publishing to wiki or committing user-facing documentation."
summary: "Use when: publishing to wiki or committing user-facing docs. Hard gate for profanity."
coordination:
  group: commit-gates
  order: 4
  requires: ["progressive-code-review-gate"]
  enables: ["public-repo-ip-audit"]
  escalates_to: []
  internal: false
---

# Professional Language Audit

> **Wrong skill?** AI slop detection → `detecting-ai-slop`. AI slop rewriting → `eliminating-ai-slop`. General writing standards → `writing-skills`.
>
> **Last Updated:** 2026-03-11
> **Incident:** Profanity found in documentation during audit. AI slop skills didn't catch it.

## When to Use

- Before publishing any user-facing text
- Pre-commit gate step 4 (after code review)
- When content includes casual or potentially inappropriate language

## Gate Behavior

This skill scans content for profanity and unprofessional language BEFORE it reaches user-facing documentation. It operates as a **HARD GATE** — content with profanity cannot be published.

**This skill fires AUTOMATICALLY before:**

- Wiki updates (any wiki platform)
- Git commits of user-facing docs (README.md, skill.md, `*.md` in skills/)

## When to Invoke Manually

- "Check this document for profanity"
- "Scan for unprofessional language"
- "Run language audit on README"
- Before publishing any user-facing content

## HARD GATE Behavior

### Gate Status: 🚫 BLOCKED

If profanity is detected, the operation is **BLOCKED**:

```markdown
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

```text
✅ PROFESSIONAL LANGUAGE AUDIT PASSED

Gate Status: ✅ PASS — Ready to publish
Scanned: 1,247 words across 3 files
Profanity matches: 0

Proceed with wiki update/commit.
```

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

## Integration Points

**Gate 4** in the commit-gates chain: `pre-commit-gate` → `enforce-style-guide` → `progressive-code-review-gate` → **this** → `public-repo-ip-audit` → commit.

**Pre-wiki**: Run profanity regex before publishing. BLOCK on match.
**Pre-commit**: Scan staged `.md` files:

```bash
git diff --cached --name-only | grep -E '\.(md)$'
node scripts/slop-dictionary.js scan-profanity FILE.md
```

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

## Companion Skills

- **detecting-ai-slop**: Profanity as Category 9 (HARD BLOCK)
- **pre-commit-gate**: Integrates this skill into commit workflow
- **enforce-style-guide**: Style checking (runs before language audit)
- **public-repo-ip-audit**: IP audit (runs after language audit)

## Failure Modes

- **Over-flagging technical terms:** Words like "kill," "abort," "master" in engineering contexts are often appropriate
- **Missing context-dependent profanity:** Profanity in quoted user feedback or log output may be intentional — flag but don't auto-remove
- **Ignoring non-English content:** Profanity in other languages in multilingual codebases
