---
name: receiving-code-review
description: Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation
---
# Code Review Reception
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
**Incident 2026-03-09 (DELTA-1216):**
- Reviewer identified 3 layers of silent `laborType` defaults
- Agent fixed all 3 listed items ✓
- Agent claimed "Done!" ✓
- CSV import (4th layer) still silently defaulted to 'C'
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
Reviewer says: "Remove defaults at lines 96, 127, and 81"

❌ WRONG: Fix lines 96, 127, 81 → "Done!"

✅ RIGHT:
     1. Goal: "No silent defaults for laborType"
     2. Search: grep -rn "laborType.*||.*'C'" .
     3. Find: Lines 96, 127, 81 (listed) + line 2199 (NOT listed)
     4. Fix ALL four
     5. Verify: grep returns nothing
     6. "Done - fixed 4 instances (3 listed + 1 additional in CSV import)"
## Forbidden Responses
**NEVER:**
- "You're absolutely right!" (performative)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)
## Handling Unclear Feedback
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.

## Source-Specific Handling
### From your human partner
- **Trusted** - implement after understanding
- **Still ask** if scope unclear
- **No performative agreement**
- **Skip to action** or technical acknowledgment

### From External Reviewers
BEFORE implementing:
     1. Check: Technically correct for THIS codebase?
     2. Check: Breaks existing functionality?
     3. Check: Reason for current implementation?
     4. Check: Works on all platforms/versions?
     5. Check: Does reviewer understand full context?

IF suggestion seems wrong:
  Push back with technical reasoning

IF conflicts with your human partner's prior decisions:
  Stop and discuss with your human partner first

## Implementation Order
FOR multi-item feedback:
     1. Clarify anything unclear FIRST
     2. Then implement in this order:
        • Blocking issues (breaks, security)
        • Simple fixes (typos, imports)
        • Complex fixes (refactoring, logic)
     3. Test each fix individually
     4. Verify no regressions
     5. SYSTEMIC CHECK (see above)
## When To Push Back

Push back when:
- Suggestion breaks existing functionality
- Reviewer lacks full context
- Violates YAGNI (unused feature)
- Technically incorrect for this stack
- Legacy/compatibility reasons exist
- Conflicts with your human partner's architectural decisions

## Common Mistakes
| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |
| **Checklist completion ≠ goal achieved** | Search for OTHER instances of same pattern |
| Fixing symptoms, not disease | Extract underlying goal, verify it's achieved |
## Acknowledging Correct Feedback

When feedback IS correct:
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ ANY gratitude expression

## The Bottom Line
**External feedback = suggestions to evaluate, not orders to follow.**
Verify. Question. Then implement. Then verify the GOAL, not just the checklist.

No performative agreement. Technical rigor always.

