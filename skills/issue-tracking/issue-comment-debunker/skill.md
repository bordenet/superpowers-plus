---
name: issue-comment-debunker
source: superpowers-plus
triggers: ["comment on ticket", "post status update", "add investigation summary", "update the ticket with"]
anti_triggers: ["create issue", "update ticket fields", "close ticket"]
description: Use BEFORE posting any comment or update to issue tickets. Prevents fabricated investigation summaries, status updates, and unverified claims. Evidence before assertion — no claims without citations.
summary: "Use when: posting comments on issue tickets. Skip when: reading issues only."
coordination:
  group: issue-tracking
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [investigation-evidence]
  produces: [verified-comment]
  capabilities: [validates-assertions]
  priority: 25
---

# Issue Comment Debunker

> **Purpose:** Prevent AI from posting fabricated or misleading comments on tickets
> **Pattern:** Evidence before assertion — no claims without citations
>
> **Wrong skill?** Creating new issues → `issue-authoring`. Updating issue fields → `issue-editing`. Verifying URLs → `issue-link-verification`.

## When to Use

Invoke **BEFORE** any of these actions:

- Adding a comment to a ticket
- Posting a status update or investigation summary
- Documenting findings or conclusions on a ticket
- Attributing statements to team members
- Claiming specific timestamps, metrics, or outcomes

## ⛔ The Iron Rule

<EXTREMELY_IMPORTANT>

**DO NOT POST CLAIMS YOU CANNOT VERIFY.**

| Banned Pattern | Why It's Dangerous |
|----------------|-------------------|
| "Investigation Summary" with fabricated details | Looks authoritative, pollutes ticket history |
| "Root cause identified as X" without evidence | May misdirect debugging efforts |
| "Confirmed that Y happened at Z time" | Creates false timeline |
| "Team discussed and agreed..." | Fabricates consensus |
| Attributing quotes to specific people | Puts words in mouths |

**If you cannot cite a source, you cannot post it as fact.**

</EXTREMELY_IMPORTANT>

## Pre-Comment Checklist

<EXTREMELY_IMPORTANT>

**HARD HALT before proceeding:** If you cannot cite a specific tool call (view, read, grep, query) that retrieved the evidence for each claim in your draft comment, STOP. Do NOT proceed to the checklist steps below. Rewrite the comment to contain only claims you have directly observed from tool output.

</EXTREMELY_IMPORTANT>

Before posting ANY comment to your issue tracker:

### 0. Validate the Target Issue

Before any claim verification, confirm the target is a real, non-PR issue:

1. Normalize the identifier using your adapter's documented rules (e.g., GitHub adapter: strip `#` prefix and `owner/repo#` prefix)
2. Call `get_issue` for identifier-based targets, or `verify_link` for URL-based targets, via your adapter
3. If **`exists: false`**: stop — report identifier not found; do not comment
4. If **`entityType` is anything other than `"issue"`** (i.e., `pull_request`, `other`, or `unknown`): stop and do not comment — route to the appropriate workflow or surface the uncertainty to the user

If the adapter result is ambiguous (cross-workspace, network error), surface the uncertainty before proceeding.

### 1. Identify Claim Types

Parse your draft comment for:

- [ ] Factual claims (X happened, Y caused Z)
- [ ] Attributions (Person said/did X)
- [ ] Timestamps (At HH:MM, on DATE)
- [ ] Metrics (X% improvement, N errors)
- [ ] Conclusions (Root cause is X, Solution is Y)

### 2. Verify Each Claim

| Claim Type | Required Evidence | How to Get It |
|------------|-------------------|---------------|
| What happened | Logs, error messages, git history | Query actual systems |
| Who did what | Git blame, PR author, commit history | `git log --author` |
| When it happened | Timestamps from logs, git commits | Actual log output |
| Why it happened | Code analysis, documented decisions | Read the code, not assume |
| What to do next | Established runbooks, prior decisions | Link to docs |

### 3. Citation Requirements

Every factual claim needs inline evidence:

```markdown
✅ GOOD:
The error occurs in `processMessage()` at line 47 (see stack trace above).

❌ BAD:
After thorough investigation, the root cause appears to be a race condition
in the message processing layer.
```

## Forbidden Comment Patterns

### "Investigation Summary" Anti-Pattern

The exact pattern that caused the incident:

```markdown
❌ NEVER POST THIS:

## Investigation Summary (2026-02-18)

After analyzing the system behavior, I've identified the following:

1. **Root Cause**: The webhook handler was...
2. **Timeline**: At 14:32, the first error occurred...
3. **Impact**: Approximately 47 requests were affected...
4. **Resolution**: The fix involves updating the retry logic...
```

**Why it's dangerous:**

- Reads as authoritative status update
- Contains fabricated timestamps, metrics, analysis
- Future readers will trust it as ground truth
- Pollutes ticket history with misinformation

### What to Post Instead

```markdown
✅ ACCEPTABLE:

I looked at [specific log/code/resource] and found:
- [Actual observation with link/quote]

I'm not certain about:
- [Things you're unclear on]

Next step: [Specific action, not speculation]
```

## Safe vs. Unsafe Comments

| Safe | Unsafe |
|------|--------|
| "I see this error in the logs: [paste]" | "The error appears to be caused by..." |
| "This commit changed X: [link]" | "Someone recently modified the..." |
| "The code at line 47 does Y" | "After thorough analysis..." |
| "I'm not sure, but it might be..." | "The root cause is definitely..." |
| "Question: Could X cause Y?" | "Investigation confirms X caused Y" |

## Before Posting: Final Check

Every claim has evidence · no fabricated timestamps/metrics · no "investigation summary" framing · no unsourced attributions · uncertainty marked · reads as observation, not conclusion.

**If ANY check fails → REWRITE before posting.**

## Recovery: If Bad Comment Posted

If you've already posted a problematic comment:

1. **Add correction immediately:**

   ```markdown
   ⚠️ CORRECTION: The above comment contains unverified claims I generated.
   Please disregard the investigation summary — it may contain inaccuracies.
   ```

2. **Do NOT silently edit** — timestamps don't update, future readers won't know

3. **Notify the user** — they should review and potentially delete

## Example

```bash
# Verify factual claims in issue comments
# Check: commit SHAs exist, PR numbers are real, dates match events
git log --oneline --after="2026-01-14" --before="2026-01-16" | head -5
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Self-exemption: "This comment is different, I'm confident" | No — verify every factual claim regardless of confidence |
| Quoting code from memory instead of re-reading the file | Re-read the file NOW — memory drifts within conversations |
| Constructing a timeline by interpolating between git commit dates | Report only what git log actually says — gaps between commits are unknown |
| Fabricating consensus: "The team agreed..." | Only attribute decisions you can cite from meeting notes or comments |

## Companion Skills

- **wiki-debunker**: Same principles for wiki content
- **verification-before-completion**: General verification discipline
- **think-twice**: Pause before consequential actions
- **issue-editing**: Editing issues after debunking claims
- **issue-authoring**: Creating issues with verified facts
- **issue-link-verification**: Checking links referenced in comments
