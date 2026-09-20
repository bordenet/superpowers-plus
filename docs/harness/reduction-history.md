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

A split does two different things, and this ledger reports them separately
because conflating them hid a real regression once already. **Moved** bytes
leave the kernel but stay in the skill unit, reachable through the section
loader. **Deleted** bytes leave the skill entirely -- prose compressed,
examples dropped, tables condensed. Only `Retained` is recoverable at runtime;
`Deleted` is a permanent content decision and needs its own justification.
Earlier revisions of this table described all three splits as content that
"moved to `reference.md`", which was false for roughly half of PHR.

## Applied

| Skill | Before | Kernel after | Reference | Retained | Deleted | Reduction | Note |
|---|---|---|---|---|---|---|---|
| progressive-harsh-review | 18018 | 8480 | 1602 | 10082 | 7936 (44%) | 52% | Persona weights, vetoes, verdicts, convergence, anti-recursion, the sentinel rule, AND the verbatim `## Failure Modes` table stay resident; project-floor detail and the report format load from `reference.md` through trusted managed tooling. The Failure Modes table was moved BACK into the kernel on review: loading it on demand put the anti-rubber-stamping rules (the <=7 score-inflation cap, the REGRESSION flag, Operational-Risk veto eligibility) behind the exact condition they exist to prevent. Deleted: the three long-form `### Persona N` lens definitions and `## Artifact-Aware Persona Mapping`, condensed into one persona dimension table per the approved Phase 2A plan. 2026-09-20: llm-skill-review found the kernel-split loader's installed-path precedence was reversed (`.agents`->`.codex`->`.claude` instead of the canonical `.claude`->`.codex`->`.agents`) and bound the wrong loader to a source-checkout fallback -- both fixed by replacing the block with the exact canonical template debate/context-ferry already use (also removes an unguarded `cmp` dependency that hard-failed on the sanctioned `--skip-augment` staleness state). Also fixed a stale "detailed failure recovery" phrase in the Reference loading prose that resolved to no real heading. |
| context-ferry | 10688 | 7122 | 3116 | 10238 | 450 (4%) | 33% | Full/PreCompact routing, durable-state priority, safety invariants, origin-bound reference loading, AND the verbatim `## Failure Modes` table remain resident; the output scaffold, output path, and fidelity/privacy detail live in `reference.md`. Failure Modes moved back resident for the same reason as PHR. Deleted: prose compression of step narration. 2026-09-20: llm-skill-review found (S0) the kernel-split had silently replaced Step 1's explicit checkbox-toggle/`BLOCKED:`-comment/write-back-to-disk mechanics with the unoperationalized verb "track" -- restored. Also added `Output path` to the routing table (was orphaned, unreachable via the documented loader) and a sensitive-content-scan trigger to the PreCompact abbreviated path, which previously never loaded that check at all. |
| debate | 13660 | 7703 | 5023 | 12726 | 934 (6%) | 43% | Mandatory routing and origin-bound installed/source reference loading remain resident; detailed protocols and examples moved to `reference.md`. Deleted: worked example prose and duplicated persona text now sourced from PHR. 2026-09-18: `## Rationalizations to reject` moved back resident from reference.md (matches PHR/context-ferry precedent -- anti-rubber-stamping content must not live behind the on-demand-load condition it prevents). 2026-09-20: llm-skill-review found the kernel-split had silently DELETED (not relocated) the REQUIRED `adversarial-search` invocation, and the hostile-review dispatch step named no concrete tool -- both restored. Added a resident `## Failure Modes` table (debate had none, unlike its two Phase-2A siblings). Renumbered reference.md's `### Step N` subheadings, which had drifted onto the pre-split 5-step scheme while a body sentence already used the current 6-step scheme ("Step 3 of 6") in the same section. |

**Branch shorthand used below:** `P1h` = `chore/simplify-p1h-test-pruning`;
`P1d` = `chore/simplify-p1d-debug-helpers`; `P2A` = the Phase 2A kernel-split
batch (the PHR/context-ferry/debate rows above) -- not a branch, committed
directly to `dev`. As of 2026-09-18, `P1h` and `P1d` both exist on `origin`
at `ced54426` and `aec3b808` respectively (`git rev-parse <branch>
origin/<branch>` returns identical SHAs for both); verify directly rather
than trusting a status claim in prose, since branch state changes.

The PHR compression golden is intentionally not regenerated here. P1h removes
exact-text compression goldens while retaining structural checks, so refreshing
that soon-to-be-deleted fixture would create throwaway churn. Final integration
also depends on P1d making the operative-move detector reference-aware.

### Combined-tree merge requirement (transient -- remove this subsection once P1h merges)

When P1h fixture hardening merges, retain Debate's P2A `expected_substrings`, `verified_by`, `verified_at`, and `merge_requirement` fields while adopting P1h's fail-closed fixture validation and trigger-refresh behavior. This is a cross-branch coordination note, not permanent ledger content -- delete it the day P1h lands (merged or abandoned), whichever comes first.

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
