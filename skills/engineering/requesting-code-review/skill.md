---
name: requesting-code-review
disable-model-invocation: true
source: superpowers-plus
augment_menu: true
# Override rationale: Routes review requests through code-review-battery (the
# superpowers-plus specialist engine) instead of the upstream single-reviewer
# template. Adds the "Cardinal Rule" — autonomous review before presenting work
# as ready — and integrates with the commit-gate and completion-gate chains.
# Triggers are INTENT-BASED (what the agent is about to do), not output-phrase-based.
triggers:
  - /sp-request
  - request code review
  - review my changes
  - before merging
  - review before PR
  - thorough review
  - please review my changes
  - please review my implementation
  - here's what I built
  - here's what I implemented
  - here's what I changed
anti_triggers:
  - providing code review
  - receiving code review
  - code review battery
  - ready to commit
  - ready to push
description: "Use when presenting code changes to a human for review — dispatches code-review-battery. Self-fires on intent to present (see Cardinal Rule in skill body). Resolves current content/context coverage before presentation; reuses valid review evidence and reviews only missing or affected scope."
summary: "Use when: about to present code to a human (even informally). Skip dispatch when native strategy proves valid review coverage for the current content/context."
coordination:
  group: code-quality
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [review-feedback]
  capabilities: [dispatches-review]
  priority: 25
---

> **Wrong skill?** Pre-commit/push → `unified-commit-gate`. Reviewing someone else's PR → `providing-code-review`. Implementing feedback you received → `receiving-code-review`. Inter-agent file handoff → `inter-agent-review-protocol`.

# Requesting Code Review

Use the repository's review router and native clearance parser before dispatch.
Review missing or invalidated classes; preserve an existing clean independent
review while its content, coverage, dependencies and guidance remain valid.

## Strategy before execution

Before every automated review or test/check pass, resolve a snapshot-bound
REUSE, WAIT, RUN_MINIMAL, REVIEW_REQUIRED or STOP decision at its supported
execution/dispatch boundary. Reuse valid coverage or join its active producer.
Missing/stale decisions refuse; unknown coverage stays conservative. No model
calls or recursive checks inside strategy. Status/HEAD changes, clean reviews
and score targets alone never justify another expensive pass.

## Before presenting completed work

Use the actual target snapshot, including relevant staged/unstaged changes.
In superpowers-plus, run `tools/review.sh route <paths>` and read
`tools/push-readiness.sh --json` or `tools/review-preflight.py --staged`.
Never infer staleness from HEAD alone or parse a guessed sentinel format.

- Valid content-scoped clearance: reuse it, including after tree-identical
  merges, amends or history-only commits. Do not dispatch another reviewer.
- Missing/invalidated clearance: obtain the required initial or affected-delta
  review and use the native writer after genuine review judgment.
- Failed/malformed evidence: STOP and diagnose; preserve it rather than deleting
  the sentinel to force a clean slate.
- Uncommitted relevant changes: review that exact snapshot. Do not stash or
  commit merely to make the status look clean.

One initial independent review is sufficient when clean and above the required
floor. Reopen for material changed scope, an unresolved actionable finding,
invalidated evidence or an explicitly justified independent safety lens. Report
a low score without new actionable evidence; never chase it by redispatching.

Progress updates may report existing results without launching tests or review.
A final completion claim needs valid evidence for the actual presented scope.
Keep review evidence in its native artifact; do not force process banners into
every human-facing message or treat publication permission as review clearance.

## How to Request

### 1. Gather context

```bash
BASE_SHA=$(git merge-base HEAD main)   # or origin/dev, origin/main
HEAD_SHA=$(git rev-parse HEAD)
git diff $BASE_SHA..$HEAD_SHA          # the diff to review
```

### 2. Dispatch code-review-battery

Follow the `code-review-battery` procedure:

1. **Triage** the diff → select relevant specialist reviewers
2. **Dispatch** all activated reviewers in parallel via `sub-agent-code-reviewer`
3. Each reviewer gets: reviewer prompt + full diff + source context (callers, field readers, state types)
4. **Aggregate** findings → triple-filter → classify Implement/Defer/Reject

### 3. Act on findings

| Severity | Action |
|----------|--------|
| Critical | Fix immediately; validate the fix and review only its affected delta when required. |
| Important | Fix before proceeding; reopen only affected scope with an actionable basis. |
| Minor | Fix now or document for follow-up. |
| Reviewer wrong | Push back with technical reasoning and evidence. |

### 4. Confirm verdict

Only proceed to presenting work as "ready" when battery verdict is **PASS** or **PASS_WITH_NITS** (with nits fixed).

## Integration with Workflows

| Workflow | When to Review |
|----------|---------------|
| **Subagent-driven development** | At the approved review boundary; new scope/findings select the required delta |
| **Feature development** | After implementation, before presenting options |
| **Ad-hoc development** | Before merge or when stuck |
| **Finishing a branch** | Resolve native strategy first; dispatch only missing/invalidated review coverage |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Skipping review because "it's simple" | Complexity doesn't determine risk |
| Ignoring Critical findings | Critical = broken if shipped |
| Proceeding with unfixed Important findings | Fix first, then re-dispatch |
| Arguing with valid technical feedback | Push back only with evidence |
| Presenting work as "ready" then reviewing | Review first, present second |

## Companion Skills

- **code-review-battery**: The review engine this skill dispatches
- **progressive-code-review-gate**: Fires at commit time (uses battery) — handles "ready to commit/push" triggers
- **verification-before-completion**: Completion gate that requires review evidence
- **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
