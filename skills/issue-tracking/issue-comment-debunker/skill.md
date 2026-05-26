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
  enables: [issue-editing, issue-authoring]  # advisory: no runtime enforcement
  escalates_to: []
  internal: false
composition:
  consumes: []
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

**This gate evaluates FRAMING and VOICE, not claim accuracy.** Apply the checklist below mechanically — do not assess your own framing intent or confidence.

**Evaluation checklist — run all three steps on every sentence; FAIL if any hit:**

1. **Passive-voice ticket-modification?** ("the description was updated", "findings were added to the ticket") → FAIL regardless of grammatical subject.
2. **AI as subject?** Is the grammatical subject AI process or decisions rather than a system artifact, log entry, or finding? → FAIL.
3. **Trigger table hit?** Does any sentence match a pattern below? → FAIL.

**GATE FAIL triggers — active AND passive voice, any person:**

| Pattern | Examples |
|---------|---------|
| AI ticket-modification actions | "I changed/revised/updated the description", "The description was updated to...", "Two findings were added to..." |
| AI cognition / reasoning | "I analyzed/assessed/evaluated/concluded...", "Three hypotheses were weighed/evaluated against..." (passive form — also triggers) |
| AI collaborative framing | "We updated/revised/added..." (an AI author writing "we" on a ticket always includes itself) |
| AI changelog commentary | "Update — ticket revised with N findings", "What changed: ...", "What stayed: ..." |
| AI recommendation / directive | "I would suggest/recommend...", "A better approach would be...", "Consider refactoring..." |

**Compound artifact noun rule:** Named specific artifact (URL, log group path, recording ID, PR number, commit SHA) = passes. Bare noun ("The analysis", "The investigation") = FAIL. Category nouns ("team feedback") do not qualify.

**Permitted observation verbs (do NOT trigger) — when paired with a named cited artifact:** see/saw, found/noticed, reviewed/checked/looked at/investigated. Not permitted even with a named artifact: *confirmed, validated, verified, determined, concluded* (epistemic action verbs, not observation verbs).

**Key distinction:** observation verb + named cited artifact = PASS. Any trigger table match = FAIL, regardless of verb type or artifact naming.

**Quoted human text exception:** Verbatim human quotes (`>` blockquote or "X said: ...") → Iron Rule only, skip this gate.

**Exemption — correction comments only:** Permitted exclusively to retract a specific false factual claim:
- PERMITTED: `"**Correction to [date/id] comment:** the [specific claim] is incorrect. Evidence: [citation]."`
- NOT PERMITTED: new analysis, recommendations, or reasoning in the correction
- NOT PERMITTED: after two corrections on the same **factual claim**, notify the user instead of posting again

**If gate fails — do not post. Offer one of:**
- "I can post only the observation (stripped of AI framing) — e.g., 'Logs show X at timestamp Y.' Want me to draft that?"
- "Should I update the description directly?" (appropriate if finding revises the problem statement)
- "The finding is already in the description — is a comment needed?"

</EXTREMELY_IMPORTANT>

---

## Preflight Evidence Block (HARD GATE)

<EXTREMELY_IMPORTANT>

**Before generating this block, apply the AI Meta-Commentary HARD GATE above. GATE FAIL → do not generate this block — offer the three alternatives instead.**

**Emit immediately before calling your issue tracker's `create_comment` tool.** Do not summarize or skip fields. If `GATE != PASS`, do not post.

> **Self-attestation caveat:** This block is filled in by the AI. On high-stakes tickets, a human should spot-check before the comment goes live.

```
PREFLIGHT: ISSUE-COMMENT-DEBUNKER
- target_issue: <identifier>
- issue_verified: PASS | FAIL (via adapter)
- iron_rule_check: PASS | FAIL -> stop here (every claim has a cited source; no forbidden patterns)
- ai_meta_check: PASS | FAIL -> stop here (BOTH passes required: structural test AND trigger table PASS; OR correction format exactly)
- entity_type: issue  # must be "issue", not pull_request or other
- claims_extracted: [list each factual claim in draft]
- evidence_per_claim: [claim -> source URL/SHA, or "UNVERIFIED" -> rewrite]
- forbidden_patterns: NONE | [list violations -> rewrite]
- existing_comments_checked: YES (count=N) -- same factual claim re-asserted? YES (id) → GATE FAIL / NO
- correction_count: N  # per-ticket; gate fails on 3rd correction for same claim → notify user instead
- comment_action: NEW       # Always create_comment; never silently update
- url_verification: PASS/FAIL OR "no URLs"
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Validate the Target Issue First

Normalize the identifier. Run `issue-verify` via your adapter (`get_issue` or `verify_link`). Routing table:

| Result | Action |
|--------|--------|
| `exists: false` | STOP — identifier not found |
| `entity_type: pull_request` | STOP — use PR review workflow, not this skill |
| `entity_type: other / unknown` | STOP — ask user which workflow applies |
| `exists: true, entity_type: issue` | Proceed |
| tool error / timeout | STOP — surface error to user, do not proceed |

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

1. **Add correction immediately:** `"**Correction to [date] comment:** the [specific claim] is incorrect. Evidence: [citation]."` After two corrections on the same factual claim → notify the user rather than posting again.
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

- **issue-verify**: REQUIRED — validate issue exists and is the correct entity type before commenting
- **issue-link-verification**: REQUIRED if comment contains URLs
- **wiki-debunker**: Same principles for wiki content
- **verification-before-completion**: General verification discipline
- **think-twice**: Pause before consequential actions
- **issue-editing**: Editing issues after debunking claims
- **issue-authoring**: Creating issues with verified facts
