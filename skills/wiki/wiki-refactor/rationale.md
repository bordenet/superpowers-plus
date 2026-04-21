# wiki-refactor — rationale & background

Context for `skill.md`. The procedural skill is self-sufficient; this file
captures success criteria, PRD-protection reasoning, and when to use the
full pipeline vs lighter alternatives.

## When to use the full pipeline

- Wiki needs structural overhaul: duplicated pages, broken navigation,
  inconsistent structure across sections
- Consolidating many small pages into fewer authoritative ones
- Reorganizing a wiki section after a large product or team change
- Not for single-page edits — use `wiki-orchestrator` or
  `tools/wiki-write.sh` instead

## Example invocation

```
Refactor the Engineering wiki: seed URL https://wiki.example.com/engineering
Goal: eliminate duplicate setup guides, consolidate runbooks, improve navigation
```

## Why PRD protection is atomic

Product Requirements Documents are source-of-truth artifacts owned by
product management. Refactoring them silently under cover of a "wiki
cleanup" would delete or rephrase authoritative product decisions. The
pipeline HALTs immediately on detection and requires the operator to
explicitly scope PRDs out before re-invoking.

## Success criteria

| Metric | Threshold |
|--------|-----------|
| Duplicate content resolved | ≥80% |
| Core concepts with single source | ≥90% |
| Pages passing 3-round review | ≥70% |
| PRD documents touched | **Zero** |
| Navigation depth to any concept | ≤3 clicks |

## Phase 1 scope cap rationale

>100 pages or >50k words is the boundary where a single agent session
risks context exhaustion mid-refactor. Operator confirmation above this
threshold forces a deliberate choice about scope narrowing or multi-session
strategy.

## Human checkpoint rationale

After Phase 4, the writing plan captures every page merge, delete, and
create. The cost of a bad plan is N pages of rewrites; the cost of a
five-minute operator review is negligible. No autonomous path past this
checkpoint.

## Companion skills

- **progressive-harsh-review** — review engine used in Phase 5
- **link-verification** — invoked in Phase 7 for cross-reference validation
- **wiki-secret-audit** — invoked in Phase 7 for credential scanning
- **wiki-content-coherence** — lighter-weight alternative for single-page edits
- **writing-skills** — prose standards applied in Phase 5 rewrites
