---
name: thinking-orchestrator
source: superpowers-plus
triggers: ["no issue found", "no inconsistency", "already correct", "looks fine", "nothing to fix", "no changes needed", "no problem found", "everything is consistent", "user reports bug", "user reports inconsistency", "user says something is wrong", "grep", "search for", "find all", "investigate", "stuck:confirmation-bias", "stuck:narrow-search", "stuck:premature-closure", "think twice", "you're stuck", "you're looping", "you're going in circles", "stuck in a loop", "spiraling", "stop and think", "fresh perspective", "stuck:reasoning", "stuck:perspective", "work complete", "done", "shipped", "finished", "fixed", "passing", "ready to merge", "ready for review", "claiming completion", "audit complete", "done with refactoring", "finished updating", "bulk edit done", "is this done", "check for incomplete work", "rigorous", "thorough", "comprehensive", "in-depth", "deep dive", "don't cut corners", "full analysis", "harsh review", "analyze", "evaluate", "assess", "review in detail", "leave no stone unturned"]
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

## Routing Table

| Context | Route To | Why |
|---------|----------|-----|
| About to report "no issue found" / "already correct" | `adversarial-search` | Prevent confirmation bias |
| User reports bug/inconsistency you disagree with | `adversarial-search` | Search for the BAD value, not the good one |
| Running grep/find/search | `adversarial-search` | Scope justification gate |
| User asks for rigor/depth | `adversarial-search` (Depth Challenge) | Shallow Response Check before delivering |
| Stuck in loop, circular reasoning, same fix 3+ times | `think-twice` | Fresh sub-agent with zero context |
| Claiming "done"/"shipped"/"fixed" (single fix) | `verification-before-completion` | Evidence before assertions |
| Claiming done (bulk edit/audit/refactoring) | `exhaustive-audit-validation` then `verification-before-completion` | Exhaustive scope first |
| Repo takeover, incomplete work audit | `completeness-check` | Detect abandoned work |
| None of the above | PAUSE — "Am I about to give a shallow answer?" | Route to `adversarial-search` if yes |

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

4. **Rigor + Completion**: Run `adversarial-search` Depth Challenge first, then `verification-before-completion`

## Shallow Response Check

<EXTREMELY_IMPORTANT>

Before delivering ANY analysis, evaluation, or review that the user requested with rigor keywords, answer ALL of these:

1. **Did the user ask for depth?** Check for: "rigorous", "thorough", "comprehensive", "in-depth", "deep dive", "harsh review", "full analysis", "evaluate", "assess", "leave no stone unturned"
2. **How many dimensions of the problem did I consider?** If < 3, you are being shallow.
3. **Did I challenge my own conclusions?** If not, you are exhibiting confirmation bias.
4. **Would the user say "you only pursued part of it"?** If yes, STOP and expand scope.
5. **Am I about to deliver a short answer to a complex question?** Short != rigorous.

**If ANY answer is concerning, go back and deepen the analysis before responding.**

### Common Shallow Analysis Patterns

| Pattern | What You Did | What You Should Have Done |
|---------|-------------|--------------------------|
| Surface scan | Looked at 2 of 5 files and said "looks good" | Examined all 5 files systematically |
| Premature conclusion | Found one issue and stopped | Asked "are there MORE issues?" |
| Narrow framing | Analyzed from one angle | Analyzed from multiple angles (user, technical, operational) |
| Scope reduction | Silently dropped part of the request | Addressed every part, or explicitly flagged what was deferred |
| Confident ignorance | Declared "no problem" without evidence | Searched exhaustively before concluding |

</EXTREMELY_IMPORTANT>

## Related Skills

- `engineering-rigor` -- Hub for engineering process (pre-commit, blast radius, code review)
