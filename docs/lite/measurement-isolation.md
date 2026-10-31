# Isolate every host before measuring lite mode

Proposal for a future approved measurement run. The [planning hold](README.md)
applies. Publishing this checklist authorizes no probes, authentication, plugin
installation or evaluation spend. All host-specific mechanisms and CLI options
must be verified against the selected host version before execution.

## Required configuration boundaries

Each arm and host gets a disposable source copy, neutral workspace, private HOME
and private temporary directory in a declared runtime area outside every Git checkout.
Keep durable evidence in a separately declared private folder. A global Git ceiling
does not make a checkout-descendant temporary directory safe: a fixture or host can
override that ceiling. Pin the source
revision, host version, model when applicable, payload and hook/router hashes.
Use standalone Full and its candidate from that same revision. Keep credentials
outside inventories and logs; the owner authenticates only through an approved,
supported scratch method. Never copy, read, hash or export live credentials.

| Host | Configuration isolation to establish before approval |
|---|---|
| Claude Code | Private HOME and CLAUDE_CONFIG_DIR. Verify effective settings, skills, commands, plugin/marketplace state and instruction paths, including project/workspace discovery. |
| Codex | Private HOME **and CODEX_HOME**. Verify effective configuration, skill roots, plugin/marketplace and connector state, and instruction discovery. HOME alone is insufficient evidence of isolation. |
| Augment | Private HOME plus the host-version-specific profile/configuration and workspace mechanism verified from documentation and effective paths. Do not assume CLAUDE_CONFIG_DIR or CODEX_HOME isolates the IDE. If isolation cannot be established, mark Augment UNVERIFIED and defer its probe. |

These are requirements to verify, not claims that a host honors a particular
variable or supports an untested profile flag. A neutral workspace must have no
inherited repository instructions, plugin manifests or remote-derived identity.
Record unexpected built-ins separately; do not silently add them to an approved
catalog allowlist or relax an exact-name check.

## Inherited environment and discovery

Before starting the host, construct an explicit environment allowlist. Inspect
variable names, then omit or rebind inherited host configuration, skill/source
root, plugin, workspace, XDG and temporary-path overrides to declared scratch
paths. Remove inherited Git discovery overrides and place a verified Git ceiling
around scratch workspaces. Do not print variable values that could contain secrets.
An approved credential mechanism must be explicit; missing authentication is a
stop, never a reason to fall back to the active account's configuration.

The approval request must list the effective HOME, temporary directory, host
configuration/profile paths, workspace, source and discovery roots for each arm.
Validate every supported override against current host documentation and local
help without a model call first. If confirming an effective path needs a model
call, itemize that call in the requested budget; it is not a free startup check.

## Containment evidence and stop conditions

Declare every output path before execution. Take before/after manifests of the
source copy and the owner's real skill roots for Claude, Codex and the shared
agents root, plus relevant real host configuration/plugin directories. Use a
metadata-only inventory for credential locations: exclude their content and hashes.
Reading protected content or resolving credentials requires separate authorization.

Record the effective catalog, instruction and configuration paths from supported
host diagnostics. Compare them with the approved roots and exact expected names.
Unexpected paths, plugins, connectors, instructions or catalogs invalidate the
run and require an owner decision before another call. No unknown location is
assumed safe merely because HOME is private. Any difference outside declared
outputs is a containment STOP; do not automatically repair or accept it.

For every host/arm, report which checks were performed, which paths were excluded
from content inspection, and any UNVERIFIED boundary. A skipped Augment probe
cannot support an Augment compatibility claim or a shared-host default decision.
The owner approves the revised plan, exact calls/spend and credential method only
after this preparation. All actual observations remain deferred.
