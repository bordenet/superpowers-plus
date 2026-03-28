# Code Review Battery — Phase 2f: Deep Review

> **Status**: Design (pending approval)
> **Author**: Matt Bordenet + AI
> **Created**: 2026-03-28
> **Companion**: [PRD.md](../../../skills/engineering/code-review-battery/PRD.md), [DESIGN.md](../../../skills/engineering/code-review-battery/DESIGN.md)
> **Research Basis**: Perplexity deep research survey (2026-03-28) — 45 sources covering CodeRabbit, Qodo, Sourcegraph/Cody, Amazon CodeGuru, Semgrep, Greptile v3, Meta TestGen-LLM, Google DIDACT, Cycode, Veracode
> **Note**: Phase 3 is reserved for debugging parallelization (see PRD.md). This work is Phase 2f.

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

Phase 2f adds two new pipeline stages and enhances four existing ones:

**Naming note**: "Pipeline phases" (1, 1.5, 2, etc.) are coordinator execution steps — distinct from PRD roadmap phases (Phase 1, Phase 2, Phase 2f, Phase 3). The pipeline phase numbers are internal to the coordinator and do not change; they match the existing coordinator.md naming.

```
Diff arrives
    │
    ▼
Pipeline Step 1: Triage (unchanged)
    │
    ▼
Pipeline Step 1.5: Context Expansion ──────────── NEW
    │  Extract changed symbols from diff
    │  Find related code (callers, types via grep)
    │  Find related test files
    │  Get recent file history (monolith only)
    │  Get commit messages / PR description
    │  Run tests for changed files (opt-in only)
    │  Output: structured context package
    │
    ▼
Pipeline Step 2: Dispatch ─────────────────────── ENHANCED
    │  5-part contract (+ context package)
    │  Investigation Protocol in monolith/defect-finder/guardian
    │  Expanded dimensions (reliability, layering, test adequacy)
    │
    ▼
Pipeline Step 3: Collect reviewer output (unchanged)
    │
    ▼
Pipeline Step 3.5: Deterministic Verification ─── NEW
    │  Parse structured finding schema
    │  For each finding: verify file exists, line valid,
    │  symbol exists in file
    │  Tag: [VERIFIED], [UNVERIFIED], or [UNSTRUCTURED]
    │
    ▼
Pipeline Step 4: Aggregate ────────────────────── ENHANCED
    │  Verified findings first
    │  Unverified + unstructured in appendix
    │
    ▼
Pipeline Step 5: Gap Analysis ─────────────────── ENHANCED
    │  Semgrep YAML as primary rule format
    │  Shell grep as fallback
    │
    ▼
Pipeline Step 6: Dashboard Update (unchanged)
```

## Enhancement 1: Context Expansion Engine (Pipeline Step 1.5)

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

#### Step 2: Find Related Code (1-level grep expansion)

> **Note**: This is text-based symbol search, not a true call graph. It catches direct references but misses multi-line definitions, method receivers, and matches in comments/strings. The term "call graph" is used loosely — this is cheap related-code discovery, not interprocedural analysis.

For each changed symbol:

```bash
# Find all references to the symbol across the repo:
grep -rn '<symbol>' <repo> --include='*.ts' --include='*.js' --include='*.py' --include='*.sh' --include='*.go' --include='*.jsx' --include='*.tsx' | grep -v 'node_modules\|dist\|build'

# Find the symbol's type/interface definition (if it's a function parameter or return):
grep -rn 'interface.*<TypeName>\|type.*<TypeName>' <repo> --include='*.ts' --include='*.d.ts'
```

For each caller found: extract the enclosing function signature (so reviewers know the calling context without reading the entire file).

#### Step 3: Find Related Test Files

```bash
# For each changed file, find its test file:
find <repo> \( -name '*test*' -o -name '*spec*' \) -type f | xargs grep -l '<changed-file-basename>' 2>/dev/null
```

