# sp-bughunt -- Reference Material

Companion to `skill.md`. Holds language-aware patterns, the full Failure Modes catalogue, parser worked examples, full report templates, and the migration note. `skill.md` is the canonical source for protocol semantics; if anything in this file disagrees, `skill.md` wins -- raise an issue.

## 1. Parameter Parser -- worked examples

**Rule (canonical, restated from `skill.md`):** any numeric `X` token following `above`, `>=`, `at least`, or `threshold` resolves to **the smallest mode `>= X`**, clamped to the `confidence-mode` enum range `{7.0, 8.0, 9.0}`. A bare integer sets `N`. Both the resolved mode and the source input are echoed in the audit-trail header.

| User says | Parsed |
|---|---|
| "bug hunt" | N=2, scope=repo, focus=all, mode=release-prep (T=8.0, source=default) |
| "find the top 5 worst bugs" | N=5, mode=release-prep (default) |
| "top 5 worst bugs at threshold 7" | N=5, mode=hygiene (T=7.0, source="threshold 7") |
| "find bugs above 7.5" | mode=release-prep (T=8.0; smallest mode >= 7.5 is 8.0) |
| "find bugs above 6.5" | mode=hygiene (T=7.0; smallest mode >= 6.5 is 7.0) |
| "find bugs above 5" | mode=hygiene (T=7.0; clamped -- 5 < smallest mode 7.0) |
| "find bugs above 9.5" | mode=release-gate (T=9.0; clamped -- 9.5 > largest mode 9.0) |
| "find security bugs in src/auth, top 3" | N=3, scope=src/auth, focus=security |

Fields not stated in the user message take defaults. `confidence-mode` is named to prevent silent threshold lowering. The audit-trail header makes every resolved value visible; reviewers grep the header to spot tampering.

## 2. Language-Aware Sibling Glob Patterns

Detect from file extensions in scope, then use:

| Language | Sibling glob hints | Notes |
|---|---|---|
| JavaScript / TypeScript | `*-storage.{js,ts}`, `*-validator.{js,ts}`, `*Service.{js,ts}`, `*Repository.{js,ts}` | Hyphenated suffix family is common; also check `*.module.ts` |
| Go | `*Handler.go`, `*Service.go`, `*Repository.go`, `*_v2.go` | Test files live adjacent as `*_test.go` |
| Python | `*_storage.py`, `*_validator.py`, `*_service.py` | Underscore not hyphen |
| Rust | adjacent `mod.rs` trees; `*_v2.rs` near `*.rs` | Sibling family often expressed as adjacent modules |
| Java / Kotlin | `*Service.java`, `*Repository.java`, `*Handler.java`, `*Controller.java` | Parallel `src/test/` tree for tests |
| ColdFusion | `*Service.cfc`, `*Gateway.cfc`, `*DAO.cfc` | Legacy CF often has no formal test infrastructure |
| C# | `*Service.cs`, `*Repository.cs`, `*Controller.cs` | `*.Tests` parallel project for tests |

If the language is not in this table, derive the sibling pattern from the candidate file's own suffix family (e.g. given `parser-json.ml`, search for `parser-*.ml`). Record the derived pattern in the audit trail.

## 3. Test-File Discovery Algorithm (deterministic)

For each candidate function, look for tests in this order. First match wins.

1. Same directory: file with the same base name plus suffix `_test.<ext>`, `.test.<ext>`, `.spec.<ext>`.
2. Sibling `__tests__/`, `tests/`, `spec/`, `test/` directory; match by base name.
3. Parallel `src/test/` tree (Java / Kotlin / Scala convention); match by package path.
4. Inline `#[cfg(test)] mod tests` in the same file (Rust).
5. ColdFusion: check `tests/`, `mxunit/`, `testbox/` adjacent. Legacy CF often has none of these; expect `no-test-infrastructure` on legacy ColdFusion repos.
6. None located -> label `no-test-infrastructure`. Do **not** default to `uncovered`.

