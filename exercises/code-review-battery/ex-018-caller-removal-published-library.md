---
id: ex-018
title: "Exported function loses its only in-repo caller, but the repo is a published npm package"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [dead-code, caller-removal, published-library, severity-calibration, candidate-003]
expected_reviewers: [defect-finder]
graduated_pattern: candidate-003
---

## Context

`@acme/report-utils` is a published npm package (`publishConfig.access:
"public"`, registry `npmjs.org`), not an internal application repo. It
exports two date-formatting helpers from `format-date.ts`:
`formatDateLegacy()` (locale-formatted) and `formatDateIso()` (ISO 8601).
`package.json`'s `exports` map publishes an explicit `"./format-date"`
subpath, re-exposing the entire `format-date.ts` module -- including
`formatDateLegacy` -- as a public, external entry point independent of
whatever internally calls it.

The diff rewrites `renderReport()`'s only call to `formatDateLegacy()` to
call `formatDateIso()` instead. After the diff, `formatDateLegacy` has
zero call sites anywhere in this repo's source.

This is the same shape as ex-017 (a diff reroutes the only in-repo caller
of an exported function), but in a repo that IS a published library --
the exact case Caller Removal Trace's severity branch (`defect-finder.md`
step 4) exists to calibrate differently: a repo-scoped grep cannot rule
out an external consumer importing `formatDateLegacy` directly via the
published `./format-date` subpath, so the finding must downgrade to
Possible, not Important.

## Diff

```diff
diff --git a/src/index.ts b/src/index.ts
index 1111111..2222222 100644
--- a/src/index.ts
+++ b/src/index.ts
@@ -10,7 +10,7 @@ import { formatDateLegacy, formatDateIso } from './format-date'
 export function renderReport(entry: Entry) {
-  return `${entry.title}: ${formatDateLegacy(entry.createdAt)}`
+  return `${entry.title}: ${formatDateIso(entry.createdAt)}`
 }
```

## Context: unchanged files (present in the repo, NOT part of the diff)

```json
// package.json (unchanged by this diff)
{
  "name": "@acme/report-utils",
  "version": "3.1.0",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js",
    "./format-date": "./dist/format-date.js"
  },
  "publishConfig": { "access": "public", "registry": "https://registry.npmjs.org/" }
}
```

```ts
// src/format-date.ts (unchanged by this diff)
export function formatDateLegacy(d: Date): string {
  return d.toLocaleDateString('en-US')
}

export function formatDateIso(d: Date): string {
  return d.toISOString().slice(0, 10)
}
```

## Expected Findings

### Finding 1 (Caller Removal Trace -- severity calibration)

- **Severity:** Possible (NOT Important)
- **Reviewer:** defect-finder
- **File:** src/format-date.ts
- **Issue:** `formatDateLegacy()` has zero remaining call sites in this repo after the diff -- its only known caller, `renderReport()`, was rewritten to call `formatDateIso()` instead. Per Caller Removal Trace, this is a dead-code-introduced candidate. However, `package.json`'s `exports` map publishes an explicit `"./format-date"` subpath re-exposing the entire module externally, and `publishConfig.access` is `"public"` -- a documented, intentional external entry point a repo-scoped grep cannot rule out as a caller.
- **Category:** dead-code-introduced, severity-calibration, published-library
- **Reachability evidence:** Not found: grepped `src/index.ts` (post-diff body + import line) and `src/format-date.ts` (full file) for `formatDateLegacy(` call sites other than the declaration -- none remain. Found: `package.json`'s `exports` map, `"./format-date": "./dist/format-date.js"`, combined with `publishConfig.access: "public"` -- an external consumer outside this repo's grep scope could still import and call it directly.
- **Fix:** If `formatDateLegacy` is meant to be retired, remove it from `format-date.ts` AND drop (or deprecate) the `"./format-date"` subpath from `package.json`'s `exports`, treating this as a breaking change requiring a semver-major bump. If intentionally retained as a standalone public utility, no removal needed -- but the now-unused `formatDateLegacy` import in `src/index.ts` is a separate, local unused-import issue.

## Anti-Findings

- **Do NOT flag this at Important severity.** This is the exercise's entire point: the same dead-code shape as ex-017, but the published-library context must downgrade the severity, per `defect-finder.md` step 4's explicit caveat ("do not invert this").
- **Do NOT flag the unused `formatDateLegacy` import in `src/index.ts` as the primary finding** -- it's a real, separate, minor lint issue, but the primary Caller Removal Trace finding is about the exported symbol's external reachability, not the local import hygiene.
- Don't suggest removing the `"./format-date"` export subpath as the fix without first confirming `formatDateLegacy` has no external consumers -- that's a breaking-change decision for whoever owns this package's semver, not something to recommend unconditionally.

## Pass criteria

The exercise passes when Defect Finder flags `formatDateLegacy()` as a Caller Removal Trace candidate at **Possible** severity (not Important), explicitly citing `package.json`'s `exports`/`publishConfig` fields as the reason a repo-scoped grep can't prove non-use. Flagging at Important severity is a fail -- it means the severity-calibration branch (`defect-finder.md` step 4) was not applied.
