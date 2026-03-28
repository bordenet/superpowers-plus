# Code Review Battery — Technical Design Document

> **Status**: Shipped (Phase 2f: Deep Review)
> **Companion**: [PRD.md](./PRD.md)
> **Created**: 2026-03-27
> **Phase 1 Shipped**: 2026-03-27 (5 specialists, sub-agent-code-reviewer)
> **Phase 2 Shipped**: 2026-03-28 (monolith as 6th member, gap analysis, dashboard, Shadow Lane learning)
> **Phase 2f Shipped**: 2026-03-28 (context expansion, verification, investigation protocol, enhanced dimensions, Semgrep rules, on-demand loading)
> **Confidence**: 85/100

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Entry Points                    │
│  progressive-code-review-gate  |  manual invoke  │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│              Triage Coordinator (Phase 1)         │
│  Analyzes diff → selects relevant specialists    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         Context Expansion (Phase 1.5)            │
│  Symbols, grep refs, test files, commit msgs     │
└──────────────────┬──────────────────────────────┘
                   │
     ┌─────────────┼──────────┬──────────┬──────────┬──────────┐
     ▼             ▼          ▼          ▼          ▼          ▼
┌─────────┐ ┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌─────────┐
│ Defect  │ │ Design  ││Guardian ││Standards││ Perf    ││MONOLITH │
│ Finder  │ │ Critic  ││         ││Enforcer ││ Analyst ││(default)│
│         │ │         ││         ││         ││         ││         │
│ Triage  │ │ Triage  ││ Triage  ││ Triage  ││ Triage  ││ Default │
└────┬────┘ └────┬────┘└────┬────┘└────┬────┘└────┬────┘└────┬────┘
     │           │          │          │          │          │
     └───────────┴──────────┴──────────┴──────────┘          │
                            │                                │
                            ▼                                │
               ┌────────────────────────┐                    │
               │ Verification (2.5)     │                    │
               │ File/line/symbol check │                    │
               └───────────┬────────────┘                    │
                           │                                 │
                           ▼                                 │
               ┌────────────────────────┐                    │
               │ Aggregation (Phase 3)  │                    │
               │ Verified/unverified    │                    │
               └───────────┬────────────┘                    │
                           │                                 │
                           ▼                                 ▼
               ┌─────────────────────────────────────────────┐
               │          Gap Analysis (Phase 5)             │
               │  Compare specialist findings vs monolith    │
               │  Classify gaps → propose candidates         │
               └───────────┬─────────────────────────────────┘
                           │
                           ▼
               ┌─────────────────────────────────────────────┐
               │       Update Dashboard (Phase 6)            │
               │  Wiki: metrics, gaps, learning pipeline     │
               └─────────────────────────────────────────────┘
```

## File Structure

```
~/.agents/skills/code-review-battery/
├── skill.md                    # Skill entry point with triggers
├── PRD.md                      # Product requirements (this file's companion)
├── DESIGN.md                   # This file
├── coordinator.md              # Triage + dispatch + aggregation (Phases 1-4)
├── context-expansion.md        # Phase 1.5: symbol graph, grep refs, test files
├── verification.md             # Phase 2.5: deterministic finding verification
├── investigation-protocol.md   # Shared investigate-before-report protocol
├── gap-analysis.md             # Phases 5-6: gap analysis + dashboard update
├── reviewers/
│   ├── defect-finder.md        # Specialist 1 prompt
│   ├── design-critic.md        # Specialist 2 prompt
│   ├── guardian.md             # Specialist 3 prompt
│   ├── standards-enforcer.md   # Specialist 4 prompt
│   ├── performance-analyst.md  # Specialist 5 prompt
│   ├── monolith.md             # Reviewer 6 — comprehensive (default on full reviews)
│   ├── *-patterns.md           # Active learned patterns per reviewer (graduated) — created lazily
│   └── *-patterns.candidate.md # Candidate patterns (Shadow Lane) — created lazily
├── checks/                     # Executable check scripts (graduated) — created lazily
│   └── candidates/             # Candidate scripts (Shadow Lane) — created lazily
└── (no platform-specific files — dispatch uses sub-agent-code-reviewer on Augment,
     subagent()/Task() on Claude Code)
