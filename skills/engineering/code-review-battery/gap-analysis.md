# Gap Analysis & Candidate Pipeline

## When to Run Gap Analysis

Run gap analysis when:
1. **Battery misses a finding** that a human or monolithic reviewer catches
2. **A false positive recurs** in the same category across 2+ reviews
3. **An exercise exposes a weakness** — battery fails to catch an Expected Finding

## Candidate Pattern Schema

Each candidate is stored as a YAML file in `candidates/` with this schema:

```yaml
id: candidate-NNN
status: proposed | validating | validated | rejected | graduated
kind: pattern | anti-pattern  # pattern = new check; anti-pattern = suppress false positive
created: YYYY-MM-DD
source_gap: "Description of the gap that triggered this candidate"
source_exercise: ex-NNN  # or null if from live review
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
  true_positives: 0
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
   - 3+ holdout exercises (must not introduce false positives)
6. **Score**: If precision ≥ 80% across validation exercises, set status to `validated`
7. **Queue for promotion**: Validated candidates are eligible for Phase 5 promotion

## Candidate Validation Workflow

```
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

## Candidate Storage

All candidates live in `candidates/` under the battery skill directory:

```
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
| Total candidates | 1 |
| Proposed | 0 |
| Validated | 0 |
| Graduated | 1 |
| Rejected | 0 |

**candidate-001** (graduated 2026-03-28): Resource Handle Leak on Early Return. Defect Finder missed fd leak on error paths in ex-007. Pattern graduated into `defect-finder.md` line 104. Validation: source exercise PASS (ex-007), holdouts PASS (ex-001, ex-004, 0 false positives).
