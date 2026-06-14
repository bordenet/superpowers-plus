---
name: linear-comment-debunker-engineer
source: superpowers-plus
augment_menu: true
triggers: ["post Linear status update", "add investigation summary", "update issue with findings", "close issue with rationale", "post engineering update"]
anti_triggers: ["/linear-comment-debunker-pm", "create ticket", "edit ticket fields", "search tickets", "PM customer-impact framing"]
description: Use BEFORE posting any engineer comment, closure rationale, or claim-bearing text to organization Linear tickets. Prevents (1) fabricated investigation summaries and (2) AI meta-commentary in ticket history.
summary: "Use when: posting engineer comments or claim-bearing text on organization Linear tickets at linear.app."
coordination:
  group: linear
  order: 4
  requires: ['linear-issue-verify', 'linear-comment-gate']
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [investigation-evidence, user-intent]
  produces: [verified-comment]
  capabilities: [validates-assertions]
  priority: 25
  optional: false
  requires_all: true
internal_refs_ok: true
---

# linear-comment-debunker-engineer

> **Purpose:** Prevent AI from posting fabricated or misleading engineer comments on organization Linear tickets.
> **Pattern:** Evidence before assertion — no claims without citations to git, ADO PRs, Fathom recordings, logs, or Linear search.
> **Incidents:** 2026-02-18 — fabricated "Investigation Summary" posted as authoritative update. 2026-05-26 — AI meta-commentary (description changelog + evidence analysis) posted to incident-2026-1563; manually deleted.
>
> **Wrong skill?** Creating issues → `linear-issue-authoring-engineer` · Editing fields → `linear-issue-editing-engineer` · Verifying URLs → `link-verification` · PM framing → `linear-comment-debunker-pm`

## When to Use

Invoke **BEFORE** any of these actions on `linear.app/issue/{KEY}`: adding a comment, status update, or investigation summary; documenting engineering findings or root-cause conclusions; attributing statements to teammates or claiming timestamps/metrics/outcomes.

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
| "The deploy fixed it" without ADO build link | Attributes outcome to wrong cause |

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

**Passive-voice ticket-modification predicates** ("the description was updated", "two findings were added to the ticket") trigger this gate regardless of grammatical subject — the structural test's subject-based logic does not apply to ticket-modification predicates.

**Compound artifact noun rule:** A phrase naming a specific artifact passes ("The CloudWatch analysis of group /aws/lambda/X"). A bare noun fails ("The analysis", "The investigation", "The review"). "Specific artifact" = one with a unique system identifier (URL, log group path, recording ID, PR number, or commit SHA). Category nouns ("team feedback", "the codebase") do not qualify.

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

**Exemption — correction comments only:** Permitted exclusively to retract a specific false factual claim from a prior comment. Scope is strict:
- PERMITTED: `"**Correction to [date] comment:** the [specific claim] is incorrect. Evidence: [citation]."`
- NOT PERMITTED: new analysis, recommendations, or reasoning in the correction
- NOT PERMITTED: chained corrections — after two corrections on the same **factual claim**, notify the user instead of posting again

**If gate fails — do not post. Offer one of:**
- "I can post only the engineering observation (stripped of AI framing) — e.g., 'CloudWatch shows X at Y.' Want me to draft that?"
- "Should I update the description directly?" (appropriate if finding revises the problem statement; use a new comment for time-stamped follow-on observations)
- "The finding is already in the description — is a comment needed?"

</EXTREMELY_IMPORTANT>

---

## Preflight Evidence Block (HARD GATE)

<EXTREMELY_IMPORTANT>

**Before generating this block, apply the AI Meta-Commentary HARD GATE above. GATE FAIL → do not generate this block — offer the three alternatives instead.**

**Emit immediately before calling the `create_comment` MCP tool.** Do not summarize or skip fields. If `GATE != PASS`, do not post.

```
PREFLIGHT: LINEAR-COMMENT-ENGINEER
- target_issue: <TEAM-NNNN>
- issue_verified: PASS | FAIL (via linear-issue-verify)
- iron_rule_check: PASS | FAIL → stop here (every claim has a cited source; no forbidden patterns)
- ai_meta_check: PASS | FAIL → stop here (grammatical subjects are system artifacts/findings, not AI process; OR correction format exactly)
- entity_type: issue  # must be "issue", not pull_request or other
- claims_extracted: [list each factual claim in draft]
- evidence_per_claim: [claim -> source URL/SHA, or "UNVERIFIED" -> rewrite]
- evidence_sources_used:
    - git/ADO commit SHAs:    [list, or NONE]
    - Azure DevOps PR URLs:   [dev.azure.com/yourorg/... or NONE]
    - Fathom recording links: [fathom.video/... or NONE]
    - Linear cross-refs:      [linear.app/issue/... or NONE]
    - Wiki refs:              [wiki.yourorg.com/... or NONE]
    - Log snippets:           [pasted inline or NONE]
- forbidden_patterns: NONE | [list violations -> rewrite]
- linear_comment_gate: PASS (action=NEW|EDIT|CONSOLIDATE) | EXEMPT (reason=...) — must run before this preflight
- comment_action: [from gate: NEW=create_comment, EDIT=commentUpdate, CONSOLIDATE=create_comment after delete]
- url_verification: PASS/FAIL (link-verification ran) OR "no URLs"
- GATE: PASS | FAIL (reason)
```

