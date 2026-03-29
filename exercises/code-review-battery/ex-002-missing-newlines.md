---
id: ex-002
title: "Files missing trailing newlines + triggers array out of sync"
difficulty: 1
source_commit: 16a8d8d
source_pr: 289
tags: [standards, newline, yaml-sync, easy]
expected_reviewers: [standards-enforcer]
---

## Context

The code-review-battery was just shipped (PR #288). The battery then reviewed its own shipped code and found two issues: missing trailing newlines on 3 files, and a triggers array in skill.md YAML frontmatter that was out of sync with the INTENT_PATTERNS array in skill-router.js.

This is the diff of the original problematic files (before the fix). The battery should catch both issues.

## Diff

```diff
diff --git a/skills/engineering/code-review-battery/DESIGN.md b/skills/engineering/code-review-battery/DESIGN.md
--- a/skills/engineering/code-review-battery/DESIGN.md
+++ b/skills/engineering/code-review-battery/DESIGN.md
@@ -358,4 +358,4 @@ Triage gating is the primary cost control.

 **Phase 1c gate decision**: PASS. Precision >=90% on clean diffs (A), >=50% on
 complex diffs (B). Recall gap is addressable by running full battery (not just
-Defect Finder). No prompt iteration needed.
\ No newline at end of file
+Defect Finder). No prompt iteration needed.
diff --git a/skills/engineering/code-review-battery/PRD.md b/skills/engineering/code-review-battery/PRD.md
--- a/skills/engineering/code-review-battery/PRD.md
+++ b/skills/engineering/code-review-battery/PRD.md
@@ -186,4 +186,4 @@ The groupings were determined through a structured process:
 1. **Aggregation format**: Flat list by severity, or grouped by reviewer?
 2. **Reviewer model selection**: Should Performance Analyst use a more expensive model?
 3. **Project-specific config**: How should per-project reviewer settings be stored?
-4. **Incremental review**: Re-run only dimensions that found issues?
\ No newline at end of file
+4. **Incremental review**: Re-run only dimensions that found issues?
diff --git a/skills/engineering/code-review-battery/skill.md b/skills/engineering/code-review-battery/skill.md
--- a/skills/engineering/code-review-battery/skill.md
+++ b/skills/engineering/code-review-battery/skill.md
@@ -1,7 +1,7 @@
 ---
 name: code-review-battery
 source: superpowers-plus
-triggers: ["battery review", "run the battery", "parallel review", "parallel code review", "specialized review", "multi-agent review", "run all reviewers"]
+triggers: ["battery review", "run the battery", "parallel review", "parallel code review", "specialized review", "multi-agent review", "run all reviewers", "review battery", "five reviewer", "five-agent review"]
 anti_triggers: ["simple review", "quick review", "lint only"]
```

## Expected Findings

### Finding 1

- **Severity:** Minor
- **Reviewer:** standards-enforcer
- **File:** skills/engineering/code-review-battery/DESIGN.md, PRD.md
- **Issue:** Files end without a trailing newline. Violates project standard (AGENTS.md: "All files must end with exactly one newline").
- **Category:** standards-violation

### Finding 2

- **Severity:** Important
- **Reviewer:** standards-enforcer (or defect-finder)
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** triggers array in YAML frontmatter has 7 entries but INTENT_PATTERNS in skill-router.js has 10. Missing: "review battery", "five reviewer", "five-agent review". This means the skill won't be routed correctly for those phrases.
- **Category:** data-sync, routing-gap

## Anti-Findings

- The fix diff itself is clean — no issues with the added newlines or trigger entries
- Don't flag the anti_triggers array (it's correct)
- Don't flag the description or summary fields (they're fine)
