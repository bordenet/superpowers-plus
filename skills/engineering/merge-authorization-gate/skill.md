---
name: merge-authorization-gate
source: superpowers-plus
augment_menu: true
auto_invoke: true
description: "Hard stop before gh pr merge, glab mr merge, or any forge REST merge endpoint. These call the forge API directly -- git hooks and pre-push gates never fire. Requires an explicit human merge utterance in the current conversation, distinct from PR/MR web-UI approval and distinct from push approval."
summary: "Use when: about to run an API-level merge (gh pr merge / glab mr merge / forge REST merge). Verify a distinct human 'merge it' utterance in THIS conversation first. git merge (local, hooks fire) is out of scope."
triggers:
  - "merge the PR"
  - "merge the MR"
  - "gh pr merge"
  - "glab mr merge"
  - "approve and merge"
  - "go ahead and merge"
  - "merge it"
  - "run the merge"
  - "land the merge"
  - "/sp-merge-authorization-gate"
anti_triggers:
  - "git merge"
  - "merge conflict"
  - "merge locally"
  - "git rebase"
  - "merge upstream into my branch"
coordination:
  group: push-gates
  order: -5
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [user-intent, pr-context]
  produces: [merge-clearance]
  capabilities: [gates-authorization]
  priority: 100
---

# Merge Authorization Gate

> **Wrong skill?** For `git merge` (local, no API -- hooks fire normally) during `finishing-a-development-branch` Option 1, this gate does NOT apply. For `git push` -- use `push-authorization-gate`. This gate covers `gh pr merge`, `glab mr merge`, and raw `gh api` / `glab api` calls to a merge endpoint.

**Announce at start:** "I'm using the **merge-authorization-gate** skill to verify explicit human approval before running an API-level merge."

## Why This Exists

`gh pr merge` and `glab mr merge` (and `gh api .../merges`, `glab api .../merge`) call the forge REST API directly. Git hooks never fire. `pre-tool-use-red-autonomy.sh` gates `git push` but not API merges. So an API-level merge is the one integration action with **no mechanical gate at all** -- this skill is the gate.

An API merge lands code on a protected branch, can trigger a deploy pipeline, and on a squash/rebase merge rewrites history. Treat it as at least as sensitive as a push.

## Gate Check (run this before ANY API-level merge command)

> **Sub-agent context:** If you are executing from a task prompt with no live human conversation, skip to [Sub-agent Rules](#sub-agent-rules) below.

Ask: **Has the human in THIS conversation explicitly said to merge?**

Valid approval phrases (word-bounded, case-insensitive): "merge it", "go ahead and merge", "approve the merge", "run the merge", "you may merge".

> **Self-trigger note:** The phrase that triggered this skill does NOT count as approval -- it is the trigger, not the authorization. The human must confirm after the gate states its requirements. If the human's reply directly to this gate's stop message is "merge it", treat that second utterance as approval; the gate does not re-fire on a direct response to its own requirements statement.

| Situation | Action |
|---|---|
| Human said an approval phrase in this conversation | State the approval, run the merge, confirm the PR/MR status changed to merged |
| No explicit approval found | State the gate fired, present the PR/MR URL, STOP -- do not run the merge |
| `gh api` / `glab api` call targets a non-merge endpoint (e.g. `gh api user`, `glab api projects/:id`) | Gate does not apply -- proceed |

A revoke phrase ("do not merge", "cancel the merge", "hold the merge") in a later message overrides an earlier approval.

## What Does NOT Count as Merge Authorization

| This is NOT approval | Why |
|---|---|
| Approval granted in a prior session | Does not transfer -- requires fresh approval per conversation |
| Human approved the PR/MR in the forge web UI | Code-review authorization -- separate from merge-execution authorization |
| "push approved" / "push it" | Push and merge are independent authorizations |
| Human chose "merge locally" in `finishing-a-development-branch` Option 1 | That approves `git merge` (local, hooks fire) -- NOT an API merge |
| CI green / required checks passed | Quality signal, not authorization |
| "looks good" / "lgtm" on the diff | Review feedback, not a merge instruction |

## Permitted Merge Flow

```text
1. git push origin <branch>            (push-authorization-gate applies)
2. gh pr create --fill  /  glab mr create --fill
3. Present the PR/MR URL -- STOP AND WAIT for the human
4. Human approves the PR/MR in the forge web UI       (code-review authorization)
5. Human says "merge it" in this conversation         (merge-execution authorization)
6. gh pr merge <n>  /  glab mr merge <iid>            -- only after step 5
```

Steps 4 and 5 are independent. Neither substitutes for the other.

`dev -> staging -> main` promotions carry their own approval rules (see `AGENTS.md`); a `staging -> main` promotion additionally needs a batch review. This gate does not lower those bars.

## Sub-agent Rules

Sub-agents are the highest-risk context for this gate -- a sub-agent has no human conversation history and cannot verify approval by scanning the chat.

**If you are a sub-agent:**

1. Your task prompt MUST contain explicit text authorizing the merge, attributed to the human -- canonical form `Human said: merge it`. A bare task verb ("finish the branch and merge it") is NOT sufficient; the approval must be attributed to the human.
2. Do NOT infer approval from context ("the orchestrator asked me to finish the branch", "the PR was open", "CI passed"). None of those are authorization.
3. Do NOT call the merge command without explicit authorization. Attempting the call is itself the violation, even if it errors.
4. Surface the block with: "Merge gate: no explicit human approval found in the task prompt. Stopping. The human must authorize in their conversation before this can proceed."

**If you are an orchestrator:** do NOT delegate merge execution to a sub-agent unless the sub-agent's task prompt contains the human approval utterance verbatim in the canonical form (`Human said: <utterance>`). Approval granted to you does not transfer automatically.

## Failure Modes

| Failure | Fix |
|---|---|
| Trigger phrase ("merge it") counted as approval for itself | Approval must be a distinct human utterance after the gate states its requirements; re-read the *Self-trigger note* |
| Sub-agent infers approval from CI passing or the PR being open | Neither is authorization -- see *Sub-agent Rules*; surface the block to the orchestrator |
| Agent uses `gh api -X PUT .../merge` or `glab api ... /merge` directly; gate never fires | Any `gh api` / `glab api` call targeting a merge endpoint is in scope -- treat it as `gh pr merge` for gate purposes |
| Confusing the forge "Approved" badge with agent merge permission | UI approval is code-review auth; agent merge needs a separate human utterance in this conversation |
| Treating `finishing-a-development-branch` Option 1 (merge locally) as API-merge approval | Option 1 uses `git merge` locally -- hooks fire; it does not authorize an API merge |
| Prior-session approval carried forward | Approval is conversation-scoped; a new session resets the gate |
