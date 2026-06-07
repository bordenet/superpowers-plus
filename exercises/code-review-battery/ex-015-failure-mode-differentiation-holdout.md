---
id: ex-015
title: "Failure-mode differentiation FP holdout: alert-fatigue, single-provider, non-alarm-feeding"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [holdout, failure-mode, alarm-feeding, false-positive]
expected_reviewers: [guardian]
tests_pattern: failure-mode-differentiation
test_kind: fp-trap
---

## Context

FP-trap holdout for the Failure-mode Differentiation / Alarm-Feeding
Isolation pattern in `skills/engineering/code-review-battery/reviewers/guardian.md`
section 2a. Exists to catch the case where the pattern over-fires
and demands a new metric/alarm/runbook for a diff where the
on-call response is identical to the generic failure path
(alert-fatigue carve-out), where the system is single-provider
(multi-provider predicate inapplicable), or where the emit isn't
alarm-feeding.

The pattern carries explicit anti-fire conditions:

- "If the response is identical to the generic case, do NOT demand a
  new alarm (alert fatigue)."
- Multi-provider predicate coverage matters only when the system has
  multiple providers.
- Alarm-feeding isolation matters only when an emit feeds an alarm.

This diff exercises all three negatives. If the augmented Guardian
over-fires, it will demand a new metric/alarm where none is warranted.

## Diff

```diff
diff --git a/src/llm-client.ts b/src/llm-client.ts
index 1111111..2222222 100644
--- a/src/llm-client.ts
+++ b/src/llm-client.ts
@@ -8,6 +8,7 @@ const PROVIDER = 'anthropic';   // single-provider system; no multi-provider matrix
 
 export class LlmClient {
   async complete(prompt: string): Promise<string> {
+    const startTime = Date.now();
     try {
       const res = await this.transport.post('/v1/messages', { prompt });
       return res.body.completion;
@@ -16,12 +17,28 @@ export class LlmClient {
       // generic transport failure -- same runbook as any other LLM error.
       Metrics.LlmRequestFailure.emit(1, { provider: PROVIDER });
       throw new LlmRequestError(err.message);
+    } finally {
+      // Latency telemetry. Not an alarm-feeding metric; the SLO dashboard
+      // reads this directly from the histogram, no derived alarm exists.
+      Metrics.LlmRequestLatencyMs.observe(Date.now() - startTime, { provider: PROVIDER });
     }
   }
+
+  // New: surface a typed error for transient network blips. The on-call
+  // response is identical to the generic failure path (retry, then page if
+  // the broader LlmRequestFailureTotal alarm trips). No dedicated alarm.
+  async completeWithRetry(prompt: string, attempts = 3): Promise<string> {
+    for (let i = 0; i < attempts; i++) {
+      try { return await this.complete(prompt); }
+      catch (e) {
+        if (e instanceof LlmRequestError && i < attempts - 1) continue;
+        throw e;
+      }
+    }
+    throw new LlmRequestError('exhausted attempts');
+  }
 }
diff --git a/src/errors.ts b/src/errors.ts
index 3333333..4444444 100644
--- a/src/errors.ts
+++ b/src/errors.ts
@@ -10,3 +10,9 @@ export class LlmRequestError extends Error {
   constructor(public readonly cause: string) { super(cause); }
 }
+
+// Distinct shape for telemetry/log filtering only -- same runbook, same
+// owner, same severity. Folded into LlmRequestFailureTotal upstream by
+// intent (see RFC-0042: transient retries are not separately actionable).
+export class LlmTransientNetworkError extends LlmRequestError {
+  readonly transient = true;
+}
```

## Expected Findings

None from the Failure-mode Differentiation / Alarm-Feeding pattern.
The diff is FP-trap-only.

Adjacent concerns (e.g., `completeWithRetry`'s lack of an exponential
backoff) may be legitimately flagged by other reviewer dimensions;
those are out of scope for this holdout's pass/fail.

## Anti-Findings

Section 2a of `guardian.md` must NOT fire on any of these scenarios:

1. **`LlmTransientNetworkError`** -- the new error subclass has the
   same runbook, same owner, same severity as the parent
   `LlmRequestError`. The on-call response is identical (retry, then
   page on aggregate). Per the explicit alert-fatigue carve-out in the
   pattern, the reviewer must NOT demand a dedicated metric, alarm,
   or runbook. Flagging this as a missing-dimensioned-emit is the
   exact FP class the alert-fatigue carve-out was designed to avoid.
2. **`completeWithRetry` retry behaviour** -- internal retries that
   re-throw the same error type do not constitute a separately-
   actionable failure mode. No new alarm warranted.
3. **Single-provider multi-provider check** -- the system runs against
   a single provider (`const PROVIDER = 'anthropic'`). The multi-
   provider predicate coverage requirement does not apply. The
   reviewer must NOT demand coverage for OpenAI / Bedrock / etc. error
   shapes when only one provider is in scope.
4. **`LlmRequestLatencyMs` in `finally`** -- this is a latency
   observation, not an alarm-feeding emit. The alarm-feeding-isolation
   rule applies to metrics that DO feed alarms; this one does not.
   Putting it in `finally` is correct hygiene, not a sign of
   alarm-feeding intent.

Don't flag the `Date.now()` source -- it's the standard latency
idiom. Don't suggest replacing the for-loop retry with a library
unless backwards-compat is broken (it isn't).

## Pass criteria

The holdout passes when the augmented Guardian produces ZERO findings
at Important severity against any of these four file:line scenarios
from the anti-findings:

- `src/errors.ts` lines defining `LlmTransientNetworkError` (anti-finding #1)
- `src/llm-client.ts` lines defining `completeWithRetry` (anti-finding #2)
- `src/llm-client.ts` lines around `const PROVIDER = 'anthropic'` (anti-finding #3)
- `src/llm-client.ts` lines around `Metrics.LlmRequestLatencyMs.observe` in `finally` (anti-finding #4)

Findings on OTHER file:line tuples are out-of-scope for this holdout's
pass/fail. Severity matters: only Important (or higher) findings
against the four scenarios fail the holdout. Minor or "Possible: ..."
findings on the same scenarios are acceptable -- they preserve
reviewer judgment without conflating it with the alarm-feeding pattern's
intended scope.
