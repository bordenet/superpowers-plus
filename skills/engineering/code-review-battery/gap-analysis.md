# Gap Analysis & Candidate Pipeline

## When to Run Gap Analysis

Run gap analysis when:

1. **Battery misses a finding** that a human or monolithic reviewer catches
2. **A false positive recurs** in the same category across 2+ reviews
3. **An exercise exposes a weakness** — battery fails to catch an Expected Finding
4. **A charter-scoping candidate (like candidate-004) is due for standing re-examination** — a candidate that only narrows an existing dimension rather than adding a new detectable trigger (no exercise/precision harness applies to it) carries a standing obligation to be re-checked at every gap-analysis pass, not just at graduation, for whether it turned out to be masking a real detection gap

## Candidate Pattern Schema

Each candidate is stored as a YAML file in `candidates/` with this schema:

```yaml
id: candidate-NNN
status: proposed | validating | validated | rejected | graduated
kind: pattern | anti-pattern  # pattern = new check; anti-pattern = suppress false positive
created: YYYY-MM-DD
source_gap: "Description of the gap that triggered this candidate"
source_exercise: ex-NNN  # or null if from live review
graduation_path: standard  # standard = exercise-validated; live-incident = exercise-deferred; scoping-only = no detectable pattern, charter/scoping clarification
reviewer: defect-finder   # Which reviewer this augments
pattern: |
  When reviewing code that <trigger condition>,
  check for <specific defect pattern>.
  Look at <what to examine>.
  Flag as <severity> if <condition>.
examples:
  - file: "path/to/example.sh"
    issue: "What was missed"
    fix: "How to fix it"
confidence: 0.0-1.0       # Starts at 0.5 for proposals
ttl_days: 90              # Auto-reject if not validated within TTL
validation:
  exercises_tested: []     # Exercise IDs used for validation
  true_positives: 0        # count of correctly-caught Expected Findings across
                            # all exercises_tested, NOT count of exercises --
                            # one exercise with 2 Expected Findings both caught
                            # contributes 2, same as 2 exercises with 1 each
  false_positives: 0
  precision: null
rejection:
  reason: null             # Why the candidate was rejected (if status = rejected)
  date: null
graduation:
  promoted_date: null
  reviewer_line: null      # Line in reviewer prompt where pattern was added
  regression_check: null   # Exercise suite result after graduation
```

## Gap → Candidate Proposal Procedure

When a gap is discovered:

1. **Identify the gap**: What did the battery miss? What severity? Which reviewer should have caught it?
2. **Root cause**: WHY did the reviewer miss it? (a) Missing dimension, (b) Insufficient technique, (c) Context truncation, (d) Prompt ambiguity
3. **Draft candidate pattern**: Write a specific, testable pattern that would catch this gap
4. **Create candidate file**: Save to `candidates/candidate-NNN.yaml` with status `proposed`
5. **Validate immediately**: Run the candidate pattern against:
   - The original gap exercise (must catch it)
   - 2+ holdout exercises (must not introduce false positives) -- matches the "Candidate Validation Workflow" section below and candidate-001's actual precedent (1 source + 2 holdouts)
6. **Score**: If precision ≥ 80% across validation exercises, set status to `validated`
7. **Queue for promotion**: Validated candidates are eligible for Phase 5 promotion

## Candidate Validation Workflow

```text
proposed → validating → validated → graduated
                ↓              ↓
             rejected       rejected (regression)
```

**Validation steps:**

1. Add the candidate pattern text to the relevant reviewer's prompt (temporary, in-memory)
2. Run the augmented reviewer against 3+ exercises:
   - The source exercise (MUST catch the gap)
   - 2+ holdout exercises (MUST NOT introduce new false positives)
3. If source exercise catches the gap AND holdout precision ≥ 80%:
   - Status → `validated`, confidence → measured precision
4. If holdout precision < 80% or source exercise still misses:
   - Status → `rejected`, record rejection reason