#### Step 4: Recent File History (monolith context only)

```bash
# Last 5 commits touching each modified file:
git log --oneline -5 -- <changed-file>
```

Tells the monolith what recent changes affected each file — enables intent-sensitive review. This is `git log` (commit history), not `git blame` (line-level attribution).

#### Step 5: Commit Messages / PR Description

Extract intent from commit messages. The log range MUST match the review scope (same as the diff command):

```bash
# Match to review scope:
# If diff is: git diff --cached        → no commit messages yet (staged but uncommitted); skip this step
# If diff is: git diff @{u}..HEAD      → git log --format='%s%n%b' @{u}..HEAD | head -30
# If diff is: git diff main..HEAD      → git log --format='%s%n%b' main..HEAD | head -30
# If diff is: git diff HEAD~1          → git log --format='%s%n%b' -1 HEAD | head -30
```

#### Step 6: Test Status (OPTIONAL — skip by default)

Test execution during context expansion is **opt-in only** (`--run-tests` flag) due to latency, flakiness, and environment dependency risks.

**When skipped** (default): the context package reports "Test status: not run" and reviewers can choose to run tests themselves.

**When enabled** (`--run-tests`):
```bash
# Per-command timeout: 15s per test command. Kill if exceeded.
timeout 15 <test-command> 2>&1 | tail -20
```

Safeguards:
- 15-second hard timeout per test command; skip and note "timed out" if exceeded
- Only run tests that match changed files (not the full test suite)
- Test runner detection: look for `package.json` (npm/jest), `pytest.ini`/`setup.cfg` (pytest), `test/` dir with `.bats` files. If no runner detected, skip.
- Do NOT run tests that require env vars, secrets, databases, or network services — if `test-command` fails immediately with a non-test error, skip and note "test setup failed"
- Reviewers may still run tests independently via workspace access — this step is convenience, not mandatory

### Context Package Format

The context package reports **grep results and command output** — labeled as what the commands found, not what the results mean. Reviewers draw their own semantic conclusions. This preserves reviewer independence and avoids biasing all 6 reviewers with a single analysis.

```markdown
## Context Package

### Changed Symbols
- `parseConfig()` in src/config.ts:42 (modified)
  - Grep hits: src/app.ts:15, src/cli.ts:88, lib/init.ts:22 (3 files reference "parseConfig")
  - Test file hits: test/config.test.ts (3 grep hits for "parseConfig")
  - Type/interface hits: src/types.ts:31 (grep hit for "ConfigOptions")

- `UserService` class in src/services/user.ts (new method `deactivate()` added)
  - Grep hits: src/routes/auth.ts:44, src/routes/profile.ts:12 (2 files reference "UserService")
  - Test file hits: test/services/user.test.ts (0 grep hits for "deactivate")
  - Type/interface hits: src/interfaces/IUserService.ts (0 grep hits for "deactivate")

### Test Status (if tests were run — requires --run-tests)
- test/config.test.ts: PASS (3/3)
- test/services/user.test.ts: PASS (12/12)

### Recent History (monolith only)
- src/config.ts: "fix: handle nested YAML maps" (3d), "feat: add env override" (1w)
- src/services/user.ts: "feat: add user roles" (2w)

### Commit Messages
- "Add account deactivation flow with soft-delete and audit logging"
```

Note: the package reports grep hit counts and locations. It does NOT label results as "callers," "COVERAGE GAP," or "CONTRACT GAP." Whether a grep hit represents a caller, a comment, or a string literal is for the reviewer to determine.

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

### Prerequisite: Structured Finding Schema

Deterministic verification requires machine-parseable findings. The current reviewer output format uses prose (`**File:Line**: location`). Phase 2f updates the output format in all 6 reviewer prompts to require a structured block per finding:

