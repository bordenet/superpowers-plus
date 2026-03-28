# Pre-Phase Retrospective Template

> **When:** Before starting each phase (skip for the first phase).
> **Purpose:** Extract learnings from the completed phase and drive improvements into all upcoming phases.
> **Output:** Completed retro + rewritten upcoming TODOs with ≥2 substantive improvements distributed across remaining TODOs (where they add real value).

---

## Section 1: Review of Completed Phase

**Phase completed:** `#plan-<project> Phase N: <name>`

### What Went Well (keep doing)
<!-- List 2-3 specific things that worked. Be concrete — not "it went smoothly" but "breaking the API change into two commits caught a regression early." -->

1.
2.
3.

### What Didn't Go Well (stop or change)
<!-- List 2-3 specific things that caused friction, rework, or quality issues. -->

1.
2.
3.

### Harsh Review Findings
<!-- What did progressive harsh review surface that we didn't anticipate during planning? These are the most valuable learnings. -->

1.
2.
3.

---

## Section 2: Process and Quality Improvements

### Process Improvement
<!-- One concrete change to HOW we work on the next phase. Must be actionable, not aspirational. -->

- **Change:**
- **Why:** Based on [specific finding from Section 1]
- **Applied to:** [list which upcoming TODOs this affects]

### Quality Improvement
<!-- One concrete change to WHAT we check. A new gate, a sharper criterion, a different review focus. -->

- **Change:**
- **Why:** Based on [specific finding from Section 1]
- **Applied to:** [list which upcoming TODOs this affects]

---

## Section 3: Upcoming TODO Improvements

**Review ALL remaining TODOs in the `#plan-<project>` list.** Drive at minimum 2 substantive improvements across the set — distributed where they add real value. If a TODO genuinely needs no changes, state why and move on.

For projects with many remaining phases, focus improvement effort on the next 2-3 phases. Scan later phases for applicability but don't force changes into distant phases.

### TODO: `<ID> - <description>`

**Improvement (substantive):**
- What changed:
- Why (linked to retro finding):

**Harsh review of rewritten TODO:**
- Reviewed: [ ] yes
- Issues found and resolved:

### TODO: `<ID> - <description>` (no changes needed)
- Why: [specific reason this TODO doesn't benefit from current retro findings]

<!-- Repeat for each remaining TODO -->

---

## Substantive vs. Cosmetic (Calibration)

| Substantive (counts) | Cosmetic (does NOT count) |
|-----------------------|---------------------------|
| Adding a new success criterion based on a discovered failure mode | Rewording existing criteria |
| Changing the execution approach based on what worked/didn't | Fixing typos |
| Adding a guard against a specific risk discovered in harsh review | Reordering bullets |
| Splitting a phase that proved too large | Adding "be careful" notes |
| Removing a step that proved unnecessary | Adding emphasis markers |
| Changing deliverable format based on what was actually useful | Renaming tags |

---

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| "Everything went well, no changes needed" | If harsh review found nothing, the review was too shallow. Re-run. |
| Improvements are vague ("be more careful") | Must be specific and actionable ("add integration test for X") |
| Only improving the next TODO, not all remaining | Review and improve EVERY remaining TODO |
| Skipping harsh review of rewritten TODOs | Rewritten TODOs get reviewed too — changes can introduce new problems |
| Retro is copy-paste from previous retro | Each retro must reference specific findings from the phase just completed |