## Scoping-Only Graduation (no precision harness applies)

Some candidates aren't a new detectable pattern -- they're a scoping/attribution rule added to a reviewer's existing charter (e.g., "state whether this finding is diff-introduced or pre-existing"), constraining findings the reviewer already produces rather than teaching it a new signal. No true/false-positive rate exists to measure, so these don't fabricate a precision number or sit at `proposed` forever waiting on a harness that will never apply.

- `graduation_path: scoping-only`. `source_exercise: null`, `validation.exercises_tested: []`, `true_positives: 0`, `false_positives: 0`, `precision: null`.
- `confidence` stays at the proposal floor **0.5** permanently -- no measurement exists to raise it.
- `graduation.regression_check` must explain why no exercise applies.
- A NEW trigger condition is never scoping-only, even a narrow one -- it's a `standard` or `live-incident` candidate needing its own exercise/holdout bar.
- Standing obligation: re-examine every `scoping-only` candidate at each gap-analysis pass for whether it's actually suppressing findings that should fire; demote to `rejected` and re-propose as `standard` if so.

## Candidate Storage

All candidates live in `candidates/` under the battery skill directory:

```text
skills/engineering/code-review-battery/
├── candidates/
│   ├── candidate-001.yaml
│   ├── candidate-002.yaml
│   └── ...
```

Candidates are version-controlled. No external infrastructure needed.

## Integration with Battery

After the review is complete (post-Phase 5 convergence):

1. If any reviewer reported 0 findings on a non-trivial diff, flag for potential gap analysis
2. If the monolith finds something no specialist found, auto-propose a candidate
3. If an exercise fails (battery misses Expected Finding), auto-propose a candidate

The battery does NOT auto-modify reviewer prompts. Candidates go through the validation → promotion pipeline before affecting live reviews. See the "Gap Analysis (post-review)" section in `skill.md`.

## Current State

| Metric | Value |
|--------|-------|
| Total candidates | 6 |
| Proposed | 2 |
| Validated | 0 |
| Graduated | 4 |
| Rejected | 0 |

**Candidate-ID gap note:** this branch's candidates go 001-004,006,008 -- gaps 005, 007 are not missing, they're reserved on the separate, not-yet-merged `feat/cr-battery-field-reference-trace-holdback` branch: `candidate-005` (Field Reference Trace) and `candidate-007` (2>/dev/null Masks Genuine Absence in Evidence Commands). Verify with `git ls-tree -r --name-only feat/cr-battery-field-reference-trace-holdback -- skills/engineering/code-review-battery/candidates/` if that branch is still available.

**Resolved — `skill.md` line budget:** this batch's new Phase 1 reviewer-activation table row initially pushed `skill.md` from 250 to 251 lines, over `skill-health-check`'s hard-ERROR cap. Fixed by consolidating two adjacent one-line Companion Skills bullets into one (no content removed, just reformatted) -- `skill.md` is back at exactly 250 lines.

