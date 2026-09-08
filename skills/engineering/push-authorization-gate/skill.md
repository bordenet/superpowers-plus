---
name: push-authorization-gate
source: superpowers-plus
augment_menu: true
auto_invoke: true
description: "Hard stop before any git push to a remote. Requires explicit human approval in the current conversation -- push triggers CI/CD, overwrites remote history with --force, and is not reliably reversible. Covers the discipline the pre-tool-use-red-autonomy.sh hook enforces mechanically; adds the sub-agent rules and the what-does-NOT-count table."
summary: "Use when: about to git push. Verify a distinct human approval utterance exists in THIS conversation before pushing. Distinct from unified-commit-gate (code quality) -- this gate covers human authorization."
triggers:
  - "git push"
  - "push origin"
  - "push this branch"
  - "push the branch"
  - "push to remote"
  - "push it"
  - "force push"
  - "force-push"
  - "ready to push"
  - "about to push"
  - "/sp-push-authorization-gate"
anti_triggers:
  - "git pull"
  - "git fetch"
  - "dry-run push"
  - "review the push"
  - "merge conflict"
  - "push tags only"
coordination:
  group: push-gates
  order: -5
  requires: []
  enables: ["unified-commit-gate"]
  escalates_to: []
  internal: false
composition:
  consumes: [user-intent, branch-context]
  produces: [push-clearance]
  capabilities: [gates-authorization]
  priority: 100
---

# Push Authorization Gate

> **Wrong skill?** For `gh pr merge`, `glab mr merge`, or any forge REST merge (API-level merge that bypasses git hooks) -- use `merge-authorization-gate`. For code quality before push (lint/build/test, sentinel) -- use `unified-commit-gate`. This gate covers `git push` to any remote.

**Announce at start:** "I'm using the **push-authorization-gate** skill to verify explicit human approval before pushing."

## Why This Exists

`git push` triggers CI/CD pipelines, can overwrite remote history with `--force`, and is not reliably reversible on a shared remote. **Explicit human authorization is required every time.**

`tools/claude-hooks/pre-tool-use-red-autonomy.sh` enforces this mechanically for `git push` / force-push / branch-delete: it blocks the command unless an approval phrase sits in the last 10 user messages, bound to the same target ref. This skill is the discipline layer -- an agent that understands it never reaches the block, and it covers the two things the hook does not: sub-agent task prompts, and API-level merges (cross-ref `merge-authorization-gate`).

## Gate Check (run this before ANY git push)

> **Sub-agent context:** If you are executing from a task prompt with no live human conversation, skip to [Sub-agent Rules](#sub-agent-rules) below.

Ask: **Has the human in THIS conversation explicitly said to push?**

Valid approval phrases (word-bounded, case-insensitive): "push it", "approve push", "you may push", "go ahead and push", "push the branch", "proceed with push".

> **Self-trigger note:** The phrase that triggered this skill does NOT count as approval. If "push it" invoked the gate, that utterance is the trigger, not the authorization -- the human must confirm again after the gate states its requirements. If the human's reply directly to this gate's stop message is "push it", treat that second utterance as approval; the gate does not re-fire on a direct response to its own requirements statement.

| Situation | Action |
|---|---|
| Human said an approval phrase in this conversation | State the approval, run `unified-commit-gate` (push mode), then push |
| No explicit approval found | State the gate fired, show what would be pushed (`git log --oneline <base>..HEAD` and `git diff --stat <base>..HEAD`, where `<base>` is the upstream or the target branch), then end the turn -- do not push |

"End the turn" means report and stop, not block at a prompt: `superpowers-plus` tooling never pauses for interactive input. The next human message carries the approval or does not.

A revoke phrase ("do not push", "cancel push", "stop pushing") in a later message overrides an earlier approval.

`superpowers-plus`'s stance is explicit human approval for **every** push -- there is no per-remote autonomous exemption. `pre-tool-use-red-autonomy.sh` enforces this uniformly.

## What Does NOT Count as Push Authorization

| This is NOT approval | Why |
|---|---|
| "continue" / "proceed" / "keep going" | Task-continuation words -- they do not name the push action |
| "done" / "great" / "ok" / "yes" / "lgtm" | Acknowledgments -- they do not name the push action |
| "continue with the task" | Task-scoped -- does not explicitly authorize the push step |
| Approval from a prior session or conversation | Does not transfer -- expires at context compaction and sub-agent handoff; the human must restate |
| CI passing / tests green | Quality signal, not authorization |
| A valid review sentinel for HEAD | Quality signal, not authorization |
| Human approved the PR/MR in the forge web UI | Code-review authorization -- separate from push authorization |
| "merge approved" / "merge it" | Merge authorization -- separate from push authorization |
| Completing the implementation work | Finishing a task does not authorize publishing it |

## Sub-agent Rules

**If you are a sub-agent:**

1. Your task prompt MUST contain explicit text authorizing the push, attributed to the human. The canonical form is `Human said: push it` (or whichever phrase the human used). Bare task verbs ("implement and push", "finish the branch") are NOT sufficient.
2. Do NOT infer approval from context ("the orchestrator asked me to finish the branch", "CI passed", "the sentinel is valid"). None of those are authorization.
3. Surface the block with: "Push gate: no explicit human approval found in the task prompt. Stopping. The human must authorize in their conversation before this can proceed."

**If you are an orchestrator dispatching a sub-agent to push:** embed the human's exact approval utterance in the task prompt (`Human said: <utterance>`). Approval granted to the orchestrator does NOT transfer automatically.

## Failure Modes

| Failure | Fix |
|---|---|
| "continue" treated as push authorization | It is not. Re-read *What Does NOT Count*. Ask explicitly: "Ready to push -- should I?" |
| Task completion ("implementation done") treated as authorization | Completing work does not authorize publishing it. Present the changes; ask for push approval |
| Sub-agent infers approval from a sentinel or CI | Neither is authorization; surface the block to the orchestrator |
| Force-push run without an explicit force-push approval | Force-push is higher risk than a plain push; it needs the same explicit gate, naming the force |
| Prior-session approval carried forward | Approval is conversation-scoped and expires at compaction / sub-agent handoff |
| Gate softened to "personal repo, so autonomous" | There is no per-remote exemption in `superpowers-plus` -- every push needs a fresh utterance |
