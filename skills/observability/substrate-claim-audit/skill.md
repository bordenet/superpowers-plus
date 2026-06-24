---
name: substrate-claim-audit
source: superpowers-plus
augment_menu: true
triggers: ["/sp-substrate-audit", "substrate audit", "verify substrate", "audit named artifacts", "verify metric exists", "check symbol exists", "evidence before naming", "propose SLI", "propose SLO", "propose alarm", "propose dashboard", "propose runbook", "propose metric", "propose health check", "design observability", "draft observability spec", "list KPIs", "name new metric", "name new counter", "quote threshold target"]
anti_triggers: ["skip substrate audit", "no audit needed", "audit not required", "draft only no audit"]
trigger_precedence: triggers_win
description: "Hard gate. Use BEFORE sending output that NAMES artifacts (metrics, fields, file paths, ticket IDs, function names) or QUOTES numeric thresholds. Requires grep-verified evidence for every named symbol AND a baseline citation for every numeric target. Fires on the PROPOSAL pattern -- different from output-verification (file outputs) and verification-before-completion (completion claims). Prevents confabulated-substrate AI slop."
summary: "Every named symbol in output needs a grep evidence trail. Every numeric threshold needs a baseline citation. Triggers win against anti-triggers unless the prompt explicitly contains a skip directive."
coordination:
  group: completion-gate
  order: -1
  requires: []
  enables: ["progressive-harsh-review", "output-verification", "verification-before-completion"]
  escalates_to: ["progressive-harsh-review"]
  internal: false
composition:
  consumes: [proposal]
  produces: [verification-report]
  capabilities: [verifies-output, gates-quality, prevents-confabulation]
  priority: 35
---

# Substrate Claim Audit

> **Wrong skill?** Generated file -> describe it -> `output-verification`. About to claim work done -> `verification-before-completion`. URL / ticket exists -> `link-verification`. Multi-persona deep review of a proposal -> `progressive-harsh-review` (this skill is the surface gate that runs BEFORE PHR).
>
> **Purpose:** Prevent confabulation disguised as proposal. Every named artifact in agent output must have grep-verified evidence or an explicit fictional-label.
>
> **Core Principle:** Substrate before claim. Always.

## Companion Skills

- **output-verification**: Confabulation gate for GENERATED outputs (files, PDFs, script results)
- **verification-before-completion**: Confabulation gate for COMPLETION claims
- **progressive-harsh-review**: Deep adversarial review of proposals -- declares `requires: [substrate-claim-audit]` so this skill must clear FIRST
- **detecting-ai-slop**: AI-slop density scoring for prose

## When to Use

Auto-fires on the PROPOSAL action pattern:

- Naming metrics, fields, functions, file paths, ticket IDs in output
- Quoting numeric thresholds (>=X%, <=Yms, P95 <= Z) in output
- Proposing SLIs, SLOs, alarms, dashboards, runbooks, observability surfaces
- Listing KPIs / health checks / monitoring queries
- Producing tables of N rows where each row carries substrate claims
- Drafting design proposals that reference codebase artifacts

Explicit invocation: `/sp-substrate-audit` or "substrate audit this".

## Trigger Precedence Rule (load-bearing)

`trigger_precedence: triggers_win` means: when a prompt matches BOTH a trigger and an anti-trigger, **the trigger fires**. The anti-trigger list is intentionally narrow -- only explicit skip directives (`"skip substrate audit"`, `"audit not required"`) suppress the skill. Casual phrasing like `"quick draft of an SLI list"` matches the trigger `"propose SLI"` AND no anti-trigger, so the skill fires.

Rationale: the originating failure (confabulated SLI proposal) happened on casual phrasing that would have matched an anti-trigger under a more permissive scheme. Bias toward over-firing.

## AUTO-FIRE TRIGGERS -- ACTION PATTERN

This skill fires on a BEHAVIOR pattern, not just phrases:

