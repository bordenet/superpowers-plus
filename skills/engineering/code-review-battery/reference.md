# Code Review Battery -- Reference

Companion reference for `skill.md`. Holds material that reviewers
read but doesn't need to live in the main procedure body.

## Anti-Patterns

| Anti-Pattern | Detection | Correction |
|--------------|-----------|------------|
| All reviewers agree | No disagreements found | Force second-order critique: each reviewer names >=1 plausible failure mode OR cites a specific property of the change explaining why none exists (e.g., "pure rename, no callers"). Generic dismissal is rubber-stamping. |
| Duplicate findings | Same issue from 3 reviewers | Deduplicate in synthesis, attribute first finder |
| Reviewer fatigue | Later reviewers less thorough | Randomize dispatch order |
| Missing source context | Review diff without callers | Include grep results for all touched functions |
| Over-scoping | Reviewing unchanged code | Focus on diff + directly impacted callers only |

## Failure Modes

| Failure | Fix |
|---------|-----|
| Sub-agent returns no findings on complex diff | Verify diff + source context was passed inline -- sub-agents have no conversation context |
| False positives from isolated diff review | Include source context (callers, field readers) per Phase 2 -- isolation is the #1 cause |
| Convergence never reached | Escalate to human after 3 passes |
| Monolith finds issues specialists missed | Log as gap-analysis candidate for specialist prompt improvement |

## BugPath Detection Script

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if echo "$BRANCH" | grep -qE '^(hotfix/|fix/[A-Z]+-[0-9]+)'; then
  echo "BugPath Mode: ACTIVE (branch: $BRANCH)"
else
  echo "BugPath Mode: INACTIVE"
