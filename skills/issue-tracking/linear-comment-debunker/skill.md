---
name: linear-comment-debunker
source: superpowers-callbox
description: Use BEFORE posting any comment, closure rationale, or claim-bearing text to Linear tickets. Prevents fabricated investigation summaries, unverified claims, and comment pollution. Also owns comment hygiene (single living comment rule).
summary: "Use when: posting comments or claim-bearing text on Linear tickets."
triggers: ["comment on Linear ticket", "post Linear status update", "add investigation summary", "update issue with findings", "close issue with rationale", "root cause analysis"]
coordination:
  group: linear
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['create ticket', 'edit ticket', 'search tickets']
---

# Linear Comment Debunker

> **Owns:** All comments, closure rationale, blame/causality statements on Linear tickets
> **Incident:** 2026-02-18 — AI posted fabricated "Investigation Summary" as authoritative update

## ⛔ The Iron Rule

<EXTREMELY_IMPORTANT>

**DO NOT POST CLAIMS YOU CANNOT VERIFY.** If you cannot cite a source, you cannot post it as fact.

| Banned Pattern | Why It's Dangerous |
|----------------|-------------------|
| "Investigation Summary" with fabricated details | Looks authoritative, pollutes ticket history |
| "Root cause identified as X" without evidence | Misdirects debugging |
| "Confirmed that Y happened at Z time" | Creates false timeline |
| "Team discussed and agreed..." | Fabricates consensus |
| Attributing quotes to specific people | Puts words in mouths |

</EXTREMELY_IMPORTANT>

---

## Preflight Evidence Block

<EXTREMELY_IMPORTANT>

**Emit this block immediately before calling `add_comment_linear`.** Do not summarize or skip fields. If `GATE != PASS`, do not post.

```
PREFLIGHT: COMMENT
- claims_extracted: [list each factual claim in draft]
- evidence_per_claim: [claim → source, or "UNVERIFIED" → must rewrite]
- forbidden_patterns: NONE | [list violations found → must rewrite]
- existing_comments: [fetched — same-topic comment by me? YES (id) / NO]
- comment_action: NEW | UPDATE_EXISTING (comment id)
- url_verification: [PASS/FAIL if links in comment] or "no URLs"
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed with the comment. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Comment Hygiene

Before posting, fetch existing comments on the issue. Check if you already have a comment on the same topic.

- **Same-topic comment exists →** prefer updating it over adding a new one (via `linear` tool `updateComment` mutation)
- **No existing comment →** post new
- **Correcting a prior comment →** append a follow-up correction, do NOT silently edit history

Write for a teammate arriving fresh. Current state only — no revision numbers, no changelog-style updates.

---

## Claim Verification

| Claim Type | Required Evidence | How to Get It |
|------------|-------------------|---------------|
| What happened | Logs, error messages, git history | Query actual systems |
| Who did what | Git blame, PR author, commit history | `git log --author` |
| When it happened | Timestamps from logs/commits | Actual log output |
| Why it happened | Code analysis, documented decisions | Read the code |
| What to do next | Runbooks, prior decisions | Link to docs |

---

## Safe vs. Unsafe

| Safe | Unsafe |
|------|--------|
| "I see this error in the logs: [paste]" | "The error appears to be caused by..." |
| "This commit changed X: [link]" | "Someone recently modified the..." |
| "The code at line 47 does Y" | "After thorough analysis..." |
| "Question: Could X cause Y?" | "Investigation confirms X caused Y" |

**Uncertainty is mandatory** when evidence is partial: "I'm not sure, but it might be..." is acceptable. "The root cause is definitely..." without evidence is not.

---

## The Forbidden Pattern

```markdown
❌ NEVER POST:
## Investigation Summary (2026-02-18)
After analyzing the system behavior, I've identified:
1. Root Cause: The webhook handler was...
2. Timeline: At 14:32, the first error...
3. Impact: Approximately 47 requests...
```

```markdown
✅ POST INSTEAD:
I looked at [specific resource] and found:
- [Actual observation with link/quote]

I'm not certain about:
- [Things unclear]

Next step: [Specific action, not speculation]
```

---

## Recovery: If Bad Comment Posted

1. Add correction immediately — do not silently edit (future readers won't know)
2. Notify user — they should review and potentially delete

---

## Compound Workflows

| Intent | Sequence |
|--------|----------|
| "Close with explanation" | debunker validates comment → `linear-issue-editing` updates status → debunker posts comment |
| "Update status and comment" | `linear-issue-editing` updates status first → debunker posts comment second |
| "Create from investigation" | debunker validates claims → `linear-issue-authoring` creates issue |

---

## Failure Modes

| Failure | Consequence |
|---------|-------------|
| Fabricated investigation summary | Pollutes ticket history, misdirects team |
| Multiple comments superseding each other | Noise, confusing history |
| Unverified claims posted as fact | Team acts on wrong information |


## When to Use

- Before posting any comment or closure rationale to Linear tickets
- Verifying claims in comments against actual evidence
- Posting investigation summaries with provenance
