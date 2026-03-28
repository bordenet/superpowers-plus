# Gap Analysis & Dashboard Update (Phases 5-6)

Loaded after aggregation on full review rounds. Skip entirely if `--skip-monolith` was used.

---

## Phase 5: Gap Analysis

Compare battery specialist findings vs monolith findings.

### Procedure

1. **Collect findings by source**:
   - `specialist_findings` = all findings from reviewers 1–5
   - `monolith_findings` = all findings from the monolith (reviewer 6)

2. **Match findings**: For each monolith finding, check if any specialist found the same or equivalent issue (same file, same area, same class of problem). Equivalence is approximate — same root cause counts.

3. **Classify unmatched findings**:
   - **Monolith-only** (gaps): The battery missed this. These drive learning.
   - **Battery-only** (specialist depth): The monolith missed this. Validates specialist value.
   - **Both found** (overlap): Confirms the battery is working.

4. **Adjudicate each gap** (3-part verification):
   a. **Disconfirm first**: Try to prove the monolith finding is WRONG. Known noise: severity overrating, phantom file references, hallucinated API behavior.
   b. **Require evidence**: Must point to specific file:line with concrete issue. Vague opinions do not qualify.
   c. **Map to specialist gap**: Identify which specialist SHOULD have caught this AND which dimension was insufficient. If unclear, log as `unassigned_gap`.
   - Fails any check → log as `monolith_noise` or `unassigned_gap`, do NOT generate candidate
   - Passes all three → proceed to step 5

5. **For each confirmed gap, determine learning form**:

#### Semgrep YAML (primary — when Semgrep is installed)

```yaml
rules:
  - id: <gap-id>
    patterns:
      - pattern: <pattern>
    message: >
      <gap description>
    severity: ERROR
    languages: [javascript, typescript]
    metadata:
      source: gap-analysis
      gap_date: "<date>"
      specialist_missed: <reviewer>
      ttl_days: 14
      confidence: <0.0-1.0>
```

Validate: `semgrep --validate --config <rule>.semgrep.yml`
Dry run: `semgrep --config <rule>.semgrep.yml <changed-files> --json`

#### Shell Script (fallback — when Semgrep is NOT installed)

```bash
#!/usr/bin/env bash
# Source: gap-analysis <date> | TTL: 14 days | Confidence: <0.0-1.0>
set -euo pipefail
grep -rn '<pattern>' "$@" || true
```

- **Pattern-learnable**: Heuristic gap → candidate for `reviewers/<reviewer>-patterns.candidate.md`
- **Script-learnable**: Deterministic gap → candidate script for `checks/candidates/`

6. **Stage candidates** (Shadow Lane — NEVER write to active files):
   - Candidates go into `.candidate.md` files (NOT active pattern files)
   - Each candidate gets: `date`, `source_diff`, `gap_description`, `confidence`, `TTL` (14 days)
   - ⚠️ **INVARIANT**: Candidates NEVER go into active pattern files or checks directory

7. **Log gaps**: Add each gap to the Gap Analysis Log in the dashboard (Phase 6).

### Skip Conditions

- `--skip-monolith`: skip entirely
- Monolith timed out or failed: note in report, skip

---

## Phase 6: Update Dashboard

### Dashboard Location

- **Wiki**: Outline
- **Page title**: `Code Review Battery — Performance Dashboard`
- **Document ID**: `66eec34c-5590-4f4f-a370-b4d134cd174e`

### What to Update

1. **Review-Level Metrics** — add new row with date, diff, LOC, files, findings, FPs, times
2. **Rolling Aggregates** — update current week (increment count, recalculate averages)
3. **Learning Pipeline** — update counters (gaps detected, candidates proposed, etc.)
4. **Gap Analysis Log** — add each new gap with description, classification, disposition
5. **Pattern/Check Health** — update if patterns graduated, retired, or changed
6. **Safety Indicators** — update current values


### Update Procedure (Safe Write Protocol)

1. **Fetch** current page: `get_document_outline(id="66eec34c-...")`
2. **Retain** `original_content` for restore on failure
3. **Parse** existing markdown tables
4. **Append** new rows / update aggregates — NEVER remove existing data
5. **Pre-flight**: verify ALL original headings, callouts, row counts preserved; no truncation
6. **Write**: `update_document_outline(documentId="66eec34c-...", text=<updated>)`
7. **Post-write verify**: re-fetch, confirm new data, confirm all original structure intact
   - If ANY check fails: restore `original_content`, verify restore, escalate if restore fails

> ⚠️ **INVARIANT**: Always re-fetch after write. Restore on failure. See `~/.ai-guidance/invariants.md`.
> ⚠️ **NEVER truncate**: Dashboard updates are append-only.
> ⚠️ **Platform note**: On platforms without Outline access, skip Phase 6. Not blocking to verdict.