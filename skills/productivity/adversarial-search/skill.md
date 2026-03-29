---
name: adversarial-search
source: superpowers-plus
triggers: ["adversarial search", "investigation inversion", "search for the wrong thing", "confirmation bias check"]
anti_triggers: ["brainstorm", "design options", "plan this feature", "self-prompt"]
description: Use when investigating bugs, inconsistencies, conducting any search/grep task, OR when the user requests rigorous/thorough/comprehensive analysis. Routed to by thinking-orchestrator for confirmation-bias, negative-finding, and depth-challenge triggers. Prevents confirmation bias by forcing search for the WRONG thing, not just confirming the RIGHT thing exists.
summary: "Use when: investigating bugs or conducting search tasks. Prevents confirmation bias."
coordination:
  group: thinking
  order: 2
  requires: []
  enables: ["think-twice", "verification-before-completion"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
---

# Adversarial Search

> **Wrong skill?** Getting unstuck on a bug → `think-twice`. Research → `perplexity-research`. Broad brainstorming → `brainstorming`.

> **Never confirm correctness. Hunt for incorrectness.** The user's observed behavior is ground truth. Your grep results are not.

## The Three Steps

### Step 1: Investigation Inversion

Search for the BAD thing, not the good thing. If user says "you're using X instead of Y" → grep for X. Finding Y everywhere proves nothing.

### Step 2: Exhaustive Scope

Search ALL of these — never stop at the first clean scope:
- Repo source code (drop `--include` — catches `.env`, `.sample`, config files)
- Gitignored files (`.env` files contain real config)
- Deployed/installed copies (`~/.codex/`, `~/.augment/`) — **only after in-repo search is exhausted**
- Other repos (monorepo/multi-repo setups) — **only with explicit user permission**
- Home directory configs — **only with explicit user permission**

**Anti-pattern:** `--include='*.ts'` misses `.env` files. This caused the `WIKI_API_TOKEN` miss (2026-03-17).

⛔ **HARD GATE — IP/Redaction:**
- **Out-of-repo search requires explicit user permission.** If permission is not granted, **do not proceed** — limit search to the current repo only.
- **Never paste match context.** Report only: filename + high-level description (e.g., "found token present in `~/.env` (redacted)"). <!-- doctor-ignore -->
- **Never paste** proprietary code, config values, tokens, or credentials into responses.
- If unsure whether content is proprietary, **treat it as proprietary and redact.**

### Step 3: Adversarial Self-Review

Before reporting "no issue found," answer:
1. Did I search for the WRONG thing, or only confirm the RIGHT thing?
2. Did `--include` patterns exclude the problem file type?
3. Did I search only tracked files and miss gitignored configs?
4. Did I search only ONE repo when the system spans multiple?
5. Am I about to tell the user their observed behavior is wrong? (It almost never is.)

**If YES to any of 2-5: DO NOT report "no issue." Search again.**

## Depth Challenge Gate

When user asks for rigor/thorough/comprehensive analysis:
1. **Enumerate dimensions** — ≥3 angles (technical, operational, security, performance, etc.)
2. **Enumerate items** — list ALL items in scope, check each one
3. **Challenge conclusions** — for every conclusion, ask "what evidence contradicts this?"
4. **Check scope reduction** — did you silently drop part of the request?

## Rationalizations to Reject

| Excuse | Reality |
|--------|---------|
| "I searched and didn't find it" | Wrong scope or wrong term |
| "All files use the correct value" | You confirmed correctness, not disproved the bug |
| "No changes needed" | The user just told you something is broken. It is. |


## Companion Skills

- **think-twice**: Escalation when adversarial search isn't enough
- **systematic-debugging**: For specific bug investigation
- **verification-before-completion**: Final verification step
- **investigation-state**: Investigation state tracking
## When to Use

- When investigating bugs, inconsistencies, or suspected incorrect values
- BEFORE declaring negative findings ("no issue found", "already correct")
- When user reports a problem and you're about to dismiss it
- When user requests rigorous, thorough, or comprehensive analysis


## Failure Modes

| Failure | Fix |
|---------|-----|
| Confirmation bias — searched for correct value, not incorrect one | Invert the search: grep for the BAD thing |
| Narrow scope — `--include='*.ts'` missed `.env` files | Drop file-type filters, search ALL files |
| Single-repo search in multi-repo system | Enumerate ALL repos that could contain the value |

```bash
# Example: adversarial search — hunt for the WRONG value
grep -r "OUTLINE_API_TOKEN" . --include='*' | head -20
# NOT: grep -r "OUTLINE_API_KEY" (that just confirms the right thing exists)
```
