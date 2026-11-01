---
name: holistic-repo-verification
disable-model-invocation: true
source: superpowers-plus
augment_menu: true
triggers: ["/sp-checkrepo", "repo health", "verify repo", "CI is green", "check all workflows", "before creating PR"]
anti_triggers: ["fix CI", "debug pipeline", "write tests"]
description: Audit repository health when explicitly requested, or verify workflows required for the assigned release. Distinguish release blockers from unrelated and advisory checks.
summary: "Use when: an explicit whole-repository health audit or required release workflow verification. Do not expand every task into an all-workflow audit."
coordination:
  group: observability
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [verification-report]
  capabilities: [verifies-repo-health]
  priority: 30
---

# Holistic Repository Verification

> **Wrong skill?** Task completion evidence -> `verification-before-completion`. Commit/push checks -> `unified-commit-gate`.

## Choose the scope first

| User's request | Verification boundary |
|---|---|
| Explicit repository-health audit | Inventory all relevant workflows, Pages if used, and other requested deployment systems |
| Release/deployment | Required checks and deployment workflows for the exact artifact/environment being released |
| Ordinary fix, PR, documentation, or status update | Its acceptance criteria and required forge checks; no automatic whole-repository audit |

Record which checks block the requested outcome and why. Forge protection,
repository release policy, and the user's acceptance criteria remain authoritative.
Never waive one because it is slow. Do not make unrelated branches, advisory
post-merge jobs, or older failures into new blockers for a narrower task.

## Verify without re-executing

1. Read required workflow/check status for the exact target head or artifact.
2. Use provenance-bound results for the same tested tree and execution context.
   Commit or PR identity alone is not a test input. The CI runner owns receipt reuse.
3. If equivalent validation is in progress, follow that producer with one watcher.
   Do not start another full suite or repeatedly request unchanged status.
4. If source, context, or merge-result tree differs, require validation of those
   new inputs. Missing, failed, cancelled, skipped, or untrusted evidence is not PASS.
5. Read the required deployment result when deployment is in scope.
6. Report required checks, pending advisory checks, and known unrelated findings
   separately. Stop when the assigned acceptance boundary is satisfied.

## Explicit whole-repository audit

For a requested health audit, inspect the latest relevant run of each workflow,
not merely the most recently completed workflow. Check Pages only if the repository
uses it; check other deployment systems only when they apply. Name the branch,
head, and scope. A pending required check is pending, not green; a known error
must be disclosed even when it is outside a release's blocking scope.

Do not repair unrelated findings, alter protections, or trigger new workflows
without authority. An audit is read-only unless the user authorized fixes.

## Report

State the assigned scope, required results, remaining blockers, and advisory or
unrelated findings. Cite the actual workflow/deployment records. Do not claim
whole-repository health from a narrow release check. Do not withhold a completed
narrow task merely to obtain an unrequested whole-repository green badge.
