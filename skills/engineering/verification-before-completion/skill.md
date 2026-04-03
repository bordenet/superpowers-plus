---
name: verification-before-completion
source: superpowers-plus
overrides: superpowers/verification-before-completion
# Override rationale: Adds intent-based auto-fire triggers (fires on INTERNAL AGENT STATE,
# not on output phrase detection). Adds sentinel short-circuit (if battery sentinel exists
# for HEAD, skip battery re-dispatch). Adds incident history tracking.
triggers:
  - verify completion
  - verification before completion
  - run verification check
  - check evidence before completing
  - verify before completing
description: "Use before claiming any work is complete, fixed, or passing — and before writing any response that presents results to a human. Requires evidence before assertions. If code was changed, check battery sentinel (or dispatch battery) before the completion claim. See AUTO-FIRE section in skill body for self-assessment trigger conditions."
summary: "Use when: forming any response that presents results (even without 'done'/'shipped' language). Skip when: still actively working. Code changes require battery sentinel for HEAD or battery dispatch."
coordination:
  group: completion-gate
  order: 4
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Verification Before Completion

## When to Use

- **BEFORE FORMING the response** — not after you notice you said "done"
- Any time you are about to write a response that describes what you built or found
- Before creating or merging a PR — even if you don't use the word "done"
- Before closing a ticket or marking a task complete
- After fixing a bug — verify the fix AND verify no regressions
- At session end for any multi-step or TODO-backed work

**The trigger is your INTENT, not your words.** The moment you are composing a message to the human that presents results — that is the moment to run this skill. Not after you've written it.

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## Completion-Gate Coordination

**BEFORE running this skill's gate function, check:**

| Task Type | Action |
|-----------|--------|
| Bulk edit, audit, or refactoring | Invoke `exhaustive-audit-validation` FIRST, then return here |
| Single fix, feature, or bug fix | Continue directly with this skill |

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## ⚠️ AUTO-FIRE TRIGGERS — INTENT STATES, NOT OUTPUT PHRASES

**This skill fires on WHAT YOU ARE ABOUT TO DO, not on what you say.**

> "Even if there's only a 1% chance you are about to present results — fire this skill."

| Internal state (INTENT) | Required action before writing |
|--------------------------|-------------------------------|
| About to write any response describing implementation results | Stop. Verify evidence first. |
| About to describe what you built or changed | Stop. This IS the trigger. |
| About to share an MR/PR/commit link | Stop. Sentinel must exist for HEAD. |
| About to write a "here's what I did" summary | Stop. Battery must have passed. |
| About to commit or push code changes | Stop. Battery must have passed. |
| About to claim a bug is fixed | Stop. Show test output proving it. |
| About to claim tests pass | Stop. Show the actual test output. |
| Finishing a multi-step task | Stop. Run TODO maintenance first. |
| **ANY response that presents results — even without "done" language** | **STOP. This IS the trigger.** |

**The output phrase is NOT the trigger.** An agent can share an MR link and write a completion summary without using "done", "shipped", or "fixed". That is the exact failure mode this skill exists to prevent.

**The trigger is the INTENT TO PRESENT** — the moment you begin composing a response to the human that describes results. That moment fires this skill.

## The Gate Function

```
BEFORE forming any response that presents results to the human:

0. INTENT CHECK: Am I about to write a response presenting results?
   - YES → continue. NO → this skill doesn't apply yet.
   (Most common false negative: "I'm just sharing a link" — that IS presenting results.)

1. LOOSE-ENDS RETROSPECTIVE: See "Loose-Ends Retrospective" section below.
   - Scan session for unacted observations and deferred items.
   - Block on any must-address items before proceeding.

2. IDENTIFY: What command proves this claim?
3. RUN: Execute the FULL command (fresh, complete)
4. READ: Full output, check exit code, count failures
5. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
6. CODE REVIEW GATE: If you made code changes, see "Code Review Gate" below.
   Run Step 0 of Code Review Gate BEFORE deciding whether to dispatch.
7. HOUSEKEEPING: If the work spanned multiple steps or used TODO.md, run:
   `~/.codex/superpowers-plus/tools/todo-maintenance.sh`
   Read the summary and resolve any stale-plan/archive surprises before proceeding.
8. ONLY THEN: Write the response

Skip any step = lying, not verifying
```

## Loose-Ends Retrospective

**Purpose:** Catch observations noted but not acted on — primary source of shipped bugs and broken links. Defense-in-depth, not a perfect audit.

### The Retrospective (run at Step 1)