```text
IF: you are about to send a response that names an artifact (metric, field, file,
    function, ticket ID, threshold value, formula referencing any of these)
AND: you have NOT (a) grep-verified the artifact exists in the relevant repo
     IN THIS CONVERSATION (current session, current branch context), OR
     (b) explicitly labeled it as fictional/placeholder
THEN: STOP. This skill applies. Audit before sending.
```

Phrase triggers are a backup. The primary trigger is the action pattern above.

**Conversation-window boundary:** "in this conversation" means the current session transcript, scoped to the current branch context. A grep run yesterday in a different session does NOT satisfy the rule -- the audit trail must be reconstructable from THIS session's tool-call history. If the relevant repo changed branches since the last grep, re-grep.

## The Anti-Pattern

**Confabulation disguised as proposal:** the agent produces a clean-looking deliverable (table, formula, SLI grid, alarm spec) that NAMES artifacts which do not exist. Form is correct; substrate is invented. The output looks rigorous because the FORM looks rigorous -- the underlying claims are unverified.

Characteristics:

- Clean tables, ratio shapes, target values, units -- all decorative
- Named symbols not grep-verifiable in the target repo
- Numeric thresholds with no baseline citation ("based on what data?")
- Plausibility (the symbol "should" exist) confused with verification

`verification-before-completion` asks "did you run the command?". `output-verification` asks "did you read what the command produced?". **This skill asks: "is the artifact you just NAMED actually there?"**

## The Iron Law

```text
NO NAMED ARTIFACT IN OUTPUT WITHOUT
  (a) A GREP TOOL CALL ON IT IN THIS CONVERSATION,
  OR
  (b) AN EXPLICIT [NEEDS NEW INSTRUMENTATION] / [PLACEHOLDER] / [DOES NOT EXIST] LABEL
      DIRECTLY ADJACENT TO THE REFERENCE.

NO NUMERIC THRESHOLD WITHOUT
  (a) A BASELINE CITATION ("based on N-day prod P95 of M"),
  OR
  (b) AN EXPLICIT [NO BASELINE -- PLACEHOLDER] LABEL DIRECTLY ADJACENT.
```

The tool-call IS the evidence. Conversation transcript IS the audit trail.

## Audit Checklist

Run before composing the response, NOT after:

| Claim shape | Required evidence | Edge cases |
|---|---|---|
| Named metric `FooBarRate` | `Grep` tool call returns >=1 emit site in target repo | If symbol is emitted dynamically (`Metrics[name].emit()`), grep the dispatch site for the literal string |
| Named field / property `obj.bar` | `Grep` or `Read` shows declaration | If field is from a vendor SDK or generated code, cite the schema source instead |
| File path `src/foo/bar.ts` | `Read` or `Bash ls` confirms | If file is in a sibling repo, specify the repo and grep there explicitly |
| Function / method name | `Grep` returns definition | If method is from a pending PR not yet on `main`, label `[PENDING IN PR #N]` |
| Ticket ID (TICKET-NNNN, LIN-NNNN) | Linear / Jira tool call confirms | Never invent IDs -- drop the reference if unverifiable |
| Numeric threshold (>=X%, <=Yms) | Citation: "based on 7-day prod P95 of Z" | If no production baseline exists yet, label `[NO BASELINE -- PLACEHOLDER]` |
| Formula `A / B` | A AND B both audited independently | A composite formula inherits the strictest label of its components |
| Table with N rows | Each row audited separately (N x check) | The grid does NOT amortize verification |
| Paraphrase ("the X counter") | Same audit as the literal symbol | Paraphrase does NOT evade the rule. If the agent self-detects a paraphrase, audit the paraphrase's referent |

**Multi-repo guidance:** generic monorepo layout (`service-a`, `service-b`, `api-gateway`, `platform-core`, `superpowers-plus`, etc.) means a symbol may exist in repo A but not repo B. Specify the target repo at audit time. When ambiguous, grep ALL candidate repos and report which one matched.

## Anti-Patterns To Refuse

