### Short path for a proven local repair

Use this path only for a requested repair when you have reproduced the symptom
through its caller, traced it to one expression, and checked that the caller and
component already agree on the required behavior. Demonstrate the failing case,
add its regression test, make the local correction, and rerun the reproduction
and affected tests. Report the decisive before and after observations. Follow
the existing completion, commit and push requirements at their usual boundaries.

For example, if an explicit zero selects a documented default, check the caller
and the omitted-value case. Once both establish the parser as the sole cause,
correct the parser and verify both inputs.

When a producer and consumer disagree, or sibling paths have different behavior,
use the full investigation below. For each affected path, identify its own
contract before editing. Exercise documented exceptions as preservation cases.
A difference between siblings alone does not establish a defect in either.
