---
id: ex-006
title: "New enum value added to definition but not to all switch consumers"
difficulty: 5
source_commit: synthetic
source_pr: null
tags: [cross-file, enum-drift, incomplete-change, ripple-analysis]
expected_reviewers: [defect-finder, standards-enforcer]
---

## Context

A skill routing system dispatches skills by type. A new skill type `orchestrator` is being added. The type enum is defined in `lib/skill-types.js` and consumed by a switch statement in `lib/skill-router.js` and a validation function in `lib/skill-validator.js`. The diff adds the new enum value and updates the router but forgets the validator.

## Diff

```diff
diff --git a/lib/skill-types.js b/lib/skill-types.js
index aaa1111..bbb2222 100644
--- a/lib/skill-types.js
+++ b/lib/skill-types.js
@@ -3,6 +3,7 @@ const SKILL_TYPES = Object.freeze({
   ENGINEERING: 'engineering',
   PRODUCTIVITY: 'productivity',
   SECURITY: 'security',
+  ORCHESTRATOR: 'orchestrator',
   WRITING: 'writing',
   WIKI: 'wiki',
 });
diff --git a/lib/skill-router.js b/lib/skill-router.js
index ccc3333..ddd4444 100644
--- a/lib/skill-router.js
+++ b/lib/skill-router.js
@@ -22,6 +22,9 @@ function routeSkill(skill) {
     case SKILL_TYPES.SECURITY:
       return dispatchSecurity(skill);
 
+    case SKILL_TYPES.ORCHESTRATOR:
+      return dispatchOrchestrator(skill);
+
     case SKILL_TYPES.WRITING:
       return dispatchWriting(skill);
 
diff --git a/lib/skill-validator.js b/lib/skill-validator.js
index eee5555..fff6666 100644
--- a/lib/skill-validator.js
+++ b/lib/skill-validator.js
@@ -1,5 +1,6 @@
 const { SKILL_TYPES } = require('./skill-types');
 
+// Validates that a skill's type field is a known type
 function validateSkillType(skill) {
   const validTypes = [
     SKILL_TYPES.ENGINEERING,
```

## Expected Findings

### Finding 1
- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** lib/skill-validator.js
- **Issue:** The `validTypes` array in `validateSkillType()` was not updated to include `SKILL_TYPES.ORCHESTRATOR`. Skills with type `orchestrator` will pass routing but fail validation. The diff only adds a comment to the validator file, not the actual enum value.
- **Category:** incomplete-change, cross-file-consistency
- **Durable Check:** Add a test that asserts `validTypes` contains all values from `SKILL_TYPES`.

### Finding 2
- **Severity:** Minor
- **Reviewer:** defect-finder or standards-enforcer
- **File:** lib/skill-router.js
- **Issue:** `dispatchOrchestrator` is called but not shown as imported or defined. If it doesn't exist, this will throw a ReferenceError at runtime.
- **Category:** undefined-reference

## Anti-Findings

- Don't flag the alphabetical ordering of enum values (ORCHESTRATOR between SECURITY and WRITING is fine)
- Don't flag `Object.freeze` usage (it's correct for enum immutability)
- Don't suggest converting to TypeScript enums (out of scope)
