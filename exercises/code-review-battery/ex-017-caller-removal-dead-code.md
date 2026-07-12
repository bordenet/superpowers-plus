---
id: ex-017
title: "Retry-helper refactor reroutes all callers but leaves the old function behind, now dead"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [dead-code, caller-removal, refactor, candidate-003]
expected_reviewers: [defect-finder]
graduated_pattern: candidate-003
---

## Context

`retry-helpers.ts` exports three functions: `retryWithBackoff()` (fixed
exponential backoff), `retryWithJitter()` (backoff plus randomized
jitter, calls the shared `computeBackoffMs()` helper), and
`retryWithBackoffLegacy()` (an older strategy kept only for a
string-keyed strategy registry used by a plugin system,
`RETRY_STRATEGIES['legacy']`).

The diff migrates all three call sites of `retryWithBackoff()` (in
`worker.ts`, `sync-job.ts`, `webhook-sender.ts`) to call
`retryWithJitter()` instead, because jitter avoids thundering-herd
retries. The diff does not delete `retryWithBackoff()` itself.

## Diff

```diff
diff --git a/src/worker.ts b/src/worker.ts
index 1010101..2020202 100644
--- a/src/worker.ts
+++ b/src/worker.ts
@@ -12,7 +12,7 @@ import { retryWithBackoff, retryWithJitter } from './retry-helpers'
 async function processJob(job: Job) {
-  return retryWithBackoff(() => runJob(job), { maxAttempts: 3 })
+  return retryWithJitter(() => runJob(job), { maxAttempts: 3 })
 }
diff --git a/src/sync-job.ts b/src/sync-job.ts
index 3030303..4040404 100644
--- a/src/sync-job.ts
+++ b/src/sync-job.ts
@@ -8,7 +8,7 @@ import { retryWithBackoff, retryWithJitter } from './retry-helpers'
 function syncOne(record: Record) {
-  return retryWithBackoff(() => pushRecord(record), { maxAttempts: 5 })
+  return retryWithJitter(() => pushRecord(record), { maxAttempts: 5 })
 }
diff --git a/src/webhook-sender.ts b/src/webhook-sender.ts
index 5050505..6060606 100644
--- a/src/webhook-sender.ts
+++ b/src/webhook-sender.ts
@@ -20,7 +20,7 @@ import { retryWithBackoff, retryWithJitter } from './retry-helpers'
 async function sendWebhook(url: string, body: string) {
-  return retryWithBackoff(() => post(url, body), { maxAttempts: 4 })
+  return retryWithJitter(() => post(url, body), { maxAttempts: 4 })
 }
```

## Context: unchanged file (present in the repo, NOT part of the diff)

```ts
// src/retry-helpers.ts (unchanged by this diff)
export function computeBackoffMs(attempt: number): number {
  return Math.min(30_000, 2 ** attempt * 100)
}

export function retryWithBackoff(fn: () => Promise<unknown>, opts: RetryOpts) {
  // ... uses computeBackoffMs() internally, no jitter
}

export function retryWithJitter(fn: () => Promise<unknown>, opts: RetryOpts) {
  // ... uses computeBackoffMs() internally, adds Math.random() jitter
}

export function retryWithBackoffLegacy(fn: () => Promise<unknown>, opts: RetryOpts) {
  // ... older strategy, no longer called directly anywhere
}
```

```ts
// src/strategy-registry.ts (unchanged by this diff)
import { retryWithBackoffLegacy } from './retry-helpers'

export const RETRY_STRATEGIES: Record<string, RetryFn> = {
  jitter: retryWithJitter,
  legacy: retryWithBackoffLegacy,
}

// invoked elsewhere as: RETRY_STRATEGIES[plugin.strategyName](fn, opts)
```

## Expected Findings

### Finding 1 (Caller Removal Trace)

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** src/retry-helpers.ts
- **Issue:** `retryWithBackoff()` had exactly three call sites before this diff (`worker.ts`, `sync-job.ts`, `webhook-sender.ts`); this diff rewrites all three to call `retryWithJitter()` instead and does not delete `retryWithBackoff()`. Grep of the full source after the diff finds zero remaining references to `retryWithBackoff(` outside its own declaration and export statement -- it is exported (public across the module) but has no caller anywhere, dead code introduced by this diff's refactor.
- **Category:** dead-code-introduced, refactor-cleanup
- **Reachability evidence:** Found: none. Not found: not found in: worker.ts, sync-job.ts, webhook-sender.ts, retry-helpers.ts (declaration only), strategy-registry.ts (references `retryWithBackoffLegacy`, a different symbol).
- **Durable Check:** Add a lint rule or CI check that flags exported functions with zero call sites across the repo (excluding declaration/export lines and dynamic-dispatch registries).

## Anti-Findings

- **`computeBackoffMs()` is NOT dead code.** It's still called from inside `retryWithJitter()`, which is now the live path for all three original call sites. Do not flag it just because the diff touches its neighbors.
- **`retryWithBackoffLegacy()` is NOT dead code**, even though it also has zero *literal* call sites in the diff or the migrated files. It's reached dynamically via `RETRY_STRATEGIES['legacy']` in `strategy-registry.ts` -- a string-keyed dispatch table. Per the Caller Removal Trace's dynamic-caller downgrade rule (mirroring Producer Trace step 4), this must be downgraded to "Possible: ..." at most, not asserted as dead code. This is the exercise's primary false-positive trap.
- **Do not conflate this with Dead Catch Verification.** There is no `try`/`catch` anywhere in this diff; that pattern doesn't apply here and shouldn't be cited.
- **Do not conflate this with dead code a reviewer itself might suggest adding** (e.g. a defensive catch block around a callee that already swallows its own errors). This finding is about dead code the diff's *author* left behind during a refactor -- a different mechanism, different owner (the engineer, not the reviewer).
- Don't suggest renaming `retryWithJitter` back to `retryWithBackoff` to avoid the migration -- that's a valid alternative but not a defect, and orthogonal to the dead-code finding.

## Pass criteria

The exercise passes when Defect Finder flags `retryWithBackoff()` as dead-code-introduced-by-this-diff (Important, with reachability evidence), and does NOT flag `retryWithBackoffLegacy()` at Important/Critical (the dynamic-dispatch anti-finding) or misattribute the finding to Dead Catch Verification.

## Severity calibration note

This exercise assumes `retry-helpers.ts` lives in an internal application repo (no `package.json` publish metadata), so `retryWithBackoff()`'s orphaning is flagged **Important**. The opposite case -- the repo IS a published library, so the same finding must downgrade to **Possible** -- is validated as its own standalone exercise, `ex-018-caller-removal-published-library.md`, rather than folded in here as prose.
