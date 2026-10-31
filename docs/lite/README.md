# Lite planning: start here

Status: planning hold. Measurement and implementation are not authorized by these documents.

This is the canonical entrypoint for future lite planning. A separate standalone
integration effort removes the requirement for a second superpowers installation.
Its completion has not been confirmed by the owner. A commit, merged PR or idle
process is not that confirmation.

## What may proceed

Sanitized planning Markdown may be reviewed and published. Product code, tests,
installers, hooks, configuration, installed skills and host/model measurement
probes stay outside this authorization. Normal documentation quality gates still
apply; their isolated test fixtures do not authorize product changes or new probes.
Existing implementation worktrees and staged work must remain untouched.

## Before any execution

1. Obtain the owner's standalone completion confirmation and accepted revision,
   verification report and remaining limitations.
2. Obtain permission for read-only reconciliation against that revision. Reconcile
   staged lite work explicitly; do not resume, merge, discard or rebase it automatically.
3. Preserve the historical Full oracle and interface. If intentional standalone
   changes conflict with them, propose a scoped amendment for owner approval;
   do not regenerate compatibility fixtures to hide a conflict.
4. Present a bounded host-specific measurement plan, including configuration
   isolation, controls, calls, spend and containment checks. Obtain execution approval.
5. Present the resulting evidence before requesting any implementation approval.
   Completion confirmation, documentation approval and a favorable result each
   leave the next execution step subject to its own authorization.

Measure any proposed lite saving against the same pinned standalone Full revision.
Standalone dependency removal and reduced suite listings are separate benefits;
never count one removed contribution in both totals. Historical measurements retain
only their recorded source, host, configuration and metric scope. They establish
neither current standalone costs nor complete Light support.

## Legacy handoffs

The private migration bundle is historical execution material. Its `AGENTS.md`,
`NEXT-PROMPT.md`, `NEXT-PROMPT.txt` and launcher instructions are retired as current
execution authority: do not paste or launch them. Earlier GO decisions and staged
review results do not lift this hold. Retain the bundle outside Git as evidence;
never copy its reports, archives, authentication material or local resume files here.

The private required read path and prompt twins still omit this hold. This public
page does not change those files or enforce a launcher block. An executor started
from the old bundle can still miss it. Before that bundle is used again, the owner
must explicitly retire it in favor of this entrypoint, or authorize a private
read-order/prompt amendment with a corresponding manifest update. That correction
is pending; no runtime enforcement is claimed.

[Historical baseline](baseline.md) is retained for provenance. Later planning notes
must link here and state whether their criteria are proposals or approved execution
requirements. Public planning text supersedes conflicting historical recommendations
for this planning track; protected oracle/interface decisions still need owner approval.

## Planning amendments

These proposals remain subject to the execution approvals above.

- [Isolate each host before measurement](measurement-isolation.md)
- [Require component evidence for duplicate recommendations](duplicate-evidence.md)
- [Validate controls and core coverage before comparison](evaluation-validity.md)
