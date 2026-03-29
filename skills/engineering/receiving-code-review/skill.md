---
name: receiving-code-review
source: superpowers-plus
overrides: superpowers/receiving-code-review
# Override rationale: Adds Systemic Verification gate (search for OTHER instances
# of same pattern beyond reviewer's checklist), adds triggers array for auto-fire,
# and refines implementation order with systemic check step. obra's version lacks
# the "fix the disease not the symptoms" workflow.
triggers: ["received code review", "PR feedback", "reviewer commented", "code review feedback", "implement review suggestions", "address review comments"]
anti_triggers: ["review this PR", "review these changes", "send to reviewer agent", "I am the reviewer agent"]
description: Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation
summary: "Use when: implementing PR feedback. Skip when: the feedback is a simple typo fix."
coordination:
  group: code-quality
  order: 4
  requires: [providing-code-review]
  enables: [code-review-respond]
  escalates_to: [think-twice]
  internal: false
---
# Code Review Reception

> **Wrong skill?** Reviewing someone's PR → `providing-code-review`. Sending to reviewer agent → `code-review`. Acting as reviewer → `code-review-respond`.

## When to Use

- After receiving PR/MR review comments from any reviewer
- When review feedback seems unclear, contradictory, or technically questionable
- Before implementing any suggested changes from code review

## Overview
Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern
WHEN receiving code review feedback:

  1. READ: Complete feedback without reacting
  2. UNDERSTAND: Restate requirement in own words (or ask)
  3. VERIFY: Check against codebase reality
  4. EVALUATE: Technically sound for THIS codebase?
  5. RESPOND: Technical acknowledgment or reasoned pushback
  6. IMPLEMENT: One item at a time, test each
  7. SYSTEMIC CHECK: Search for OTHER instances (see below)
## 🚨 Systemic Verification (MANDATORY)

**After implementing all feedback items, BEFORE claiming done:**
The reviewer's feedback identifies SYMPTOMS.
Your job is to fix the DISEASE, not just the symptoms.

AFTER implementing all items:
     1. EXTRACT the underlying principle/goal
     Example: "Remove all silent defaults" not "fix these 3 lines"

     2. SEARCH for OTHER instances of the same pattern
     grep -rn "pattern" --include="*.ts" --include="*.js" .

     3. FIX any additional instances found

     4. VERIFY the GOAL is achieved, not just the checklist
### Why This Exists
**Common failure pattern:**
- Reviewer identified 3 instances of a problematic pattern
- Agent fixed all 3 listed items ✓
- Agent claimed "Done!" ✓
- A 4th instance existed that wasn't in the reviewer's list
- Only caught by adversarial self-review asking "are there OTHER places?"

**Root cause:** Treated feedback as finite checklist, not systemic issue.
### The Gate
BEFORE claiming code review changes are complete:

☐ Did I extract the underlying GOAL from the feedback?
☐ Did I search for OTHER instances of the same pattern?
☐ Did I verify the GOAL is achieved (not just items checked off)?
☐ Would a harsh reviewer find more instances I missed?

If ANY box is unchecked → you're not done
### Example
Reviewer says: "Remove hardcoded defaults at lines 96, 127, and 81"

❌ WRONG: Fix lines 96, 127, 81 → "Done!"

✅ RIGHT:
     1. Goal: "No hardcoded defaults for userRole"
     2. Search: grep -rn "userRole.*||.*'guest'" .
     3. Find: Lines 96, 127, 81 (listed) + line 2199 (NOT listed)
     4. Fix ALL four
     5. Verify: grep returns nothing
     6. "Done - fixed 4 instances (3 listed + 1 additional in data import)"
## Response Rules

**Never performative** ("You're absolutely right!", "Great point!"). Instead: restate requirement, ask questions, push back with reasoning, or just fix it.

**Correct feedback**: "Fixed. [what changed]" or "Good catch — [issue]. Fixed in [location]." or just fix and show.

**Unclear feedback**: STOP — clarify ALL items before implementing. Partial understanding = wrong implementation.

## Source-Specific Handling

**Human partner**: Trusted — implement after understanding. Still ask if scope unclear.
**External reviewers**: Check: correct for THIS codebase? Breaks functionality? Reason for current approach? Push back if wrong. Conflicts with partner's decisions → discuss with partner first.

## Implementation Order

1. Clarify unclear items FIRST
2. Blocking (breaks, security) → simple (typos, imports) → complex (refactoring)
3. Test each individually → verify no regressions → SYSTEMIC CHECK

## Push Back When

Breaks functionality · reviewer lacks context · YAGNI · technically wrong · legacy reasons · conflicts with partner's architecture.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Checklist ≠ goal achieved | Search for OTHER instances |
| Fixing symptoms not disease | Extract underlying goal |
❌ ANY gratitude expression

## The Bottom Line
**External feedback = suggestions to evaluate, not orders to follow.**
Verify. Question. Then implement. Then verify the GOAL, not just the checklist.

No performative agreement. Technical rigor always.


## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| Defensive dismissal | "That's by design" without evidence | Assume reviewer saw something real |
| Blind acceptance | Fix everything without evaluation | Evaluate each: agree/disagree/discuss |
| Scope deflection | "Out of scope for this PR" for real issues | Fix if <30 min, else log TODO |
| Silent disagreement | Ignore comment, don't respond | Every comment gets a response |
| Fix without understanding | Mechanical fix, same pattern recurs | Understand root cause first |

## Failure Modes

- **Blind implementation:** Implementing every suggestion without evaluating whether it's correct for THIS codebase
- **Performative agreement:** Saying "great catch!" instead of technically verifying the feedback is accurate
- **Fixing symptoms only:** Addressing the specific line a reviewer flagged without checking for the same pattern elsewhere

## Example: Systemic Check After Review

```bash
# Reviewer says: "This null check is missing"
# WRONG: Add null check to just this line
# RIGHT: Search for ALL similar patterns in the codebase
grep -rn "\.getData()" --include="*.ts" src/ | grep -v "?." | grep -v "!= null"
# Then fix ALL instances, not just the one the reviewer spotted
```

## Companion Skills

- **providing-code-review**: How the reviewer should structure feedback
- **code-review**: File-protocol review (may generate the feedback you're processing)
- **systematic-debugging**: For investigating complex review findings
- **code-review-respond**: Review response workflow
- **code-review-battery**: Multi-reviewer orchestration
