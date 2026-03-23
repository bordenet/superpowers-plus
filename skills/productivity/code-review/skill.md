---
name: code-review
description: Inter-agent code review file protocol — structured request/response handoff between agent sessions via ~/.codex/superpowers-review/
triggers: ["write review request", "generate review request", "prepare review handoff", "send to reviewer agent", "harsh review handoff", "the reviewer finished", "execute reviewer findings", "implement reviewer response", "review response ready", "superpowers-review"]
---

# Code Review — Requesting Agent File Protocol

This skill handles the **file I/O and structured handoff** for inter-agent code review. It has two modes: **Generate Request** and **Execute Response**.

**Complements these skills (load as needed):**
- `receiving-code-review` — Behavioral protocol for processing feedback (systemic verification, no performative agreement). Load during Execute Response mode.
- `providing-code-review` — Engineering rigor checklist for reviewers (data flow, blast radius). The REVIEWER loads this, not you.

**File protocol:** `~/.codex/superpowers-review/active/{scope}/` — scope is a project or feature name (e.g., `context-optimization`).

---

## Mode 1: Generate Request

Use when: you've completed work and want a second agent to review it.

### Steps

1. **Determine scope.** Derive from git branch name, feature name, or ask the user. Example: `context-optimization`.
2. **Check for existing scope:**
   - If `~/.codex/superpowers-review/active/{scope}/` does NOT exist → create it.
   - If it exists with `request.md` → warn user: "Scope '{scope}' has an in-progress review at Round {N}. Resume, or restart from Round 1?" If restart, archive existing files to `~/.codex/superpowers-review/archive/{scope}/round-{N}/` first.
3. **Build `request.md`** using the template below. You are the author — fill it with YOUR session context (diffs you ran, files you measured, references you traced). This template is a protocol guide, not a generator.
4. **Tell the user** the exact prompt to give the reviewer agent:
   > Review request ready. Open a new session and say:
   > "Read `~/.codex/superpowers-review/active/{scope}/request.md` and follow its instructions. You are the code reviewer."

### Request Template

```markdown
# Code Review Request — Round {N}

**Reviewer:** You are a harsh, adversarial code reviewer. Call out EVERYTHING.
**Write response to:** ~/.codex/superpowers-review/active/{scope}/response.md

## Files to Read Before Reviewing
(ordered list of file paths the reviewer MUST read, with 1-line purpose each)
THIS IS THE MOST IMPORTANT SECTION — forces the reviewer to read code, not just claims.

## Round {N-1} Feedback Status
(if N > 1: status table of previous findings — fixed/deferred/rejected with evidence)

## What Changed
(diff summary: which files, what was added/removed/modified, before/after metrics)

## What We Intend to Do Next
(planned changes for the reviewer to evaluate for risks)

## Review Questions
(numbered, specific, verifiable — not "is this good?" but "does X reference Y correctly?")
```

### Key Rules

- **"Files to Read" goes FIRST.** It is the most valuable section.
- List EVERY file the reviewer needs. Don't assume they'll search.
- Include before/after metrics (char counts, line counts).
- Frame review questions as verifiable claims, not open-ended opinions.
- If Round > 1, include a status table showing how each prior finding was addressed.

---

## Mode 2: Execute Response

Use when: the reviewer has finished and written `response.md`.

**Before implementing fixes**, follow the `receiving-code-review` skill's verification protocol: verify each finding technically before implementing, check for systemic issues, don't implement blindly.

### Steps

1. **Read `response.md`** from `~/.codex/superpowers-review/active/{scope}/`. If it doesn't exist, tell the user the reviewer hasn't finished yet.
2. **Parse findings by severity.** Present a summary table:
   - Count of CRITICAL / WARNING / INFO findings
   - Verdict (PASS / PASS_WITH_CHANGES / FAIL)
3. **Ask user for confirmation** before implementing. User may say "implement all", "skip INFO", "let me review first", etc.
4. **Execute confirmed fixes.** For each fix, note what was done. For each skipped finding, note why.
5. **Handle verdict:**

   **If PASS:**
   a. Archive final round: copy `request.md` and `response.md` to `~/.codex/superpowers-review/archive/{scope}/round-{N}/`
   b. Clean up `active/{scope}/` directory
   c. Report summary to user — done!

   **If PASS_WITH_CHANGES or FAIL:**
   a. Generate updated `request.md` for Round N+1 (write to `active/{scope}/request.md`)
   b. AFTER the new request.md is written, archive the previous round: copy old request/response to `archive/{scope}/round-{N}/`
   c. Tell user the prompt for the reviewer (same as Mode 1, step 4)

   **If Round N ≥ 5 and verdict is not PASS:**
   Refuse to generate Round 6. Tell user: "5 review rounds completed without PASS. Escalating — please review manually or adjust approach."

### Key Rules

- Always ask for user confirmation before implementing fixes.
- Archive AFTER the new request is written (crash safety — prevents empty active directory).
- Archive the final PASS round too (user may want to reference it).
- Track round number from the response header (`# Code Review Response — Round {N}`), not a separate file.