For non-listed languages, derive the convention from the candidate's suffix family (e.g. `*.ml` -> `*_test.ml`, `test/`).

## 4. Gate D Label Table (full)

Apply I1 on the test file using the discovery algorithm. Assign exactly one label. Gate D **records** the label; the routing decision happens in the Phase 3 Routing Decision (skill.md), not inside this gate. The "outcome" column below describes which Routing Decision rule a label triggers.

| Label | Meaning | Recording effect (short-circuit or continue) | Routing Decision rule that fires |
|---|---|---|---|
| `uncovered` | No test exercises this path. | Continue to C and E. Correctness anchors may reach 10. | Falls through to rules 5-11. |
| `covered-passing-intentional` | A test asserts the current behavior; the assertion is correct. | **Short-circuit:** halt this candidate; skip C and E. | Rule 2 -> Rejections. |
| `covered-passing-misread` | A test asserts the current behavior; the agent's claim is the misread. | **Short-circuit:** halt; skip C and E. | Rule 3 -> Rejections. |
| `covered-passing-test-buggy` | Test passes, but the agent has quoted a specific incorrect assertion. | Continue to C and E. Required record: the assertion line, the expected-correct assertion, AND a **reason** explaining why the assertion is wrong. | Falls through to rules 5-11. |
| `covered-skipped` | Test exists but is `it.skip` / `xit` / `t.Skip` / `@Disabled` / `xfail`. | Continue; counts as fail-open `D-covered-skipped`. Required record: skip reason. | Falls through to rules 5-11. |
| `no-test-infrastructure` | Per discovery algorithm, the repo has no test infrastructure for this file. | Continue; required record: discovery patterns tried. | Rule 7 -> Low-Confidence Risks UNLESS sibling-divergence OR (Gate C pass AND hops <= 1); when compensated, falls through and counts as `D-no-test-infra-compensated`; when demoted, counts as `D-no-test-infra-demoted`. |
| `unsure` | Agent looked at the test and cannot determine which branch applies. | Continue (fail-closed); counts as fail-open `D-unsure`. Required record: the ambiguity description. | Rule 6 -> Low-Confidence Risks. |

## 5. Gate C Concurrency Principle, Hop Definition, Boundary Definition

**Hop** = one call-graph edge traversed when tracing **outward** from the candidate function toward the nearest user-input boundary. `foo() -> bar()` is one hop. `foo() -> bar() -> baz()` is two hops. The cap is **3 hops**; beyond 3, Gate C records `fail`.

**User-input boundary** = the nearest of: HTTP route handler, queue consumer, scheduled task, signal handler, IPC endpoint, message-bus subscriber, CLI entry point, web-hook receiver, IRQ handler. The boundary is where external (non-orchestrator) input enters the system.

**Path-resolution contract for Phase 1:** use `realpath` with the semantics "resolve all symlinks; the path must exist; reject otherwise" (GNU `realpath -e`; on BSD/macOS, equivalent is `realpath` followed by a stat existence check). Any `realpath` failure aborts the run with `path-resolution-failure`.

**Concurrency principle:** *any caller that produces two unawaited promises, two unjoined threads/goroutines, or two outstanding async tasks before a join point is concurrent.* Sequential `await x(); await y()` within a single async function is sequential **within this caller** -- but cross-caller races still apply if another caller mutates the same shared state concurrently.

Non-exhaustive examples by language:

| Language | Concurrent constructs |
|---|---|
| JavaScript / TypeScript | `Promise.all`, `Promise.allSettled`, `Promise.race`, `queueMicrotask`, `setInterval`, `setTimeout`, web workers, `process.nextTick` |
| Python | `asyncio.gather`, `asyncio.create_task`, `asyncio.wait`, `concurrent.futures`, `multiprocessing`, `threading.Thread` |
| Rust | `tokio::spawn`, `tokio::join!`, `rayon::join`, raw `std::thread::spawn` |
| Go | `go` statements, `errgroup.Group.Go`, `sync.WaitGroup` patterns |
| Java | `ExecutorService.submit`, `CompletableFuture.thenComposeAsync`, `Thread.start`, `ForkJoinPool` |
| Cross-cutting | signal handlers, IPC message handlers, web-hook handlers, queue consumers, IRQ handlers |

