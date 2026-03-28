# Code Review Battery — Phase 3: Deep Review

> **Status**: Design (pending approval)
> **Author**: Matt Bordenet + AI
> **Created**: 2026-03-28
> **Companion**: [PRD.md](../../../skills/engineering/code-review-battery/PRD.md), [DESIGN.md](../../../skills/engineering/code-review-battery/DESIGN.md)
> **Research Basis**: Perplexity deep research survey (2026-03-28) — 45 sources covering CodeRabbit, Qodo, Sourcegraph/Cody, Amazon CodeGuru, Semgrep, Greptile v3, Meta TestGen-LLM, Google DIDACT, Cycode, Veracode

## Problem Statement

Phase 2 shipped a 6-reviewer battery with gap analysis and Shadow Lane learning. Benchmark data (V4-V8) shows:
- Battery precision: **63%** (37% of findings are wrong)
- Monolith precision: **46%** (54% of findings are wrong)
- Cross-file bugs spanning 3+ files: **missed consistently** by specialists
- Reviewers explore blindly — they get a diff command and decide what to read
- No deterministic verification — LLM confidence gates are self-reported
- Investigation is ad-hoc — no structured protocol for digging deeper

Industry state-of-the-art (CodeRabbit, Qodo, Sourcegraph/Cody) achieves **<10% FPR** by layering deterministic program analysis under LLM review and pre-building structured context. We need to close this gap.

## Architecture Overview

Phase 3 adds two new pipeline stages and enhances four existing ones:

```
Diff arrives
    │
    ▼
Phase 1: Triage (unchanged)
    │
    ▼
Phase 1.5: Context Expansion ──────────────────── NEW
    │  Extract changed symbols from diff
    │  Build call graph (callers, callees, types)
    │  Find related test files
    │  Get git blame summary (monolith only)
    │  Get PR description / commit messages
    │  Run tests for changed files (if available)
    │  Output: structured context package
    │
    ▼
Phase 2: Dispatch ──────────────────────────────── ENHANCED
    │  5-part contract (+ context package)
    │  Investigation Protocol in monolith/defect-finder/guardian
    │  Expanded dimensions (reliability, layering, test adequacy)
    │
    ▼
Phase 3: Collect reviewer output (unchanged)
    │
    ▼
Phase 3.5: Deterministic Verification ─────────── NEW
    │  For each finding: verify file exists, line valid,
    │  symbol exists, claims true
    │  Tag: [VERIFIED] or [UNVERIFIED]
    │
    ▼
Phase 4: Aggregate ────────────────────────────── ENHANCED
    │  Verified findings first
    │  Unverified in appendix (not suppressed)
    │
    ▼
Phase 5: Gap Analysis ─────────────────────────── ENHANCED
    │  Semgrep YAML as primary rule format
    │  Shell grep as fallback
    │
    ▼
Phase 6: Dashboard Update (unchanged)
```

## Enhancement 1: Context Expansion Engine (Phase 1.5)

### Research Basis

| Source | Technique | Evidence |
|--------|-----------|----------|
| CodeRabbit | Enriches with repo rules, linked repos, MCP tools, related PR/issue context | [docs.coderabbit.ai] |
| Qodo | Context Engine indexes and maps codebases, understands cross-file/service/version relationships | [docs.qodo.ai] |
| Sourcegraph/Cody | SCIP-powered cross-repository symbol resolution + remote repo awareness | [sourcegraph.com/blog] |
| Ranking | cross-file dataflow/taint > call-graph expansion > type/contract propagation > pure RAG > diff-only | Multiple sources converge |

### Current Gap

Reviewers get `{repo_path} + {diff_command} + {prompt} + "read full source files"`. They independently decide what to explore. Result: they often miss callers 3+ levels deep, don't check tests for changed code, and don't know about related type definitions. Each reviewer wastes tokens on redundant exploration.

### Mechanism

The coordinator runs Phase 1.5 between triage and dispatch. It builds a **context package** — a structured document that every reviewer receives alongside the diff.

#### Step 1: Extract Changed Symbols

Parse the diff to identify changed symbols:


```bash
# From git diff output, extract function/class/export definitions on changed lines:
git diff <scope> | grep '^+' | grep -E '(function |class |export |def |const |interface |type )' \
  | sed 's/^+//' | head -50
```

