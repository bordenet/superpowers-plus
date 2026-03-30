---
id: ex-010
title: "Test mocks out the exact behavior it claims to verify"
difficulty: 5
source_commit: synthetic
source_pr: null
tags: [test-quality, mock-fidelity, false-confidence, standards-enforcer]
expected_reviewers: [standards-enforcer, defect-finder]
---

## Context

A test is added for the skill router's error handling. The test mocks `fs.existsSync` to return false, then asserts the router throws an error. But the mock replaces the exact function whose behavior the test is supposed to verify — the test passes regardless of whether the real `fs.existsSync` works correctly.

## Diff

```diff
diff --git a/tools/tests/test_skill_router_errors.js b/tools/tests/test_skill_router_errors.js
new file mode 100644
--- /dev/null
+++ b/tools/tests/test_skill_router_errors.js
@@ -0,0 +1,48 @@
+const assert = require('assert');
+const fs = require('fs');
+const path = require('path');
+
+// Test: Router throws when skill directory doesn't exist
+function testMissingSkillThrows() {
+    const originalExistsSync = fs.existsSync;
+
+    // Mock fs.existsSync to simulate missing skill
+    fs.existsSync = (p) => {
+        if (p.includes('nonexistent-skill')) return false;
+        return originalExistsSync(p);
+    };
+
+    try {
+        const { loadSkill } = require('../lib/skill-loader');
+        assert.throws(
+            () => loadSkill('nonexistent-skill'),
+            /Skill not found/
+        );
+        console.log('  ok: missing skill throws Error');
+    } finally {
+        fs.existsSync = originalExistsSync;
+    }
+}
+
+// Test: Router handles corrupted skill file gracefully
+function testCorruptedSkillFile() {
+    const originalReadFileSync = fs.readFileSync;
+
+    fs.existsSync = () => true;
+    fs.readFileSync = (p, enc) => {
+        if (p.includes('corrupted-skill')) return '{{not valid yaml';
+        return originalReadFileSync(p, enc);
+    };
+
+    try {
+        const { loadSkill } = require('../lib/skill-loader');
+        assert.throws(
+            () => loadSkill('corrupted-skill'),
+            /parse|invalid|yaml/i
+        );
+        console.log('  ok: corrupted skill file throws parse error');
+    } finally {
+        fs.readFileSync = originalReadFileSync;
+        fs.existsSync = require('fs').existsSync;
+    }
+}
+
+testMissingSkillThrows();
+testCorruptedSkillFile();
+console.log('PASS: skill router error tests');
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** standards-enforcer
- **File:** tools/tests/test_skill_router_errors.js:10-13
- **Issue:** Test mocks `fs.existsSync` to return false, then asserts `loadSkill` throws. But `loadSkill` uses `fs.existsSync` to check if the skill exists — the mock is replacing the exact behavior being tested. This test will pass even if `loadSkill` has no existence check at all (because the mock forces the "not found" path). The test proves the mock works, not the code.
- **Category:** mock-fidelity, tautological-test
- **Fix:** Use a real filesystem: create a temp dir with no skill file, point `loadSkill` at it, assert it throws. Or at minimum, verify the test fails when the existence check is removed from `loadSkill`.

### Finding 2

- **Severity:** Important
- **Reviewer:** standards-enforcer or defect-finder
- **File:** tools/tests/test_skill_router_errors.js:31-34
- **Issue:** `testCorruptedSkillFile` mocks BOTH `existsSync` (line 31, unconditionally returns true) and `readFileSync` (line 32). The `existsSync` mock is never restored properly — `fs.existsSync = require('fs').existsSync` on line 44 re-requires the module but gets the same mutated reference since `fs` is a singleton. The mock leaks to subsequent tests.
- **Category:** test-pollution, mock-leak
- **Fix:** Save `const originalExistsSync = fs.existsSync` before mocking and restore in `finally`.

### Finding 3

- **Severity:** Minor
- **Reviewer:** defect-finder
- **File:** tools/tests/test_skill_router_errors.js:17
- **Issue:** `require('../lib/skill-loader')` is inside the test function. Node.js caches `require` calls — the second test's `require` returns the cached module, which was loaded with the first test's mock still active. The module's closure captures the mocked `fs` reference from first load.
- **Category:** require-cache, test-isolation

## Anti-Findings

- Don't flag the lack of a test framework (raw assert is the repo convention)
- Don't flag the `try/finally` pattern (it's correct for mock cleanup)
- Don't suggest using jest/sinon (out of scope)
