---
name: professional-language-audit
source: superpowers-plus
triggers: ["before wiki update", "check for profanity", "scan for unprofessional language", "language audit", "professional language check", "commit:language", "commit:profanity"]
anti_triggers: ["code review", "scan for secrets", "security audit", "check for bugs", "scan shell scripts"]
description: "HARD GATE — Scans content for profanity and unprofessional language before publishing to wiki or committing user-facing documentation."
summary: "Use when: publishing to wiki or committing user-facing docs. Hard gate for profanity."
coordination:
  group: commit-gates
  order: 4
  requires: ["progressive-code-review-gate"]
  enables: ["public-repo-ip-audit"]
  escalates_to: []
  internal: false
composition:
  consumes: [markdown-content]
  produces: [language-audit-report]
  capabilities: [scans-language, gates-quality]
  priority: 35
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

## Automated Scanner (`tools/language-scanner.js`)

A Node.js scanner ships at `tools/language-scanner.js`. It is the authoritative enforcement mechanism for wiki write paths.

### Contract (stable — callers depend on these exit codes)

| Exit | Meaning | Required action |
|------|---------|-----------------|
| 0 | PASS — no profanity | Proceed |
| 1 | BLOCK — profanity found (per-finding detail on stderr) | STOP. Replace each flagged term, or wrap in `[F-WORD]`/`[EXPLETIVE]`/`[REDACTED: reason]` marker. Re-run. Do NOT mark audit PASS without a fresh exit-0 run. |
| 2 | USAGE/IO error (missing arg, unreadable file, multi-file invocation) | ABORT. Fix invocation. Do NOT infer PASS. |
| 127+ | `node` not on PATH | ABORT. Install Node.js. Do NOT infer PASS. |
| 1 with `MODULE_NOT_FOUND` on stderr | Scanner file missing (node found, script absent) | ABORT. Re-run `install.sh` or verify `tools/language-scanner.js` exists. Do NOT infer PASS or treat as profanity BLOCK. |
| Any other non-zero | Scanner unreachable or broken | ABORT. Do NOT infer PASS. |

### Usage

```bash
# Scan one file (only one at a time — loop in the caller for multiple files)
node tools/language-scanner.js draft.md

# Wiki write pre-flight (combined with secret scan in one shell invocation):
WIKI_TMP=$(mktemp -t wiki-update.XXXXXX.md)
trap 'rm -f "$WIKI_TMP"' EXIT
printf '%s' "$WIKI_BODY" > "$WIKI_TMP"
node tools/language-scanner.js "$WIKI_TMP" || exit $?
```

**Important:** Rules 5 (secrets) and 6 (language) MUST run in a single shell invocation when combined — splitting them across two separate Bash calls destroys the `$WIKI_TMP` variable (the EXIT trap fires when the first shell exits), causing the second scan to exit 2 with ENOENT.

### Allowlist markers

To intentionally reference profanity in a document (e.g., policy documentation), wrap it: `[F-WORD]`, `[EXPLETIVE]`, `[REDACTED: reason]`. The marker BODY is itself scanned — only the keyword portion is safe.

### Evasion resistance

The scanner normalizes Unicode (NFD/NFKC), folds Cyrillic homoglyphs, decodes HTML entities (&#102;&#117;&#99;&#107;), and strips zero-width characters before scanning — bypasses via Unicode tricks are blocked.

## Integration Points

**Gate 4** in the commit-gates chain: `pre-commit-gate` → `enforce-style-guide` → `progressive-code-review-gate` → **this** → `public-repo-ip-audit` → commit.

> **Preferred:** `use-skill unified-commit-gate` loads all gates in one load. Use this skill directly only for deep-dive when the language gate fails.

**Pre-wiki**: Run `node tools/language-scanner.js "$WIKI_CONTENT_FILE"` before any wiki write. BLOCK on exit 1.
**Pre-commit**: Scan staged `.md` files:

```bash
git diff --cached --name-only | grep -E '\.(md)$' | while IFS= read -r f; do
  node tools/language-scanner.js "$f" || exit 1
done
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

Use `tools/language-scanner.js` (see Automated Scanner section above). The older `scripts/slop-dictionary.js` approach is **deprecated** — do not use it for new integrations.

```bash
# Scan a single file (canonical command)
node tools/language-scanner.js FILE.md
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