## 6. Report Templates (full)

Sections appear in this fixed order: **Bugs** -> **Unreachable Risks** -> **Low-Confidence Risks** -> **Rejections**.

```markdown
## Bug Hunt Report

[If re-dispatch-exhausted=true] **WARNING: coverage incomplete (<X>% of resolved scope unread)**

**Parameters resolved:** N=<N>, scope=<resolved file count>, focus=<focus>, confidence-mode=<mode> (T=<threshold>, source=<user input or 'default'>)
**Audit trail -- gate evaluations:** A=<count> B=<count> D=<count> C=<count> E=<count>
**Audit trail -- gate passes-to-next:** A=<count> B=<count> D=<count> C=<count> E=<count>
**Audit trail -- gate fail-opens:** B-no-sibling=<n>, D-no-test-infra-compensated=<n>, D-no-test-infra-demoted=<n>, D-unsure=<n>, D-covered-skipped=<n>, Phase4-mitigation-downgrade=<n>, Phase4-I3-rerun=<n>
**Audit trail -- phases:** Phase1-sanitization-rejections=<n>, Phase2-re-dispatches=<n>, re-dispatch-exhausted=<true|false>
**Audit trail -- outcomes:** confirmed=<n>, unreachable-risk=<n>, low-confidence-risk=<n>, rejected=<n>, sub-agent-candidates-returned=<n>, files-unreached=<n>
**Languages detected:** <list>
**Sibling patterns applied:** <list>
**Test discovery:** matches found=<n>, no-test-infrastructure=<n>, covered-passing-intentional=<n>, covered-passing-misread=<n>, covered-passing-test-buggy=<n>, covered-skipped=<n>, uncovered=<n>, unsure=<n>

[If triggered] **Low-yield justification:** scope size=<n>, files reached=<n>, why fewer candidates surfaced: <one paragraph>

## Bugs (Confirmed)

### Bug #N -- <title> ([CONFIRMED] severity: <S>)

**File:** `<path>`, `<function>()`, line <N>
**Mechanism:** <one sentence: what the code does wrong>
**Failure mode:** <user/system effect; "data loss" only per the strict definition>
**Sibling check:** <sibling file + how it diverges, or "no sibling found; patterns tried: <list>">
**Test coverage:** <label from Gate D; if covered-passing-test-buggy: quote the offending assertion line, the expected-correct assertion, AND the reason>
**Reachability:** <caller file:line; sequential vs concurrent; hops-to-boundary>
**Confidence scores:** Correctness <X> / Testability <X> / Severity <X> (avg <X.X>); floors: Correctness <pass/fail>, Severity <pass/fail>
[If Phase 4 mitigation fired] **Severity audit:** original=<Y>, post-mitigation=<Z>
**Mitigation check:** <list of surfaces checked, present yes/no per surface; "<surface>: not-present" appears as negative evidence>
**Evidence:** <exact snippet, <=8 lines>
**Fix sketch:** <one paragraph>

## Unreachable Risks (real bug class, no current caller)

### Risk #N -- <title>
**File:** `<path>:<line>`
**Why unreachable:** <e.g. "no caller within 3 hops; closest is `foo()` at file:line, but `foo()` itself is unused">
**Sibling check:** <Gate B output>
**Test coverage:** <Gate D label; D ran before C-demotion, so the label is always present>
**Hardening suggestion:** <one sentence; narrow the API surface so the bug becomes impossible-by-construction>
*(Gate E was skipped per Gate C demotion; no confidence scores.)*

## Low-Confidence Risks (borderline)

### Risk #N -- <title>
**File:** `<path>:<line>`
**Why low-confidence:** <e.g. "Correctness 6, Severity 7, avg 6.7 < threshold 8.0", or "D-unsure demotion", or "no-test-infrastructure plus no sibling divergence">
**Sibling check:** <Gate B output>
**Test coverage:** <Gate D label>
**Confidence scores:** Correctness <X> / Testability <X> / Severity <X> (avg <X.X>); floors: Correctness <pass/fail>, Severity <pass/fail>
**Promotion path:** <what evidence would move this to Confirmed -- e.g. "add a failing test that demonstrates the failure">

## Rejections (transparent log)

- `<file>:<line>` -- rejected because <reason>; scores: [Correctness=<X> (floor <pass/fail>), Testability=<X>, Severity=<X> (floor <pass/fail>)]; label=<Gate D label or 'skipped'>; sibling=<Gate B status or 'skipped'>
- ...
```

