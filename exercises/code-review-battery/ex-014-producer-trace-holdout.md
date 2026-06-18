---
id: ex-014
title: "Producer Trace FP holdout: indirect producers, enum-value-only-definitions, paired-symmetry"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [holdout, producer-trace, false-positive, observability]
expected_reviewers: [defect-finder, standards-enforcer]
tests_pattern: producer-trace
test_kind: fp-trap
---

## Context

FP-trap holdout for the Producer Trace / Dead Definition Detection
pattern in `skills/engineering/code-review-battery/reviewers/defect-finder.md`.
Exists to catch the case where the pattern over-fires on a diff that
LOOKS like it should trip the dead-definition check but doesn't,
because the producer exists via an escape hatch in step 4 or step 5
of the pattern.

The diff exercises every escape hatch in the Producer Trace pattern:

- Dynamic / computed producer (step 4 downgrade)
- Enum-value-only definition with no producer (step 5 default to
  "Possible: unreachable" Minor)
- Same-diff producer in a different file (the producer is in scope,
  just not co-located)
- Re-export of an already-emitted metric (the new "definition" is just
  re-exposure)

If the augmented Defect Finder over-fires, it will flag one of these
as a dead literal-pair-asymmetry Important. The holdout passes when
none of the four scenarios is flagged at Important severity by the
Producer Trace pattern.

## Diff

```diff
diff --git a/src/metrics-catalog.ts b/src/metrics-catalog.ts
index 1111111..2222222 100644
--- a/src/metrics-catalog.ts
+++ b/src/metrics-catalog.ts
@@ -10,4 +10,5 @@ export enum AgentSyncOutcome {
   Started = 'Started',
   Completed = 'Completed',
+  Cancelled = 'Cancelled',
 }
@@ -40,7 +41,15 @@ export const Metrics = Object.freeze({
   AgentSync: {
     Started: makeMetric('AgentSyncStarted'),
     Completed: makeMetric('AgentSyncCompleted'),
+    Cancelled: makeMetric('AgentSyncCancelled'),
+    TimedOut: makeMetric('AgentSyncTimedOut'),
+  },
+  // Re-export for the new dashboards module (single source of truth still
+  // lives in AgentSync; this is just a typed alias for dashboard consumers).
+  AgentSyncDashboard: {
+    Started: makeMetric('AgentSyncStarted'),
+    Completed: makeMetric('AgentSyncCompleted'),
   },
 });
diff --git a/src/agent-sync.ts b/src/agent-sync.ts
index 3333333..4444444 100644
--- a/src/agent-sync.ts
+++ b/src/agent-sync.ts
@@ -20,11 +20,21 @@ export class AgentSync {
   async run() {
     Metrics.AgentSync.Started.emit(1, { agentId: this.agentId });
     try {
-      await this.doWork();
+      const outcome = await this.doWork();
       Metrics.AgentSync.Completed.emit(1, { agentId: this.agentId });
+      // Dynamic emit covers Cancelled and TimedOut via a known-finite map.
+      const terminalKey: 'Cancelled' | 'TimedOut' | null = outcome.terminal;
+      if (terminalKey) {
+        Metrics.AgentSync[terminalKey].emit(1, { agentId: this.agentId });
+      }
     } catch (err) {
       throw err;
     }
   }
 }
diff --git a/src/agent-sync.test.ts b/src/agent-sync.test.ts
index 5555555..6666666 100644
--- a/src/agent-sync.test.ts
+++ b/src/agent-sync.test.ts
@@ -50,3 +50,11 @@ describe('AgentSync', () => {
     expect(emitSpy).toHaveBeenCalledWith(Metrics.AgentSync.Completed, 1, expect.anything());
   });
+
+  it('emits Cancelled on user-cancellation', async () => {
+    mockDoWork.mockResolvedValue({ terminal: 'Cancelled' });
+    await sync.run();
+    expect(emitSpy).toHaveBeenCalledWith(Metrics.AgentSync.Cancelled, 1, expect.anything());
+  });
 });
```

## Expected Findings

None from the Producer Trace pattern -- the diff is FP-trap-only for
that pattern.

The diff DOES contain legitimate adjacent defects that other Defect
Finder patterns may catch. These were not the design intent of the
holdout but are real and are recorded here per the catalog's
"bonus finding" rule (see `README.md`):

### Bonus Finding 1

