---
name: issue-comment-debunker
source: superpowers-plus
triggers: ["comment on ticket", "post status update", "add investigation summary", "update the ticket with"]
anti_triggers: ["create issue", "update ticket fields", "close ticket"]
description: Use BEFORE posting any comment or update to issue tickets. Prevents (1) fabricated investigation summaries and (2) AI meta-commentary in ticket history.
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

> **Purpose:** Prevent AI from posting fabricated or misleading comments on tickets.
> **Pattern:** Evidence before assertion — no claims without citations.
> **Incidents:** 2026-02-18 — AI posted a fabricated "Investigation Summary" as authoritative update. 2026-05-26 — AI posted meta-commentary (description changelog + evidence analysis) to a ticket; had to be manually deleted.
>
> **Wrong skill?** Creating new issues → `issue-authoring`. Updating issue fields → `issue-editing`. Verifying URLs → `issue-link-verification`.

## When to Use

Invoke **BEFORE** any of these actions: adding a comment, status update, or investigation summary; documenting findings or conclusions; attributing statements to team members or claiming timestamps/metrics/outcomes.

## The Iron Rule (HARD GATE)

<EXTREMELY_IMPORTANT>

**DO NOT POST CLAIMS YOU CANNOT VERIFY.** This gate covers claim accuracy only. For framing and voice, see AI Meta-Commentary HARD GATE below.

| Banned Pattern | Why It's Dangerous |
|----------------|--------------------|
| "Investigation Summary" with fabricated details | Looks authoritative, pollutes ticket history |
| "Root cause identified as X" without evidence | Misdirects debugging efforts |
| "Confirmed that Y happened at Z time" | Creates false timeline |
| "Team discussed and agreed..." | Fabricates consensus |
| Attributing quotes to specific people | Puts words in mouths |
| "The deploy fixed it" without build/deploy link | Attributes outcome to wrong cause |

**If you cannot cite a source, you cannot post it as fact.**

</EXTREMELY_IMPORTANT>

---

## AI Meta-Commentary HARD GATE

<EXTREMELY_IMPORTANT>

**Evaluate this gate BEFORE generating the Preflight Evidence Block.** GATE FAIL → do not generate the preflight block — offer alternatives instead.

**This gate evaluates FRAMING and VOICE, not claim accuracy.** A fully evidenced comment still fails if it narrates AI process, decisions, or ticket-modification activity. Apply the trigger table mechanically — do not assess your own framing intent or confidence.

**Evaluation protocol (two required passes — BOTH must pass):**
1. **Structural test:** Is the grammatical subject of each sentence a system artifact, log entry, or engineering finding — rather than AI process or decisions?
2. **Trigger table check:** Check each sentence against the GATE FAIL table below — **regardless of the structural test result.** The trigger table governs on any conflict.

**Passive-voice ticket-modification predicates** ("the description was updated", "two findings were added to the ticket") trigger this gate regardless of grammatical subject.

**Compound artifact noun rule:** A phrase naming a specific artifact passes ("The CloudWatch analysis of group /aws/lambda/X"). A bare noun fails ("The analysis", "The investigation"). "Specific artifact" = one with a unique system identifier (URL, log group path, recording ID, PR number, commit SHA). Category nouns ("team feedback", "the codebase") do not qualify.

**Quoted human text exception:** Text quoted verbatim from a human (markdown `>` blockquote or attribution "X said: ...") is evaluated under the Iron Rule only — not this gate.

**GATE FAIL triggers — active AND passive voice, any person:**

| Pattern | Examples |
|---------|---------|
| AI ticket-modification actions | "I changed/revised/updated the description", "The description was updated to...", "Two findings were added to..." |
| AI cognition / reasoning | "I analyzed/assessed/evaluated/concluded...", "Three hypotheses were weighed/evaluated against..." (passive form — also triggers) |
| AI collaborative framing | "We updated/revised/added..." where "we" includes the AI |
| AI changelog commentary | "Update — ticket revised with N findings", "What changed: ...", "What stayed: ..." |
| AI recommendation / directive | "I would suggest/recommend...", "A better approach would be...", "Consider refactoring..." |

**Permitted first-person forms (including but not limited to) — do NOT trigger this gate:** `"I see/saw this in [artifact]: [paste]"`, `"I found/noticed X in [artifact]: [paste]"`, `"I reviewed/checked/looked at/investigated [specific artifact] and found: [paste]"`, `"I'm not sure, but it might be..."`. Not permitted even with a named artifact: *confirmed, validated, verified, determined, concluded* (epistemic action verbs, not observation verbs).

**Key distinction:** observation verb + named cited artifact = PASS. Action verb on ticket/description/fields = FAIL.

**Exemption — correction comments only:** Permitted exclusively to retract a specific false factual claim:
- PERMITTED: `"**Correction to [date] comment:** the [specific claim] is incorrect. Evidence: [citation]."`
- NOT PERMITTED: new analysis, recommendations, or reasoning in the correction
- NOT PERMITTED: after two corrections on the same **factual claim**, notify the user instead of posting again

