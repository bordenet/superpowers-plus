---
name: thinking-orchestrator
source: superpowers-plus
triggers: ["no issue found", "looks fine", "no changes needed", "everything is consistent", "user reports bug", "user says something is wrong", "stuck:confirmation-bias", "stuck:narrow-search", "stuck:premature-closure", "think twice", "you're stuck", "you're looping", "stuck in a loop", "stop and think", "rigorous review", "thorough analysis", "deep dive", "harsh review", "what's the best approach", "where should we put", "which option", "which is better", "how should this be structured", "recommend a strategy", "evaluate alternatives", "what would you recommend", "what's the best place"]
description: Hub skill for thinking and metacognition. Routes to the correct thinking skill based on context — adversarial-search, think-twice, verification-before-completion, exhaustive-audit-validation, or completeness-check. Load this skill when ANY thinking trigger fires; it will dispatch to the right child.
summary: "Use when: routing to the right thinking skill (brainstorming vs design-triad vs think-twice)."
coordination:
  group: thinking
  order: 0
  requires: []
  enables: ["adversarial-search", "think-twice", "output-verification", "verification-before-completion", "exhaustive-audit-validation", "completeness-check", "investigation-state", "feature-development", "design-triad", "plan-and-execute"]
  escalates_to: []
  internal: false
---

# Thinking Orchestrator

> **Source:** `superpowers-plus`

This is the **hub skill** for metacognition and thinking quality. It routes to the correct child skill based on what you are doing right now.

## When to Use

- When ANY thinking-related trigger fires (confirmation bias, stuck loops, completion claims, thoroughness requests)
- When unsure which thinking skill applies — this orchestrator will route correctly
- Before claiming "no problem found" or "looks fine" — check for premature closure

**Do not try to handle thinking tasks yourself.** Use the routing table below to dispatch to the right skill, then follow that skill's process.

## Routing Table

| Context | Route To | Why |
|---------|----------|-----|
| About to report "no issue found" / "already correct" | `adversarial-search` | Prevent confirmation bias |
| User reports bug/inconsistency you disagree with | `adversarial-search` | Search for the BAD value, not the good one |
| Running grep/find/search | `adversarial-search` | Scope justification gate |
| User asks for rigor/depth | `adversarial-search` (Depth Challenge) | Shallow Response Check before delivering |
| Starting a new feature, full development workflow | `feature-development` | Orchestrate requirements → design → plan → implement → verify |
| Strategic / structural / ambiguous question (3+ plausible answers, affects long-lived artifacts, involves tradeoffs) | `design-triad` → then `plan-and-execute` if winner has implementation consequences | Prevent shallow recommendations |
| Debugging a bug, starting/resuming investigation | `investigation-state` | Persist hypotheses, evidence, eliminated approaches |
| Stuck in loop, circular reasoning, same fix 3+ times | `think-twice` | Fresh sub-agent with zero context |
| Describing/approving generated output (files, PDFs, API responses) | `output-verification` then `verification-before-completion` | No claims about output without inspection |
| Claiming "done"/"shipped"/"fixed" (single fix) | `verification-before-completion` | Evidence before assertions |
| Claiming done (bulk edit/audit/refactoring) | `exhaustive-audit-validation` then `verification-before-completion` | Exhaustive scope first |
| Repo takeover, incomplete work audit | `completeness-check` | Detect abandoned work |
| None of the above | PAUSE — "Am I about to give a shallow answer?" | Route to `adversarial-search` if yes |

## Child Skills

| Skill | Domain | Purpose |
|-------|--------|---------|
| `adversarial-search` | Investigation | Counter confirmation bias, enforce exhaustive scope |
| `think-twice` | Stuck detection | Break loops via fresh sub-agent |
| `output-verification` | Output inspection | Hard gate: no claims about output without reading it |
| `exhaustive-audit-validation` | Bulk completion | Item-by-item tracking for audits/refactors |
| `verification-before-completion` | All completion | Evidence-based completion claims |
| `completeness-check` | Repo audit | Detect incomplete/abandoned work |
| `investigation-state` | Debugging | Persist investigation context across sessions |
| `feature-development` | Feature work | Orchestrate full feature lifecycle |
| `design-triad` | Decision quality | 3+ options, comparison, harsh review |
| `plan-and-execute` | Execution planning | Challenge → plan → quality gates → execute |

## The Iron Law

```
NEVER SKIP THE ROUTER. If a thinking trigger fires, route to the child skill.
Do not handle it inline. The child skills have process steps you will miss.
```

## Anti-Patterns

1. **"I'll just quickly check"** -- No. Load the child skill. It has steps you will skip otherwise.
2. **"This is a simple case"** -- The `WIKI_API_TOKEN` incident was "simple" too. Route anyway.
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

Before delivering ANY analysis, evaluation, recommendation, or review, answer ALL of these:

1. **Did the user ask for depth?** Check for: "rigorous review", "thorough analysis", "comprehensive review", "in-depth analysis", "deep dive", "harsh review", "full analysis", "leave no stone unturned"
2. **Is this a strategic/structural/ambiguous question?** Check for: the question has 3+ plausible answers, affects long-lived artifacts (docs, architecture, process), involves tradeoffs, or determines where/how something will live long-term. If YES → route to `design-triad` before answering.
3. **How many dimensions of the problem did I consider?** If < 3, you are being shallow.
4. **Did I challenge my own conclusions?** If not, you are exhibiting confirmation bias.
5. **Would the user say "you only pursued part of it"?** If yes, STOP and expand scope.
6. **Am I about to deliver a short answer to a complex question?** Short != rigorous.
7. **Am I about to recommend without generating alternatives first?** If yes, STOP. Route to `design-triad`.

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

## Common Failure Modes

- **Wrong child skill:** Routing to `verification-before-completion` when `adversarial-search` was needed (check the routing table)
- **Skipping orchestrator:** Invoking a child skill directly without checking if a different child was more appropriate
- **Trigger saturation:** Multiple thinking triggers fire simultaneously — pick the highest-priority match from the routing table

## Related Skills

- `engineering-rigor` -- Hub for engineering process (pre-commit, blast radius, code review)
