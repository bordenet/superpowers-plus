---
name: code-review-battery
description: "Use when reviewing code changes to dispatch parallel specialized reviewers instead of a single monolithic review — provides deeper, more precise findings across focused lenses. Invoke as: /sp-cr-battery [min-score] [--security|--no-security] [--mode=bug-fix|feature] (optional 1.0–10.0 quality threshold, default 7.0; default 9.2 in Bug Fix Review Mode). Bug Fix Mode auto-activates on hotfix/* and fix/[A-Z]+-[0-9]+ branches."
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
# cat succeeds on a stale sentinel (wrong SHA) — compare the printed SHA to HEAD explicitly.
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

> **Load gate:** This phase requires `reference.md` to be loaded alongside this skill. If absent AND the branch matches a BugPath pattern (`hotfix/*` or `fix/[A-Z]+-[0-9]+`, per the detection script in `reference.md`): **hard halt** — emit only: "Cannot enter BugPath Mode: reference.md is absent. Load it before proceeding." Output nothing further — no phase summaries, no partial results, no clarifying questions. Return control to the user. If absent AND the branch does NOT match a BugPath pattern: treat BugPath Mode as INACTIVE and note in triage line.

Run immediately after the sentinel check. Detect whether this is a targeted bug fix, then set the mode before triage.

(Detection script: `reference.md` § BugPath Detection Script.)

| Signal | BugPath Mode trigger |
|--------|---------------------|
| Branch prefix `hotfix/*` | Active |
| Branch matching `fix/[A-Z]+-[0-9]+` (e.g., `fix/PROJ-1234` or `fix/PROJ-1234-description`) | Active |
| Explicit flag `--mode=bug-fix` | Active |
| Explicit flag `--mode=feature` | Inactive (overrides branch detection) |

**When BugPath Mode is active:** BugPath Verifier mandatory (not skippable), threshold 9.2, path-coverage floor applies (see Phase 3). SCOPE-SKIP on a confirmed bug-fix branch = Important finding, score -1.5. State mode in executive summary triage line (`reference.md` § Executive Summary Template). Also supports `--mode=bug-fix` and `--mode=feature`. If the diff also matches the Sibling Path Trace signal (Phase 1), BugPath Verifier's dispatch payload (Phase 2 step 4) MUST additionally include the "Sibling Path Trace" excerpt from `reviewers/defect-finder.md`, since BugPath Verifier's Sibling Bug Scan dimension runs that method rather than re-deriving it.

### Phase 1: Triage

Analyze the diff and select reviewers:

| Reviewer | Focus | Activate When |
|----------|-------|---------------|
| **Defect Finder** | Correctness, edge cases, concurrency | Any code change |
| **Design Critic** | Factoring, complexity, API design | Adds/modifies classes, functions, public APIs |
| **Guardian** | Security, blast radius, backwards compat | Any code change |
| **Standards Enforcer** | Docs, test quality, observability | Always |
| **Performance Analyst** | Performance, logging | DB, loops, caching, network I/O, or >500 LOC |
| **AttackerPersona** | Credential-flow, AI-agent boundary, ident-vs-value, cookie/session, revival re-validation, CWE tagging | Any security-class signal (see signal-driven dispatch table below) or `--security` flag |
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
| **New user-visible feature** (new endpoint, new agent action, new UI-affecting path, new workflow branch) with **no metric or trace emit in the diff** | Standards Enforcer (OE Telemetry Gate — mandatory Critical) | Missing time-series metrics and/or distributed trace instrumentation for new behavior — ships blind; see §4a OE Telemetry Gate |
| `try { ... } catch` block in the diff (regardless of size or context) | Defect Finder -- this signal does NOT activate a new reviewer (Defect Finder already activates for any code change); it mandates specific coverage: `Catch-Swallow Fall-Through` (always) + `Finally-Block State Precondition` (only if the diff also contains a `finally` block) + `Dead Catch Verification` (before proposing any new catch) | Catch-fall-through races, finally blocks emitting against partially-completed state, unreachable defensive catches |
| Diff deletes or reroutes what was the only call site of a function/method/export, checked repo-wide (an ordinary unused-import left behind by the same refactor, with no other reference removed, is a separate minor lint concern -- NOT this pattern) | Defect Finder | Caller Removal Trace: dead code introduced by this diff (orphaned function/export) -- findings MUST use Guardian's Anti-Hallucination Gate evidence format (`reviewers/guardian.md`) |
| New property added to a type/interface/shared-state object already consumed by 2+ non-test files, OR diff touches only one file in a known parallel-path family (siblings sharing a create/update/post vs. reschedule/cancel/delete naming pattern, or sync/async twins, for the same resource) where the change supplements/supersedes a field those siblings already read | Defect Finder + Guardian | Sibling Path Trace: does every other handler for the same conceptual entity get equivalent treatment on the shared field? |

