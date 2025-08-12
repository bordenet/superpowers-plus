---
name: issue-comment-debunker
source: superpowers-plus
triggers: ["comment on ticket", "post status update", "add investigation summary", "update the ticket with"]
description: Use BEFORE posting any comment or update to issue tickets. Prevents fabricated investigation summaries, status updates, and unverified claims. Evidence before assertion — no claims without citations.
---

# Issue Comment Debunker

> **Purpose:** Prevent AI from posting fabricated or misleading comments on tickets
> **Pattern:** Evidence before assertion — no claims without citations

---

## When to Use

Invoke **BEFORE** any of these actions:

- Adding a comment to a ticket
- Posting a status update or investigation summary
- Documenting findings or conclusions on a ticket
- Attributing statements to team members
- Claiming specific timestamps, metrics, or outcomes

---

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

---

## Pre-Comment Checklist

Before posting ANY comment to your issue tracker:

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

---

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

---

## Safe vs. Unsafe Comments

| Safe | Unsafe |
|------|--------|
| "I see this error in the logs: [paste]" | "The error appears to be caused by..." |
| "This commit changed X: [link]" | "Someone recently modified the..." |
| "The code at line 47 does Y" | "After thorough analysis..." |
| "I'm not sure, but it might be..." | "The root cause is definitely..." |
| "Question: Could X cause Y?" | "Investigation confirms X caused Y" |

---

## Before Posting: Final Check

```
┌─────────────────────────────────────────────────────────────┐
│ ISSUE COMMENT GATE                                         │
├─────────────────────────────────────────────────────────────┤
│ □ Every factual claim has cited evidence                   │
│ □ No fabricated timestamps or metrics                       │
│ □ No "investigation summary" framing                        │
│ □ No attributions without source                            │
│ □ Uncertainty is explicitly marked                          │
│ □ Reads as observation, not authoritative conclusion        │
└─────────────────────────────────────────────────────────────┘

If ANY box is unchecked → REWRITE before posting.
```

---

## Recovery: If Bad Comment Posted

If you've already posted a problematic comment:

1. **Add correction immediately:**
   ```markdown
   ⚠️ CORRECTION: The above comment contains unverified claims I generated.
   Please disregard the investigation summary — it may contain inaccuracies.
   ```

2. **Do NOT silently edit** — timestamps don't update, future readers won't know

3. **Notify the user** — they should review and potentially delete

---

## Related Skills

- **wiki-debunker**: Same principles for wiki content
- **verification-before-completion**: General verification discipline
- **think-twice**: Pause before consequential actions

---

## Quick Reference

```
Before posting ANY your issue tracker comment:

1. EXTRACT — What claims am I making?
2. VERIFY — Can I cite evidence for each?
3. REFRAME — Is this observation or conclusion?
4. HEDGE — Am I marking uncertainty appropriately?
5. CHECK — Does this look like fabricated analysis?
```
