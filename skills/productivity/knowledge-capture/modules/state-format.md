# Module: state file format

Load before any state file read or write (Phase 1 onward).

## Location

`~/.codex/knowledge-capture/<topic-slug>.md` — one file per capture session.
Create the directory if absent.

## Structure

```markdown
# Knowledge Capture: <topic>

- **Topic:** <domain / subject>
- **Audience:** <who reads the finished article>
- **Intent:** reference | runbook | architecture | onboarding
- **Scope (in):** <bullet list>
- **Scope (out):** <bullet list>
- **Source:** interview | conversation
- **Mode:** new | update | companion
- **Wiki Page ID:** <id, or "none yet">
- **Wiki Page URL:** <url, or "none yet">
- **Phase:** 1 | 1.5 | 2 | 2.5 | 3 | 4 | 5 | published | abandoned

## Coverage Matrix
<the coverage-matrix.md table, updated in place>

## Interview Log (append-only)
- Q1 / H1: <question or harvested claim>
  A1: <answer>  [sme-stated | inferred]
- Q2: ...
```

## Rules

- **Append-only interview log.** Never rewrite an entry; add a new one.
- **Phase is a single-field update.** Change only the `Phase:` line when advancing.
- On resume, read this file first — topic, phase, and source mode drive where to continue.
- On abandon, rename to `<topic-slug>.abandoned.md`.
