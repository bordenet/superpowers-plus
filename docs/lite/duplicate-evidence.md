# Treat duplicate names as advisory evidence

Proposal for future duplicate reporting. The [planning hold](README.md) applies;
no report, doctor change, plugin disablement or host probe is authorized here.
Reconcile the completed standalone revision before choosing fields or check numbers.

## What a name match proves

Canonical skill-name overlap identifies candidates for inspection. If every visible
plugin skill name appears locally, report complete **name overlap**. A zero-skill,
partially parsed, inaccessible or incompletely scoped inventory cannot establish
complete overlap. State the inspected host, version, installation scopes and
visibility limits; unavailable input must never become a clean result.

The earlier draft's proposed `fully_redundant` predicate, `skills > 0` and
`covered_by_local == skills`, is withdrawn as a redundancy claim. If those counts
are retained in a future report, label them as visible name counts. Do not publish
a field called `fully_redundant` based only on them. These are design requirements,
not claims about fields implemented by today's report.

Equal names do not establish equal bodies, triggers, versions, loading behavior,
permissions or workflow guarantees. Equal skill-file hashes alone also do not
establish that the rest of a plugin is replaceable.

## Evidence needed before recommending disablement

Create a version-pinned component inventory for the plugin and the proposed retained
installation. Cover skills and companions, commands, hooks and their timing,
always-on rules/instructions, tools or connectors, permission grants, approval
policies and privilege restrictions, configuration/defaults, and installation/update
behavior. Record each component as absent, covered, different
or unknown, with evidence; a missing manifest or unreadable file is unknown.

For every required component, identify its retained replacement and verify the
relevant behavior in an approved isolated configuration. Include safety/enforcement
gates, routing and on-demand access where applicable. Explicitly compare permission
grants, approval policies and privilege restrictions for each retained replacement;
an unapproved widening of access blocks the recommendation. A mapped filename or existing
local install directory is not proof of availability in the actual host session.
Unknown or uncovered functionality prevents an equivalence-based disablement
recommendation. Record any intentionally abandoned capability as a separate owner
choice; it is not evidence of full redundancy.

Only after coverage is verified may a report recommend that the owner disable a
specific plugin in a stated scope. Provide supported, version-appropriate manual
steps and a restoration path. Verification that needs a host/model call requires
separate approval and budget. A report must not perform the disablement itself.

## Ownership and misleading warnings

Detection remains read-only under every repair or cleanup flag. Foreign plugins,
synced copies and other installers' files survive. A recommendation grants no
ownership or deletion permission; a future installer may remove only its own
recorded files under an approved lifecycle design.

Report local/plugin coexistence as observed coexistence. Directory presence alone
cannot prove that a plugin restores a Full listing, defeats Light or duplicates
hooks. Establish its effective catalog and component behavior first. Apply the
same distinction to synced name collisions: flag the overlap for inspection rather
than recommending that uploads be turned off solely because names match.

Future acceptance cases must include equal names with different bodies, a unique
hook or command, unknown component input, partial project/user scope, a zero-skill
plugin, and a genuinely verified replacement. All name-only cases must remain
advisory and offer no equivalence-based disablement instruction. This document
supersedes conflicting historical name-only recommendations for this planning track.