When no signal and no default activates a reviewer, skip it and say why in the triage line.

**Mandatory activation (not subject to triage exclusion):**

- **Guardian** is ALWAYS activated when changes touch: retry logic, circuit breakers, rollback behavior, deployment config, feature flags, authentication/authorization, or state machine transitions.
- **Design Critic** is ALWAYS activated in Standard Mode when changes touch: interfaces, public APIs, contracts, message schemas, shared state types, or cross-module boundaries.

**Design Critic in Bug Fix Mode (SUPPRESSED by default):** Only re-activated if diff contains API-change signals (new exports, public method signatures). State in triage line; see `reference.md` § Design Critic BugPath Logic for the detection command (if `reference.md` absent: default to SKIPPED unless `--all` flag set).
**Reduced dispatch for a cited port claim (evidence required, not self-attested):** A "verbatim/near-verbatim port of already-reviewed code" claim does NOT by itself reduce the activated reviewer set. It only reduces dispatch when the triage line pastes both the cited source (repo + commit SHA) and the literal `git diff <cited-source-sha> -- <changed files>` command plus its output — the command itself, not just the output, so the claim is independently re-runnable rather than plausible-looking. Guardian is never dropped by this exemption: a byte-identical port can still be dangerous at its new call site (different callers, different exposure), which is Guardian's lens, not a text-diff concern. The rest of the retained set depends on mode: Bug Fix Mode retains Guardian + Standards Enforcer (BugPath Verifier is already mandatory there per the roster above); Standard Mode retains Guardian + Standards Enforcer + Defect Finder. **Carve-out:** Defect Finder's charter also covers concurrency (races, locking, ordering), which BugPath Verifier's root-cause/fix-coverage lens does not substitute for. If the cited-port diff touches concurrency-relevant constructs (locks, threads/goroutines, async/await, shared mutable state, retry/backoff timing), Defect Finder is re-activated in Bug Fix Mode regardless of the port citation — the exemption covers correctness/edge-case redundancy only, not concurrency. Content beyond the cited source (new tests, new logic, fixes not upstream) gets the full reviewer set; the exemption never extends past what the citation covers. No evidence in the triage line means unverified — dispatch normally. (A genuine verbatim port produces a trivial/empty comparison here — if it doesn't, the "port" framing was wrong, not the review depth.)

**Overrides:** `--all` (force all), `--only=<name>`, `--skip=<name>`, `--round1-only` (skip escalation), `--security` (force AttackerPersona on), `--no-security` (force AttackerPersona off), `--mode=bug-fix` (force Bug Fix Mode), `--mode=feature` (force Standard Mode). `--skip=BugPath Verifier` is silently ignored in Bug Fix Mode (the reviewer is mandatory).

State your triage decision before dispatching:

```markdown
**Triage**: Activated: [list] | Skipped: [list] | Reason: [1-2 sentences]
```

### Phase 2: Diff + Source Context + Dispatch

Sub-agents have NO conversation context. Pass diff + source context inline.

**1. Capture diff:** `git diff --cached`, `git diff HEAD~1`, or `git diff main..HEAD`

