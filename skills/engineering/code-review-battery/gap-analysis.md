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

```bash
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
| Total candidates | 4 |
| Proposed | 1 |
| Validated | 0 |
| Graduated | 3 |
| Rejected | 0 |

**Candidate-ID gap note:** this branch's candidates go 001,003,004 -- `candidate-002` is not missing, it's reserved by "Sibling Path Trace" on the separate, not-yet-merged `feat/cr-battery-sibling-dead-code-checks` branch. Verify with `git ls-tree -r --name-only feat/cr-battery-sibling-dead-code-checks -- skills/engineering/code-review-battery/candidates/` if that branch is still available.

**Known debt — `skill.md` line budget:** `skill-health-check`'s hard-ERROR cap is 250 lines. This file is 251 lines as of the Caller Removal Trace candidate above, against a baseline of exactly 250 lines on `origin/dev` (at the cap, not over). This batch is the sole cause of the 1-line violation here -- no low-risk extraction target was found in `reference.md` (the added line is part of the Phase 1 reviewer-activation table, kept whole in `skill.md` rather than split across files). No fix attempted in this pass.

**candidate-001** (graduated 2026-03-28): Resource Handle Leak on Early Return. Defect Finder missed fd leak on error paths in ex-007. Pattern graduated into `defect-finder.md` line 104. Validation: source exercise PASS (ex-007), holdouts PASS (ex-001, ex-004, 0 false positives).

**candidate-003** (graduated 2026-07-10): Caller Removal Trace. The structural inverse of Producer Trace -- catches a diff that reroutes or deletes the only call site of a function/export, leaving it orphaned. Graduated into `defect-finder.md` ("Caller Removal Trace"); findings route through Guardian's Anti-Hallucination Gate evidence format. Validation: source ex-017 + holdouts ex-007, ex-004 (0 false positives) + ex-018 (dedicated severity-calibration exercise for published-library repos).

**candidate-004** (graduated 2026-07-10, scoping-only -- no exercise applies): Design Critic Diff Attribution. Requires every code-smell finding to state whether the diff introduced/worsened it vs. pre-existing. Graduated into `design-critic.md` ("Diff Attribution"). No precision harness applies -- this narrows an existing, already-validated detection mechanism rather than adding a new trigger.

**candidate-008** (proposed 2026-07-12): Producer Trace's Mechanized Evidence Shares Caller Removal Trace's Grep-Replay Exposure. Caller Removal Trace's mechanized JSON evidence-verification accumulated 9 confirmed bugs across three review rounds (word-boundary collisions, exit_code-vs-count semantics, comment-only mentions, multi-declaration/re-export, symlinked-directory traversal, case-insensitive-filesystem checkout collisions) and was ultimately dropped in favor of prose-only evidence. Producer Trace's evidence commands use the structurally identical grep-replay-for-absence primitive and are flagged as likely exposed to the same bypass classes -- NOT independently confirmed, only reasoned about by analogy. Needs its own dedicated adversarial review before any fix is proposed.
