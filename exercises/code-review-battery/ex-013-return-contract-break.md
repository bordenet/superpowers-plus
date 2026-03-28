---
id: ex-013
title: "Function changes return-null contract to throw, breaking all callers"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [contract-break, error-handling, backwards-compat, caller-impact]
expected_reviewers: [defect-finder, guardian]
---

## Context

A utility function `findSkillByName` previously returned `null` when a skill was not found. A refactor changes it to throw an `Error` instead. The function is called in 3 places across the codebase — all check for `null` return. After this change, those callers will crash with an unhandled exception instead of gracefully handling the missing-skill case.

The diff shows only the utility function change. The callers are shown in the Context section (not in the diff) to simulate a real review where you must consider downstream impact.

**Callers (not shown in diff, but exist in the codebase):**
```javascript
// In skill-router.js:
const skill = findSkillByName(name);
if (skill === null) { return { error: 'not found' }; }

// In skill-catalog.js:
const meta = findSkillByName(requested);
if (!meta) { log.warn('Skill not in catalog:', requested); }

// In mcp/tools.js:
const s = findSkillByName(args.skill);
if (s == null) { return { content: [{ type: 'text', text: 'Unknown skill' }] }; }
```

## Diff

```diff
diff --git a/lib/skill-lookup.js b/lib/skill-lookup.js
index aaa1111..bbb2222 100644
--- a/lib/skill-lookup.js
+++ b/lib/skill-lookup.js
@@ -8,14 +8,14 @@ const skillCache = new Map();
  * Find a skill by its short name across all source directories.
- * Returns the skill metadata object, or null if not found.
+ * Returns the skill metadata object.
+ * @throws {Error} if the skill is not found.
  */
 function findSkillByName(name) {
     if (skillCache.has(name)) return skillCache.get(name);
 
     for (const dir of getSourceDirs()) {
         const skillPath = path.join(dir, '**', name, 'skill.md');
         const matches = glob.sync(skillPath);
         if (matches.length > 0) {
             const meta = parseSkillFile(matches[0]);
             skillCache.set(name, meta);
             return meta;
         }
     }
 
-    return null;
+    throw new Error(`Skill not found: ${name}`);
 }
```

## Expected Findings

### Finding 1
- **Severity:** Critical
- **Reviewer:** defect-finder or guardian
- **File:** lib/skill-lookup.js:24
- **Issue:** Return contract changed from `null` to `throw Error`. All 3 existing callers (skill-router.js, skill-catalog.js, mcp/tools.js) check for null/falsy return and handle gracefully. After this change, they will crash with unhandled exception. The JSDoc update documents the new behavior but doesn't fix the callers.
- **Category:** contract-break, backwards-compat, unhandled-exception
- **Fix:** Either (a) keep returning `null` and add an optional `{ throws: true }` parameter for callers that want the exception, or (b) update ALL 3 callers to wrap calls in try/catch. Option (a) is safer as it doesn't require coordinated changes.

### Finding 2
- **Severity:** Minor
- **Reviewer:** defect-finder
- **File:** lib/skill-lookup.js:11
- **Issue:** The cache stores found skills but never caches "not found" results. Repeated lookups for non-existent skills will re-scan all source directories every time, performing unnecessary filesystem I/O.
- **Category:** performance, negative-cache
- **Fix:** Cache negative results too: `skillCache.set(name, null)` before throwing/returning, with a TTL or invalidation on directory changes.

## Anti-Findings

- Don't flag the JSDoc update as misleading — it correctly describes the new behavior
- Don't flag `glob.sync` as a performance issue — it's called once per lookup, cached afterward
- Don't suggest converting to async — the sync API is intentional for this use case
