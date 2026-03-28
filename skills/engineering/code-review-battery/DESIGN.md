# Code Review Battery — Technical Design Document

> **Status**: Active Development (v2.3 — proven against real PR)
> **Companion**: [PRD.md](./PRD.md)
> **Created**: 2026-03-27
> **v2 Shipped**: 2026-03-28 (ripple analysis, consumer trace, comment-as-spec)
> **v2.3 Shipped**: 2026-03-28 (feedback loop analysis, paired boundary tests, convergent findings, Round 2 escalation)
> **Confidence**: 92/100 (v2.2 battery caught all Round 1-3 findings in single pass)

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  Entry Points                    │
│  progressive-code-review-gate  |  manual invoke  │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│              Triage Coordinator                  │
│  Analyzes diff → selects relevant reviewers      │
│  Input: git diff, file list, change metadata     │
│  Output: list of reviewers to activate           │
└──────────────────┬──────────────────────────────┘
                   │
        ┌──────────┼──────────┬──────────┬──────────┐
        ▼          ▼          ▼          ▼          ▼
   ┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌─────────┐
   │ Defect  ││ Design  ││Guardian ││Standards││ Perf    │
   │ Finder  ││ Critic  ││         ││Enforcer ││ Analyst │
   │         ││         ││         ││         ││         │
   │ Always  ││Conditnl ││ Always  ││ Always  ││Conditnl │
   └────┬────┘└────┬────┘└────┬────┘└────┬────┘└────┬────┘
        │          │          │          │          │
        └──────────┴──────────┴──────────┴──────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────┐
│           Aggregation (Coordinator)              │
│  Merges findings, deduplicates, ranks severity   │
│  Output: unified review report                   │
└─────────────────────────────────────────────────┘
```

## File Structure

```
~/.agents/skills/code-review-battery/
├── SKILL.md                    # Skill entry point with triggers + coordination
├── PRD.md                      # Product requirements
├── DESIGN.md                   # This file
├── coordinator.md              # Triage + dispatch + aggregation + escalation
├── reviewers/
│   ├── defect-finder.md        # Agent 1 — correctness, ripple analysis, state lifecycle
│   ├── design-critic.md        # Agent 2 — factoring, complexity, naming
│   ├── guardian.md             # Agent 3 — security, blast radius, contract drift
│   ├── standards-enforcer.md   # Agent 4 — docs, test quality, observability
│   ├── performance-analyst.md  # Agent 5 — performance, logging
│   └── monolith.md             # On-demand comprehensive reviewer
├── [v1 deprecated — not used by v2 procedure]
│   ├── context-expansion.md
│   ├── verification.md
│   ├── investigation-protocol.md
│   ├── gap-analysis.md
│   └── implementation-plan.md
```

> **Monolith demotion rationale (v2):** V4 validation showed monolith had higher single-reviewer recall than any specialist. However, v2's ripple analysis techniques (consumer trace, state lifecycle, feedback loop analysis) absorbed the monolith's recall advantage into the specialist prompts. The 5-specialist battery now matches or exceeds monolith recall while providing structured, attributable findings. Monolith retained as on-demand fallback for comprehensive single-pass reviews.

## Platform Dispatch

### Augment.ai

Uses `sub-agent-code-reviewer` with unique names. All activated reviewers fire in parallel:

```
# Dispatched by the coordinator (the orchestrating agent):
sub-agent-code-reviewer(name="battery-defect-finder", instruction=<defect-finder.md prompt + diff + source context>)
sub-agent-code-reviewer(name="battery-design-critic", instruction=<design-critic.md prompt + diff>)
sub-agent-code-reviewer(name="battery-guardian", instruction=<guardian.md prompt + diff + source context>)
sub-agent-code-reviewer(name="battery-standards", instruction=<standards-enforcer.md prompt + diff>)
# Performance Analyst skipped if no perf-sensitive code
```

**Why `sub-agent-code-reviewer`?**
- Purpose-built sub-agent type for code review tasks in Augment workspaces
- Pre-configured with workspace access — no manual setup needed
- Supports parallel dispatch with unique names
- Reviewer behavior is controlled by the instruction prompt

### Claude Code

Two options (prefer Option A):

**Option A: Custom Subagent Files** (recommended)
Install `.claude/agents/` files during setup. Claude auto-delegates based on description:

```yaml
# .claude/agents/battery-defect-finder.md
---
name: battery-defect-finder
description: "Code review focused on defects: correctness, edge cases, error handling, concurrency"
tools: ["View", "Bash", "Grep"]
---
<defect-finder prompt content>
```

**Option B: Inline Task Dispatch**
The skill instructs the agent to use `Task()` calls directly:
```
Task("Review for defects: <diff content>")
Task("Review for design: <diff content>")
```

Option A is preferred because it survives across sessions, auto-delegates, and
can be version-controlled. Option B is simpler but requires the agent to
understand the dispatch pattern each time.

### Graceful Degradation

If neither sub-agent tools nor Task() are available (e.g., a basic LLM chat):
- The coordinator prompt includes inline fallback: "If you cannot dispatch
  sub-agents, perform the review yourself using the following 5 checklists
  sequentially."
- Quality degrades (no parallelism, monolithic) but functionality is preserved.

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

| Condition | Reviewers Activated |
|-----------|-------------------|
| Any code change | Defect Finder, Guardian, Standards Enforcer |
| Adds/modifies classes, functions, public APIs | + Design Critic |
| Touches DB, loops, caching, or >500 LOC | + Performance Analyst |
| Docs-only change | Standards Enforcer only |
| Config/dependency change only | Guardian only |
| `--all` flag | All 5 |
| `--only=<name>` flag | Named reviewer only |

### Output
A JSON-like selection that the dispatcher uses:
```json
{
  "activated": ["defect-finder", "guardian", "standards-enforcer", "design-critic"],
  "skipped": ["performance-analyst"],
  "reasoning": "No DB/perf-sensitive code touched. 3 files changed, all in src/."
}
```

## Reviewer Prompt Structure

Each reviewer prompt follows a consistent template:

```markdown
# [Reviewer Name]

