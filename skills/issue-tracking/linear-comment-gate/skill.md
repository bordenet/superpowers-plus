---
name: linear-comment-gate
source: superpowers-plus
augment_menu: false
triggers: ["post comment to Linear", "add Linear comment", "comment on Linear ticket", "post Linear status update", "MR update to ticket", "post progress update to Linear", "update ticket with findings"]
anti_triggers: ["create ticket", "edit ticket fields", "search Linear", "PM framing"]
description: Pre-comment classification gate. Enforces the one-living-comment rule for engineering progress updates -- prevents comment explosion by routing status updates to edit/consolidation rather than new comments. Mandatory before any commentCreate on a Linear ticket.
summary: "Classify a proposed Linear comment as NEW, EDIT, or CONSOLIDATE before allowing commentCreate."
coordination:
  group: linear
  order: 3.5
  requires: ['linear-issue-verify']
  enables: ['linear-comment-debunker-engineer']
  escalates_to: []
  internal: false
composition:
  consumes: [proposed-comment, existing-issue-comments]
  produces: [comment-action]
  capabilities: [classifies-comments, enforces-volume-discipline]
  priority: 20
  optional: false
  requires_all: false
internal_refs_ok: true
---

# linear-comment-gate

> **Purpose:** Stop Linear comment-thread explosion. Classify every proposed comment as NEW, EDIT, or CONSOLIDATE before any `commentCreate` call.
> **Incident:** incident-2026-1507 (2026-06-12) -- 10 individual engineering status comments on one ticket over 12 hours, all about MR !23. Required a manual consolidation session to make the ticket readable.
> **Core rule:** One living comment per ongoing work thread. Progress updates amend the existing comment. New comments are for state transitions and new work items only.
> **Scope note:** This gate lives in `skills/engineer/` and is required by both engineer and PM debunker skills. The one-living-comment rule applies equally to both. Migration to `skills/common/` is a follow-on task.

## Exemptions (emit EXEMPT verdict, skip classification)

Two paths bypass Steps 2-3 (classification is skipped) but still run Step 4 to emit a traceable preflight block:

- **Threaded reply** to another person's comment: skip to Step 4 with `action=EXEMPT (reason=threaded-reply)`. Debunker applies `action=NEW` implicitly.
- **Factual correction** — comment will open with `**Correction to [date] comment:**`: skip to Step 4 with `action=EXEMPT (reason=factual-correction)`. Debunker applies `action=NEW`.

> "First comment by this author on this ticket" is NOT an exemption — Step 3 handles it correctly (0 same-signature comments → `NEW`). Run the full gate.

---

## Step 1 -- Fetch Existing Comments (REQUIRED)

Fetch all comments on the target issue before doing anything else. Record:
- Total comment count
- Same-author comments: list with IDs and bodies

**If you cannot fetch comments: STOP. Do not post until you can.**

---

## Step 2 -- Extract Topic Signature

Extract the primary work artifact from both the proposed comment and each existing same-author comment.

| Artifact pattern in comment text | Signature key |
|----------------------------------|---------------|
| MR reference `!NN` | `MR !NN` |
| Branch name `fix/TICKET-XXXX-*` or `feat/TICKET-XXXX-*` | `branch:TICKET-XXXX` |
| Commit SHA (7+ hex chars) | associate with its MR signature if determinable |
| Named env var or feature flag (e.g. `GREETING_PROTECTION_MS`) | `feature:<NAME>` |
| "reverted" / "rolled back" / "revert SHA" | `state:revert` |
| "work ceased" / "closed" / "cancelled" / "shipped to production" | `state:terminal` |
| "deployed" / "merged to main" | `state:deploy` |
| No extractable artifact | `general-update` |

> **`general-update` rule:** `general-update` signatures always produce `action: NEW` regardless of existing `general-update` comment count. Topic overlap cannot be reliably determined for unstructured updates — do not merge.

**State signatures (`state:*`) always produce `action: NEW` regardless of existing comment count** -- terminal events warrant their own comment.

---

## Step 3 -- Classify (HARD GATE)

| Same-signature same-author comments | Existing thread | Proposed content type | Action |
|-------------------------------------|-----------------|-----------------------|--------|
| 0 | — | anything | `NEW` |
| 1+ | has `state:terminal` or `state:deploy` | any | `NEW` (thread closed; start fresh) |
| 1 | open | state transition | `NEW` |
| 1 | open | progress update | `EDIT` |
| 2+ | open | state transition | `NEW` |
| 2+ | open | progress update | `CONSOLIDATE` |

**Progress update** = pipeline status, test count change, MR state change, review finding addressed, code pushed, approval pending, timer values, build numbers. When in doubt, classify as progress update.

**State transition** = ship to production, revert/rollback, work ceased, ticket closed/cancelled, new external blocker.

---

## Step 4 -- Emit Preflight Block

