---
id: ex-003
title: "50-line callee trace cap truncates complex functions"
difficulty: 2
source_commit: 3688511
source_pr: 300
tags: [regression, context-truncation, defect-finder-gap]
expected_reviewers: [defect-finder]
---

## Context

The callee implementation trace feature was added to the battery to solve the #1 source of unreproducible findings: reviewers assuming callees behave as named instead of reading their implementation. The original implementation included full function bodies.

A subsequent commit changed the policy to cap callee bodies at 50 lines, supposedly for prompt budget reasons. This is a regression — it truncates context exactly when functions are complex enough to hide defects (functions with many branches, error paths, or cleanup logic).

## Diff

```diff
diff --git a/skills/engineering/code-review-battery/skill.md b/skills/engineering/code-review-battery/skill.md
--- a/skills/engineering/code-review-battery/skill.md
+++ b/skills/engineering/code-review-battery/skill.md
@@ -64,7 +64,7 @@ Sub-agents don't inherit your conversation context.
 - For every threshold comparison -> grep all PRODUCERS of values crossing it
 - For stateful code -> include full state type definition + transitions
 - For changed signatures -> include all callers
-- For every cross-module function CALLED in the diff -> include the full function body (callee implementation trace)
+- For every cross-module function CALLED in the diff -> include up to 50 lines of the function body (callee implementation trace — the #1 source of unreproducible findings is assuming callees behave as named)
 
 ```bash
 # Example: find all consumers of a field
```

## Expected Findings

### Finding 1
- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** skills/engineering/code-review-battery/skill.md
- **Issue:** The 50-line cap on callee implementation traces is a regression. Complex functions (>50 lines) with multiple error paths, cleanup branches, or state mutations are exactly the functions where context truncation causes the battery to miss defects. The cap removes context precisely when it's most needed.
- **Category:** regression, context-loss
- **Durable Check:** Add a principle to DESIGN.md: "Callee trace default is full body. Any cap requires evidence that truncated context didn't miss findings."

## Anti-Findings

- Don't flag the comment text about "unreproducible findings" — it's accurate context
- Don't suggest removing callee traces entirely (the feature is sound, the cap is the problem)
- Don't suggest a different cap number (the fix is restoring full body as default with intelligent compression fallback)
