# Reduction history

Rolling log of before/after sizes for every `spc-kernel-split` application in
this repo. This file is the single source of truth for the harness README
ledger; any diagram or dashboard is downstream of the numbers here.

## How to add a row

1. Record the pre-split byte count: `wc -c skills/<domain>/<skill>/skill.md`
2. Apply the split: `bash tools/skill-partitioner apply ...`
3. Record the post-split kernel byte count: `wc -c skills/<domain>/<skill>/skill.md`
4. Reduction percentage: `(before - after) * 100 / before`
5. Add a row below in `Applied` (append, do not reorder).
6. If the split legitimately failed the 40% target, put it under `Deferred` with
   the reason.

Percentages are the net reduction of the resident kernel vs the pre-split
`skill.md`. Bytes moved to `reference.md` do not count as resident cost.

## Applied

| Skill | Before | Kernel after | Reduction | Note |
|---|---|---|---|---|
| _none yet_ | | | | |

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
