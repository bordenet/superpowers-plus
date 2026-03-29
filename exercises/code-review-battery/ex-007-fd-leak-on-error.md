---
id: ex-007
title: "File descriptor leak on JSON parse error path"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [resource-leak, error-handling, fd-leak, bash]
expected_reviewers: [defect-finder, guardian]
---

## Context

A backup function reads a state file, validates it, then writes a backup. The function opens the file descriptor early for locking, but the error path after JSON validation doesn't close it.

## Diff

```diff
diff --git a/tools/state-backup.sh b/tools/state-backup.sh
new file mode 100644
--- /dev/null
+++ b/tools/state-backup.sh
@@ -0,0 +1,42 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+STATE_FILE="${HOME}/.codex/workflow-state.json"
+BACKUP_DIR="${HOME}/.codex/backups"
+
+backup_state() {
+    local fd
+    mkdir -p "$BACKUP_DIR"
+
+    # Open file descriptor for advisory lock
+    exec {fd}<"$STATE_FILE"
+    flock -n "$fd" || {
+        echo "State file locked by another process" >&2
+        return 1
+    }
+
+    # Read and validate
+    local content
+    content=$(cat "$STATE_FILE")
+
+    if ! echo "$content" | jq empty 2>/dev/null; then
+        echo "ERROR: State file contains invalid JSON" >&2
+        return 1
+    fi
+
+    # Check for required fields
+    local version
+    version=$(echo "$content" | jq -r '.version // empty')
+    if [[ -z "$version" ]]; then
+        echo "ERROR: State file missing version field" >&2
+        return 1
+    fi
+
+    # Write backup
+    local backup_file="$BACKUP_DIR/state-$(date +%Y%m%d-%H%M%S).json"
+    echo "$content" > "$backup_file"
+
+    # Release lock
+    exec {fd}<&-
+    echo "Backup written: $backup_file"
+}
+
+backup_state "$@"
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** tools/state-backup.sh:23-24
- **Issue:** File descriptor `$fd` is not closed on the JSON validation error path (line 24 returns without closing). The `exec {fd}<&-` on line 39 is only reached on the happy path. Same leak on line 32 (missing version error path).
- **Category:** resource-leak, fd-leak
- **Fix:** Add `exec {fd}<&-` before each `return 1`, or use a trap: `trap "exec {fd}<&-" RETURN`

### Finding 2

- **Severity:** Minor
- **Reviewer:** defect-finder
- **File:** tools/state-backup.sh:13
- **Issue:** The `flock -n` failure path (line 15 `return 1`) also doesn't close the fd. While `flock` failed to acquire, the fd was still opened by `exec {fd}<` on line 12.
- **Category:** resource-leak, fd-leak

### Finding 3

- **Severity:** Minor
- **Reviewer:** guardian
- **File:** tools/state-backup.sh:36
- **Issue:** Backup filename uses second-precision timestamp. Two rapid calls in the same second would overwrite the previous backup silently.
- **Category:** data-loss, timestamp-collision

## Anti-Findings

- Don't flag `set -euo pipefail` (it's correct)
- Don't flag `jq empty` for validation (it's the standard idiom)
- Don't suggest using `mktemp` for the backup file (the timestamped name is intentional for human readability)