| Pattern | Why it fails |
|---|---|
| Sprinkling `[PLACEHOLDER]` across fabricated content without restructuring | Label-laundering. Defeats the spirit. If more than 2-3 symbols in a single proposal need placeholder labels, the proposal is premature; defer until instrumentation lands |
| Paraphrasing a symbol to evade the literal-name check | Audit applies to paraphrases |
| "Should be X%" / "<=Yms" without a citation | Gut-feel disguised as rigor |
| Tables of N claims with one substrate check at the top | N rows = N substrate checks |
| Naming a symbol that "obviously must exist somewhere" | Grep it. If you cannot find it, it does not exist; do not name it |
| "I'll verify before final" | The audit IS final. Drafts that leak to the user are the failure mode |

## What This Skill Does NOT Prevent

**Honest disclosure (Phase 1 of a two-phase plan):**

This skill relies on **self-fire** (the agent noticing the action pattern). The same self-fire mechanism has demonstrated failure modes in prior sessions -- the agent wrote memory rules then immediately violated them. Reliable prevention requires **tool-level enforcement (Phase 2)**: a `verify_symbol(name, repo)` tool the agent MUST call before naming the symbol, structurally enforced by the harness or by a repo-side CI gate.

**Phase 1 (this skill) catch rate:** unknown -- `[NO BASELINE -- ESTIMATE]`. No telemetry yet measures how often the skill self-fires correctly vs. fails silently. The first round of production use IS the baseline-gathering exercise. Until then, do not trust this skill to be the only defense -- pair it with `/sp-substrate-audit` explicit invocation on high-stakes proposals.

