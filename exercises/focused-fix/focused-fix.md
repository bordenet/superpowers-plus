### When the cause and correction are local

For an explanation request, trace the reported behavior to its source, give the
decisive observation, and stop. For a repair, use this shorter path once you
can reproduce the symptom, identify one cause, and show that the correction
stays within one component and preserves the contract its callers rely on.

For example, if parsing an explicit zero selects the default, reproduce it
through a caller and compare zero with an omitted value. Trace both to the
defaulting expression and inspect the other callers. If the contract already
defines zero as valid, cover that case with a failing regression test, correct
the expression, rerun the original reproduction and relevant tests, and
report the failing and passing observations. Existing completion, commit and
push checks still apply at their usual boundaries.

If the cause is uncertain, a sibling path behaves differently, or fixing the
symptom requires changing a producer/consumer contract, continue through the
four phases below. Follow the value across the boundary and verify every
affected path before calling the repair complete.