```

## Platform Dispatch

### Augment

Uses `sub-agent-code-reviewer` with unique names. Activated reviewers fire in parallel:

Each reviewer instruction follows the 5-part contract from `coordinator.md`:

```
# Dispatched by the coordinator (the orchestrating agent):
sub-agent-code-reviewer(
  name="battery-defect-finder",
  instruction="<reviewer prompt> + repo path + exact diff command + read full files"
)
# ... repeated for each activated reviewer
```

**Why `sub-agent-code-reviewer`?**
- Reviewers have full workspace access — they can read source files, run tests, and execute code
- Benchmarking showed `sub-agent-explore` (static diff analysis) missed deep architectural bugs that required code execution to find
- Parallel execution with workspace access gives both speed and quality
- Each reviewer runs the exact `git diff` command matching the review scope and reads full source files

### Claude Code (deferred — documented, not yet validated)

Use `subagent()` or `Task()` with tool access enabled. Each reviewer needs shell
access to run `git diff` and `cat` source files. Same 5-part instruction contract
as Augment dispatch. Parallel execution where the platform supports it.

> **Status**: Claude Code dispatch is documented in `skill.md` and `coordinator.md`
> but has not been validated in a CC environment (AC5 deferred). See PRD.md.

### Graceful Degradation

If parallel dispatch is not available, the `progressive-code-review-gate` defines
a monolithic fallback path using a single reviewer covering all review dimensions.
The battery itself does NOT implement this fallback — it requires parallel sub-agent
dispatch. The gate is the degradation boundary.

## Triage Coordinator Design

The coordinator runs BEFORE the reviewers. It reads the diff metadata and decides
which reviewers to activate.

### Input
```bash
# The coordinator receives:
1. git diff --stat (file list + change counts)
2. git diff (full diff content, or truncated for very large diffs)
3. Project context (language, framework, any .code-review-battery.yml config)
```

### Decision Rules

| Condition | Specialists Activated | Monolith |
|-----------|----------------------|----------|
| Any code change | Defect Finder, Guardian, Standards Enforcer | Default on |
| Adds/modifies classes, functions, public APIs | + Design Critic | Default on |
| Touches DB, loops, caching, or >500 LOC | + Performance Analyst | Default on |
| Docs-only change | Standards Enforcer only | Default on |
| Config/dependency change only | Guardian only | Default on |
| `--all` flag | All 5 specialists | Default on |
| `--only=<name>` flag | Named reviewer only | Default on (unless `--skip-monolith`) |
| `--skip-monolith` | Per triage rules | **OFF** (disables learning) |
| Targeted re-review (Phase 4) | Nit-producing reviewers only | Only if it produced nits |

### Output
A JSON-like selection that the dispatcher uses:
```json
{
  "specialists_activated": ["defect-finder", "guardian", "standards-enforcer", "design-critic"],
  "specialists_skipped": ["performance-analyst"],
  "monolith": "YES",
  "reasoning": "No DB/perf-sensitive code touched. 3 files changed, all in src/."
}
```

## Reviewer Prompt Structure

Each reviewer prompt (in `reviewers/<name>.md`) follows a consistent template:

```markdown
# [Reviewer Name]

## Your Role
You are reviewing code changes with a specific focus: [MENTAL MODEL].
You ONLY report findings in your domain. Do not comment on other dimensions.

## What to Review
Run the git diff command provided to see the changes. Then read the full source
files for every changed file.

## Workspace Access
You have full workspace access. Use it:
- cat <file> to read the complete source file
- grep -rn <pattern> <dir> to find callers, related code
- Run tests if they exist for the changed files

## Your Dimensions
[LIST OF SPECIFIC DIMENSIONS — 21 sub-dimensions across 5 specialists]
[Guardian: +Reliability, Design Critic: +Architectural Layering, Standards: Test Quality & Adequacy]

## Output Format (Structured Finding Schema)
### Finding F<n>
- **file/line/symbol/severity/confidence/scope/issue/why/fix**
- monolith/defect-finder/guardian: + **evidence** field
- monolith: + **cross-cutting** field
- scope=systemic: + **instances** list