**2. Source context for ripple analysis** (#1 missed-finding cause = reviewing diff in isolation): Fields SET/RESET/NULLED → grep READERS. Symbols DEFINED (metrics, events, enums, error codes) → grep PRODUCERS; zero producers = dead definition (mandatory finding for metric/alarm signals). Threshold comparisons → grep PRODUCERS of the compared value. Stateful code → full state type + transitions. Changed signatures → all callers. Cross-module calls → full callee body (or signature + state-mutating/throwing/early-return branches if budget-constrained). On-disk format changed (ad-hoc-parsed, no shared parser) → grep ALL consumers repo-wide incl. tests; prefer "extract a shared parser" over "update each consumer" (see reference.md Failure Modes). Symbol whose only call site the diff removes or reroutes → grep the FULL repo for remaining references; zero = dead code introduced by this diff; also pass `package.json` (`exports`/`publishConfig`/`main`) into context, since the severity ladder downgrades an exported symbol from Important to Possible when the repo is a published library (see Caller Removal Trace). New/changed field that supplements or partially supersedes an existing field on shared state → grep ALL existing readers of the field it supplements (not just the new field's own readers, which may not exist yet) → verify every such reader was updated, or confirm why it doesn't need to be (see Sibling Path Trace).

**3. Inbound reference scan** (mandatory when diff renames, moves, or deletes files):

```bash
git diff --diff-filter=RD --name-only main..HEAD   # old paths
grep -rn "old-filename" . --include="*.md" --include="*.ts" --include="*.sh"  # scan ENTIRE repo
```

**MUST scan outside the changed directory.** The #1 failure mode: scoping grep to the refactored directory, missing sibling modules that reference old paths. Hits outside the diff are **mandatory CRITICAL findings** — broken consumers the author didn't update. Include grep results in every reviewer's context.

**4. Dispatch ALL activated reviewers simultaneously** via `sub-agent-code-reviewer` (Augment) or `Task()` (Claude). Each gets: reviewer prompt + full diff + source context + inbound reference scan results.

### Phase 3: Aggregate

After all reviewers return:

1. Sort findings: **Critical → Important → Minor → Possible**, then by file path
2. Prefix each with `[Reviewer Name]`
3. **BugPath Verifier SCOPE-SKIP** (BugPath Mode only): if the BugPath Verifier reports SCOPE-SKIP, add an Important finding "BugPath Verifier SCOPE-SKIP on confirmed bug-fix branch — manual path-coverage review required" and deduct 1.5 from the score.
4. **Convergence**: same location from 2+ reviewers — keep both; True convergence (different reasoning paths) → promote to **≥ Important** (never demote a Critical); Echo convergence (same evidence/phrasing) → retain original severity.
5. Clean dimensions need same `evidence` block as findings; missing evidence on any clean dimension causes the verifier to cap the overall run score at 7.0.
6. **Severity**: Critical=broken now; Important=breaks under conditions; Minor=standards gap. Elevate to Important when operator-visible signal is wrong/missing. Reclassify process gaps downward. See `reference.md` § Severity Definitions.
7. **Triple-filter** each Important/Critical on CX impact, complexity, testability:
   - **Implement**: passes all 3 filters — propose exact code change.
   - **Defer**: good finding but doesn't pass all 3 filters — document for future work.
   - **Reject**: correct observation but fix adds more complexity than it removes.
8. Preserve Regressions Risked + Durable Check per Implement finding.

**Tightening**: >10 findings → suppress Minors from body (count in summary; state "Tightening applied: [N] Minor findings suppressed"). **Score**: `10.0 − 2.5×C − 1.5×I − 0.25×M − (durable<50%?0.5:0)`, floor 0.0. Extract threshold from invocation (e.g. `/sp-cr-battery 8.5` → 8.5; default 7.0, or 9.2 in BugPath Mode). Score < threshold → skip the sentinel write step in Phase 6 (still write the JSON envelope to `.cr-battery-runs/`). BugPath path-coverage floor: INSUFFICIENT→cap 6.5, PARTIAL→8.0, FULL→none. Metrics: durable ≥50%, convergent count, unresolved Critical=0.

**Report format**: Executive Summary (see `reference.md` § Executive Summary Template) → Header → Critical → Important → Minor → Possible → Clean Dimensions → Action Classification → Durable Checks → Summary (`Findings: [N]C/[N]I/[N]M ([N] suppressed)/[N]P | durable=[N]%, convergent=[N], unresolved-critical=[N]`).

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
| Diff adds new user-visible functionality with zero metric/trace emits (OE Telemetry Gate) | Standards Enforcer (OE focus — mandatory Critical) | Feature ships with no time-series metrics or trace instrumentation; cannot be operated or alarmed on |

Re-dispatch with focused instruction (diff slice + refreshed context + trigger signal). Append under `### Round 2 Findings`. Skip if `--round1-only`, all clean, or diff <20 lines.

### Phase 5: Convergence

**STOP** when: unresolved Critical = 0, last 2 passes <20% new high-sev, durable ≥50%. **CONTINUE** if escalation trigger fires or Critical remains. **ESCALATE TO HUMAN** after 3 passes.

### Correlated-Failure Detection

After synthesis: (1) evidence overlap: ≥3 reviewers cite same file+line → flag and expand scope; (2) phrasing similarity: near-identical rationale across findings → flag and re-examine from different entry; (3) clean sweep: all-zero findings → verify reviewers examined different slices. Flags trigger scope expansion, not verdict changes. See `reference.md` § Correlated-Failure Detection.

### Phase 6: Finalize Verdict + Write Sentinel

**Prerequisite:** Correlated-Failure Detection has completed and no re-examination was triggered.

**Preserve the run (before sentinel write):**

1. Determine the verdict from this MR's score vs threshold: PASS if score >= threshold (no unresolved nits); PASS_WITH_NITS if at or above threshold but Minor nits remain; PASS_WITH_FIXES if below threshold but all Critical/Important findings are Implement-classified (fixable path exists); REJECT if any Critical is Reject-classified or there are unresolvable blockers.
2. Write a JSON envelope to `.cr-battery-runs/<HEAD-sha>.json`. Schema: `reference.md` § Run Envelope Schema. Every finding AND clean-dimension verdict must carry an `evidence` block; `verifiable: false` caps at 7.0. Expectation types: `reference.md` § Verifier Details. `tools/run-battery.sh` refuses sentinel write if JSON missing in Bug Fix Mode; graceful degrade in Standard Mode.

```bash
# tools/run-battery.sh is the ONLY permitted way to write .code-review-cleared.
tools/run-battery.sh --verdict PASS --min-score <threshold>           # no unresolved nits
tools/run-battery.sh --verdict PASS_WITH_NITS --min-score <threshold> # Minor nits remain unresolved
```

> ❌ **Never write `.code-review-cleared` directly with `echo`.** Use `tools/run-battery.sh`.

**Timing:** Pre-commit battery → sentinel stales after commit; re-run before push. `REJECT` or `PASS_WITH_FIXES`: do NOT write sentinel — fix Critical/Important, re-dispatch, re-run.

### Gap Analysis + Error Handling
Monolith found something no specialist found → candidate pattern → `candidates/`. Reviewer fails → note, don't retry. Diff >3000 lines → warn, suggest chunks, keeping structurally-related files (Caller Removal Trace or Sibling Path Trace candidates) in the same chunk or cross-passing their excerpts so neither chunk's reviewer works blind to the other file -- this bounds what one dispatch reads, not what Phase 2's full-repo grep obligation searches; a chunked sub-battery still greps the whole repo for out-of-diff references. Empty diff → skip.

## Anti-Patterns

See `reference.md` for the 5 anti-patterns (all-agree, duplicates, fatigue, missing-context, over-scoping) with detection + correction columns. Moved to the companion file to keep this skill under the per-skill line budget.

## Failure Modes

See `reference.md` for the 5 standard failure modes (no-findings, FPs-from-isolation, convergence-stuck, monolith-vs-specialist, duplicated-format-parsing) with fixes. Moved to the companion file alongside the Anti-Patterns table.

## Companion Skills

- **progressive-code-review-gate**: Primary consumer (dispatches this battery pre-commit) · **providing-code-review**: Engineering rigor checklist (informs reviewer focus)
- **inter-agent-review-protocol**: File-protocol review (alternative dispatch method) · **micro-harsh-review**: Per-batch review