```
### Finding F1
- **file**: src/auth/validator.ts
- **line**: 42 (or "N/A" for findings without a single location)
- **symbol**: validateToken (or "N/A" for non-symbol findings like doc drift)
- **severity**: Critical
- **confidence**: High (>80%) or Possible (60-80%)
- **scope**: isolated | systemic
- **issue**: Missing null check on token parameter
- **why**: Crashes with TypeError when token is undefined
- **fix**: Add `if (!token) return null;` guard
- **evidence**: Searched callers with `grep -rn 'validateToken'` — found 3
  callers, none check for null before passing token. (optional — required
  when Investigation Protocol is used)
- **cross-cutting**: yes | no (monolith only — replaces existing Cross-cutting? field)
- **instances**: (only when scope=systemic — list all locations)
  - src/auth/validator.ts:42
  - src/auth/refresh.ts:18
  - src/api/middleware.ts:91
```

#### Schema Rules

| Field | Required | Verifiable | Notes |
|-------|----------|-----------|-------|
| `file` | Yes | Check 1 (file exists) | "N/A" for findings without a file (e.g., missing tests entirely) |
| `line` | Yes | Check 2 (line in range) | "N/A" for file-level or architectural findings |
| `symbol` | No | Check 3 (symbol in file) | Omit for non-symbol findings |
| `severity` | Yes | No | Critical / Important / Minor |
| `confidence` | Yes | No | High (>80%) / Possible (60-80%) |
| `scope` | Yes | No | "isolated" or "systemic" |
| `issue` | Yes | No | Free text, may be multiline |
| `why` | Yes | No | Free text, may be multiline |
| `fix` | No | No | Free text, may be multiline |
| `evidence` | Conditional | No | Required when Investigation Protocol is active |
| `cross-cutting` | Monolith only | No | Replaces current `Cross-cutting?` field |
| `instances` | Conditional | No | Required when scope=systemic; list all locations |

#### Parsing Rules

The coordinator parses structured fields via line-prefix matching (`- **file**:`, `- **line**:`, etc.):
- Each finding starts with `### Finding F<n>` (heading signals boundary)
- Single-line fields: everything after `: ` on the same line
- Multiline fields (`issue`, `why`, `fix`, `evidence`): all lines until the next `- **` prefix or next `### Finding` heading
- `instances` block: indented `- file:line` entries until next field or heading
- If a finding block cannot be parsed (no `### Finding` heading, missing required fields), tag it `[UNSTRUCTURED]` and skip verification

### Mechanism

Phase 3.5 runs after all reviewers return and before aggregation. The coordinator parses each finding's structured fields and runs deterministic checks:

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

#### Check 3: Symbol Existence in File
```bash
grep -n '<claimed_symbol>' "<referenced_file>"
```
This checks if the symbol appears **anywhere in the file** (not at the specific line — line-level verification would require AST parsing, which is out of scope). If `grep` finds zero hits for the symbol in the file → mark `[UNVERIFIED: symbol not found in file]`. If the symbol exists in the file but not near the claimed line, the finding is still tagged `[VERIFIED]` — the reviewer may have the right function but wrong line number.

#### Check 4: Claim Verification (incremental — start with Checks 1-3 only)
```bash
# "Function X is never called":
grep -rn '<function_name>' <repo> --include='*.ts' --include='*.js' --include='*.py' --include='*.sh' | grep -v '<definition_file>'

# "Variable X is unused":
grep -rn '<variable_name>' <repo> --include='*.ts' --include='*.js' --include='*.py' --include='*.sh' | wc -l
```

#### Verification Output

Each finding gets one of:
- `[VERIFIED]` — all referenced files, lines, and symbols confirmed to exist; claims checked where possible
- `[UNVERIFIED: <reason>]` — at least one verification check failed (file missing, line out of range, symbol not in file, or claim disproved)
- `[UNSTRUCTURED]` — reviewer output did not follow the structured finding schema; verification could not be performed

