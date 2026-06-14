---
name: code-review-battery
description: "Use when reviewing code changes to dispatch parallel specialized reviewers instead of a single monolithic review — provides deeper, more precise findings across focused lenses. Invoke as: /sp-cr-battery [min-score] [--security|--no-security] [--mode=bug-fix|feature] (optional 1.0–10.0 quality threshold, default 7.0; default 9.2 in Bug Fix Review Mode). Bug Fix Mode auto-activates on hotfix/* and fix/TICKET-* branches."
summary: Dispatches up to 6 specialist reviewers (Defect Finder, Design Critic, Guardian, Standards Enforcer, Performance Analyst, AttackerPersona) in parallel with source context for ripple analysis. AttackerPersona is signal-driven (security-sensitive diffs) and toggleable via --security/--no-security. Aggregates findings with triple-filter prioritization and Round 2 escalation.
triggers:
  - /sp-cr-battery
  - /sp-deepreview
  - code review battery
  - battery review
  - parallel review
  - dispatch reviewers
  - specialist review
  - multi-reviewer
  - review with battery
aliases: [CRB, review-battery]
anti_triggers:
  - requesting code review
  - receiving code review
coordination:
  group: code-quality
  order: 1
  enables:
    - progressive-code-review-gate
    - verification-before-completion
  requires: []
  escalates_to: []
  internal: false
source: superpowers-plus
augment_menu: true
composition:
  consumes: [code-changes]
  produces: [review-feedback]
  capabilities: [dispatches-review, parallel-review]
  priority: 25
---

# Code Review Battery

> **Wrong skill?** File-protocol review handoff → `code-review`. PR inline → `providing-code-review`. Pre-commit gate → `progressive-code-review-gate`. Full-repo security audit → `repo-security-scan` or `/sp-devsec-audit`. **Slash commands:** `/sp-cr-battery [min-score]` (primary; optional 1.0–10.0 quality threshold, default 7.0), `/sp-deepreview` (legacy).

Dispatch up to 6 specialized reviewer agents in parallel, each focused on a distinct set of review dimensions. A triage coordinator selects which reviewers to activate based on the diff, then aggregates findings into a unified report.

**Why this exists**: A single reviewer tries to evaluate everything simultaneously, leading to shallow coverage, inconsistent focus, and ~40% false positive rates. Specialized reviewers with focused prompts produce deeper analysis with near-zero false positives.

## When to Use

- When `requesting-code-review` or `progressive-code-review-gate` triggers a review
- When you want a thorough review of staged changes, a commit range, or a PR diff
- When reviewing someone else's code
- When `verification-before-completion` detects the implementation→presentation transition and no valid sentinel exists for HEAD

**Gate chain position 3 of 4:**

| Gate (order) | Self-fires when | Short-circuit if |
|---|---|---|
| 1. `debate` | About to commit to a design before coding | Already ran this session |
| 2. `progressive-harsh-review` | About to present a non-code deliverable | Already ran on this artifact |
| **3. `code-review-battery`** | **About to present/commit/push code** | **Valid sentinel for HEAD exists** |
| 4. `verification-before-completion` | About to write any results-presenting response | Sentinel SHA == HEAD → skip re-dispatch |

**One-per-unit rule:** Battery fires at most once per coherent unit of work. If a valid `.code-review-cleared` sentinel exists for HEAD, the gate is already satisfied — do not re-dispatch.

## Procedure

### Phase 0: Sentinel Check (canonical skip gate — run before dispatching anything)