This gives a list like: `parseConfig`, `UserService`, `IConfigOptions`.

#### Step 2: Build Call Graph (1-level expansion)

For each changed symbol:

```bash
# Find all callers across the repo:
grep -rn '<symbol>' <repo> --include='*.{ts,js,py,sh,go,jsx,tsx}' | grep -v 'node_modules\|dist\|build'

# Find the symbol's type/interface definition (if it's a function parameter or return):
grep -rn 'interface.*<TypeName>\|type.*<TypeName>' <repo> --include='*.{ts,d.ts}'
```

For each caller found: extract the enclosing function signature (so reviewers know the calling context without reading the entire file).

#### Step 3: Find Related Test Files

```bash
# For each changed file, find its test file:
find <repo> \( -name '*test*' -o -name '*spec*' \) -type f | xargs grep -l '<changed-file-basename>' 2>/dev/null
```

#### Step 4: Git Blame Summary (monolith context only)

```bash
# Last 5 changes to each modified file:
git log --oneline -5 -- <changed-file>
```

Tells the monolith *why* the code was last changed — enables intent-sensitive review.

#### Step 5: PR Description / Commit Messages

```bash
# Extract intent from commit messages:
git log --format='%s%n%b' @{u}..HEAD 2>/dev/null | head -30
```

#### Step 6: Test Status (if available)

```bash
# Run tests for changed files (platform-dependent):
# Node: npm test -- --testPathPattern='<test-files>' 2>&1 | tail -20
# Python: pytest <test-files> 2>&1 | tail -20
# Shell: bats <test-files> 2>&1 | tail -20
```

Include pass/fail summary. If tests fail, include failure output — reviewers can check if their findings explain the failure.

### Context Package Format

```markdown
## Context Package

### Changed Symbols
- `parseConfig()` in src/config.ts:42 (modified)
  - Callers: src/app.ts:15 (in `initApp()`), src/cli.ts:88 (in `main()`), lib/init.ts:22 (in `bootstrap()`)
  - Tests: test/config.test.ts (3 test cases reference parseConfig)
  - Types: src/types.ts:31 (ConfigOptions interface)

- `UserService` class in src/services/user.ts (new method `deactivate()` added)
  - Callers: src/routes/auth.ts:44 (in `handleLogout()`), src/routes/profile.ts:12 (in `deleteAccount()`)
  - Tests: test/services/user.test.ts (no tests for deactivate — COVERAGE GAP)
  - Interfaces: src/interfaces/IUserService.ts (deactivate not in interface — CONTRACT GAP)

### Test Status
- test/config.test.ts: PASS (3/3)
- test/services/user.test.ts: PASS (12/12) — but no test for new `deactivate()` method

### Recent Changes (monolith only)
- src/config.ts: "fix: handle nested YAML maps" (3 days ago), "feat: add env override" (1 week ago)
- src/services/user.ts: "feat: add user roles" (2 weeks ago)

### Commit Intent
- "Add account deactivation flow with soft-delete and audit logging"
```

### Dispatch Contract Update

The 4-part reviewer instruction contract becomes **5-part**:

| # | Element | Source |
|---|---------|--------|
| 1 | Repo path | Coordinator |
| 2 | Exact diff command | Coordinator |
| 3 | Reviewer prompt | `reviewers/<name>.md` |
| 4 | Instruction to read full source files | Reviewer prompt |
| 5 | **Context package** | **Phase 1.5 output (NEW)** |

### Token Budget

Context expansion adds ~300-800 tokens to each reviewer instruction (the package is compact — symbol names + file:line references, not full file contents). This is offset by reduced blind exploration. Net cost: **roughly neutral**.

### Skip Conditions

- If the diff changes only 1 file with <20 LOC: skip context expansion (not enough complexity to justify the overhead). Reviewers can still explore manually.
- If no symbols are extracted (pure config/docs change): skip.

---

## Enhancement 2: Deterministic Verification Filter (Phase 3.5)

### Research Basis