**Unverified and unstructured findings are NOT dropped.** They move to an appendix in the aggregated report. The reviewer may have the right insight with wrong evidence — the user decides.

### Expected Impact

Based on our benchmark data:
- **Phantom file references** (V6 monolith): 5 findings would be caught → precision from 35% to 100% for that specific diff
- **Overall battery precision**: Checks 1-3 eliminate phantom refs and out-of-range lines. Actual impact depends on what fraction of current FPs fall in these categories. V6 data suggests ~60% of monolith FPs are phantom refs; battery FPs are more often wrong reasoning with correct file references, so improvement will be smaller.
- **Overall monolith precision**: Higher improvement expected since monolith FPs are dominated by phantom refs and non-existent symbol claims.

**Honest projection**: Checks 1-3 alone will not achieve 85%+ precision. Severity inflation and wrong causal reasoning (the other major FP categories) are NOT addressed by file/line/symbol verification. Achieving 85%+ requires Check 4 (claim verification) AND the Investigation Protocol (E3) to mature over multiple review cycles.

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

The research identifies 8 key review dimensions. We cover 5 well across 19 sub-dimensions (Defect Finder 4, Design Critic 4, Guardian 4, Standards Enforcer 5, Performance Analyst 2). Three areas need expansion:

| Dimension | Current Status | Enhancement |
|-----------|---------------|-------------|
| Correctness (4 sub-dims) | ✅ Covered | — |
| Design/Architecture (4 sub-dims) | ⚠️ Missing layering | Add Architectural Layering sub-dimension to Design Critic |
| Security (4 sub-dims) | ✅ Covered | — |
| Standards (5 sub-dims) | ⚠️ Test Quality needs test-adequacy items | Expand sub-dimension 4 with coverage gap checks |
| Performance (2 sub-dims) | ✅ Covered | — |
| **Reliability/Resilience** | ❌ Not covered | Add as Guardian sub-dimension 5 |
| **Architectural Layering** | ❌ Not covered | Add as Design Critic sub-dimension 5 |
| **Test Adequacy** | ⚠️ Present but shallow | Expand Standards Enforcer sub-dimension 4 |

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

**Dimension count**: 19 → 21 (Guardian +1 new sub-dimension, Design Critic +1 new sub-dimension). Standards Enforcer sub-dimension 4 is expanded with additional check items but remains 1 sub-dimension.

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

#### Validation and Execution

Generated rules must be validated before candidate staging:

1. **Syntax validation**: `semgrep --validate --config <rule>.semgrep.yml` (if Semgrep installed). No fallback YAML validation — if Semgrep is unavailable, the LLM generates a shell script instead (not a Semgrep rule).
2. **Dry run on changed files** (if Semgrep available): `semgrep --config <rule>.semgrep.yml <changed-files> --json` — verify it runs without error
3. **If validation fails**: fall back to shell script format for that gap

**Semgrep availability**: Semgrep is treated as an optional dependency. If not installed, all script-learnable gaps generate shell scripts. The graduation pipeline (future) will validate rules against a holdout corpus — that pipeline must also handle both formats.

**Execution during reviews**: Graduated checks (both Semgrep and shell) run as part of the review process. The coordinator runs active checks against changed files and includes results in the context package. This is future work — Phase 2f only covers candidate generation and validation, not runtime execution of graduated checks.

---

## Token Budget Constraint

Research shows prompt effectiveness peaks at 800–2,000 tokens and degrades past ~2,000 for coding tasks. Every file loaded as a prompt must stay under **1,500 tokens** (~500 lines of concise markdown). Reference docs (DESIGN.md, PRD.md) are exempt — they're not loaded into LLM context.

### Current Problem

