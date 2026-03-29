---
id: ex-008
title: "Unsanitized skill name used in file path construction"
difficulty: 5
source_commit: synthetic
source_pr: null
tags: [security, path-traversal, injection, input-validation]
expected_reviewers: [guardian, defect-finder]
---

## Context

A skill lookup function takes a skill name from user input and constructs a file path to read the skill's configuration. The skill name is not sanitized, allowing path traversal.

## Diff

```diff
diff --git a/lib/skill-loader.js b/lib/skill-loader.js
index aaa1111..bbb2222 100644
--- a/lib/skill-loader.js
+++ b/lib/skill-loader.js
@@ -5,10 +5,18 @@ const SKILLS_DIR = path.join(process.env.HOME, '.codex', 'skills');
 /**
  * Load a skill's configuration by name.
  * @param {string} skillName - The skill to load (e.g., "think-twice")
- * @returns {object|null} Parsed skill config, or null if not found
+ * @returns {object} Parsed skill config
+ * @throws {Error} If skill not found
  */
-function loadSkill(skillName) {
-    const skillPath = path.join(SKILLS_DIR, skillName, 'skill.md');
+function loadSkill(skillName, options = {}) {
+    const baseDir = options.skillsDir || SKILLS_DIR;
+    const skillPath = path.join(baseDir, skillName, 'skill.md');
+
+    if (!fs.existsSync(skillPath)) {
+        throw new Error(`Skill not found: ${skillName}`);
+    }
+
     const content = fs.readFileSync(skillPath, 'utf8');
     return parseSkillFrontmatter(content);
 }
```

## Expected Findings

### Finding 1

- **Severity:** Critical
- **Reviewer:** guardian
- **File:** lib/skill-loader.js
- **Issue:** `skillName` is used directly in `path.join()` without sanitization. A caller passing `../../etc/passwd` or `../../../.ssh/id_rsa` as skillName would read arbitrary files. The `path.join()` call resolves `..` segments, enabling path traversal outside `SKILLS_DIR`.
- **Category:** path-traversal, injection
- **Fix:** Validate that the resolved path starts with `baseDir`: `if (!path.resolve(skillPath).startsWith(path.resolve(baseDir))) throw new Error('Invalid skill name');`

### Finding 2

- **Severity:** Important
- **Reviewer:** guardian
- **File:** lib/skill-loader.js
- **Issue:** The `options.skillsDir` parameter allows callers to override the base directory. Combined with the path traversal above, this doubles the attack surface — an attacker controlling both `skillsDir` and `skillName` can read any file.
- **Category:** security, excessive-flexibility

### Finding 3

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** lib/skill-loader.js
- **Issue:** The function signature changed from returning `null` on not-found to throwing an Error. All existing callers that check for `null` return value will now crash with an unhandled exception instead of gracefully handling missing skills.
- **Category:** breaking-change, contract-violation

## Anti-Findings

- Don't flag `fs.readFileSync` as blocking (sync is acceptable for config loading at startup)
- Don't flag `existsSync` + `readFileSync` as TOCTOU (the race window is negligible for config files)
- Don't suggest switching to async (out of scope for this change)