Scan for:
1. **Unacted observations** — "I noticed X", "the URL looks wrong" — without fixing it
2. **Deferred items** — "I'll fix this later", "I'll do this later", "let me skip this for now"
3. **Technical debt introduced** — TODO / FIXME / HACK comments written in code
4. **Open loose ends** — single command handles count + note inspection:
   ```bash
   ~/.codex/superpowers-plus/tools/loose-ends.sh check
   # Exit 0 = clean. Non-zero = items listed with justification visibility.
   ```
   The pre-commit hook also runs this automatically at every commit.

Classify each item shown:

| Label | Action |
|-------|--------|
| `resolved` | Already addressed — proceed |
| `deferred` | Confirm a note/reason line is visible in the output; if missing, escalate to human — no retrofit path exists — proceed once confirmed |
| `must-address` | **FIX IT NOW** — do not claim completion until resolved |

Any `must-address` item → **STOP** → fix → restart gate from Step 1.

## Code Review Gate

**If you made code changes, you MUST verify battery evidence before claiming completion.**

### Step 0 — Sentinel short-circuit (run FIRST, before dispatching anything)

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
# Check for uncommitted/staged changes (unreviewed code not yet in HEAD)
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

| Sentinel state | Action |
|----------------|--------|
| `NO CLEARANCE` | Proceed to Step 1 (dispatch battery). |
| Sentinel SHA ≠ HEAD SHA | Proceed to Step 1 (battery is stale — changes were made after last review). |
| Sentinel valid for HEAD but `WORKTREE_DIRTY` | Proceed to Step 1 (staged/unstaged changes exist that were not reviewed — sentinel covers HEAD, not the current diff). |
| `v1\|SHA\|PASS\|...` or `PASS_WITH_NITS`, SHA matches HEAD, AND `WORKTREE_CLEAN` | **Evidence confirmed.** Skip Step 1. Note the clearance and proceed to Step 5 (Housekeeping). |
| Malformed | Delete `.code-review-cleared`, proceed to Step 1. |

**One-per-unit rule (agent self-enforcement):** Battery fires at most once per coherent unit of work. If Step 0 confirms evidence, do NOT re-dispatch. This prevents double-dispatch when `requesting-code-review` and `verification-before-completion` both apply to the same moment. Note: this rule is expressed in skill prose (agent-layer), not in the runtime. The mechanical enforcement is at the git-hook layer (pre-commit Gate 0, pre-push Gate 1). Both layers are complementary.

### Step 1 — Dispatch (only if Step 0 found no valid sentinel)

Self-review is not review. The implementer cannot objectively evaluate their own work.

| Condition | Action |
|-----------|--------|
| Made code changes (any `.ts`, `.js`, `.py`, `.sh`, etc.) | Dispatch `sub-agent-code-reviewer` with diff context |
| Documentation-only changes | Skip code review (still verify links/content) |
| Config-only changes (env, yaml) | Skip code review unless security-relevant |
| Reviewer found issues | Fix issues, re-dispatch reviewer |
| Reviewer approved | Proceed to Step 5 (Housekeeping) |

**Dispatch template:**
```
Provide the reviewer with:
1. What was implemented (1-2 sentences)
2. Files changed (list with purpose)
3. The actual diff or file contents to review
4. Specific review questions (verifiable, not "is this good?")
5. Request to run tests independently
```

**The reviewer loads `providing-code-review` automatically.** You do not need to tell them how to review.

> **Why:** The 2026-03-23 incident — implementer ran 1,636 tests, self-reviewed, claimed "Fixed". Reviewer found a state leak immediately. Self-review is not review.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| PR created | API response showing PR exists | `git push` succeeded |
| Shipped | PR merged confirmation | PR created |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", "🚀", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- **Saying "Shipped!" after git push but before verifying PR was created**
- Finishing a multi-step session without running TODO maintenance

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Push succeeded" | Push ≠ PR created |
| "Agent said success" | Verify independently |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**PR:** `✅ [API returns: state=open, number=17]` vs `❌ "Shipped!" after git push`

**Tests:** `✅ [34/34 pass]` vs `❌ "Should pass now"`

**Build:** `✅ [exit 0]` vs `❌ "Linter passed"`

## Incident History

| Date | Violation | Impact |
|------|-----------|--------|
| 2026-03-13 | Said "Shipped! 🚀" after git push before verifying PR created | Trust erosion, required post-hoc verification |
| 2026-03-23 | Claimed "Fixed" without dispatching code reviewer | State leak caught only after user forced review |
| 2026-04-02a | Presented work as "ready to commit and push" without running code review battery | Human caught the gap; unreviewed code nearly shipped |
| 2026-04-02b | Committed, pushed branch, shared MR link + summary — no battery run | Wrong approach shipped to MR. Battery (when forced) found safety regression. Skills had explicit incident history from same session yet gate still failed. Transition from "implementation" to "reporting" was not recognized as trigger. Fix: sentinel file gate in pre-push hook + explicit "writing a summary" trigger. |

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