`coordinator.md` is already **2,916 tokens** — over the 2K ceiling. Phase 2f additions would push it to ~4,400. `skill.md` at 1,564 tokens is borderline.

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
│   └── monolith.md             # + Investigation + file history ctx  ≤850 tok
├── checks/
│   └── candidates/
└── (pattern files created lazily)
```

### Loading Sequence and Runtime Context

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

**Runtime context accumulation**: All loaded files accumulate in the coordinating agent's context window — splitting files does not reduce total runtime context. The benefits of splitting are:

1. **Conditional loading**: Targeted re-reviews skip context-expansion.md, verification.md, and gap-analysis.md entirely — loading only coordinator.md (~1,500 tokens vs ~4,100 for a full review)
2. **Signal density per-file**: Each file stays focused on its concern, avoiding attention dilution from unrelated instructions (research shows accuracy degrades when instructions exceed ~2,000 tokens per concern)
3. **Reviewer sub-agents**: Each reviewer sub-agent reads only its own prompt (~600-850 tok) — they never see coordinator logic

**Worst-case full review**: coordinator (~1,500) + context-expansion (~800) + verification (~600) + gap-analysis (~1,200) = ~4,100 tokens of skill content in the coordinating agent's context. This is above the 2K sweet spot but below the 5.5K degradation cliff for Claude models. The coordinating agent is also seeing diff output, reviewer findings, and user messages — total context will be larger.

**Mitigation**: The coordinating agent's instructions are purpose-structured (triage → dispatch → verify → aggregate → learn) — each phase operates on its own section, reducing effective noise. Each individual file stays under 1,500 tokens to maintain signal density within that concern.

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
| `coordinator.md` | 1, 2 | Extract Phases 5-6, add 5-part contract, structured output parsing in aggregation, Phase 3.5 ref | ≤1,500 |
| `context-expansion.md` | 1, 6 | NEW — Phase 1.5 context package building | ≤800 |
| `verification.md` | 2 | NEW — Phase 3.5 deterministic verification + structured finding schema | ≤600 |
| `gap-analysis.md` | 5 | NEW (extracted) — Phases 5-6 + Semgrep rules | ≤1,200 |
| `DESIGN.md` | 1, 2, 4, 5 | Architecture diagram, file structure, dimensions | exempt |
| `PRD.md` | 4 | Phase 2f scope, dimension matrix, ACs | exempt |
| `reviewers/monolith.md` | 2, 3 | Structured output format, Investigation Protocol, file history context | ≤850 |
| `reviewers/defect-finder.md` | 2, 3 | Structured output format, Investigation Protocol | ≤800 |
| `reviewers/guardian.md` | 2, 3, 4 | Structured output format, Investigation Protocol, Reliability sub-dimension | ≤850 |
| `reviewers/design-critic.md` | 2, 4 | Structured output format, Architectural Layering sub-dimension | ≤800 |
| `reviewers/standards-enforcer.md` | 2, 4 | Structured output format, Test Quality → Test Quality & Adequacy | ≤800 |
| `reviewers/performance-analyst.md` | 2 | Structured output format only | ≤700 |

### Reviewer Prompt Changes (All 6 Reviewers)

Every reviewer prompt requires these changes to support Phase 2f:

**All 6 reviewers**:
- Replace current `## Output Format` section with the structured finding schema (see Enhancement 2)
- Current format (`**Severity**: ... **File:Line**: ... **Issue**: ...`) → structured block (`### Finding F<n>` with `- **file**:`, `- **line**:`, `- **symbol**:`, `- **severity**:`, etc.)
- Add `- **confidence**: High / Possible` (replacing the prose "Possible: ..." prefix)
- Add `- **scope**: isolated / systemic` with `- **instances**:` list when systemic

**Monolith, Defect Finder, Guardian only**:
- Add Investigation Protocol section (see Enhancement 3)
- Add `- **evidence**:` as a required field in finding schema
- Replace monolith's `- **Cross-cutting?**: Yes/No` with `- **cross-cutting**: yes / no`

**Guardian only**:
- Add sub-dimension `5. Reliability & Resilience` (see Enhancement 4)