- Severity: Important
- Reviewer: defect-finder
- File: src/agent-sync.ts:23
- Issue: `doWork()` previously had its return value ignored; the diff
  now reads `outcome.terminal`. If `doWork()` ever resolves to
  `undefined`, `null`, or any value lacking a `.terminal` property,
  this throws TypeError.
- Category: correctness, null-deref
- Pattern: Consumer Trace

### Bonus Finding 2

- Severity: Important
- Reviewer: defect-finder
- File: src/agent-sync.ts:30-32 (catch block in run())
- Issue: The exception path emits `Started` but no terminal metric
  (no Failed/Errored exists in the catalog, and the catch only
  rethrows). Started count will not reconcile with the sum of
  Completed+Cancelled+TimedOut, breaking any dashboard that assumes
  terminal symmetry.
- Category: error-handling, metric-symmetry
- Pattern: Success/Failure asymmetry (different from the four
  anti-finding scenarios below). This finding is about a missing
  `Failed` metric on the exception path, not about any of the four
  scenarios the pass criteria evaluates -- it cites a different
  file:line tuple than any anti-finding scenario.

### Bonus Finding 3

- Severity: Important
- Reviewer: defect-finder
- File: src/metrics-catalog.ts:12 (AgentSyncOutcome enum after the new Cancelled addition)
- Issue: `AgentSyncOutcome` enum gained `Cancelled` but not
  `TimedOut`, even though `TimedOut` is a valid terminal outcome per
  the new `terminal: 'Cancelled' | 'TimedOut' | null` contract. Any
  consumer mapping the `terminal` string back to the enum will get
  `undefined` for TimedOut.
- Category: cross-file-consistency, incomplete-enum
- Pattern: State Lifecycle Completeness

## Anti-Findings

The Producer Trace pattern must NOT fire on any of these scenarios:

1. **`AgentSync.Cancelled` / `TimedOut`** -- the producer is the
   dynamic emit at `agent-sync.ts` (`Metrics.AgentSync[terminalKey].emit`)
   with `terminalKey` typed as a known-finite literal union
   (`'Cancelled' | 'TimedOut' | null`). Per step 4 of the Producer
   Trace pattern in `defect-finder.md`, a known-finite computed key
   over the catalog is an indirect producer; if flagged at all,
   downgrade to "Possible: ...", NOT Important. The step-4 Exception
   (literal-vs-hypothetical asymmetry) does NOT apply here -- both
   `Started` and `Completed` are emitted via literal calls, and
   `Cancelled` / `TimedOut` have a real (typed-finite-union) producer,
   not a hypothetical one.
2. **`AgentSyncOutcome.Cancelled` (enum value)** -- per step 5, an
   enum value with no producer defaults to "Possible: unreachable"
   Minor, not Important. The reviewer must not promote it.
3. **`AgentSyncDashboard.Started` / `Completed`** -- these are re-
   exports. The original `AgentSync.Started` and `AgentSync.Completed`
   still have literal producers in `agent-sync.ts:21,24`. A re-
   exported definition is not a new dead symbol.
4. **`AgentSync.Cancelled` test emit** -- the test file at
   `agent-sync.test.ts:54-58` references the symbol; this is not a
   production producer but the symbol is reachable. Combined with the
   dynamic production emit, this is unambiguously not dead.

Don't flag the `Object.freeze` usage. Don't suggest converting the
dynamic emit to a switch statement -- the map style is intentional and
matches existing conventions.

## Pass criteria

The holdout passes when the augmented Defect Finder produces ZERO
findings at Important severity against any of these four file:line
scenarios from the anti-findings:

- `src/metrics-catalog.ts` lines defining `AgentSync.Cancelled` /
  `AgentSync.TimedOut` (anti-finding #1)
- `src/metrics-catalog.ts` lines defining the `AgentSyncOutcome.Cancelled`
  enum value (anti-finding #2)
- `src/metrics-catalog.ts` lines defining `AgentSyncDashboard.Started`
  / `AgentSyncDashboard.Completed` (anti-finding #3)
- `src/agent-sync.test.ts` lines referencing `AgentSync.Cancelled`
  (anti-finding #4)

Findings on OTHER file:line tuples are out-of-scope for this holdout's
pass/fail. In particular, the bonus findings above (which cite
different files / lines / patterns) do not affect the pass criteria.

Minor "Possible: unreachable" findings on the enum value (anti-finding
#2) are acceptable per step 5 of the Producer Trace pattern in
`defect-finder.md`.
