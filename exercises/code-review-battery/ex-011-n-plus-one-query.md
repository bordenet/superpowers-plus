---
id: ex-011
title: "Skill catalog endpoint loads full file content in a loop"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [performance, n-plus-one, observability, unbounded, performance-analyst]
expected_reviewers: [performance-analyst, defect-finder]
---

## Context

A new REST endpoint returns a catalog of all installed skills with metadata. It iterates over skill directories, reads each `skill.md` to extract frontmatter, and returns aggregated results. The implementation has several performance and observability anti-patterns that would degrade under real-world load (60+ skills).

## Diff

```diff
diff --git a/mcp/skill-catalog.js b/mcp/skill-catalog.js
index aaa1111..bbb2222 100644
--- /dev/null
+++ b/mcp/skill-catalog.js
@@ -0,0 +1,68 @@
+const fs = require('fs');
+const path = require('path');
+const yaml = require('js-yaml');
+
+/**
+ * Returns metadata for all installed skills.
+ * Called by MCP list_skills tool and REST /api/skills endpoint.
+ */
+function getSkillCatalog(skillDirs) {
+    const catalog = [];
+
+    for (const dir of skillDirs) {
+        const domains = fs.readdirSync(dir);
+
+        for (const domain of domains) {
+            const domainPath = path.join(dir, domain);
+            if (!fs.statSync(domainPath).isDirectory()) continue;
+
+            const skills = fs.readdirSync(domainPath);
+
+            for (const skill of skills) {
+                const skillPath = path.join(domainPath, skill);
+                if (!fs.statSync(skillPath).isDirectory()) continue;
+
+                const skillFile = path.join(skillPath, 'skill.md');
+                if (!fs.existsSync(skillFile)) continue;
+
+                const content = fs.readFileSync(skillFile, 'utf8');
+                const frontmatter = extractFrontmatter(content);
+
+                catalog.push({
+                    name: skill,
+                    domain: domain,
+                    description: frontmatter.description || '',
+                    triggers: frontmatter.triggers || [],
+                    companions: frontmatter.companions || [],
+                    fullContent: content,
+                    wordCount: content.split(/\s+/).length,
+                    charCount: content.length,
+                });
+            }
+        }
+    }
+
+    return catalog;
+}
+
+function extractFrontmatter(content) {
+    const match = content.match(/^---\n([\s\S]*?)\n---/);
+    if (!match) return {};
+    try {
+        return yaml.load(match[1]);
+    } catch {
+        return {};
+    }
+}
+
+module.exports = { getSkillCatalog };
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** performance-analyst
- **File:** mcp/skill-catalog.js:27
- **Issue:** N+1 filesystem reads. Each skill triggers a synchronous `readFileSync` inside a triple-nested loop. With 60+ skills across multiple source directories, this performs 60+ blocking I/O operations sequentially. In a Node.js server context, this blocks the event loop for the entire duration.
- **Category:** n-plus-one, blocking-io, event-loop
- **Fix:** Read files asynchronously with `fs.promises.readFile` + `Promise.all`, or cache the catalog on startup and invalidate on file changes.

### Finding 2

- **Severity:** Important
- **Reviewer:** performance-analyst
- **File:** mcp/skill-catalog.js:36
- **Issue:** `fullContent` stores the entire file content for every skill in the response. For 60+ skills averaging 200 lines each, this returns ~500KB+ of markdown text that callers likely don't need. The catalog endpoint should return metadata only, not full content.
- **Category:** unbounded-payload, memory
- **Fix:** Remove `fullContent` from the default response. Add an optional `?include=content` query parameter for callers that need it.

### Finding 3

- **Severity:** Minor
- **Reviewer:** performance-analyst
- **File:** mcp/skill-catalog.js:37
- **Issue:** `content.split(/\s+/).length` re-scans the entire file content just to count words. This is O(n) per skill, repeated 60+ times, for metadata that could be computed once and cached. Combined with retaining `fullContent`, the content is traversed twice.
- **Category:** unnecessary-computation, hot-path
- **Fix:** If word count is needed, compute it lazily or at install time and cache in a metadata file.

### Finding 4

- **Severity:** Minor
- **Reviewer:** performance-analyst
- **File:** mcp/skill-catalog.js (overall)
- **Issue:** No logging or timing instrumentation. If catalog generation takes >1s under load, operators have no visibility into the bottleneck. No error logging for individual skill parse failures — `extractFrontmatter` silently returns `{}`.
- **Category:** observability, silent-failure
- **Fix:** Add timing log (`catalog built in ${ms}ms for ${count} skills`). Log warnings for skills with unparseable frontmatter.

## Anti-Findings

- Don't flag synchronous `readdirSync`/`statSync` for directory listing — the overhead is in file content reads, not directory enumeration
- Don't suggest adding TypeScript types (out of scope)
- Don't flag the regex in `extractFrontmatter` as a performance issue (it's called per-file, not in a tight loop on the same content)
- Don't flag missing input validation on `skillDirs` — that's a correctness issue, not performance
