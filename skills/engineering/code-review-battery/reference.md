# Code Review Battery -- Reference

Companion reference for `skill.md`. Holds material that reviewers
read but doesn't need to live in the main procedure body.

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| All reviewers agree | No disagreements found | Force second-order critique: each reviewer names >=1 plausible failure mode OR cites a specific property of the change explaining why none exists (e.g., "pure rename, no callers"). Generic dismissal is rubber-stamping. |
| Duplicate findings | Same issue from 3 reviewers | Deduplicate in synthesis, attribute first finder |
| Reviewer fatigue | Later reviewers less thorough | Randomize dispatch order |
| Missing source context | Review diff without callers | Include grep results for all touched functions |
| Over-scoping | Reviewing unchanged code | Focus on diff + directly impacted callers only |

## Failure Modes

| Failure | Fix |
|---------|-----|
| Sub-agent returns no findings on complex diff | Verify diff + source context was passed inline -- sub-agents have no conversation context |
| False positives from isolated diff review | Include source context (callers, field readers) per Phase 2 -- isolation is the #1 cause |
| Convergence never reached | Escalate to human after 3 passes |
| Monolith finds issues specialists missed | Log as gap-analysis candidate for specialist prompt improvement |

## See Also

- `skill.md` -- main procedure (Phases 0-6)
- `DESIGN.md` -- architecture rationale and validation results
- `PRD.md` -- product requirements
- `gap-analysis.md` -- candidate pattern pipeline for closing reviewer gaps
- `candidates/` -- graduated and proposed patterns
- `docs/cr-battery/finding-lifecycle-design.md` -- design problem for the deferred Finding Lifecycle flywheel (preservation ships in this MR; tagging + aggregation deferred)