If GATE is not PASS, do not proceed. Fix the failing condition first.

</EXTREMELY_IMPORTANT>

---

## Validate the Target Issue First

Normalize the identifier (`DELTA-1189`, not `#1189`). Run `linear-issue-verify`. If `exists: false` or the entity resolves to a project/document → stop and route to the appropriate workflow.

---

## Comment Hygiene (HARD GATE -- route through linear-comment-gate first)

**linear-comment-gate MUST run before this skill.** The gate classifies the proposed comment and determines the correct action. Do not bypass it.

| Gate verdict | Action |
|--------------|--------|
| `NEW` | `create_comment_linear` -- proceed normally |
| `EDIT` | `commentUpdate` on the existing same-topic comment -- append new content as a dated subsection |
| `CONSOLIDATE` | Gate handles merge + delete first; then `create_comment_linear` with consolidated body |
| `EXEMPT (reason=factual-correction)` | `create_comment_linear` beginning with `**Correction to [date] comment:**` |

> **Why linear-comment-gate?** The prior rule ("prior comment exists -- always post new") was correct for factual evidence but wrong for engineering progress updates. incident-2026-1507 (2026-06-12) produced 10 individual MR !23 status comments on one ticket over 12 hours under the old rule.

Write for a organization teammate arriving fresh. Current state only -- no revision numbers, no changelog-style updates.

---

## Citation Requirements

Every factual claim needs inline evidence:

```markdown
GOOD: The error occurs in `processMessage()` at line 47 of
github.com/bordenet/example
(CloudWatch group /aws/lambda/scheduler-prod, request id req-abc123).
ADO PR #24513 introduced this on 2026-03-04.

BAD: After thorough investigation, the root cause appears to be a race condition.
```

---

## Forbidden Comment Patterns

### "Investigation Summary" Anti-Pattern

```markdown
NEVER POST THIS:
## Investigation Summary (2026-02-18)
After analyzing the system behavior, I've identified: 1. Root Cause... 2. Timeline...
```
**Why dangerous:** Reads as authoritative; future engineers trust it as ground truth; pollutes ticket history with misinformation.

### AI Meta-Commentary Anti-Pattern (Incident 2026-05-26, incident-2026-1563)

```markdown
NEVER POST (AI changelog):
## Update — ticket revised with two new findings
**What changed in the description:** ... **What stayed:** ...

NEVER POST (AI evidence analysis framing):
After analyzing the evidence, I assessed each claim. My recommended path forward: ...
```

**Why dangerous:** Engineers see AI talking to itself, not engineering decisions. A changelog belongs in a commit message. Creates redundant history that must be manually deleted.

**Post instead:** State the engineering observation directly — e.g., "CloudWatch group `/aws/lambda/org-agent-lambda-production` shows 16–20% empty-response rate on receptionist vs 2–7% on scheduler. Source: [CloudWatch Insights permalink]."

---

## Before Posting: Final Check

Every claim has evidence · no fabricated timestamps/metrics · no "investigation summary" framing · no unsourced attributions · uncertainty marked · `ai_meta_check = PASS` (grammatical subjects are system artifacts/findings, not AI process) · reads as observation, not conclusion · all URLs verified via `link-verification`.

**If ANY check fails -> REWRITE before posting.**

---

## Recovery: If Bad Comment Posted

1. **Add correction immediately** as a new comment: `"**Correction to [date] comment:** The above contains unverified claims I generated. Please disregard — source evidence is being gathered now."` After two corrections on the same factual claim → notify the user rather than posting again.
2. **Do NOT silently edit** (except when the gate returned `action=EDIT` — that path is the authorized `commentUpdate` with a dated subsection per the EDIT Procedure). Unilateral silent edits outside a gate verdict remain forbidden.
3. **Notify the user** — they should review and potentially delete.

---

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Self-exemption: "This comment is different, I'm confident" | No — verify every claim regardless of confidence |
| Quoting code from memory | Re-read the file NOW — memory drifts within conversations |
| Constructing a timeline by interpolating between commit dates | Report only what `git log` actually says — gaps are unknown |
| Fabricating consensus: "The team agreed..." | Cite only Fathom recordings, Linear comments, or wiki notes |
| Fathom recording without a timestamp | Include the exact `?timestamp=NNN` in the URL |
| Posting closure rationale without `linear-issue-verify` | Always verify the issue is in a closable state |
| AI meta-commentary — active ("I revised/analyzed..."), passive ("description was updated..."), collective ("we added..."), bare noun ("The analysis...") | Apply the AI Meta-Commentary HARD GATE. Strip AI framing; post only the engineering observation with its citation. |

---

## Companion Skills

- `linear-issue-verify` — REQUIRED before any comment (validates target issue)
- `link-verification` — REQUIRED if comment contains URLs
- `fathom-meeting-notes` — pull Fathom transcripts for citation
- `wiki-debunker` — same principles for Outline wiki content
- `verification-before-completion` — general verification discipline
- `think-twice` — pause before consequential actions
- `linear-issue-editing-engineer` — editing issue fields after debunking claims
- `linear-issue-authoring-engineer` — creating issues with verified facts
- `linear-comment-debunker-pm` — sibling skill for PM-framed comments (use INSTEAD if you are the PM)