| Source | Technique | Evidence |
|--------|-----------|----------|
| Cycode | Deterministic security analysis + sanitizer recognition | 2.1% FPR |
| Veracode | Deterministic static analysis | <1.1% FPR |
| arXiv 2601.18844 | LLM-assisted path-feasibility reasoning | Reduces FPs in static bug detection |
| Our V4-V8 benchmarks | Monolith phantom file refs, severity overrating, hallucinated API behavior | Battery 63% precision, monolith 46% |

### Current Gap

The 80% confidence gate is self-reported by the LLM. Our benchmarks prove this is insufficient — 37% of battery findings and 54% of monolith findings are wrong. The most common FP patterns are:

1. **Phantom file references** — reviewer claims a file exists that doesn't (monolith V6: 5/7 findings referenced non-existent files)
2. **Severity overrating** — Critical label on Minor issues (monolith V4: 3/4 "Critical" findings were Minor)
3. **Hallucinated API behavior** — reviewer claims a function does X when it actually does Y
4. **Non-existent symbol claims** — "function X is never called" when it's called in 5 places

### Mechanism

Phase 3.5 runs after all reviewers return and before aggregation. The coordinator runs deterministic checks on each finding:

#### Check 1: File Existence
```bash
test -f "<referenced_file>"
```
If the finding references `src/auth/validator.ts` and that file doesn't exist → mark `[UNVERIFIED: file not found]`.

#### Check 2: Line Validity
```bash
wc -l < "<referenced_file>"
# Compare against referenced line number
```
If finding references `config.ts:542` but the file has 200 lines → mark `[UNVERIFIED: line out of range]`.

#### Check 3: Symbol Existence
```bash
grep -n '<claimed_symbol>' "<referenced_file>"
```
If finding says "the `validateToken()` function at line 42 is missing error handling" but no such function exists at that line → mark `[UNVERIFIED: symbol not found at location]`.

#### Check 4: Claim Verification (incremental — start with Checks 1-3 only)
```bash
# "Function X is never called":
grep -rn '<function_name>' <repo> --include='*.{ts,js,py,sh}' | grep -v '<definition_file>'

# "Variable X is unused":
grep -rn '<variable_name>' <repo> --include='*.{ts,js,py,sh}' | wc -l
```

#### Verification Output

Each finding gets one of:
- `[VERIFIED]` — all referenced files, lines, and symbols confirmed to exist
- `[UNVERIFIED: <reason>]` — at least one verification check failed

**Unverified findings are NOT dropped.** They move to an appendix in the aggregated report. The reviewer may have the right insight with wrong evidence — the user decides.

### Expected Impact

Based on our benchmark data:
- **Phantom file references** (V6 monolith): 5 findings would be caught → precision from 35% to 100% for that diff
- **Overall battery precision**: estimated 63% → 85%+
- **Overall monolith precision**: estimated 46% → 70%+

### Performance Cost

Each verification check is a single shell command: <100ms each. Total Phase 3.5 time for a typical review (10-15 findings): **<2 seconds**.

---

## Enhancement 3: Investigation Protocol (Reviewer Prompt Enhancement)

### Research Basis

| Source | Technique | Evidence |
|--------|-----------|----------|
| Greptile v3 | Detective-style loop with codebase search and repeated inference | "agentic approach to code review" |
| Meta TestGen-LLM | Generation + validation filters | Tests must pass filters for measurable improvement |
| Google DIDACT | Model-assisted edits in real workflows | Groups related files for multi-file changes |

### Current Gap

Each reviewer makes one pass. The prompts say "grep -rn to find callers" but there's no structured investigation protocol. When a reviewer spots something suspicious, it either reports immediately (risking FPs) or ignores it (missing real bugs).

### Mechanism

Add an **Investigation Protocol** section to three reviewer prompts:

```markdown
## Investigation Protocol

When you encounter a suspicious pattern, DO NOT report immediately. Investigate first:

### Step 1: Gather Evidence
Search for related code that confirms or denies the issue.
- `grep -rn '<pattern>' <relevant-dirs>` — find all instances
- `cat <caller-file>` — read the calling code to understand intent
- Execute code snippets to verify behavior if possible

### Step 2: Test the Negative
Actively try to DISPROVE the issue before reporting it.
- Is there a guard clause you missed? Read the full function.
- Does the caller handle this error case? Read the caller.
- Is there a test that covers this path? Check the test file.
- Does the type system prevent this? Check type definitions.

### Step 3: Classify Scope
If the issue is real:
- **Systemic** (pattern in 3+ places): Report as architectural finding with ALL instances
- **Isolated** (1-2 places): Report as localized finding

### Step 4: Report with Evidence
Only report when you have:
- Specific file:line reference (verified to exist)
- Concrete description of what breaks
- Proof that no existing code handles it
- Evidence from your investigation (what you searched, what you found)
```

