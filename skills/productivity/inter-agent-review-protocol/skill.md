---
name: inter-agent-review-protocol
source: superpowers-plus
description: Use when sending work to a separate reviewer agent or executing reviewer findings via the ~/.codex/superpowers-review/ request.md → response.md file protocol
triggers: ["send to reviewer agent", "execute reviewer findings", "implement reviewer response", "superpowers-review"]
anti_triggers: ["review my PR", "review this PR", "code review before commit", "pre-commit"]
coordination:
  group: code-quality
  order: 1
  requires: []
  enables: [providing-code-review, progressive-code-review-gate]
  escalates_to: [code-review-battery]
  internal: false
composition:
  consumes: [code-changes]
  produces: [review-request-file]
  capabilities: [file-protocol-review]
  priority: 25
---

# Code Review — Requesting Agent File Protocol

## When to Use

- Sending completed work to a separate reviewer agent via the file protocol
- Executing reviewer findings from a `response.md`
- NOT for: acting as reviewer (`code-review-respond`), pre-commit review (`progressive-code-review-gate`)

This skill handles the **file I/O and structured handoff** for inter-agent code review. It has two modes: **Generate Request** and **Execute Response**.

**Complements these skills (load as needed):**

- `receiving-code-review` — Behavioral protocol for processing feedback (systemic verification, no performative agreement). Load during Execute Response mode.
- `providing-code-review` — Engineering rigor checklist for reviewers (data flow, blast radius). The REVIEWER loads this, not you.

**File protocol:** `~/.codex/superpowers-review/active/{scope}/` — scope is a project or feature name (e.g., `context-optimization`).

**Use distinctive file-protocol phrases for this skill:** `send to reviewer agent`, `execute reviewer findings`, `implement reviewer response`, `superpowers-review`.

**Do not rely on bare review phrasing here.** Generic prompts like `code review`, `request code review`, or `perform code review` belong to the broader review skills and may route elsewhere by design.

---

## Mode 1: Generate Request

Use when: you've completed work and want a second agent to review it.

### Steps

1. **Determine scope.** Prefer the user's description, git branch name, or feature name. If no obvious scope emerges, default to the current directory basename. Ask the user only when that default would be ambiguous or they want a different scope. Example: `context-optimization`.
2. **Check for existing scope:**
   - If `~/.codex/superpowers-review/active/{scope}/` does NOT exist → create it.
   - If it exists with `request.md` → warn user: "Scope '{scope}' has an in-progress review at Round {N}. Resume, or restart from Round 1?" If restart, archive existing files to `~/.codex/superpowers-review/archive/{scope}/round-{N}/` first.
3. **Build `request.md`** using the template below. You are the author — fill it with YOUR session context (diffs you ran, files you measured, references you traced). This template is a protocol guide, not a generator.
4. **Tell the user** the exact prompt to give the reviewer agent:
   > Review request ready. Open a new session and say:
   > "I am the reviewer agent. Read request.md at `~/.codex/superpowers-review/active/{scope}/request.md` and follow the reviewer agent protocol."

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

1. **Read `request.md` and `response.md`** from `~/.codex/superpowers-review/active/{scope}/`. If `response.md` doesn't exist, tell the user the reviewer hasn't finished yet.
2. **Verify the round numbers match before proceeding.** The `# Code Review Request — Round N` header in `request.md` must match the `# Code Review Response — Round N` header in `response.md`. If they do not match, stop and tell the user the current round has no reviewer response yet (stale `response.md` detected).
3. **Parse findings by severity.** Present a summary table:
   - Count of CRITICAL / WARNING / INFO findings
   - Verdict (PASS / PASS_WITH_CHANGES / FAIL)
4. **Ask user for confirmation** before implementing. User may say "implement all", "skip INFO", "let me review first", etc.
5. **Execute confirmed fixes.** For each fix, note what was done. For each skipped finding, note why.
6. **Handle verdict:**

   **If PASS:**
   a. Archive final round: copy `request.md` and `response.md` to `~/.codex/superpowers-review/archive/{scope}/round-{N}/`
   b. Clean up `active/{scope}/` directory
   c. Report summary to user — done!

   **If Round N ≥ 5 and verdict is not PASS:**
   Refuse to generate Round 6. Tell user: "5 review rounds completed without PASS. Escalating — please review manually or adjust approach."

   **If PASS_WITH_CHANGES or FAIL:**
   a. Stage the current Round N pair somewhere safe before overwriting anything: copy `active/{scope}/request.md` and `response.md` to temp files or a staging directory
   b. Generate the Round N+1 request in a temp file first (do NOT overwrite `active/{scope}/request.md` yet) when `N < 5`
   c. Archive the staged Round N request/response pair to `archive/{scope}/round-{N}/`
   d. Atomically replace `active/{scope}/request.md` with the staged Round N+1 request
   e. Remove or clear `active/{scope}/response.md` so Round N+1 cannot accidentally execute against stale reviewer output
   f. Tell user the prompt for the reviewer (same as Mode 1, step 4)

### Key Rules

- Always ask for user confirmation before implementing fixes.
- Stage the previous round before overwrite. Archive the staged Round N pair, then atomically replace the active request with Round N+1.
- Clear stale `active/{scope}/response.md` during rollover, and refuse execute mode if request/response round numbers do not match.
- Archive the final PASS round too (user may want to reference it).
- Track round number from the response header (`# Code Review Response — Round {N}`), not a separate file.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Stale `response.md` from previous round executed | Check round numbers match before processing (Step 2 of Execute Response) |
| Reviewer can't find referenced files | Verify all paths in "Files to Read" exist before generating request |
| 5+ rounds without PASS | Stop generating rounds, escalate to human review |
