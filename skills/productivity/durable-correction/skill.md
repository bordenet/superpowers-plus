---
name: durable-correction
source: superpowers-plus
augment_menu: true
triggers:
  - "this keeps happening"
  - "why does this keep happening"
  - "happened again"
  - "same mistake again"
  - "second time this happened"
  - "third time this happened"
  - "third time the same mistake happened"
  - "failure happened again"
  - "same review issue returned"
  - "this exact issue returned"
  - "we already fixed this"
  - "you said this was fixed"
  - "you were told before"
  - "same problem came back"
  - "/durable-correction"
anti_triggers:
  - "run the tests again"
  - "rerun the tests"
  - "try the command again"
  - "check the result again"
description: "Redirect when a human reports a repeated mistake or failed prior fix. Repair the defect, replace the failed control with durable enforcement, and prove failure and success paths before claiming prevention. First-time bugs remain lightweight."
summary: "Use when the human says a mistake recurred, a prior fix failed, or the response process itself was shallow. Separate repair from prevention and require evidence for durable correction."
coordination:
  group: meta
  order: 0
  requires: []
  enables: [systematic-debugging, failure-autopsy, verification-before-completion, evolution-loop]
  escalates_to: [think-twice]
  internal: false
composition:
  consumes: [human-correction, incident-description]
  produces: [immediate-repair, durable-control, verification-report]
  capabilities: [redirects-after-recurrence, prevents-repeat-failures, escalates-failed-controls]
  priority: 1
---

# Durable Correction

Treat human-reported recurrence as evidence that the work process failed, not merely that one output is wrong. Repair the output and change the conditions that allowed the failure.

## Scope gate

Classify the event as exactly one of: **ordinary correction | process failure | failed-control recurrence**.

| Class | Evidence | Required response |
|---|---|---|
| Ordinary correction | First isolated bug, typo, or review comment; no credible recurrence or process-breakdown signal | Use the normal debugging or review path. Fix and verify without a post-mortem. |
| Process failure | The human identifies recurrence, says a prior resolution was incomplete, or explicitly criticizes the response process as sloppy/shallow | Run the redirect protocol below. |
| Failed-control recurrence | The same class happened after a checklist, test, gate, skill, or other preventive control was added | Run the redirect protocol and distrust the existing control. Escalate enforcement. |

Do not fire merely because the agent drafts aspirational language, a command is being rerun, or the human reports a normal first defect. When evidence is ambiguous, make the immediate correction and ask one short question only if the answer changes whether prevention work is warranted.

## Redirect protocol

### 1. State the signal without theater

In two factual sentences at most:

1. Name what failed and the evidence that it is recurrent or process-level.
2. State the current class from the Scope gate.

Do not substitute apology, self-criticism, reassurance, or a promise for action.

### 2. Open two tracks

**Repair track:** contain or correct the immediate defect using the appropriate domain skill. Urgency can change the size of this repair, not the truth of the final status.

**Prevention track:** identify why the normal process failed to prevent, detect, or block the defect. This track is mandatory for process failure and failed-control recurrence.

Do not make prevention a vague tail item after the repair. If prevention cannot be completed within current authority or scope, mark it unresolved and name the exact missing decision or owner.

### 3. Locate the control gap

Trace the failure through these questions:

1. What observable condition first made the bad outcome possible?
2. What existing control should have prevented, detected, or blocked it?
3. Did that control not exist, not run, inspect the wrong evidence, allow bypass, or fail to block?
4. What is the closest practical **point of failure** where a control can act?

Use `systematic-debugging` for a technical root cause and `failure-autopsy` when the process cause is novel or contested. Explanation alone is not a control.

### 4. Choose a durable control

A proposed prevention mechanism must pass every test:

- **Persistent:** survives this conversation and a new agent session.
- **Proximate:** acts at or before the point of failure, not only during retrospective review.
- **Falsifiable:** has a negative case that proves it rejects the original failure.
- **Executable:** has a defined owner and invocation path; it is not advice waiting to be remembered.
- **Proportional:** addresses the failure class without imposing a heavy incident process on ordinary work.
- **Generalized:** covers the causal class, not only the exact string or symptom the human mentioned.

Durable controls include regression tests, validation at an input boundary, CI or hook gates, generated-source fixes, invariant checks, and mechanically routed procedures. Cosmetic controls include apologies, comments nobody executes, duplicate checklist prose, and tickets with no interim guard.

The durable change belongs in the system that failed. Do **not** always edit a skill: change a skill only when routing or agent procedure was the actual gap.

### 5. Escalate when a control already failed

For a failed-control recurrence: **Do not trust the failed control**.

Test why it failed, then move at least one enforcement level closer to prevention:

- prose reminder -> executable check
- advisory detection -> blocking gate
- downstream review -> source or input validation
- manual invocation -> automatic routing
- exact-example check -> causal-class invariant
- single check -> independent verification when correlated failure is plausible

Editing the wording of the same failed checklist is not escalation unless evidence shows wording was the causal defect.

### 6. Prove both paths

Before claiming prevention:

1. Show the **original failure is rejected** by the new control.
2. Show the **valid behavior still works**.
3. Run the relevant regression suite and prove the control executes at its intended boundary.
4. Use `verification-before-completion` before presenting the result.

Report exactly one status: **contained | prevented | unresolved**.

- **contained:** the immediate harm is repaired, but durable prevention is not yet proven.
- **prevented:** the durable control is installed and both failure and success paths passed.
- **unresolved:** the repair or prevention track is blocked; name the evidence and required next action.

Never collapse contained into prevented. Passing the repaired happy path alone does not prove prevention.

## Anti-gaming checks

Reject the response if any is true:

- It contains a long root-cause narrative but no changed control.
- It creates a ticket while leaving an easy in-scope guard undone.
- It adds ceremony far from the failure point.
- It verifies only the new happy path.
- It claims a mechanism exists without proving that the real workflow invokes it.
- It treats a recurrence after a control as proof that people should follow the same control more carefully.

## Compact response record

```text
Signal: <human evidence and classification>
Repair: <immediate correction and evidence>
Control gap: <why prevention/detection/blocking failed>
Durable change: <mechanism and point of enforcement>
Validation: <original failure rejected; valid behavior works; boundary exercised>
Status: contained | prevented | unresolved
```

## Companion skills

- `systematic-debugging`: technical root cause and immediate repair
- `failure-autopsy`: deeper process cause when the failure is novel or disputed
- `verification-before-completion`: evidence gate before a resolution claim
- `evolution-loop`: broader pattern capture after the concrete control is installed
- `receiving-code-review`: ordinary review feedback that does not cross this skill's recurrence threshold
- `no-empty-promises`: legacy manual tool for inspecting promise language; this skill owns automatic recurrence routing