### Which Reviewers Get This

| Reviewer | Gets Protocol? | Rationale |
|----------|---------------|-----------|
| Monolith | ✅ | Cross-file tracing is its primary advantage |
| Defect Finder | ✅ | Edge cases require tracing data flow through callers |
| Guardian | ✅ | Blast radius requires checking downstream consumers |
| Design Critic | ❌ | Design issues visible in structure, not runtime |
| Standards Enforcer | ❌ | Conformance checkable from diff + conventions |
| Performance Analyst | ❌ | Performance analyzable from code patterns |

---

## Enhancement 4: Enhanced Dimension Coverage

### Research Basis

The research identifies 8 key review dimensions. We cover 5 well, have gaps in 3:

| Dimension | Status | Enhancement |
|-----------|--------|-------------|
| Correctness | ✅ Covered | — |
| Design/Architecture | ⚠️ Missing layering | Add Architectural Layering to Design Critic |
| Security | ✅ Covered | — |
| Standards | ⚠️ Weak on test adequacy | Strengthen Test Quality in Standards Enforcer |
| Performance | ✅ Covered | — |
| **Reliability/Resilience** | ❌ Missing | Add to Guardian |
| **Architectural Layering** | ❌ Missing | Add to Design Critic |
| **Test Adequacy** | ⚠️ Weak | Expand in Standards Enforcer |

### Changes

**Guardian** — add sub-dimension `5. Reliability & Resilience`:
- Missing retry logic for transient failures (network calls, DB connections, file I/O)
- Missing or inadequate timeout handling for external calls
- Missing circuit breaker or fallback for degraded dependencies
- No graceful degradation path (what happens when dependency X is unavailable?)
- Missing idempotency for operations that may be retried automatically
- Crash-on-failure where recovery is possible and expected

**Design Critic** — add sub-dimension `5. Architectural Layering`:
- Layer violations (UI code importing data layer directly, skipping service layer)
- Wrong dependency direction (lower layers depending on higher layers)
- Circular dependencies between modules/packages
- God packages/modules that everything depends on (coupling hub)
- Missing interface boundaries between architectural layers

**Standards Enforcer** — rename sub-dimension 4 from "Test Quality" to "Test Quality & Adequacy":
- Add: New code paths in the diff without corresponding test cases (COVERAGE GAP)
- Add: Changed behavior without updated regression tests
- Add: Test coverage gaps for error/edge-case paths added in the diff
- Add: Missing integration tests for new cross-component interactions

**Dimension count**: 16 → 19 (Guardian +1, Design Critic +1, Standards Enforcer expanded)

---

## Enhancement 5: Structured Rule Generation (Semgrep-First)

### Research Basis

| Source | Technique | Evidence |
|--------|-----------|----------|
| Semgrep | Cross-file taint traces, AST-aware pattern matching | Standard format for deterministic rules |
| CodeQL | Interprocedural analysis, query-based detection | Structured rule output |
| Research consensus | "LLM creativity for discovery + deterministic enforcement for durability" | Multiple sources converge |

### Current Gap

Our "script-learnable" path generates shell scripts (`grep -rn '__proto__'`). Problems:
- No AST awareness — matches string patterns in comments and strings
- No cross-file taint tracking
- No standard format — each script is bespoke
- No precision metrics built into the format

### Mechanism

Phase 5 generates **Semgrep YAML rules** as primary format. Shell grep as fallback.

#### Primary: Semgrep YAML

```yaml
# checks/candidates/prototype-pollution.semgrep.yml
rules:
  - id: prototype-pollution-via-proto-key
    patterns:
      - pattern: $OBJ["__proto__"]
    message: >
      Prototype pollution: direct __proto__ access on potentially user-controlled object.
    severity: ERROR
    languages: [javascript, typescript]
    metadata:
      source: gap-analysis
      gap_date: "2026-03-28"
      specialist_missed: guardian
      ttl_days: 14
      confidence: 0.85
```