```
PREFLIGHT: LINEAR-COMMENT-GATE
- target_issue:           TEAM-NNNN
- total_comments:         N
- same_author_comments:   N (ids: [...])
- proposed_topic_sig:     [extracted signature]
- overlapping_existing:   [comment IDs with same signature] | NONE
- proposed_content_type:  progress-update | state-transition
- action:                 NEW | EDIT | CONSOLIDATE | EXEMPT (reason=...)
- consolidation_complete: YES | NO | N/A  # N/A for first-run action=NEW or EDIT (no consolidation needed)
- GATE: PASS | FAIL (reason)
```

Rules:
- `action=EXEMPT (reason=...)`: GATE = PASS. Proceed directly to debunker. Debunker applies `action=NEW` for factual-correction; skips classification check for threaded-reply.
- `action=NEW`: GATE = PASS immediately. Proceed to debunker.
- `action=EDIT`: GATE = PASS. Proceed to debunker which validates content; then call `commentUpdate` per EDIT Procedure.
- `action=CONSOLIDATE` AND `consolidation_complete=NO`: GATE = FAIL. Run Consolidation Procedure, then re-emit this block with `consolidation_complete=YES`.
- `action=CONSOLIDATE` AND `consolidation_complete=YES` AND re-run action is `EDIT`: GATE = PASS. Proceed to debunker; debunker appends proposed new content via `commentUpdate`.
- `action=CONSOLIDATE` AND `consolidation_complete=YES` AND re-run action is again `CONSOLIDATE`: GATE = FAIL (consolidation-loop). Stop; surface surviving same-signature comment IDs for manual review.

---

## EDIT Procedure (action = EDIT)

When `action=EDIT`, do NOT call `commentCreate`. Instead:

1. Fetch the body of the existing overlapping comment via its ID
2. Draft the appended section locally:
   ```
   **YYYY-MM-DD HH:MM -- [brief label]:** [new content]
   ```
3. Run the appropriate debunker (`linear-comment-debunker-engineer` for engineer comments, `linear-comment-debunker-pm` for PM comments) against the drafted section ONLY — GATE must PASS before continuing
4. Call `commentUpdate` with the full updated body (existing body + appended section)

---

## Consolidation Procedure (action = CONSOLIDATE)

An ongoing work thread ends when the ticket reaches a terminal state (Done, Cancelled, Merged) or
the work artifact (MR, branch) is closed. Until then, the same-topic comment is "living."

Run this before resuming the comment posting workflow:

0. **Resolve current author identity (REQUIRED before any delete):**
   - Call `viewer { id name }` (Linear GraphQL `me` query) to get `currentAuthorId`
   - If the query fails or returns null: STOP. Do not delete anything. Notify the user.

1. **Draft one consolidated comment (historical content only — do NOT include proposed new content):**
   - Header: `Consolidated [topic] history -- replaces prior comments`
   - Retain every factual claim, SHA, test count, and artifact reference from all originals
   - Each original becomes a dated subsection: `**YYYY-MM-DD HH:MM -- [brief label]:** [content]`
   - The proposed new content is NOT included here — it will be appended via the EDIT path after re-run

2. **Post** the consolidated comment via `commentCreate`

3. **Delete** each original same-topic same-author comment via `commentDelete`:
   - Only delete where `comment.user.id == currentAuthorId` (resolved in Step 0)
   - **If any delete fails:** record undeleted IDs in context, set `GATE: FAIL (reason=consolidation-incomplete, undeleted_ids=[...])`, notify the user for manual cleanup. Do NOT proceed to Step 4.

4. **Re-run Steps 1-4** from scratch (re-fetch all comments, re-classify) with `consolidation_complete=YES`:
   - Expected result: `action=EDIT` (the consolidated comment is the single surviving same-topic entry)
   - Proceed through EDIT Procedure — debunker validates and appends the proposed new content once via `commentUpdate`
   - **If re-run action is again `CONSOLIDATE`:** STOP. Set `GATE: FAIL (reason=consolidation-loop)`. Surface surviving comment IDs for manual review. Do not attempt another cycle.

---

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Classifying MR status as state-transition to avoid consolidation | Re-read the table -- "pipeline green", "tests passing", "approval pending" are progress updates |
| Skipping gate for "quick" updates ("this one is obviously fine") | No exemptions for speed -- self-exemption is exactly how incident-2026-1507 happened |
| Consolidation drafted but not posted before proceeding | GATE stays FAIL; complete the procedure before re-entering debunker |
| `commentDelete` fails for one or more originals | Record undeleted IDs; set GATE FAIL; notify user for manual cleanup; do NOT re-attempt `commentCreate` |
| Re-run after consolidation produces `CONSOLIDATE` again | STOP: consolidation-loop detected. Surface surviving same-signature comment IDs for manual review |
| Deleting another author's comment | Step 0 must resolve `currentAuthorId` via `viewer` query; only delete where `comment.user.id` matches |

---

## Companion Skills

- `linear-issue-verify` -- REQUIRED before this gate runs
- `linear-comment-debunker-engineer` -- runs AFTER this gate clears (PASS) for engineer comments
- `linear-comment-debunker-pm` -- runs AFTER this gate clears (PASS) for PM-framed comments
- `exhaustive-audit-validation` -- use for retroactive cleanup on tickets with 5+ same-author comment pileups