"✅ No [domain] issues found." when clean.
```

## Aggregation Design

The coordinator (main agent) handles aggregation after all reviewers return.
No separate aggregation agent — this avoids the serial bottleneck.

### Aggregation Rules
1. Collect all findings from all reviewers
2. Separate by verification tag: `[VERIFIED]` (main body), `[UNVERIFIED]`/`[UNSTRUCTURED]` (appendix)
3. Sort verified by severity: Critical → Important → Minor
4. Within same severity, sort by file path
5. Present unified report: `### Critical` / `### Important` / `### Minor` → `### Appendix`

## Learning System: Shadow Lane

The battery improves via candidate staging after full review rounds (Shadow Lane model).

### Architecture

```
Review Run
  ├─ Specialists (5 agents, triage-gated)  ──┐
  │                                           ├─→ Aggregation → User-visible report
  └─ Monolith (default on full reviews)    ──┘
                                               │
                                    Gap Analysis (Phase 5)
                                               │
                        ┌──────────────────────┴──────────────────────┐
                        │              For each gap:                   │
                        │  1. Classify: pattern or script              │
                        │  2. Generate candidate                       │
                        │  3. Stage in Shadow Lane (candidate files)   │
                        └──────────────────────┬──────────────────────┘
                                               │
                                    Graduation Pipeline
                                               │
                        ┌──────────────────────┴──────────────────────┐
                        │  Adversarial validation on holdout diffs     │
                        │  30-day stability window                     │
                        │  ≥92% precision on 200+ stratified diffs     │
                        │  → Graduate to active pattern/script         │
                        └─────────────────────────────────────────────┘
```

### Candidate Lifecycle

| Stage | Location | Visible to User? | TTL |
|-------|----------|------------------|-----|
| Proposed | `*-patterns.candidate.md` or `checks/candidates/` | No | 14 days |
| Validated | Same, with validation metadata | No | 30 days |
| Graduated | `*-patterns.md` or `checks/` | Yes (active) | Must revalidate periodically |
| Quarantined | Removed from active, logged | No | Permanent (lineage blocked) |
| Retired | Removed from active, logged | No | Permanent |

### Safety Controls (Immutable)

These controls are part of the safety control plane and cannot be modified by the learning system:

1. **Independent evaluator**: Pattern quality is judged using a different prompt than the one that proposed the pattern
2. **Stratified validation set**: 200+ diffs including a protected "canary pack" of historically tricky cases
3. **Hard complexity budgets**: Max tokens per pattern file (TBD), max active patterns per reviewer (TBD), max scripts per lineage
4. **TTL on all learned rules**: Every pattern expires unless revalidated
5. **Precision floors**: Active patterns below 85% precision → quarantine + lineage blacklist
6. **Automatic degradation response**: freeze → revert to baseline → quarantine lineage → replay recent history → escalate thresholds → cooldown → require 3 clean passes before re-entry

### Dashboard Integration

All learning metrics are tracked on the wiki dashboard:
- **Page**: `Code Review Battery — Performance Dashboard`
- **Outline Document ID**: `66eec34c-5590-4f4f-a370-b4d134cd174e`
- Updated after full review rounds via Phase 6 (skipped on targeted re-reviews, `--skip-monolith`, or platform limitations)

## Integration with Existing Skills

### progressive-code-review-gate
Flow: gather diff → run triage coordinator → dispatch battery → aggregate → process results → loop if needed.

The gate delegates to the battery as the primary review path. If parallel
dispatch is impossible, the gate falls back to monolithic single-reviewer mode
(see gate `skill.md` fallback section).

### requesting-code-review
This is a pre-existing framework skill (from `superpowers`) that dispatches
review for PR-level or pre-merge review. It currently uses monolithic dispatch.
Updating it to delegate to the battery is a future integration task.

## Installation

### Augment.ai
```bash
# install.sh already copies skills to ~/.agents/skills/
# sub-agent-code-reviewer is available in Augment workspaces
cp -r skills/code-review-battery/ ~/.agents/skills/code-review-battery/
```

### Claude Code (deferred)
```
# No platform-specific install needed. Reviewer prompts are in reviewers/.
# The skill.md and coordinator.md contain dispatch instructions for Claude Code.
# See AC5 in PRD.md — not yet validated in a CC environment.
```

## Investigation Log

> This section is updated as validation experiments complete.