#### Fallback: Shell Script

```bash
#!/usr/bin/env bash
# checks/candidates/prototype-pollution.sh
# Source: gap-analysis 2026-03-28 | TTL: 14 days | Confidence: 0.85
set -euo pipefail
grep -rn '__proto__\|constructor\[' "$@" || true
```

#### File Structure Update

```
checks/
├── candidates/
│   ├── *.semgrep.yml     # Semgrep rules (preferred)
│   └── *.sh              # Shell scripts (fallback)
├── *.semgrep.yml          # Graduated Semgrep rules (active)
└── *.sh                   # Graduated shell scripts (active)
```

---

## Token Budget Constraint

Research shows prompt effectiveness peaks at 800–2,000 tokens and degrades past ~2,000 for coding tasks. Every file loaded as a prompt must stay under **1,500 tokens** (~500 lines of concise markdown). Reference docs (DESIGN.md, PRD.md) are exempt — they're not loaded into LLM context.

### Current Problem

`coordinator.md` is already **2,916 tokens** — over the 2K ceiling. Phase 3 additions would push it to ~4,400. `skill.md` at 1,564 tokens is borderline.

### Solution: On-Demand Phase Loading

Split the monolithic coordinator into purpose-specific files loaded only when their phase runs:

```
skills/engineering/code-review-battery/
├── skill.md                    # Entry point + step sequence          ≤1,200 tok
├── coordinator.md              # Phases 1-4: triage/dispatch/agg     ≤1,500 tok
├── context-expansion.md        # Phase 1.5: symbol graph + context   ≤800 tok   NEW
├── verification.md             # Phase 3.5: deterministic checks     ≤600 tok   NEW
├── gap-analysis.md             # Phases 5-6: gaps + dashboard        ≤1,200 tok EXTRACTED
├── DESIGN.md                   # Reference (not a prompt)            exempt
├── PRD.md                      # Reference (not a prompt)            exempt
├── reviewers/
│   ├── defect-finder.md        # + Investigation Protocol            ≤800 tok
│   ├── design-critic.md        # + Architectural Layering            ≤800 tok
│   ├── guardian.md             # + Investigation + Reliability       ≤850 tok
│   ├── standards-enforcer.md   # + Test Adequacy                     ≤800 tok
│   ├── performance-analyst.md  # unchanged                           ~640 tok
│   └── monolith.md             # + Investigation + blame context     ≤850 tok
├── checks/
│   └── candidates/
└── (pattern files created lazily)
```

### Loading Sequence

`skill.md` directs which files to load at each step:

| Step | File Loaded | When | Tokens |
|------|------------|------|--------|
| 1 (Triage) | `coordinator.md` | Every review | ~1,500 |
| 1.5 (Context) | `context-expansion.md` | When diff has ≥2 files or ≥20 LOC | ~800 |
| 2 (Dispatch) | `coordinator.md` (already loaded) | Every review | 0 (cached) |
| 3 (Collect) | — | Every review | 0 |
| 3.5 (Verify) | `verification.md` | Every review | ~600 |
| 4 (Aggregate) | `coordinator.md` (already loaded) | Every review | 0 (cached) |
| 5 (Gaps) | `gap-analysis.md` | Full reviews only | ~1,200 |
| 6 (Dashboard) | `gap-analysis.md` (already loaded) | Full reviews only | 0 (cached) |

**Targeted re-reviews** (PASS_WITH_NITS): load only `coordinator.md` (~1,500 tokens total).
**Full reviews**: load coordinator + context + verification + gap = ~4,100 tokens total, but spread across sequential phases — no single prompt exceeds 1,500.

### What Moves Where

**Out of `skill.md`** (to hit ≤1,200):
- Shadow Lane learning details → `gap-analysis.md`
- Detailed override descriptions → `coordinator.md`
- Keep: triggers, when-to-use, 6-reviewer table, step sequence, file loading instructions

**Out of `coordinator.md`** (to hit ≤1,500):
- Phase 5 (Gap Analysis) → `gap-analysis.md`
- Phase 6 (Dashboard Update) → `gap-analysis.md`
- Gap classification examples → `gap-analysis.md`
- Dashboard location, safe write protocol → `gap-analysis.md`
- Keep: Phase 1 (triage), Phase 2 (dispatch contract), Phase 3 (aggregation), Phase 4 (targeted re-review)

