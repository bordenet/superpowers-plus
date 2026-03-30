---
id: ex-009
title: "Config parser silently changes default behavior for existing users"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [backwards-compat, silent-behavior-change, defaults, design-critic]
expected_reviewers: [guardian, design-critic]
---

## Context

The `.env` parser adds support for a new `SKILL_MATCHING_MODE` variable. Previously, skill matching always used TF-IDF. The new code adds embedding-based matching as an option. But the default changes from `tfidf` to `embedding` when `OPENAI_API_KEY` is set — silently changing behavior for existing users who set that key for other purposes.

## Diff

```diff
diff --git a/lib/config.js b/lib/config.js
index aaa1111..bbb2222 100644
--- a/lib/config.js
+++ b/lib/config.js
@@ -12,7 +12,11 @@ function loadConfig() {
     return {
         issueTracker: env.ISSUE_TRACKER_TYPE || null,
         wikiPlatform: env.WIKI_PLATFORM || null,
-        skillMatchingMode: 'tfidf',
+        skillMatchingMode: env.SKILL_MATCHING_MODE || (env.OPENAI_API_KEY ? 'embedding' : 'tfidf'),
         perplexityKey: env.PERPLEXITY_API_KEY || null,
+        openaiKey: env.OPENAI_API_KEY || null,
+        embeddingModel: env.EMBEDDING_MODEL || 'text-embedding-3-small',
+        embeddingCacheTTL: parseInt(env.EMBEDDING_CACHE_TTL || '3600', 10),
     };
 }
```

## Expected Findings

### Finding 1

- **Severity:** Important
- **Reviewer:** guardian or design-critic
- **File:** lib/config.js
- **Issue:** Silent behavior change for existing users. Anyone with `OPENAI_API_KEY` set (possibly for other tools or Perplexity proxy) will have their skill matching silently switch from TF-IDF to embedding mode. This changes which skills activate for the same input, with no user notification or opt-in.
- **Category:** backwards-compat, silent-default-change
- **Fix:** Default should remain `tfidf` regardless of API key presence. Require explicit `SKILL_MATCHING_MODE=embedding` to opt in.

### Finding 2

- **Severity:** Minor
- **Reviewer:** defect-finder
- **File:** lib/config.js
- **Issue:** `parseInt(env.EMBEDDING_CACHE_TTL || '3600', 10)` will return `NaN` if the user sets `EMBEDDING_CACHE_TTL` to a non-numeric string. No validation or fallback for parse failure.
- **Category:** input-validation, NaN-propagation
- **Fix:** `const ttl = parseInt(env.EMBEDDING_CACHE_TTL, 10); embeddingCacheTTL: Number.isNaN(ttl) ? 3600 : ttl`

## Anti-Findings

- Don't flag the ternary expression as too complex (it's readable)
- Don't flag the missing `OPENAI_API_KEY` documentation (doc updates are separate)
- Don't suggest adding TypeScript types (out of scope)