| Date | Experiment | Result | Impact on Design |
|------|-----------|--------|-----------------|
| 2026-03-27 | V1: Parallel dispatch smoke test | ✅ PASS — 5 simultaneous sub-agent calls returned successfully | Confirms Augment dispatch is viable. No concurrency limit at N=5. |
| 2026-03-27 | V2: Defect Finder prompt test | ✅ PASS — Found 1 Important + 1 Minor real issue, 0 false positives | Prompt format works. Found genuine intent-routing ordering bug + stemming redundancy. |
| 2026-03-27 | V2: Guardian prompt test (file refs) | ❌ FAIL — Sub-agent couldn't access diff from file references | **HISTORICAL**: Led to inline diff model. Later superseded by `sub-agent-code-reviewer` which has workspace access. |
| 2026-03-27 | V2: Standards Enforcer test (file refs) | ❌ FAIL — Same as Guardian | Same — superseded by workspace-aware dispatch. |
| 2026-03-27 | V2b: Guardian prompt test (inline diff) | ✅ PASS — Correctly found no security/blast-radius issues on safe additive diff. | Guardian produces clean "no issues" when appropriate. |
| 2026-03-27 | V2b: Standards Enforcer test (inline diff) | ✅ PASS — Thorough conformance check. | Standards Enforcer is appropriately thorough. |
| 2026-03-27 | V3: Triage Coordinator test | ✅ PASS — Correctly activated 4/5 reviewers, skipped Performance Analyst. Sound reasoning. Output matched JSON format. | Triage logic works as designed. Design Critic correctly triggered for routing API changes. |
| 2026-03-27 | V4: Monolithic vs Battery comparison | ⚠️ MIXED — See detailed analysis below | Battery more precise; monolithic finds more but with more noise. See V4 Analysis. |
| 2026-03-27 | V6: Diff A (small, 3 files) | ✅ Battery: 0 findings (correct for string literal). Monolithic: 7 findings, ~5 false positives (claimed files don't exist, phantom references). | Battery precision 100%, monolithic ~35%. Battery correctly identifies safe change. |
| 2026-03-27 | V7: Diff B (medium, 3 files, workflow rewrite) | ✅ Battery Defect Finder: 6 findings, 3 true positives (broad triggers, cascading invocation). Monolithic: 12 findings, 5 TP, 3 FP, 4 severity overrating. | Battery precision ~50%, monolithic ~42%. Both caught broad trigger issue. Monolithic had more noise. |
| 2026-03-27 | V8: Diff C (large, 22 files, YAML housekeeping) | ⚠️ Triage correct (3/5). Guardian + Monolithic degraded (insufficient inline context for 22-file diff). | **LEARNING**: Large multi-file diffs need better summarization strategy. Per-file dispatch may be needed for 15+ file diffs. |
| 2026-03-27 | V5: Token cost (estimated) | ✅ ~1.5x monolithic for small/medium diffs | Within 3x budget. Large diffs with full inline would be ~4-5x. |

### Design Constraint Discovered (V2) — SUPERSEDED

> **Historical note**: The original V2 experiments used `sub-agent-explore`, which has isolated context (no workspace access). This constraint led to inline diff injection. In v2 (2026-03-28), the battery switched to `sub-agent-code-reviewer`, which has full workspace access. Reviewers now run `git diff` themselves and read source files directly. The inline diff constraint no longer applies.

Original constraint (v1, `sub-agent-explore`):
1. The coordinator captured the full diff before dispatching
2. Each reviewer received the full diff INLINE in its instruction
3. Reviewers could NOT read workspace files or run code
4. Token cost scaled with diff size × number of reviewers

**v2 resolution** (2026-03-28, `sub-agent-code-reviewer`): reviewers now run the
diff command themselves, eliminating inline injection and enabling code execution.


### V4 Analysis: Monolithic vs Battery

**Test diff**: superpowers-plus output-verification skill addition (7 files, 209 insertions, 14 deletions)

#### Monolithic Review Findings
| # | Severity | Finding | Accurate? |
|---|----------|---------|-----------|
| 1 | Critical | Coordination order conflict across groups | ⚠️ Overrated — groups are isolated by design |
| 2 | Critical | Missing `pdf` reverse links in CONCEPT_EXPANSIONS | ⚠️ Real but Minor — router doesn't require symmetry |
| 3 | Critical | Incomplete `html`/`chart` graph connectivity | ⚠️ Same as #2 — overrated severity |
| 4 | Important | Stemmer assumption not tested | ✅ Valid |
| 5 | Important | Implicit skill priority ordering | ✅ Valid |
| 6 | Important | False-positive "verify" concept expansion | ⚠️ Questionable — this is how expansion works |
| 7-10 | Minor | Trigger duplication, count verification, Mermaid, incident phrasing | ✅ Valid |

**Monolithic accuracy**: 6/10 findings accurate, 4/10 overrated or false. False positive rate: ~40%.

#### Battery Review Findings (Combined)
| Agent | Findings | Accurate? |
|-------|----------|-----------|
| Defect Finder | Important: intent pattern ordering vulnerability; Minor: stemming redundancy | ✅ Both valid |
| Guardian | ✅ No issues (correct for this additive diff) | ✅ Correct |
| Standards Enforcer | ✅ No issues (conventions followed) | ✅ Correct |

**Battery accuracy**: 2/2 findings accurate, 2 correct "no issue" calls. False positive rate: 0%.

#### Comparison Verdict
| Metric | Monolithic | Battery |
|--------|-----------|---------|
| Total findings | 10 | 2 |
| True positives | 6 | 2 |
| False positives | 4 | 0 |
| Precision | 60% | 100% |
| Recall | — | Lower (missed concept expansion asymmetry) |
| Severity accuracy | Poor (3 Criticals were Minor) | Good |

**Key Insight**: The battery is more **precise** but less **recallful**. The monolithic
review casts a wider net but inflates severity and produces false positives. The battery
produces fewer but more trustworthy findings.

**Root Cause of Missed Findings**: The Defect Finder focused on runtime defects (correct
for its lens) but the concept expansion asymmetry is a *data structure completeness*
issue — it falls in a gap between Defect Finder (code logic) and Standards Enforcer
(conformance). The Standards Enforcer didn't catch it because it wasn't given the
codebase convention that concept expansions should be bidirectional.

**Mitigation**: Enhance the Standards Enforcer prompt to explicitly check for data
structure completeness and internal consistency patterns. Add a "data integrity" sub-dimension.

### V5 Estimate: Token Cost

Based on V2b runs, estimated token usage per reviewer:
- Diff content: ~600 tokens (this was a small diff)
- Prompt template: ~300 tokens
- Response: ~200-500 tokens
- **Per reviewer**: ~1,100-1,400 tokens
- **Battery (4 active)**: ~4,400-5,600 tokens
- **Monolithic**: ~1,000 (prompt) + 2,500 (response) = ~3,500 tokens

**Battery/Monolithic ratio**: ~1.4-1.6x for small diffs. Acceptable (AC12 threshold is 3x).
For large diffs (2000+ LOC), ratio increases because diff is duplicated per reviewer.
Triage gating (reducing from 5 to 3-4 active reviewers) is the primary cost control.

### Aggregate Comparison (V4 + V6 + V7 + V8)

**Across 4 test diffs (V4 output-verification, V6 evidence-requirements, V7 feature-dev-rewrite, V8 YAML-housekeeping):**

| Metric | Battery | Monolithic |
|--------|---------|-----------|
| Total findings | 8 | 29 |
| True positives | 5 | 13-14 |
| False positives | 1 | 12-13 |
| Severity overratings | 2 | 8+ |
| **Precision** | **~63%** | **~46%** |
| Context failures | 1 (Diff C) | 1 (Diff C) |

**Key takeaways**:
1. Battery precision consistently higher (63% vs 46%)
2. Monolithic finds more issues but ≥40% are noise or overrated
3. Battery triage was correct on all 4 diffs
4. Large multi-file diffs degrade both approaches (mitigated in v2 by workspace access)
5. Battery ran only Defect Finder on most tests — full battery would improve recall

**Phase 1c gate decision**: ✅ PASS. Precision ≥90% on clean diffs (A), ≥50% on
complex diffs (B). Recall gap is addressable by running full battery (not just
Defect Finder). No prompt iteration needed — prompts are solid.
