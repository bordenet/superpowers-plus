---
name: thinking-orchestrator
source: superpowers-plus
triggers: ["no issue found", "no inconsistency", "already correct", "looks fine", "nothing to fix", "no changes needed", "no problem found", "everything is consistent", "user reports bug", "user reports inconsistency", "user says something is wrong", "grep", "search for", "find all", "investigate", "stuck:confirmation-bias", "stuck:narrow-search", "stuck:premature-closure", "think twice", "you're stuck", "you're looping", "you're going in circles", "stuck in a loop", "spiraling", "stop and think", "fresh perspective", "stuck:reasoning", "stuck:perspective", "work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "ready for review", "claiming completion", "audit complete", "done with refactoring", "finished updating", "bulk edit done", "is this done", "check for incomplete work"]
description: Hub skill for thinking and metacognition. Routes to the correct thinking skill based on context — adversarial-search, think-twice, verification-before-completion, exhaustive-audit-validation, or completeness-check. Load this skill when ANY thinking trigger fires; it will dispatch to the right child.
coordination:
  group: thinking
  order: 0
  requires: []
  enables: ["adversarial-search", "think-twice", "verification-before-completion", "exhaustive-audit-validation", "completeness-check"]
  escalates_to: []
  internal: false
---

# Thinking Orchestrator

> **Source:** `superpowers-plus`

This is the **hub skill** for metacognition and thinking quality. It routes to the correct child skill based on what you are doing right now.

**Do not try to handle thinking tasks yourself.** Use the routing table below to dispatch to the right skill, then follow that skill's process.

## Routing Decision Tree

```
What is happening right now?
|
+-- INVESTIGATING something (search, grep, bug report, inconsistency)
|   |
|   +-- About to report "no issue found" or "already correct"?
|   |   --> adversarial-search (MANDATORY before any negative finding)
|   |
|   +-- About to report search results?
|   |   --> adversarial-search (fill Mandatory Investigation Report)
|   |
|   +-- User says something is wrong and you disagree?
|       --> adversarial-search (search for the BAD value, not the good one)
|
+-- STUCK (looping, circular reasoning, same fix tried 3+ times)
|   |
|   --> think-twice (pause, spawn fresh sub-agent with zero context)
|
+-- CLAIMING DONE (about to say "shipped", "fixed", "complete")
|   |
|   +-- Was this a bulk edit, audit, or refactoring?
|   |   --> exhaustive-audit-validation FIRST, then verification-before-completion
|   |
|   +-- Was this a single fix, feature, or bug fix?
|   |   --> verification-before-completion
|   |
|   +-- Taking over a repo or auditing for incomplete work?
|       --> completeness-check
|
+-- NONE OF THE ABOVE
    --> No thinking skill needed. Proceed normally.
```

## Routing Table (Quick Reference)

| Context Signal | Route To | Why |
|----------------|----------|-----|
| "no issue found", "already correct", "looks fine" | `adversarial-search` | Prevent confirmation bias |
| User reports bug/inconsistency | `adversarial-search` | Search for the BAD value |
| Running grep/find/search | `adversarial-search` | Scope justification gate |
| Stuck in loop, circular reasoning | `think-twice` | Fresh perspective via sub-agent |
| Same fix attempted 3+ times | `think-twice` | Break the cycle |
| "done", "shipped", "fixed", "complete" | `verification-before-completion` | Evidence before assertions |
| Bulk edit/audit/refactoring done | `exhaustive-audit-validation` then `verification-before-completion` | Exhaustive scope first |
| Repo takeover, incomplete work audit | `completeness-check` | Detect abandoned work |

## Child Skills

| Skill | Domain | Purpose |
|-------|--------|---------|
| `adversarial-search` | Investigation | Counter confirmation bias, enforce exhaustive scope |
| `think-twice` | Stuck detection | Break loops via fresh sub-agent |
| `exhaustive-audit-validation` | Bulk completion | Item-by-item tracking for audits/refactors |
| `verification-before-completion` | All completion | Evidence-based completion claims |
| `completeness-check` | Repo audit | Detect incomplete/abandoned work |

## The Iron Law

```
NEVER SKIP THE ROUTER. If a thinking trigger fires, route to the child skill.
Do not handle it inline. The child skills have process steps you will miss.
```

## Anti-Patterns

1. **"I'll just quickly check"** -- No. Load the child skill. It has steps you will skip otherwise.
2. **"This is a simple case"** -- The OUTLINE_API_TOKEN incident was "simple" too. Route anyway.
3. **"I already know the answer"** -- That is confirmation bias. Route to adversarial-search.
4. **Handling two contexts at once** -- If you are both investigating AND claiming done, run BOTH routes sequentially.

## When Multiple Routes Apply

If your current context matches more than one route:

1. **Investigation + Completion**: Run `adversarial-search` first (verify findings), then `verification-before-completion` (verify the fix)
2. **Stuck + Investigation**: Run `think-twice` first (get unstuck), then `adversarial-search` (investigate properly)
3. **Bulk completion**: Always `exhaustive-audit-validation` before `verification-before-completion`

## Related Skills

- `engineering-rigor` -- Hub for engineering process (pre-commit, blast radius, code review)
- `skill-effectiveness` -- Track outcomes of thinking skill invocations