**Phase 2 work** is tracked in the `~/.codex/TODO.md` entry `20260609-03` (tag `#substrate-enforcement-phase-2`). The TODO exists; verify with `todo-crud.sh list --tag '#substrate-enforcement-phase-2'` (path resolved by your ecosystem's `core.always.md`).

If you (the agent) notice yourself producing the action pattern WITHOUT this skill firing first, that is a Phase-1 reliability failure. Run the audit anyway. Log the miss as a `failure-autopsy` entry so the trigger keywords can be tuned.

## Canonical Anti-Example (DO NOT REUSE THE FAKE SYMBOL NAMES BELOW)

The incident-2026-1507 SLI proposal failure (2026-06-09 session). The agent proposed five Service Level Indicators in a clean table:

<!-- ANTI-EXAMPLE: SYMBOLS BELOW ARE DELIBERATELY-FAKE. DO NOT GREP OR REUSE. -->

```text
[FAKE-EXAMPLE] SLI-1: GreetingCompleteRate =
    1 - (IntroProtectionAwaitFailed_FAKE + IntroProtectionAbandonedMidWindow_non_hangup_FAKE)
        / total_intro_starts_FAKE
    Target: >=99.5% [NO BASELINE -- PLACEHOLDER]
```

Defects this skill would have blocked:

| Symbol / number | Audit result |
|---|---|
| `IntroProtectionAwaitFailed` | EXISTS (grep confirms emit site) -- legitimate |
| `IntroProtectionAbandonedMidWindow_non_hangup` | **DOES NOT EXIST** -- agent invented the `_non_hangup` split |
| `total_intro_starts` | **DOES NOT EXIST** -- agent invented as a denominator |
| `99.5%` | **NO BASELINE** -- agent picked the number from gut |

PHR scored the proposal **2.67/10**. Four of the five SLIs scored similarly. Time cost to user: roughly one hour of revision + re-review. Trust cost: high.

If the agent had run this audit before sending:
- `total_intro_starts` -> grep returns zero -> label `[NEEDS NEW INSTRUMENTATION: emit IntroProtectionStarted counter]` and rewrite the formula
- `_non_hangup` split -> grep returns zero -> label `[NEEDS REASON-CODED EMIT]`
- `99.5%` -> no baseline available -> label `[NO BASELINE -- PLACEHOLDER]`

The proposal would have been honest about its prerequisites instead of pretending to be a complete deliverable.

## Composition With Other Gates

```text
substrate-claim-audit (this skill, order -1)
   | "do the things you name actually exist?"
   v
progressive-harsh-review (deep design critique; declares requires: [substrate-claim-audit])
   | "is the design itself sound?"
   v
output-verification (order 0, when generated files involved)
   | "did you read the file you are about to describe?"
   v
verification-before-completion (order 4)
   | "do you have evidence for the completion claim?"
   v
unified-commit-gate (commit-time checks)
```

This skill is the EARLIEST gate. Cheapest to run, catches the most pervasive failure mode. PHR coordination is updated to declare `requires: [substrate-claim-audit]` so PHR cannot run on a proposal whose substrate was never audited.

## Output Format When This Skill Blocks

If the audit fails, the agent must NOT send the proposed output. Instead, send a revised output that either:

1. **Removes** the unverified references entirely, OR
2. **Labels** them explicitly per the Iron Law, AND
3. **Documents** the gap as a follow-up item (TODO via `todo-crud.sh add`, Linear, or wiki) so the prerequisite work is captured.

A blocked-then-revised output is a successful skill fire. A confabulated output that slips through is the failure mode.

## Regression Test Fixture

Self-test: run `/sp-substrate-audit` on the following fixture and confirm BOTH `[FAKE_METRIC_DOES_NOT_EXIST]` and the `99.9%` target are flagged.

<!-- REGRESSION FIXTURE: this proposal should be REJECTED by the audit -->
```text
[FIXTURE -- DELIBERATELY INVALID]
Proposed SLI: FakeServiceAvailability =
    1 - FakeNonExistentErrorCounter / TotalFakeFakeRequests
    Target: >=99.9%
```

Expected audit verdict: **REJECT**. Reasons: `FakeNonExistentErrorCounter` not in any repo (grep returns zero); `TotalFakeFakeRequests` not in any repo (grep returns zero); `99.9%` has no baseline citation.

If the audit passes this fixture, the skill's trigger or audit logic is broken -- file an issue.

## Failure Modes

| Failure | Detection | Recovery |
|---|---|---|
| Skill did not self-fire on proposal output | User catches confabulation post-hoc | Log to `failure-autopsy`; tune trigger keywords; invoke `/sp-substrate-audit` explicitly going forward |
| Label-laundering (every fabricated symbol gets `[PLACEHOLDER]`) | Review of output shows >50% of claims are labeled | Restructure: if more than 2-3 symbols are fictional, the proposal is premature -- defer until instrumentation lands |
| Paraphrase evasion | Same semantic claim appears as natural language without the literal symbol | Apply audit to paraphrases per the Iron Law |
| Grep against the wrong repo | False-negative ("symbol does not exist" when it does in a sibling repo) | Specify target repo at audit time; grep all candidate repos when ambiguous |
| Trigger overlap with anti-trigger | Casual phrasing matches both | Trigger wins (frontmatter `trigger_precedence: triggers_win`); only explicit skip directives suppress |
| Self-fire fails silently across model versions | No way to detect from inside the model | Phase 2 (tool-level enforcement) is the durable fix -- see TODO `20260609-03` |
| Symbol exists in pending PR but not on `main` | Grep returns zero on `main` | Label `[PENDING IN PR #N]` with the PR link instead of treating as absent |
| Dynamic-emit symbol (`Metrics[name].emit()`) | Grep on literal symbol returns zero | Grep the dispatch site for the string `name`; the audit trail is the dispatch-site evidence |

## Self-Test

When invoked with `/sp-substrate-audit`: identify the most recent proposal, enumerate all named symbols + numeric thresholds, check each for a corresponding `Grep`/`Read`/`Bash grep` tool call or explicit fictional-label, output a PASS/LABEL-REQUIRED/GREP-MISSING verdict table, and block on any GREP-MISSING.

Run the regression fixture above as part of the self-test to confirm the audit catches obvious confabulation.