---

## Summary of All File Changes

| File | Enhancement | Change | Token Budget |
|------|-------------|--------|-------------|
| `skill.md` | 1, 2 | Trimmed, add step sequence with file loading refs | ≤1,200 |
| `coordinator.md` | 1, 2 | Extract Phases 5-6, add 5-part contract, Phase 3.5 ref | ≤1,500 |
| `context-expansion.md` | 1, 6 | NEW — Phase 1.5 context package building | ≤800 |
| `verification.md` | 2 | NEW — Phase 3.5 deterministic verification | ≤600 |
| `gap-analysis.md` | 5 | NEW (extracted) — Phases 5-6 + Semgrep rules | ≤1,200 |
| `DESIGN.md` | 1, 2, 4, 5 | Architecture diagram, file structure, dimensions | exempt |
| `PRD.md` | 4 | Phase 3 scope, dimension matrix, ACs | exempt |
| `reviewers/monolith.md` | 3 | Investigation Protocol, blame context | ≤850 |
| `reviewers/defect-finder.md` | 3 | Investigation Protocol | ≤800 |
| `reviewers/guardian.md` | 3, 4 | Investigation Protocol, Reliability sub-dimension | ≤850 |
| `reviewers/design-critic.md` | 4 | Architectural Layering sub-dimension | ≤800 |
| `reviewers/standards-enforcer.md` | 4 | Test Quality → Test Quality & Adequacy | ≤800 |
| `reviewers/performance-analyst.md` | — | No changes | ~640 |

## Expected Impact

| Metric | Phase 2 (current) | Phase 3 (projected) | Basis |
|--------|-------------------|---------------------|-------|
| Battery precision | 63% | 85%+ | Verification filter eliminates phantom refs (E2) |
| Monolith precision | 46% | 70%+ | Verification filter + investigation protocol (E2+E3) |
| Cross-file bug detection | Low | Significantly higher | Context package provides call graph (E1) |
| FPR (false positive rate) | ~37% | <15% | Deterministic verification + investigation discipline (E2+E3) |
| Dimension coverage | 16 dimensions | 19 dimensions | Guardian +1, Design Critic +1, Standards expanded (E4) |
| Learned rule quality | Shell grep only | Semgrep YAML (AST-aware) + shell fallback (E5) | — |

## Open Design Decisions

1. **Context expansion timeout**: How long to wait for grep/test commands? Proposed: 30s hard timeout, skip any step exceeding 10s.
2. **Verification depth**: Start with Checks 1-3 only (file/line/symbol), add claim verification (Check 4) incrementally after measuring false-negative rate.
3. **Semgrep availability**: Optional dependency — generate both formats, use Semgrep when available.
4. **Investigation round limit**: Soft cap at 5 searches per finding, hard cap at 3 minutes per reviewer total investigation time.

## Acceptance Criteria (Phase 3)

| # | Criteria | Type |
|---|----------|------|
| AC27 | Context expansion extracts changed symbols and builds call graph on ≥3 real diffs | Must Pass |
| AC28 | Context package adds <1000 tokens per reviewer instruction on average | Must Pass |
| AC29 | Verification filter catches phantom file references (test against V6 benchmark) | Must Pass |
| AC30 | Verification filter catches out-of-range line numbers | Must Pass |
| AC31 | Battery precision ≥80% on benchmark diffs (up from 63%) | Must Pass |
| AC32 | Investigation Protocol produces evidence-backed findings on ≥3 real diffs | Must Pass |
| AC33 | Enhanced dimensions (reliability, layering, test adequacy) fire on relevant diffs | Should Pass |
| AC34 | Semgrep YAML rules generated from gap analysis on ≥1 real gap | Should Pass |
| AC35 | Total review time (with context expansion + verification) ≤ 2x monolithic | Must Pass |
| AC36 | Every prompt-loaded file ≤1,500 tokens (measured via `wc -w * 4/3`) | Must Pass |
| AC37 | No single review step loads >1,500 tokens of skill/coordinator content | Must Pass |