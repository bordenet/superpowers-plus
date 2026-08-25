---
id: ex-019
title: "A diff removes a field's last writer (stale reader survives) and, separately, another field's last reader (write-only survives)"
difficulty: 4
source_commit: synthetic
source_pr: null
tags: [dead-code, field-reference, stale-read, write-only, candidate-005]
expected_reviewers: [defect-finder]
graduated_pattern: candidate-005
---

## Context

An order-processing module tracks two fields on `Order`: `discountCode` (a
promo code applied at checkout) and `rawPayload` (the original,
unparsed webhook payload from the payment provider, kept for a
receipt-email fallback).

The diff replaces the old promo-code system with a new one. It removes
the only code path that WROTE `order.discountCode` (promo codes are now
resolved and applied directly at checkout, not stored on the order),
but does not remove `receipt-email.ts`'s existing read of
`order.discountCode` for the "you saved $X" line in the receipt email.

Separately, in the same diff, a refactor of the webhook parser removes
the only code path that READ `order.rawPayload` (the receipt-email
fallback that used to parse it for a missing-field case was replaced
with a dedicated `order.paymentMethodLast4` field), but the webhook
handler still WRITES `order.rawPayload` on every incoming webhook.

## Diff

```diff
diff --git a/src/checkout.ts b/src/checkout.ts
index 1111111..2222222 100644
--- a/src/checkout.ts
+++ b/src/checkout.ts
@@ -20,9 +20,8 @@ export function applyPromoCode(order: Order, code: string): PricedOrder {
   const promo = resolvePromoCode(code)
   const discountedTotal = order.total - promo.discountAmount
-  order.discountCode = code
   return { ...order, total: discountedTotal }
 }
diff --git a/src/receipt-email.ts b/src/receipt-email.ts
index 3333333..4444444 100644
--- a/src/receipt-email.ts
+++ b/src/receipt-email.ts
@@ -15,10 +15,6 @@ export function renderReceipt(order: Order): string {
   const lines = [`Order ${order.id}`, `Total: ${formatCents(order.total)}`]
-  if (order.rawPayload) {
-    const missing = extractMissingFieldsFromRawPayload(order.rawPayload)
-    if (missing.length > 0) lines.push(`Note: ${missing.join(', ')}`)
-  }
+  if (order.paymentMethodLast4) {
+    lines.push(`Paid with card ending ${order.paymentMethodLast4}`)
+  }
   return lines.join('\n')
 }
```

## Context: unchanged files (present in the repo, NOT part of the diff)

```ts
// src/types.ts (unchanged by this diff -- full relevant fields)
export interface Order {
  id: string
  total: number
  discountCode?: string
  rawPayload?: string
  paymentMethodLast4?: string
}
```

```ts
// src/receipt-email.ts (unchanged portion, still present after the diff)
export function renderReceipt(order: Order): string {
  const lines = [`Order ${order.id}`, `Total: ${formatCents(order.total)}`]
  if (order.discountCode) {
    lines.push(`Promo applied: ${order.discountCode}, you saved!`)
  }
  // ... (the rawPayload block shown in the diff above is what's being removed)
  return lines.join('\n')
}
```

```ts
// src/webhook-handler.ts (unchanged by this diff -- still writes rawPayload on every webhook)
export function handleWebhook(payload: RawWebhookPayload, order: Order): Order {
  return { ...order, rawPayload: JSON.stringify(payload), paymentMethodLast4: payload.card?.last4 }
}
```

## Expected Findings

### Finding 1 (Field Reference Trace -- stale-read shape)

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** src/checkout.ts, src/receipt-email.ts
- **Issue:** The diff removes the only code path that WRITES `order.discountCode` (`applyPromoCode` no longer sets it). `receipt-email.ts`'s `renderReceipt()` still READS `order.discountCode` (`if (order.discountCode) { lines.push('Promo applied...') }`) -- this is a surviving reference, NOT zero references, so it is not "dead code" in the classic sense. It is a stale-read defect: `discountCode` will now always be `undefined` on every order, so the "Promo applied" line silently never renders again, even for orders where a promo code WAS applied at checkout.
- **Category:** stale-read-risk, field-reference-trace
- **Reachability evidence:** Found (read, surviving): `src/receipt-email.ts` -- `if (order.discountCode) { ... }`. Not found (write): grepped `checkout.ts`, `receipt-email.ts`, `webhook-handler.ts`, `types.ts` for any remaining assignment to `discountCode` -- none found outside the removed line.
- **Durable Check:** Add a test that applies a promo code at checkout and asserts the receipt email includes the "Promo applied" line -- this would fail immediately on the current diff.

### Finding 2 (Field Reference Trace -- write-only shape)

- **Severity:** Important
- **Reviewer:** defect-finder
- **File:** src/receipt-email.ts, src/webhook-handler.ts
- **Issue:** The diff removes the only code path that READS `order.rawPayload` (the missing-fields fallback in `renderReceipt`). `webhook-handler.ts` still WRITES `order.rawPayload` on every webhook (`rawPayload: JSON.stringify(payload)`) -- this is dead code in the classic sense: the field is now computed and stored for nothing. `rawPayload` is a field on the exported `Order` interface in an application repo (no `package.json` publish metadata) -- per this pattern's severity ladder (mirroring Caller Removal Trace step 4), an exported/public field in a non-published-library app repo is Important, not Minor; Minor is reserved for a private/module-local field where nothing outside the file/module could plausibly read it.
- **Category:** dead-code-introduced, field-reference-trace
- **Reachability evidence:** Found (write, surviving): `src/webhook-handler.ts` -- `rawPayload: JSON.stringify(payload)`. Not found (read): grepped all files for any remaining read of `rawPayload` -- none found outside the removed block.
- **Durable Check:** Add a lint rule or periodic audit that flags a field written on every request path but never read anywhere, prompting either removal or documentation of why it's retained (e.g. for a future debugging need).

## Anti-Findings

- **Do NOT flag `paymentMethodLast4` as dead or orphaned.** It is both written (`webhook-handler.ts`) and read (the new line in `renderReceipt`) -- fully live, this diff's actual intended change.
- **Do NOT conflate Finding 1 with Caller Removal Trace.** `discountCode` is a field, not a function/exported symbol -- Caller Removal Trace's "grep for remaining references, zero = dead" algorithm does not apply here (references are NOT zero -- the reader survives). This is exactly why Field Reference Trace is a separate pattern with its own two-sided read/write check.
- **Do NOT conflate either finding with Consumer Trace.** Consumer Trace covers a field the diff explicitly SETS/RESETS/NULLS in the diff itself and traces the blast radius of that new value. Neither field here is assigned a new value by this diff -- the diff deletes an assignment/read path entirely. That is Field Reference Trace's territory, not Consumer Trace's.
- Don't suggest removing `discountCode`/`rawPayload` from the `Order` interface as "the fix" without first confirming no other consumer exists -- the fix should restore the missing side (a writer or a reader) or make an explicit, deliberate decision to deprecate the field, not silently declare victory by deleting the type.

## Pass criteria

The exercise passes when Defect Finder flags BOTH Finding 1 (stale-read, `discountCode`, Important) and Finding 2 (write-only, `rawPayload`, Important -- exported field, app repo, per the severity ladder), each correctly reasoned through the read/write reference-counting distinction (not "zero references" -- both fields have a surviving reference of the opposite kind), and does NOT flag `paymentMethodLast4` or misattribute either finding to Caller Removal Trace or Consumer Trace.