## 7. Full Failure Modes Catalogue

| Mode | Symptom | Recovery |
|---|---|---|
| Off-by-one misread of intentional design | Sub-agent claimed `slice(0, currentIndex)` was an off-by-one; a passing test explicitly validated "replace current and forward". | Gate A (I1) + Gate D: `covered-passing-intentional` / `covered-passing-misread` -> Rejections unless the agent can quote a specific incorrect assertion, the corrected expected value, and a reason (`covered-passing-test-buggy`). |
| Fabricated caller evidence | Sub-agent cited an IndexedDB race reachable from `ensureState`; `ensureState` uses sequential `await`. | Gate C: name caller, quote call site, apply concurrency principle. Sequential within one caller is not a race. Demote to Unreachable Risks. |
| Missing sibling cross-check | Real bug (no-change dedup placed after a truncation that invalidates it) was discoverable only by diffing `validator-storage.js` vs `validator-project-storage.js`. Sub-agent inspected each file in isolation. | Gate B language-aware sibling patterns + I2 (re-read both siblings from disk). |
| No-test-infrastructure inverts the gate | Brownfield repo with zero tests; every candidate stamped "uncovered", inflating bug claims. | Gate D `no-test-infrastructure` label (distinct from `uncovered`); compensating-signal rule routes to Low-Confidence if neither Gate B nor Gate C produces compensating evidence. |
| No sibling found gives free pass | Single-file utility or unique-domain module has no siblings; Gate B note-only handling lets candidates skip the high-yield gate. | Gate B compensating rule: no-sibling candidates are eligible for Confirmed only if Gate C passes with `hops <= 2` OR Gate E Correctness >= 8. Else demote to Low-Confidence Risks. Audit-trail counter `B-no-sibling`. |
| Sub-agent prompt injection via `scope` | User `scope` value contains "ignore prior instructions" or `../../etc`. | Phase 1: `realpath`-canonicalize each path; reject anything outside `git rev-parse --show-toplevel`; reject control characters; cap resolved list at 500 files. The sub-agent prompt receives a quoted file list, not raw user prose. |
| Sub-agent prompt injection via `focus` | User `focus` contains arbitrary prose. | Phase 1 enum validation. |
| Caller-chain depth unbounded | Agent traces 50 hops and hallucinates a shallow caller. | Gate C 3-hop trace cap; beyond 3 hops -> Unreachable Risks. |
| Unsubstituted template angle-brackets | Sub-agent receives the literal string `<N * 3>`. | Phase 2 explicit substitution instruction; dispatched prompt contains integer literals. |
| Threshold silently lowered | Agent quietly sets `confidence-mode: hygiene` to fill the bug list. | Named modes; audit-trail header echoes the resolved mode and the source value it was snapped from. |
| Collinear scoring inflated by averaging | Reachability+Severity+Correctness averaged together masks defects. | Three orthogonal axes only (Correctness, Testability, Severity). Reachability handled by Gate C binary. Hard floors disqualify regardless of average. |
| Promoted candidate without showing scores | Audit cannot verify the gating decision. | Quality Gate: scores AND floors shown on every Confirmed bug, Low-Confidence Risk, and Rejection. Unreachable Risks legitimately omit them. |
| Manufactured findings by lowering threshold | "Bug list" full of weak candidates passing only because `confidence-mode=hygiene`. | Header echoes mode + source; reviewers grep for `confidence-mode: hygiene` and challenge. "No bugs at release-gate" is a valid output (with `low-yield-justification` if zero candidates). |
| Sub-agent timed out or hit read budget | Incomplete exploration with no signal that exploration was incomplete. | Phase 2 read-budget contract; 20%-unreached re-dispatch with a 2-cap; `re-dispatch-exhausted=true` flagged in audit trail. |
| Test file in non-standard location | Discovery returns nothing; candidate gets `no-test-infrastructure` even though tests exist elsewhere. | Phase 1 language detection populates the discovery algorithm; for unknown languages, derive patterns from the candidate's suffix family; record the derived patterns. |
| Phase 4 mitigation downgrade bypasses Gate E | Mitigation found and severity dropped without re-routing through the bands. | Phase 4 step 3: subtract 3 from Severity, re-check floor, re-route through Gate E thresholds. Floor violation routes to Rejections with reason `mitigation neutralized below floor`. |
| Severity 10 overloaded | "Data loss or auth bypass" conflated. | Severity 10 = (a) permanent unrecoverable data loss via specific user action (strict), OR (b) auth/authorization bypass with a clear exploit path, OR (c) cross-tenant data exposure in multi-tenant SaaS. Document the chosen interpretation in the Failure mode field. |
| Zero-work bypass | Agent returns "no candidates found" with no audit evidence of work. | Minimum-yield gate: if sub-agent returns 0 candidates AND files-reached >= 50%, orchestrator must emit a `low-yield-justification` block. Zero-bug report without the block is treated as a failed run. |
| Disk drift between Phase 2 and Phase 5 | File edited between sub-agent read and report emission; evidence quote no longer matches. | I3 in Phase 4. First mismatch returns the candidate to Gate A. Second mismatch routes to Rejections with reason `disk-drift`. |
| Path traversal via symlink | Resolved path passes `..` check and prefix check but symlinks outside the repo. | Phase 1 `realpath`-canonicalize before the repo-root prefix check. |
| Non-git scope | Tool invoked outside a git repo; `git rev-parse --show-toplevel` fails. | Phase 1 aborts with `not-in-git-repo`. No fallback. |
| Resolved file list explosion | Glob expands to 50k files; sub-agent thrashes. | Phase 1 caps resolved list at 500 files; reject above the cap and require narrower scope. |
| Recursive re-dispatch loop | Each narrower scope still hits 20%-unreached. | Phase 2 caps re-dispatch at 2; sets `re-dispatch-exhausted=true` and proceeds with partial coverage. |