fi
```

## Design Critic BugPath Logic

```bash
# API-change signals that re-activate Design Critic in Bug Fix Mode:
# Scan the full branch range, not just the last commit (HEAD~1 misses API changes in earlier commits).
BASE=$(git merge-base HEAD origin/dev 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || echo "HEAD~1")
git diff "$BASE"..HEAD | grep -qE '^\+.*(export (default )?(class|interface|type|function|const)|public [a-zA-Z]+\()'
```

If any signal matches: activate and prefix triage line with `⚠️ Design Critic re-activated on bug fix (API-change signal detected).`
If no signal: state `Design Critic: SKIPPED (Bug Fix Mode — no API-change signals)`.

## Executive Summary Template

```
┌────────────────────────────────────────────────────────────────────┐
│  MODE: Bug Fix Review [9.2 threshold]  |  BRANCH: fix/proj-1234  │
│  VERDICT: REJECT [6.5/10]  |  2 Critical, 1 Important, 3 Minor   │
│  ACTION: Fix 2 Critical findings. DO NOT merge.                   │
│  BugPath Coverage: INSUFFICIENT (2/4 dimensions) → cap 6.5       │
└────────────────────────────────────────────────────────────────────┘
```

Standard mode (no BugPath row):
```
┌─────────────────────────────────────────────────────────────────────┐
│  MODE: Standard Review [7.0 threshold]  |  BRANCH: feat/new-api   │
│  VERDICT: PASS [8.5/10]  |  0 Critical, 1 Important, 2 Minor      │
│  ACTION: Address Important finding before merge (non-blocking).    │
└─────────────────────────────────────────────────────────────────────┘
```

VERDICT choices: `PASS`, `PASS_WITH_NITS`, `PASS_WITH_FIXES`, `REJECT`. ACTION is a single plain-English sentence.

## Severity Definitions

- **Critical** = broken RIGHT NOW if shipped (wrong output, data loss, crash, security hole)
- **Important** = breaks UNDER CONDITIONS (missing guard, incomplete fix, correctness risk)
- **Minor** = works but violates standards (style, naming, missing docs/tests, observability gaps)
- **Elevate to Important** when operator-visible signal is wrong/missing (dead metric, blinded alarm) OR separately-actionable failure cause folded into generic metric/alarm
- Downgrade process gaps (e.g., "no tests added") from Critical to Minor: `[Reclassified: Critical → Minor — missing tests are a standards gap, not a production defect]`
- True convergent findings promoted to at least Important; echo convergent retain original severity.

## Correlated-Failure Detection

**Evidence overlap:** ≥3 reviewers cite same file+line range for their ONLY finding → `⚠️ CORRELATED EVIDENCE — expand to adjacent modules`.
**Phrasing similarity:** 2+ reviewers use near-identical phrasing for different findings → `⚠️ ECHO REASONING — re-examine from different entry`.
**Clean-sweep suspicion:** all reviewers zero findings → `⚠️ UNANIMOUS CLEAN — verify different evidence slices`.

Flags trigger expanded scope, not verdict changes.

## Run Envelope Schema

Schema for `.cr-battery-runs/<HEAD-sha>.json`:

```json
{
  "run_timestamp": "<ISO 8601 UTC>",
  "head_sha": "<git rev-parse HEAD>",
  "verdict": "PASS | PASS_WITH_NITS | PASS_WITH_FIXES | REJECT",
  "score": 9.30,
  "rounds": 1,
  "bugpath_verdict": {
    "path_coverage": "FULL | PARTIAL | INSUFFICIENT | SCOPE-SKIP | N/A",
    "dimensions": {
      "root_cause": "VERIFIED | UNVERIFIABLE | MISSING",
      "fix_coverage": "VERIFIED | PARTIAL | MISSING",
      "sibling_scan": "VERIFIED | FOUND-N | MISSING",
      "regression_test": "VERIFIED | MISSING"
    },
    "score_cap": null
  },
  "findings": [
    {
      "reviewer": "Defect Finder",
      "dimension": "Correctness",
      "severity": "important",
      "file": "src/foo.ts", "line": 42,
      "issue": "...", "regressions_risked": "...", "durable_check": "...",
      "claim": "no producer for Metrics.Success",
      "evidence": {
        "command": "grep -rcE 'Metrics\\.Success' src/ | awk -F: '$2>0' | head -1",
        "expectation": { "type": "absent" },
        "verifiable": true,
        "rationale": "if any line is emitted, a producer exists"
      }
    }
  ],
  "clean_dimensions": [
    {
      "reviewer": "Standards Enforcer",
      "dimension": "Tests",
      "claim": "no new test files outside tests/",
      "evidence": {
        "command": "git diff --name-only --diff-filter=A main..HEAD -- '*.test.ts' ':!tests/'",
        "expectation": { "type": "absent" },
        "verifiable": true
      }
    }
  ]
}
```

Every finding AND every clean-dimension verdict must carry an `evidence` block. `verifiable: false` is reserved for genuine judgment calls (race conditions, design smells) not re-executable deterministically; capped at 7.0 by the verifier.

## Verifier Details

**Expectation types:** `count` (e.g. `">0"`, `"==0"`), `exit_code` (integer), `match` (regex on stdout, max 256 chars), `absent` (passes iff stdout has zero non-blank lines), `exact` (string equality after trim).

**Verifier replay:** `tools/run-battery.sh` invokes `tools/verify-cr-battery-evidence.js` on the freshly-written envelope. Bug Fix Mode: mandatory. Standard Mode: graceful degrade (skipped if `.cr-battery-runs/` absent). Verifier re-executes every `evidence.command`, compares to declared expectation. FALSIFIED claim (5.0 cap) aborts sentinel write; UNVERIFIABLE claim (7.0 cap). Exit codes: `0`=all verified or unverifiable; `1`=falsification; `2`=usage/IO/parse error.

## See Also

- `skill.md` -- main procedure (Phases 0-6)
- `DESIGN.md` -- architecture rationale and validation results
- `PRD.md` -- product requirements
- `gap-analysis.md` -- candidate pattern pipeline for closing reviewer gaps
- `candidates/` -- graduated and proposed patterns
- `docs/cr-battery/finding-lifecycle-design.md` -- design problem for the deferred Finding Lifecycle flywheel (preservation ships in this MR; tagging + aggregation deferred)
