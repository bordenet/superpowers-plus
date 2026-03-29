---
id: ex-012
title: "Router dispatches function that is never imported or defined"
difficulty: 3
source_commit: synthetic
source_pr: null
tags: [undefined-reference, import-missing, runtime-crash, defect-finder]
expected_reviewers: [defect-finder]
---

## Context

A skill router gains a new `batch` mode that dispatches to a `batchDispatch` function. The function is called but never imported or defined in the file. This will throw `ReferenceError` at runtime when batch mode is selected. This is a simpler, more isolated version of the same class of bug in ex-006 (where an undefined `dispatchOrchestrator` was called).

## Diff

```diff
diff --git a/lib/skill-router.js b/lib/skill-router.js
index aaa1111..bbb2222 100644
--- a/lib/skill-router.js
+++ b/lib/skill-router.js
@@ -1,6 +1,7 @@
 const { matchSkill } = require('./skill-matcher');
 const { dispatchSingle } = require('./dispatcher');
 const { loadConfig } = require('./config');
+const { validateInput } = require('./validator');
 
 /**
  * Route an intent to the appropriate skill handler.
@@ -15,6 +16,12 @@ function routeIntent(intent, context) {
         return dispatchSingle(skill, context);
     }
 
+    if (config.batchMode && Array.isArray(intent.targets)) {
+        validateInput(intent.targets);
+        const results = batchDispatch(intent.targets, context);
+        return { mode: 'batch', results };
+    }
+
     return { error: 'no matching skill', intent: intent.query };
 }
 
```

## Expected Findings

### Finding 1

- **Severity:** Critical
- **Reviewer:** defect-finder
- **File:** lib/skill-router.js:20
- **Issue:** `batchDispatch` is called on line 20 but is never imported or defined in this file. `dispatchSingle` is imported from `./dispatcher` but `batchDispatch` is not. This will throw `ReferenceError: batchDispatch is not defined` at runtime whenever `config.batchMode` is true and `intent.targets` is an array.
- **Category:** undefined-reference, missing-import, runtime-crash
- **Fix:** Add `batchDispatch` to the import from `./dispatcher`: `const { dispatchSingle, batchDispatch } = require('./dispatcher');` — and verify it actually exists in that module.

## Anti-Findings

- Don't flag `validateInput` — it IS properly imported on line 4
- Don't flag the lack of error handling around `batchDispatch` — the function doesn't exist at all, which is the real issue
- Don't suggest adding TypeScript (out of scope)
