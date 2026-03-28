---
id: ex-001
title: "Installer excludes DESIGN.md/PRD.md in Stage 2 but not Stage 1"
difficulty: 3
source_commit: 11a8b56
source_pr: 300
tags: [installer, incomplete-fix, parallel-paths, convergent-finding]
expected_reviewers: [defect-finder, guardian]
---

## Context

The `install_skill()` function in `deploy.sh` installs skill files in two stages:
- **Stage 1**: Copy upstream companion files (for override skills)
- **Stage 2**: Copy override files on top

A decision was made to exclude process docs (DESIGN.md, PRD.md) from runtime installation. The exclusion was added to Stage 2 only. Stage 1 still copies these files from upstream, meaning override skills would get DESIGN.md/PRD.md installed despite the exclusion intent.

This is the diff that introduced the incomplete fix. The battery should catch that Stage 1 is missing the same exclusion logic.

## Diff

```diff
diff --git a/lib/install/deploy.sh b/lib/install/deploy.sh
index 1ccd538..702f592 100644
--- a/lib/install/deploy.sh
+++ b/lib/install/deploy.sh
@@ -90,10 +90,12 @@ install_skill() {
         # Stage 1: If override, copy upstream companion files first
         if [[ -n "$upstream_dir" ]]; then
             # Copy all upstream files EXCEPT the main skill file (SKILL.md/skill.md)
             local f
             while IFS= read -r -d '' f; do
                 local base
                 base=$(basename "$f")
                 # Skip the main skill file — the override replaces it
                 [[ "$base" == "SKILL.md" || "$base" == "skill.md" ]] && continue
                 cp "$f" "$dest/" || \
                     error_exit "Failed to stage upstream file $base for skill: $skill_name"
             done < <(find "$upstream_dir" -maxdepth 1 -type f -print0 2>/dev/null)
@@ -112,7 +114,11 @@ install_skill() {
         fi
 
         # Stage 2: Copy all override files on top (skill.md + any extras)
+        # Exclude process docs (DESIGN.md, PRD.md) — they're repo-only, not runtime
         while IFS= read -r -d '' f; do
+            local basename_f
+            basename_f=$(basename "$f")
+            [[ "$basename_f" == "DESIGN.md" || "$basename_f" == "PRD.md" ]] && continue
             cp "$f" "$dest/" || \
                 error_exit "Failed to install $(basename "$f") for skill: $skill_name"
         done < <(find "$skill_dir" -maxdepth 1 -type f -print0 2>/dev/null)
```

## Expected Findings

### Finding 1 (Convergent — Defect Finder + Guardian)
- **Severity:** Important
- **Reviewer:** defect-finder, guardian
- **File:** lib/install/deploy.sh
- **Issue:** Stage 1 (upstream companion copy) does not exclude DESIGN.md/PRD.md. The exclusion was only added to Stage 2. For override skills, Stage 1 will still copy process docs from the upstream skill directory, defeating the exclusion intent.
- **Category:** incomplete-fix, parallel-code-paths
- **Durable Check:** Add a test that verifies DESIGN.md/PRD.md are NOT present in installed skill directories after running the installer.

## Anti-Findings (should NOT be reported)

- Style nit about `basename_f` vs `base` variable naming (the inconsistency exists but is a Minor at best and the names are local to their loops)
- Suggesting `find --exclude` instead of the loop-and-skip pattern (valid design alternative but not a defect)
- Flagging the `error_exit` call as a potential issue (it's a defined function elsewhere)
