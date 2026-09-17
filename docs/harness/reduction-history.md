# Reduction history

Rolling log of before/after sizes for every `kernel-split` application in
this repo. This file is the single source of truth for the harness README
ledger; any diagram or dashboard is downstream of the numbers here.

## Pre-simplification resident baseline

The aggregate baseline captured before any simplification work is committed at
`tools/optimization-baseline/resident-baseline-20260917.json`. Its key costs are
60,725 installed-listing bytes (about 15,181 tokens), 4,049 bytes of injected
SessionStart context (about 1,012 tokens), 136 duplicate installed entries, and
122 projected automatic repo skills.

`tools/resident-cost-report.py --repo` supplies the CI-safe budget metrics.
`--host` supplies the local installed-state comparison. The listing is
always-on cost. A `skill.md` body is activation-time cost and is not resident
until that skill loads. Record both surfaces rather than calling them both
"resident."

## Aggregate phase ledger

Append one row at each phase gate. `Body bytes` is the sum of repository
`skill.md` files; it is activation inventory, not always-on context.

| Phase | Date | Commit | Listing bytes | Auto skills | Body bytes | Host listing bytes | SessionStart bytes | Host duplicate entries | Note |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| Pre-simplification | 2026-09-17 | `0216a9ab` | 32,840 | 122 | 1,019,947 | 60,725 | 4,049 | 136 | rollback tag `pre-simplification` |

## How to add a row

1. Record the pre-split byte count: `wc -c skills/<domain>/<skill>/skill.md`
2. Apply the split: `bash tools/skill-partitioner apply ...`
3. Record the post-split kernel byte count: `wc -c skills/<domain>/<skill>/skill.md`
4. Reduction percentage: `(before - after) * 100 / before`
5. Add a row below in `Applied` (append, do not reorder).
6. If the split legitimately failed the 40% target, put it under `Deferred` with
   the reason.

Percentages are the net reduction of the activation-time kernel vs the
pre-split `skill.md`. Bytes moved to `reference.md` do not count toward the
activated skill body.

## Applied

| Skill | Before | Kernel after | Reduction | Note |
|---|---|---|---|---|
| progressive-harsh-review | 18018 | 6447 | 64% | Persona weights, vetoes, verdicts, convergence, anti-recursion, and sentinel stay resident; project-floor detail, report format, and failures load from `reference.md` through trusted managed tooling. |

The PHR compression golden is intentionally not regenerated here. P1h removes
exact-text compression goldens while retaining structural checks, so refreshing
that soon-to-be-deleted fixture would create throwaway churn. Final integration
also depends on P1d making the operative-move detector reference-aware.

## Deferred (score under 40% after safety-correct curation)

| Skill | Reason | Follow-up |
|---|---|---|
| _none yet_ | | |

## Regenerate totals

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("docs/harness/reduction-history.md").read_text()
rows = re.findall(r"^\| [^|_]+\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|", p, re.M)
before = sum(int(b) for b, _ in rows)
after  = sum(int(a) for _, a in rows)
if before:
    print(f"Applied splits: {len(rows)}")
    print(f"Cumulative: {before} B -> {after} B = {before - after} B saved ({(before - after) * 100 // before}%)")
else:
    print("No applied splits recorded.")
PY
```