**If gate fails — do not post. Offer one of:**
- "I can post only the engineering observation (stripped of AI framing) — e.g., 'Logs show X at timestamp Y.' Want me to draft that?"
- "Should I update the description directly?" (appropriate if finding revises the problem statement; use a new comment for time-stamped follow-on observations)
- "The finding is already in the description — is a comment needed?"

</EXTREMELY_IMPORTANT>

---

## Preflight Evidence Block (HARD GATE)

<EXTREMELY_IMPORTANT>

**Before generating this block, apply the AI Meta-Commentary HARD GATE above. GATE FAIL → do not generate this block — offer the three alternatives instead.**

**Emit immediately before calling your issue tracker's `create_comment` tool.** Do not summarize or skip fields. If `GATE != PASS`, do not post.

```
PREFLIGHT: ISSUE-COMMENT-DEBUNKER
- target_issue: <identifier>
- issue_verified: PASS | FAIL (via adapter)
- iron_rule_check: PASS | FAIL -> stop here (every claim has a cited source; no forbidden patterns)
- ai_meta_check: PASS | FAIL -> stop here (grammatical subjects are system artifacts/findings, not AI process; OR correction format exactly)
- entity_type: issue  # must be "issue", not pull_request or other
- claims_extracted: [list each factual claim in draft]
- evidence_per_claim: [claim -> source URL/SHA, or "UNVERIFIED" -> rewrite]
- forbidden_patterns: NONE | [list violations -> rewrite]
- existing_comments_checked: YES (count=N) -- same factual claim by me? YES (id) / NO
- comment_action: NEW       # Always create_comment; never silently update
- url_verification: PASS/FAIL OR "no URLs"
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Validate the Target Issue First

Normalize the identifier. Call `get_issue` or `verify_link` via your adapter. If `exists: false` or the entity is not an issue (e.g., pull_request) → stop and route to the appropriate workflow.

---

## Comment Hygiene

Before posting, check existing comments for a prior comment on the same topic.

| Scenario | Action |
|----------|--------|
| No prior comment | `create_comment` — post new |
| Prior comment, adding new info | `create_comment` — new comment. Do NOT silently overwrite history. |
| Prior comment had a factual error | `create_comment` — correction beginning with `**Correction to [date] comment:**`. Do NOT silently edit. |

Write for a teammate arriving fresh. Current state only — no revision numbers, no changelog updates.

---

## Citation Requirements

Every factual claim needs inline evidence:

```markdown
GOOD: The error occurs in `processMessage()` at line 47 (see stack trace above, request id req-abc123).

BAD: After thorough investigation, the root cause appears to be a race condition.
```

---

## Forbidden Comment Patterns

### "Investigation Summary" Anti-Pattern

```markdown
NEVER POST THIS:
## Investigation Summary (date)
After analyzing the system behavior, I've identified: 1. Root Cause... 2. Timeline...
```
**Why dangerous:** Reads as authoritative; future readers trust it as ground truth; pollutes ticket history.

### AI Meta-Commentary Anti-Pattern

```markdown
NEVER POST (AI changelog):
## Update -- ticket revised with two new findings
**What changed in the description:** ... **What stayed:** ...

NEVER POST (AI evidence analysis framing):
After analyzing the evidence, I assessed each claim. My recommended path forward: ...
```

**Why dangerous:** Teammates see AI talking to itself, not engineering decisions. A changelog belongs in a commit message. Creates redundant history that must be manually deleted.

**Post instead:** State the engineering observation directly — e.g., "Logs show 16-20% empty-response rate on service A vs 2-7% on service B against the same endpoint. Source: [permalink]."

---

## Before Posting: Final Check

Every claim has evidence · no fabricated timestamps/metrics · no "investigation summary" framing · no unsourced attributions · uncertainty marked · `ai_meta_check = PASS` · reads as observation, not conclusion · all URLs verified.

**If ANY check fails -> REWRITE before posting.**

---

## Recovery: If Bad Comment Posted

1. **Add correction immediately:** `"**Correction to [date] comment:** The above contains unverified claims I generated. Please disregard — evidence is being gathered now."` After two corrections on the same factual claim → notify the user rather than posting again.
2. **Do NOT silently edit** — timestamps don't update, future readers won't know.
3. **Notify the user** — they should review and potentially delete.

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Self-exemption: "This comment is different, I'm confident" | No — verify every claim regardless of confidence |
| Quoting code from memory | Re-read the file NOW — memory drifts within conversations |
| Constructing a timeline by interpolating between commit dates | Report only what git log actually says |
| Fabricating consensus: "The team agreed..." | Cite only meeting notes or documented comments |
| AI meta-commentary — active ("I revised/analyzed..."), passive ("description was updated..."), collective ("we added..."), bare noun ("The analysis...") | Apply the AI Meta-Commentary HARD GATE. Strip AI framing; post only the observation with citation. |

---

## Companion Skills

- **wiki-debunker**: Same principles for wiki content
- **verification-before-completion**: General verification discipline
- **think-twice**: Pause before consequential actions
- **issue-editing**: Editing issues after debunking claims
- **issue-authoring**: Creating issues with verified facts
- **issue-link-verification**: Checking links referenced in comments