## Your Role
You are reviewing code changes with a specific focus: [MENTAL MODEL].
You ONLY report findings in your domain. Do not comment on other dimensions.

## What to Review
[DIFF CONTENT]

## Your Dimensions
[LIST OF SPECIFIC DIMENSIONS WITH EXAMPLES]

## Confidence Gate
Only report findings where you are >80% confident there is a real issue.
Clearly mark any finding where confidence is 60-80% as "Possible: ..."

## Output Format
For each finding:
- **Severity**: Critical / Important / Minor
- **File:Line**: Exact location
- **Issue**: What is wrong (1-2 sentences)
- **Why**: Why this matters (impact)
- **Fix**: How to fix (if not obvious)

If you find NO issues in your domain, say:
"✅ No [domain] issues found."
```

## Aggregation Design

The coordinator (main agent) handles aggregation after all reviewers return.
No separate aggregation agent — this avoids the serial bottleneck.

### Aggregation Rules
1. Collect all findings from all reviewers
2. Sort by severity: Critical → Important → Minor
3. Within same severity, sort by file path (groups related findings)
4. Flag conflicts: if two reviewers contradict (rare with clean boundaries), note both
5. Present unified report with reviewer attribution:
   ```
   ### Critical
   1. [Defect Finder] Missing null check in auth.js:42 — ...
   2. [Guardian] SQL injection in query.js:15 — ...

   ### Important
   3. [Design Critic] Function exceeds 200 LOC in parser.js:1 — ...
   ```

## Integration with Existing Skills

### progressive-code-review-gate
Current flow: gather diff → dispatch `sub-agent-code-reviewer` → process results → loop if needed.

New flow: gather diff → run triage coordinator → dispatch battery → aggregate → process results → loop if needed.

The skill.md for `progressive-code-review-gate` will be updated to check for the
battery skill. If present, delegate to it. If not (backward compat), fall back to
monolithic review.

### requesting-code-review
This skill dispatches review for PR-level or pre-merge review. It will similarly
delegate to the battery when available.

## Installation

### Augment.ai
```bash
# install.sh copies skills/engineering/code-review-battery/ to ~/.agents/skills/code-review-battery/
# No additional setup needed — sub-agent-code-reviewer is built-in
rsync -av skills/engineering/code-review-battery/ ~/.agents/skills/code-review-battery/
```

### Claude Code
```bash
# Copy reviewer prompts as custom subagent files
mkdir -p .claude/agents/
for reviewer in defect-finder design-critic guardian standards-enforcer performance-analyst; do
  cp ~/.agents/skills/code-review-battery/reviewers/$reviewer.md .claude/agents/battery-$reviewer.md
