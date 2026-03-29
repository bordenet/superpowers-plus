---
id: ex-004
title: "Lock file uses writeFileSync instead of O_EXCL atomic create"
difficulty: 4
source_commit: 6477286
source_pr: 297
tags: [race-condition, security, lock-forgery, atomicity]
expected_reviewers: [defect-finder, guardian]
---

## Context

The workflow state system uses an advisory lock file to prevent concurrent writes. The original implementation used `fs.existsSync()` + `fs.writeFileSync()` — a classic TOCTOU (time-of-check-time-of-use) race condition. Between the existence check and the write, another process could create the lock file, and both processes would think they hold the lock.

Additionally, `releaseLock()` unconditionally deletes the lock file without checking PID ownership — any process could release another process's lock.

This is the ORIGINAL (buggy) code. The battery should catch both the TOCTOU race and the lock forgery.

## Diff

```diff
diff --git a/lib/workflow-state.js b/lib/workflow-state.js
new file mode 100644
--- /dev/null
+++ b/lib/workflow-state.js
@@ -0,0 +1,45 @@
+const fs = require('fs');
+const path = require('path');
+
+const STATE_FILE = path.join(process.env.HOME, '.codex', 'workflow-state.json');
+const LOCK_FILE = STATE_FILE + '.lock';
+const LOCK_TTL_MS = 5000;
+
+/**
+ * Acquire advisory lock. Returns true if acquired, false if held.
+ */
+function acquireLock() {
+    try {
+        if (fs.existsSync(LOCK_FILE)) {
+            const lockData = JSON.parse(fs.readFileSync(LOCK_FILE, 'utf8'));
+            const lockAge = Date.now() - lockData.ts;
+            if (lockAge < LOCK_TTL_MS) return false; // Still held
+            // Expired — reap it
+        }
+        fs.writeFileSync(LOCK_FILE, JSON.stringify({ pid: process.pid, ts: Date.now() }));
+        return true;
+    } catch (_) { return true; } // If lock check fails, proceed anyway (advisory)
+}
+
+function releaseLock() {
+    try { fs.unlinkSync(LOCK_FILE); } catch (_) {}
+}
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** defect-finder, guardian
- **File:** lib/workflow-state.js
- **Issue:** TOCTOU race condition in `acquireLock()`. Between `fs.existsSync()` returning false and `fs.writeFileSync()`, another process can create the lock file. Both processes will believe they hold the lock, leading to concurrent state file corruption.
- **Category:** race-condition, TOCTOU
- **Fix:** Use `fs.openSync(LOCK_FILE, O_WRONLY | O_CREAT | O_EXCL)` for atomic create-if-not-exists.

### Finding 2

- **Severity:** Important
- **Reviewer:** guardian
- **File:** lib/workflow-state.js
- **Issue:** `releaseLock()` unconditionally deletes the lock file without verifying PID ownership. Process A could release Process B's lock, allowing Process C to acquire it while Process B still thinks it holds the lock.
- **Category:** security, lock-forgery
- **Fix:** Read lock file, check `lockData.pid === process.pid` before deleting.

### Finding 3

- **Severity:** Minor
- **Reviewer:** defect-finder
- **File:** lib/workflow-state.js
- **Issue:** The catch block `catch (_) { return true; }` silently acquires the lock on any error. If the lock file is corrupted JSON, the function will proceed as if unlocked.
- **Category:** error-handling

### Finding 4 (Bonus — discovered by battery)

- **Severity:** Important
- **Reviewer:** guardian
- **File:** lib/workflow-state.js
- **Issue:** Stale-lock reaping uses TTL only, not owner liveness. A process whose critical section exceeds 5s (GC pause, slow I/O) can have its lock reaped while it's still writing.
- **Category:** race-condition, stale-detection
- **Fix:** Before reaping, check if the recorded PID is still alive via `process.kill(pid, 0)`.

## Anti-Findings

- Don't flag the advisory nature of the lock (it's intentional — documented as advisory)
- Don't suggest external lock libraries (the implementation should be self-contained)
- Don't flag `LOCK_TTL_MS = 5000` as too short (it's appropriate for fast operations)
