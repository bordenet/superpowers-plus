---
name: code-review-respond
description: Use when acting as the reviewer agent for a ~/.codex/superpowers-review/ request.md → response.md file protocol handoff
triggers: ["I am the reviewer agent", "read request.md", "reviewer agent protocol", "superpowers-review respond"]
---

# Code Review — Reviewer Agent File Protocol

## When to Use

- You are the reviewer agent in a `~/.codex/superpowers-review/` file-protocol handoff
- User says "I am the reviewer agent" or "read request.md"
- NOT for: requesting a review (`code-review`), inline code review without file protocol (`providing-code-review`)

You are the code reviewer. Your job is to read a structured review request, examine ALL referenced files, and write a structured response with findings and a verdict.

**Also load `providing-code-review`** for engineering rigor guidance (data flow tracing, blast radius analysis, integration verification). That skill contributes WHAT to check only. **Do not use its output template here** — this protocol's `response.md` template overrides any other output-format guidance.

**Use these distinctive reviewer-side phrases:** `I am the reviewer agent`, `read request.md`, `reviewer agent protocol`, `superpowers-review respond`.

**Do not rely on generic review prompts here.** Bare phrases like `code review` or `perform code review` are intentionally broader and may route to `providing-code-review` instead.

---

## Steps

1. **Locate the request.** The user will tell you the path, e.g.:
   `~/.codex/superpowers-review/active/{scope}/request.md`
   - If the supplied `request.md` path is missing or unreadable, stop and tell the user no review has been requested for that scope/path.
   - If not specified, list directories in `~/.codex/superpowers-review/active/` and ask which scope to review.

2. **Read `request.md` completely.** Note the round number, response path, and review questions.

3. **Read EVERY file listed in "Files to Read Before Reviewing."** This is mandatory — do not form opinions from the request's claims alone. Read the actual code/docs.
   - **If a referenced file doesn't exist or can't be read, report that as a CRITICAL finding.** Missing files are evidence of broken references.

4. **Write `response.md`** to the path specified in the request header. Use the template below.

---

## Response Template

```markdown
# Code Review Response — Round {N}

## Findings

### CRITICAL (must fix before proceeding)
F1. [file:line] Description of the issue.
    Evidence: {what you actually found in the file}
    Fix: {specific recommendation}

### WARNING (should fix, risks regression if ignored)
F2. [file:line] Description...
    Evidence: ...
    Fix: ...

### INFO (observations, optional improvements)
F3. [file:line] Description...

## Verdict: {PASS | PASS_WITH_CHANGES | FAIL}
{1-2 sentence rationale referencing specific finding numbers}
```

---

## Severity Definitions

| Level | Meaning | Examples |
|-------|---------|---------|
| **CRITICAL** | Will break functionality, lose data, or create a security issue | Broken reference, missing file, wrong command path, data loss |
| **WARNING** | Regression risk if ignored; should fix but won't break immediately | Stale data, inconsistent naming, authority drift between docs |
| **INFO** | Style, improvement suggestions, minor observations | Verbose phrasing, optional compression, cosmetic issues |

## Verdict Definitions

| Verdict | Meaning |
|---------|---------|
| **PASS** | All changes are correct. No findings, or only INFO-level findings that don't need action. |
| **PASS_WITH_CHANGES** | Changes are fundamentally sound, but CRITICAL/WARNING findings must be addressed before shipping. |
| **FAIL** | Fundamental approach is wrong. Not just missing details — the direction needs rethinking. |

---

## Key Rules

1. **Read code, not claims.** The request describes what the author THINKS they did. Your job is to verify what ACTUALLY happened by reading the files.
2. **Every finding needs a file:line reference.** No vague "the code seems off." Point to the exact location.
3. **Evidence over opinion.** Show what you found, not what you feel.
4. **If a review question is unanswerable** from the provided files, say so explicitly — don't guess.
5. **Be harsh.** The requesting agent asked for adversarial review. Earn it. Call out everything — missed edge cases, broken references, semantic drift, over-cutting, under-cutting, stale data, false claims in the request itself.
6. **Don't soften your language.** If something is good, say so briefly and move on. Spend your time on problems.
7. **Use this file's response template.** `providing-code-review` may inform your checklist, but its output format does not replace `# Code Review Response — Round {N}`.

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| Malformed `request.md` | Missing round number, no file list, or broken markdown structure | Report as CRITICAL finding. Don't guess intent — tell the requesting agent what's missing |
| Scope creep into unrelated code | Flagging pre-existing issues not touched by the diff | Restrict findings to changed files and their direct callers. Note pre-existing issues as INFO only |
| Stale review after fixes | Round N+1 review doesn't re-read files, just checks if Round N findings were "addressed" | Always re-read ALL files from scratch each round. New fixes can introduce new issues |