This is the canonical skip gate for the one-per-unit rule. Callers (`requesting-code-review`, `finishing-a-development-branch`, `progressive-code-review-gate`) should run this before dispatching. If a caller does not implement Phase 0 explicitly, the agent should apply this decision manually before invoking battery.

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null || echo "NO CLEARANCE"
echo "HEAD: $(git rev-parse HEAD 2>/dev/null)"
git diff --quiet && git diff --cached --quiet && echo "WORKTREE_CLEAN" || echo "WORKTREE_DIRTY"
```

| Sentinel state | Decision |
|----------------|----------|
| `NO CLEARANCE` | Run battery (proceed to Phase 1). |
| Sentinel SHA ≠ HEAD SHA | Run battery (battery is stale). |
| Sentinel valid for HEAD but `WORKTREE_DIRTY` | Run battery (staged/unstaged changes exist that were not reviewed). |
| Valid sentinel for HEAD AND `WORKTREE_CLEAN` | **Skip.** Battery already ran on the current code. Note the clearance and skip to Phase 6. |
| Malformed | Delete `.code-review-cleared`, run battery. |

### Phase 0.5: BugPath Mode Detection

> **Load gate:** This phase requires `reference.md` to be loaded alongside this skill. If absent, treat BugPath Mode as INACTIVE and note in triage line.

Run immediately after the sentinel check. Detect whether this is a targeted bug fix, then set the mode before triage.

(Detection script: `reference.md` § BugPath Detection Script.)

| Signal | BugPath Mode trigger |
|--------|---------------------|
| Branch prefix `hotfix/*` | Active |
| Branch prefix `fix/<TICKET>-*` | Active |
| Explicit flag `--mode=bug-fix` | Active |
| Explicit flag `--mode=feature` | Inactive (overrides branch detection) |

**When BugPath Mode is active:** BugPath Verifier mandatory (not skippable), threshold 9.2, path-coverage floor applies (see Phase 3). SCOPE-SKIP on a confirmed bug-fix branch = Important finding, score -1.5. State mode in executive summary triage line (`reference.md` § Executive Summary Template). Also supports `--mode=bug-fix` and `--mode=feature`.

### Phase 1: Triage

Analyze the diff and select reviewers:

| Reviewer | Focus | Activate When |
|----------|-------|---------------|
| **Defect Finder** | Correctness, edge cases, concurrency | Any code change |
| **Design Critic** | Factoring, complexity, API design | Adds/modifies classes, functions, public APIs |
| **Guardian** | Security, blast radius, backwards compat | Any code change |
| **Standards Enforcer** | Docs, test quality, observability | Always |
| **Performance Analyst** | Performance, logging | DB, loops, caching, network I/O, or >500 LOC |
| **AttackerPersona** | Credential-flow, AI-agent boundary, ident-vs-value, cookie/session, revival re-validation, CWE tagging | Any security signal (see `reference.md`) or `--security` flag |
| **BugPath Verifier** | Root cause, fix coverage, sibling bugs, regression test | BugPath Mode active (see Phase 0.5) — mandatory, not skippable |
| **Monolith** (on-demand) | All dimensions | `--all` flag or manual request |

**Decision rules:** Docs-only → Standards Enforcer only. Config-only → Guardian (+ Standards Enforcer / Defect Finder only if a metric/alarm or other dispatch signal below is present). Any code → Defect Finder + Guardian + Standards Enforcer + conditionally Design Critic and Performance Analyst.

**Signal-driven dispatch** (additive — a signal activates its reviewer(s); it never deactivates one already selected above). Scan the diff for these signals and route accordingly:

| Diff signal | Reviewer(s) | Owns |
|---|---|---|
| Metric/counter/event definition, or `.emit(`/`.inc(`/`publish(` call | Defect Finder + Standards Enforcer | Producer Trace, metric liveness, emission symmetry |
| Alarm/threshold definition, or an error branch that emits a metric or feeds an alarm | Guardian + Standards Enforcer | Alarm-feeding isolation, failure-mode differentiation, multi-provider coverage |
| External-dependency call / SDK error classifier (429, 5xx, provider error shapes) | Guardian | Multi-provider predicate coverage, monitoring blast radius |
| Field set to `null`/`0`/`false`/reset | Defect Finder + Guardian | Consumer trace, cross-cutting regressions |
| Public signature / interface / message schema / shared type change | Design Critic + Guardian | API design, backward compat |
| Loop over I/O, DB query, cache, network call, or >500 LOC | Performance Analyst | N+1, payload bloat, blocking I/O |
| File rename/move/delete | Guardian (inbound-reference focus) | Broken external consumers |
| Test-only change | Standards Enforcer (+ Defect Finder for revert-safety) | Mock fidelity, revert-safety |
| Security-class signal (caller-supplied URL, dynamic SQL identifier, new MCP tool/IPC, secret read, cookie/session, `_disabled/` revival) | AttackerPersona | Credential-flow, AI-agent boundary, ident-vs-value; tags + threat-model severity multiplier |

When no signal and no default activates a reviewer, skip it and say why in the triage line.

**Mandatory activation (not subject to triage exclusion):**

- **Guardian** is ALWAYS activated when changes touch: retry logic, circuit breakers, rollback behavior, deployment config, feature flags, authentication/authorization, or state machine transitions.
- **Design Critic** is ALWAYS activated in Standard Mode when changes touch: interfaces, public APIs, contracts, message schemas, shared state types, or cross-module boundaries.

**Design Critic in Bug Fix Mode (SUPPRESSED by default):** Only re-activated if diff contains API-change signals (new exports, public method signatures). State in triage line; see `reference.md` § Design Critic BugPath Logic for the detection command.

**Overrides:** `--all` (force all), `--only=<name>`, `--skip=<name>`, `--round1-only` (skip escalation), `--security` (force AttackerPersona on), `--no-security` (force AttackerPersona off), `--mode=bug-fix` (force Bug Fix Mode), `--mode=feature` (force Standard Mode). `--skip=BugPath Verifier` is silently ignored in Bug Fix Mode (the reviewer is mandatory).

State your triage decision before dispatching:

```markdown
**Triage**: Activated: [list] | Skipped: [list] | Reason: [1-2 sentences]
```

### Phase 2: Diff + Source Context + Dispatch

Sub-agents have NO conversation context. Pass diff + source context inline.

**1. Capture diff:** `git diff --cached`, `git diff HEAD~1`, or `git diff main..HEAD`

**2. Source context for ripple analysis** (#1 missed-finding cause = reviewing diff in isolation): Fields SET/RESET/NULLED → grep READERS. Symbols DEFINED (metrics, events, enums, error codes) → grep PRODUCERS; zero producers = dead definition (mandatory finding for metric/alarm signals). Threshold comparisons → grep PRODUCERS. Stateful code → full state type + transitions. Changed signatures → all callers. Cross-module calls → full callee body (or signature + state-mutating/throwing/early-return branches if budget-constrained).

**3. Inbound reference scan** (mandatory when diff renames, moves, or deletes files):

```bash
git diff --diff-filter=RD --name-only main..HEAD   # old paths
grep -rn "old-filename" . --include="*.md" --include="*.ts" --include="*.sh"  # scan ENTIRE repo
```

**MUST scan outside the changed directory.** The #1 failure mode: scoping grep to the refactored directory, missing sibling modules that reference old paths. Hits outside the diff are **mandatory CRITICAL findings** — broken consumers the author didn't update. Include grep results in every reviewer's context.

**4. Dispatch ALL activated reviewers simultaneously** via `sub-agent-code-reviewer` (Augment) or `Task()` (Claude). Each gets: reviewer prompt + full diff + source context + inbound reference scan results.

### Phase 3: Aggregate

After all reviewers return:

1. Sort findings: **Critical → Important → Minor**, then by file path
2. Prefix each with `[Reviewer Name]`
3. **Convergence**: same location from 2+ reviewers — keep both; True convergence (different reasoning paths) → promote to Important; Echo convergence (same evidence/phrasing) → retain original severity.
4. Clean dimensions need same `evidence` block as findings; missing evidence caps dimension at 7.0.
5. **Severity**: Critical=broken now; Important=breaks under conditions; Minor=standards gap. Elevate to Important when operator-visible signal is wrong/missing. Reclassify process gaps downward. See `reference.md` § Severity Definitions.
6. **Triple-filter** each Imp/Critical on CX impact, complexity, testability → Implement (propose exact fix) / Defer / Reject.
7. Preserve Regressions Risked + Durable Check per Implement finding.
**Tightening**: >10 findings → suppress Minors from body (count in summary). **Score**: `10.0 − 2.5×C − 1.5×I − 0.25×M − (durable<50%?0.5:0)`, floor 0.0. BugPath path-coverage floor: INSUFFICIENT→cap 6.5, PARTIAL→8.0, FULL→none. Metrics: durable ≥50%, convergent count, unresolved Critical=0.

**Report format**: Executive Summary (see `reference.md` § Executive Summary Template) → Header → Critical → Important → Minor → Clean Dimensions → Action Classification → Durable Checks → Summary (`Findings: [N]C/[N]I/[N]M | durable=[N]%, convergent=[N], unresolved-critical=[N]`).

### Phase 4: Escalation (Round 2)

If ANY trigger fires after Round 1, re-dispatch a focused reviewer:

| Trigger | Re-run | Why |
|---------|--------|-----|
| >2 state/flag findings | Defect Finder (interaction-path focus) | Systemic timing/ordering |
| >3 test quality issues | Standards Enforcer (mock-focused) | Shared mock infrastructure |
| >50 lines removed or functions deleted | Guardian (deletion focus) | Callers may depend on removed behavior |
| Files renamed/moved/deleted without inbound scan | Guardian (inbound-reference focus) | Broken consumers outside the changed directory |
| "Pre-existing" issues flagged | Defect Finder (lifecycle focus) | Deeper structural gaps |
| Diff adds/changes a metric or alarm definition, or an error-handling branch that emits a metric or feeds an alarm | Standards Enforcer (observability-completeness focus) | Dead definitions, Success/Failure asymmetry, undifferentiated failure modes |

Re-dispatch with focused instruction (diff slice + refreshed context + trigger signal). Append under `### Round 2 Findings`. Skip if `--round1-only`, all clean, or diff <20 lines.

### Phase 5: Convergence

**STOP** when: unresolved Critical = 0, last 2 passes <20% new high-sev, durable ≥50%. **CONTINUE** if escalation trigger fires or Critical remains. **ESCALATE TO HUMAN** after 3 passes.

### Correlated-Failure Detection

After synthesis: (1) evidence overlap: ≥3 reviewers cite same file+line → flag and expand scope; (2) phrasing similarity: near-identical rationale across findings → flag and re-examine from different entry; (3) clean sweep: all-zero findings → verify reviewers examined different slices. Flags trigger scope expansion, not verdict changes. See `reference.md` § Correlated-Failure Detection.

### Phase 6: Finalize Verdict + Write Sentinel

**Prerequisite:** Correlated-Failure Detection has completed and no re-examination was triggered.

**Preserve the run (before sentinel write):**

1. Determine the verdict from this MR's score vs threshold: PASS if score >= threshold; PASS_WITH_NITS if at or above threshold but nits flagged; REJECT or PASS_WITH_FIXES otherwise.
2. Write a JSON envelope to `.cr-battery-runs/<HEAD-sha>.json` (per-engineer durable record; the directory is gitignored).

Run envelope schema: `reference.md` § Run Envelope Schema.

Every finding AND clean-dimension verdict must carry an `evidence` block. `verifiable: false` claims cap at 7.0. Expectation types and verifier replay details: `reference.md` § Verifier Details. `tools/run-battery.sh` refuses to write sentinel if per-HEAD JSON missing in Bug Fix Mode; graceful degrade in Standard Mode.

If final verdict is `PASS` or `PASS_WITH_NITS` (all nits resolved):

```bash
# tools/run-battery.sh is the ONLY permitted way to write .code-review-cleared.
tools/run-battery.sh --verdict PASS --min-score <threshold>
```

> ❌ **Never write `.code-review-cleared` directly with `echo`.** Use `tools/run-battery.sh`.

**Timing:** If battery runs pre-commit, the sentinel becomes stale after commit -- re-run before push. The pre-push hook validates sentinel SHA against the pushed ref; without a valid sentinel the push is blocked.

If verdict is `REJECT` or `PASS_WITH_FIXES`: do NOT write the sentinel. Fix all Critical/Important findings, re-dispatch, then write sentinel when the re-run passes.

### Gap Analysis + Error Handling
Monolith found something no specialist found → candidate pattern → `candidates/`. Reviewer fails → note, don't retry. Diff >3000 lines → warn, suggest chunks. Empty diff → skip.

## Anti-Patterns

See `reference.md` for the 5 anti-patterns (all-agree, duplicates, fatigue, missing-context, over-scoping) with detection + correction columns. Moved to the companion file to keep this skill under the per-skill line budget.

## Failure Modes

See `reference.md` for the 4 standard failure modes (no-findings, FPs-from-isolation, convergence-stuck, monolith-vs-specialist) with fixes. Moved to the companion file alongside the Anti-Patterns table.

## Companion Skills

- **progressive-code-review-gate**: Primary consumer (dispatches this battery pre-commit)
- **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
- **inter-agent-review-protocol**: File-protocol review (alternative dispatch method)
- **micro-harsh-review**: Per-batch review