**Resolved — reviewer-file size governance:** reviewer prompt files (`reviewers/*.md`) are dispatched verbatim to context-free sub-agents, so unbounded growth is a real per-invocation token cost with no mechanical ceiling previously governing them (`skill-health-check` and `harsh-review.sh` globbed only `skill.md`). Added a `reviewers/*.md` <=400-line ERROR gate to `tools/harsh-review.sh` (CHECK 8b-2) and documented it in `skill-health-check`, so future reviewer-file growth is metered from here on. 400 is ~1.6x the `skill.md` 250-line budget, giving reviewer files real headroom (they're denser than a skill.md by design) without leaving the ceiling unenforced.

**candidate-001** (graduated 2026-03-28): Resource Handle Leak on Early Return. Defect Finder missed fd leak on error paths in ex-007. Pattern graduated into `defect-finder.md` line 104. Validation: source exercise PASS (ex-007), holdouts PASS (ex-001, ex-004, 0 false positives).

**candidate-002** (graduated 2026-07-10): Sibling Path Trace. Catches a diff that updates one structurally-parallel handler for a resource (create/update/delete, post/reschedule/cancel, sync/async twins) while leaving a sibling handler on the same field/concern untouched -- motivated by a real pre-merge review catch (a colleague's AI code-review tool caught a transient sibling-path gap in an in-progress diff: a new per-slot field was wired into one handler but not its structurally-parallel sibling in a different file; the author fixed it same-day and the gap never shipped). This candidate is not a claim our own battery reviewed and missed that diff -- it's a claim that our battery's existing mechanisms would not have caught this shape: the "field reset" signal only fires on reset/null/0/false (never a brand-new field), and "grep all readers" for a new field only finds the one reader the diff itself just created. Graduated into `defect-finder.md` ("Sibling Path Trace") and `guardian.md` Blast Radius (condensed cross-reference). Validation: source exercise ex-016 (caught the untouched-sibling gap, correctly excluded a by-design non-sibling file) + holdouts ex-012 and ex-005 (zero false positives on either, pattern explicitly reported not firing) -- all three runs performed by dispatching a fresh sub-agent with no shared context against the augmented Defect Finder charter. Confidence 0.75 (below candidate-001's 1.0: validated synthetically only -- the source gap never reached production). NOTE: an earlier draft of this pattern extended its trigger conditions to also cover a control-flow guard changed on one sibling with no field involved; that extension was descoped after two PHR review rounds found its supporting prose kept contradicting the rest of this pattern's field-scoped machinery, and no exercise ever validated it. See candidate-006 (proposed) for that shape as its own future candidate.

**candidate-003** (graduated 2026-07-10): Caller Removal Trace. The structural inverse of Producer Trace -- catches a diff that reroutes or deletes the only call site of a function/export, leaving it orphaned. Graduated into `defect-finder.md` ("Caller Removal Trace"); findings route through Guardian's Anti-Hallucination Gate evidence format, always prose-only (mechanized JSON evidence was dropped 2026-07-11 after 3 review rounds each found a new confirmed bug in the mechanized idiom; see candidate-008.yaml and defect-finder.md for current text). Validation: source ex-017 + holdouts ex-007, ex-004 (0 false positives) + ex-018 (dedicated severity-calibration exercise for published-library repos).

**candidate-004** (graduated 2026-07-10, scoping-only -- no exercise applies): Design Critic Diff Attribution. Requires every code-smell finding to state whether the diff introduced/worsened it vs. pre-existing. Graduated into `design-critic.md` ("Diff Attribution"). No precision harness applies -- this narrows an existing, already-validated detection mechanism rather than adding a new trigger.

**candidate-006** (proposed 2026-07-10): Sibling Path Trace -- Guard-Condition Trigger. Descoped out of candidate-002 (see its NOTE above) after two PHR review rounds found the guard-condition-only trigger shape (a control-flow guard changed on one sibling family member, no field involved) was never validated by any exercise and kept surfacing prose inconsistencies with the rest of candidate-002's field-scoped machinery. Tracked here as its own future candidate, requiring a dedicated validation exercise before it can graduate.

**candidate-008** (proposed 2026-07-11): Producer Trace's Mechanized Evidence Shares Caller Removal Trace's Grep-Replay Exposure. Caller Removal Trace's mechanized JSON evidence-verification accumulated a new confirmed bug in each of three review rounds (word-boundary collisions, exit_code-vs-count semantics, comment-only mentions, multi-declaration/re-export, symlinked-directory traversal, case-insensitive-filesystem checkout collisions) and was ultimately dropped in favor of prose-only evidence. Producer Trace's evidence commands use the structurally identical grep-replay-for-absence primitive and are flagged as likely exposed to the same bypass classes -- NOT independently confirmed, only reasoned about by analogy. Needs its own dedicated adversarial review before any fix is proposed.
