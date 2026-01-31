# Future Enhancements

> **Last Updated:** 2026-01-31
> **Status:** Planning / Pre-Implementation

This document tracks potential paths forward for superpowers-plus. Ideas here are **not committed** — they represent directions worth exploring.

---

## 1. Decoupled Reporting Superpower

**Problem:** Each skill currently handles its own telemetry (e.g., `perplexity-research` writes to `~/.codex/perplexity-stats.json`). This couples reporting logic to core functionality, making it harder to:
- Add new metrics without modifying skills
- Aggregate stats across skills
- Sync telemetry to GitHub for cross-machine visibility
- Analyze patterns across skill invocations

**Proposed Solution:** A dedicated `reporting` superpower that acts as a bookkeeper agent.

**Key Features:**
- Skills report outcomes to the reporting superpower (skill name, outcome, metadata)
- Reporting superpower aggregates, compiles, and periodically pushes to GitHub
- Configurable batch size (e.g., every 20 reports per skill)
- Decouples telemetry from core skill logic

**Benefits:**
- Skills become simpler (no stats management code)
- Centralized telemetry enables cross-skill analysis
- GitHub sync provides cross-machine visibility
- Easier to add new metrics without touching skills

**Status:** PRD, Design, and Test Spec in `reporting/` folder.

---

## 2. Feedback Loop Engineering Pattern

**Observation:** Our most effective superpowers share a common pattern:
1. **Trigger** — Automatic or manual invocation
2. **Execute** — Perform the skill's core function
3. **Evaluate** — Assess whether it helped (SUCCESS/PARTIAL/FAILURE)
4. **Track** — Record outcome for continuous improvement

**Opportunity:** Formalize this as a reusable pattern for all skills.

**Proposed Approach:**
- Create a `feedback-loop` template/mixin for skills
- Standardize evaluation criteria across skills
- Enable comparative analysis (which skills have highest success rates?)
- Identify skills that need improvement vs. deprecation

---

## 3. Skill Health Dashboard

**Problem:** No visibility into which skills are working well vs. struggling.

**Proposed Solution:** A local dashboard (or CLI command) that shows:
- Invocation counts per skill
- Success rates per skill
- Trend over time (improving? degrading?)
- Skills with zero invocations (dead code?)

**Implementation Options:**
- CLI: `./scripts/skill-health.sh` that reads all stats files
- Web: Simple HTML dashboard generated from stats
- Integration: Add to `verify-perplexity-setup.sh` pattern

---

## 4. Skill Deprecation Protocol

**Problem:** `reviewing-ai-text` is deprecated but still exists. No formal process for:
- Marking skills as deprecated
- Migrating users to replacement skills
- Eventually removing deprecated skills

**Proposed Protocol:**
1. Add `deprecated: true` to YAML frontmatter
2. Add `replacement: [skill-name]` to frontmatter
3. Skill emits warning when invoked
4. After N months, remove from repo

---

## 5. Cross-Skill Integration Patterns

**Observation:** Some skills naturally chain together:
- `detecting-ai-slop` → `eliminating-ai-slop`
- `resume-screening` → `detecting-ai-slop` → `phone-screen-prep`
- `perplexity-research` → `incorporating-research`

**Opportunity:** Formalize integration patterns so skills can:
- Declare dependencies on other skills
- Pass context between skills
- Share evaluation outcomes

---

## 6. Skill Versioning

**Problem:** Skills evolve but we have no version history. If a skill regresses, we can't easily rollback.

**Proposed Solution:**
- Add `version: X.Y.Z` to YAML frontmatter
- Maintain CHANGELOG.md per skill (or in skill folder)
- Tag releases in git for major skill updates

---

## Priority Order

| Enhancement | Impact | Effort | Priority |
|-------------|--------|--------|----------|
| Decoupled Reporting | High | Medium | **P0** |
| Feedback Loop Pattern | High | Low | **P1** |
| Skill Health Dashboard | Medium | Low | **P2** |
| Deprecation Protocol | Low | Low | **P3** |
| Cross-Skill Integration | Medium | High | **P4** |
| Skill Versioning | Low | Low | **P5** |

---

## Next Steps

1. Review PRD in `reporting/PRD.md`
2. Validate design in `reporting/DESIGN.md`
3. Implement reporting superpower
4. Migrate `perplexity-research` to use reporting superpower
5. Evaluate and iterate

---

## Contributing

To propose a new enhancement:
1. Add a section to this document
2. Include: Problem, Proposed Solution, Benefits, Status
3. If ready for implementation, create PRD/Design/Test docs