done
```

## Investigation Log

> This section is updated as validation experiments complete.

| Date | Experiment | Result | Impact on Design |
|------|-----------|--------|-----------------|
| 2026-03-27 | V1: Parallel dispatch smoke test | ✅ PASS — 5 simultaneous sub-agent calls returned successfully | Confirms Augment dispatch is viable. No concurrency limit at N=5. Later switched to `sub-agent-code-reviewer`. |
| 2026-03-27 | V2: Defect Finder prompt test | ✅ PASS — Found 1 Important + 1 Minor real issue, 0 false positives | Prompt format works. Found genuine intent-routing ordering bug + stemming redundancy. |
| 2026-03-27 | V2: Guardian prompt test (file refs) | ❌ FAIL — Sub-agent couldn't access diff from file references | **CRITICAL LEARNING**: Diff must be INLINE in instruction. Sub-agents have isolated context. |
| 2026-03-27 | V2: Standards Enforcer test (file refs) | ❌ FAIL — Same as Guardian | Same fix: inline diff content. |
| 2026-03-27 | V2b: Guardian prompt test (inline diff) | ✅ PASS — Correctly found no security/blast-radius issues on safe additive diff. Systematic 4-dimension coverage. 0 false positives. | Inline diff approach works. Guardian produces clean "no issues" when appropriate. |
| 2026-03-27 | V2b: Standards Enforcer test (inline diff) | ✅ PASS — Thorough conformance check. Verified stem derivations, YAML frontmatter, arithmetic on skill counts. 0 false positives. | Inline diff works. Standards Enforcer is appropriately thorough. |
| 2026-03-27 | V3: Triage Coordinator test | ✅ PASS — Correctly activated 4/5 reviewers, skipped Performance Analyst. Sound reasoning. Output matched JSON format. | Triage logic works as designed. Design Critic correctly triggered for routing API changes. |
| 2026-03-27 | V4: Monolithic vs Battery comparison | ⚠️ MIXED — See detailed analysis below | Battery more precise; monolithic finds more but with more noise. See V4 Analysis. |
| — | V5: Token cost measurement | ⬜ Deferred — not a priority while improving precision | — |
| 2026-03-28 | V6: v2.2 battery against real PR (3 files, +513/-43) | ✅ PASS — All Round 1-3 findings caught in single pass. 10 findings, 0 false positives. 4 reviewers dispatched in parallel. | Source context + ripple analysis is the key differentiator. Battery v2.2 is production-ready. |
| 2026-03-28 | V7: v2.3 additions (feedback loop, paired boundary, convergent) | ✅ Committed — learnings from V6 incorporated | 3 new techniques added, all evidence-based. |

### Design Constraint Discovered (V2)

**Sub-agents have isolated context.** They cannot read files from the workspace
unless explicitly given them in the instruction. This means:

1. The **coordinator** must capture the full diff before dispatching
2. Each reviewer instruction must include the **full diff content inline**
3. For large diffs, the coordinator may need to **chunk** the diff per reviewer
   (e.g., Defect Finder gets src/ changes, Guardian gets config/ changes)
4. This is a token cost driver — the diff is repeated N times (once per reviewer)

**Mitigation**: Triage gating reduces N (fewer reviewers = fewer copies of the diff).
For very large diffs (>2000 lines), consider per-file dispatch instead of per-reviewer.


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
