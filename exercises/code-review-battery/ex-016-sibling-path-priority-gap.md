---
id: ex-016
title: "New priority-override field wired into sync dispatch handler but not its async sibling"
difficulty: 5
source_commit: synthetic
source_pr: null
tags: [cross-file, sibling-paths, incomplete-fix, ripple-analysis, candidate-002]
expected_reviewers: [defect-finder, guardian]
graduated_pattern: candidate-002
---

## Context

A job-dispatch system routes jobs to workers using `job.routingKey`. Two
sibling handlers exist in the same directory, both currently reading
`routingKey` today: `dispatch-sync.ts` (synchronous, in-request dispatch)
and `dispatch-async.ts` (queued, background dispatch). A third file,
`dispatch-batch.ts`, handles bulk/batch jobs and intentionally does not
support per-job routing overrides at all (by design -- batch jobs are
always routed by a fixed batch-level key).

A new requirement: some jobs need to bypass normal routing and go to a
specific worker pool regardless of `routingKey`. The diff adds a new
`job.priorityOverride` field and updates `dispatch-sync.ts` to consult it
before falling back to `routingKey`. `dispatch-async.ts` -- the sibling
handler for the exact same job resource, in the same directory -- is not
touched by the diff and still only reads `routingKey`.

This is the cross-file, cross-function version of the sibling-path bug
family that `ex-001-stage-exclusion-gap.md` already covers in its
same-function, same-file form (two loops in one function, a few lines
apart). Here the two siblings are separate files; there is no single diff
hunk that puts them side by side, and `dispatch-async.ts` is not present
in the diff at all. A reviewer must recognize that `priorityOverride`
partially supersedes `routingKey` -- a field with TWO existing readers
today -- and check whether both readers got the update, not just look at
what the diff touched.

## Diff

```diff
diff --git a/src/dispatch/dispatch-sync.ts b/src/dispatch/dispatch-sync.ts
index 1111111..2222222 100644
--- a/src/dispatch/dispatch-sync.ts
+++ b/src/dispatch/dispatch-sync.ts
@@ -10,8 +10,13 @@ export class SyncDispatcher {
   dispatch(job: Job): WorkerPool {
-    const pool = this.poolByRoutingKey.get(job.routingKey)
-    if (!pool) {
-      throw new Error(`No worker pool for routing key ${job.routingKey}`)
+    let pool: WorkerPool | undefined
+    if (job.priorityOverride) {
+      pool = this.poolByPriorityKey.get(job.priorityOverride)
+    }
+    if (!pool) {
+      pool = this.poolByRoutingKey.get(job.routingKey)
+    }
+    if (!pool) {
+      throw new Error(`No worker pool for routing key ${job.routingKey}`)
     }
     return pool
   }
diff --git a/src/dispatch/job-types.ts b/src/dispatch/job-types.ts
index 3333333..4444444 100644
--- a/src/dispatch/job-types.ts
+++ b/src/dispatch/job-types.ts
@@ -4,6 +4,7 @@ export interface Job {
   id: string
   routingKey: string
+  priorityOverride?: string
   payload: unknown
 }
```

## Context: unchanged sibling file (present in the repo, NOT part of the diff)

```ts
// src/dispatch/dispatch-async.ts (unchanged by this diff)
export class AsyncDispatcher {
  enqueue(job: Job): void {
    const pool = this.poolByRoutingKey.get(job.routingKey)
    if (!pool) {
      throw new Error(`No worker pool for routing key ${job.routingKey}`)
    }
    this.queue.push({ job, pool })
  }
}
```

```ts
// src/dispatch/dispatch-batch.ts (unchanged by this diff -- intentionally out of scope, see Anti-Findings)
export class BatchDispatcher {
  dispatchBatch(batch: Job[]): void {
    const pool = this.poolByRoutingKey.get(batch[0].routingKey)
    // Batch jobs are always routed by the first job's routingKey by design;
    // per-job overrides are explicitly not supported for batch dispatch.
    for (const job of batch) this.pool_assign(job, pool)
  }
}
```

## Expected Findings

### Finding 1 (Sibling Path Trace)

- **Severity:** Important
- **Reviewer:** defect-finder (Sibling Path Trace), guardian (Sibling path trace / blast radius)
- **File:** src/dispatch/dispatch-async.ts
- **Issue:** `AsyncDispatcher.enqueue()` is a structurally-parallel sibling of `SyncDispatcher.dispatch()` -- both read `job.routingKey` today to resolve a worker pool for the same `Job` resource. The diff adds `job.priorityOverride`, a field that partially supersedes `routingKey`, and wires it into the sync dispatcher only. The async dispatcher still only consults `routingKey`, so a job queued for async dispatch silently ignores its priority override -- the same class of routing defect the diff was written to fix, just on the untouched path.
- **Category:** incomplete-fix, cross-file-sibling-gap
- **Reachability evidence:** `Found:` `dispatch-async.ts` reads `job.routingKey` only, no `priorityOverride` reference anywhere in the file -- this is the untouched-sibling gap. `Not found:` no unaddressed sibling gap in `dispatch-batch.ts` (reads `job.routingKey` only, but comment confirms per-job overrides are explicitly out of scope for batch dispatch by design).
- **Durable Check:** Add a test that enqueues a job with `priorityOverride` set via `AsyncDispatcher` and asserts it resolves to the priority pool, not the routing-key pool.

## Anti-Findings

- **`dispatch-batch.ts` is NOT a finding.** `BatchDispatcher` is a sibling file sharing the naming convention and the same directory, but it explicitly does not support per-job routing at all, by design (batch jobs route by the first job's key). Flagging it would be over-firing the Sibling Path Trace pattern on a file that shares a naming pattern but not the underlying concern -- see the pattern's "Do NOT over-fire" clause.
- **This is not a re-detection of `ex-001`.** `ex-001` is a same-function, same-file gap (two loops in `install_skill()`, a few lines apart, no field being set/read) that general Defect Finder vigilance already catches by reading the whole diff; nothing new was needed there. This exercise's gap is cross-file (`dispatch-async.ts` never appears in the diff at all) and requires the new Sibling Path Trace pattern specifically -- a reviewer that only reads the diff's own hunks has no textual reason to open `dispatch-async.ts`.
- Don't flag `job-types.ts` making `priorityOverride` optional (`?:`) as a design issue -- optional is correct here, not every job needs an override.
- Don't suggest merging `SyncDispatcher` and `AsyncDispatcher` into one class -- that's a valid design alternative but out of scope for a defect review, and would be a Design Critic over-scoping violation (pre-existing structure, not introduced by this diff).

## Pass criteria

The exercise passes when Defect Finder (or Guardian) names both sibling files it checked (`dispatch-async.ts` and `dispatch-batch.ts`) per the Sibling Path Trace evidentiary requirement (`defect-finder.md` step 5), flags `dispatch-async.ts` as an untouched sibling missing the `priorityOverride` treatment, AND does not flag `dispatch-batch.ts` for the same reason.