## 8. Migration Note (output format)

v3+ report format differs from v1:

- Two new section headings (`Unreachable Risks`, `Low-Confidence Risks`) split from the prior single `Risks` block.
- Header expanded with audit-trail rows (gate firings, fail-opens, phase counters, outcomes).
- Each Confirmed bug now has `Sibling check`, `Test coverage`, `Reachability`, `Confidence scores`, `Mitigation check` fields.
- Severity 10 anchor expanded (cross-tenant exposure now lands at 10).
- `low-yield-justification` block may appear in the header when triggered.

Downstream parsers detect v3+ format by the presence of the `Audit trail -- gate evaluations:` line in the header. v1 reports lack this line.

v5 additionally:
- Renamed `gate firings` -> `gate evaluations` and added `gate passes-to-next` row to distinguish evaluated from passed.
- Added `Phase4-I3-rerun` fail-open counter.
- Added `WARNING: coverage incomplete` banner when `re-dispatch-exhausted=true`.
- Expanded `Test discovery` line to include all seven Gate D labels.
- I3 now binds at Phase 5 emission for every Confirmed bug, Unreachable Risk, and Low-Confidence Risk (not only Confirmed survivors).
- Phase 4 mitigation downgrade explicitly moves entries across output sections when re-routing crosses a band boundary.