**Design Critic only**:
- Add sub-dimension `5. Architectural Layering` (see Enhancement 4)

**Standards Enforcer only**:
- Expand sub-dimension 4 from "Test Quality" to "Test Quality & Adequacy" with 4 new check items (see Enhancement 4)

## Expected Impact

| Metric | Phase 2 (current) | Phase 2f (projected) | Basis |
|--------|-------------------|---------------------|-------|
| Battery precision | 63% | 70-80% (projected) | Verification catches phantom refs; severity/reasoning FPs need E3 maturation |
| Monolith precision | 46% | 60-70% (projected) | Monolith FPs dominated by phantom refs — higher impact from verification |
| Cross-file bug detection | Low | Higher | Context package pre-discovers callers and related code (E1) |
| FPR (false positive rate) | ~37% | 20-30% (projected) | Verification catches phantom refs (E2); reasoning FPs need E3 maturation |
| Dimension coverage | 19 sub-dimensions | 21 sub-dimensions | Guardian +1, Design Critic +1 (E4) |
| Learned rule quality | Shell grep only | Semgrep YAML (AST-aware) + shell fallback (E5) | — |

## Open Design Decisions

1. **Context expansion timeout**: Each context-expansion step (grep, find, git log) is wrapped in `timeout 10 <command>`. Test execution (opt-in) uses `timeout 15 <command>`. The coordinator tracks wall-clock time for Phase 1.5; if total exceeds 60s, it stops running remaining steps, reports partial context, and continues to dispatch. These timeouts are implemented by the coordinator using the shell `timeout` command (GNU coreutils), not by LLM self-regulation.
2. **Verification depth**: Start with Checks 1-3 only (file/line/symbol), add claim verification (Check 4) incrementally after measuring false-negative rate.
3. **Semgrep availability**: Optional dependency — generate both formats, use Semgrep when available.
4. **Investigation round limit**: The Investigation Protocol instructs reviewers to "investigate before reporting" but does not enforce a search limit — reviewers are LLM sub-agents with their own token budgets. In practice, each sub-agent is dispatched with a fixed prompt and returns when done. No external timer is applied. If investigation causes a reviewer to return very large output, the coordinator truncates findings to the first 20 per reviewer during aggregation.

## Acceptance Criteria (Phase 2f)

| # | Criteria | Type |
|---|----------|------|
| AC27 | Context expansion extracts changed symbols and finds related code (callers, tests, types) on ≥3 real diffs | Must Pass |
| AC28 | Context package adds <1000 tokens per reviewer instruction on average | Must Pass |
| AC29 | Verification filter catches phantom file references (test against V6 benchmark) | Must Pass |
| AC30 | Verification filter catches out-of-range line numbers | Must Pass |
| AC31 | Battery precision improves vs Phase 2 baseline on ≥3 benchmark diffs (measure, don't target a specific %) | Must Pass |
| AC32 | Investigation Protocol produces evidence-backed findings on ≥3 real diffs | Must Pass |
| AC33 | Enhanced dimensions (reliability, layering, test adequacy) fire on relevant diffs | Should Pass |
| AC34 | Semgrep YAML rules generated from gap analysis on ≥1 real gap; rule passes `semgrep --validate` (if Semgrep available) or YAML parse check | Should Pass |
| AC35 | Total review time (with context expansion + verification) ≤ 2x monolithic | Must Pass |
| AC36 | Every prompt-loaded file ≤1,500 tokens after all Phase 2f changes are applied (including structured schema addition to reviewer prompts). Measurement: `wc -w <file>` × 1.33 ≈ token count. Run on all files in the "Summary of All File Changes" table. If any file exceeds budget after implementation, trim content or split further. | Must Pass |
| AC37 | No single review step loads >1,500 tokens of skill/coordinator content (excluding diff output, context package content, and reviewer findings which are variable-length) | Must Pass |
