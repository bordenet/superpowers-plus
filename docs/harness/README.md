# The AI-Harness

A closed feedback loop that treats the instruction context loaded into every
agent session as a measured, budgeted resource instead of invisible overhead.
Each `skill.md` an agent loads costs resident context window on every LLM call,
so unchecked growth silently taxes every session. The harness makes that cost
visible, shrinks it safely, and guards it against regrowth.

## The three stages

Every box below maps to a real artifact in this repo, not a metaphor.

### 1. Sensor -- measure

[`tools/skill-size-audit.sh`](../../tools/skill-size-audit.sh) scans every
`skills/**/skill.md`, ranks them by byte count, and flags any that exceed the
fleet-wide threshold (default 10,240 bytes / 10 KB). It exits non-zero when one
or more skills are over budget, so bloat becomes a visible signal instead of a
silent accumulation.

```bash
bash tools/skill-size-audit.sh                 # human-readable table
bash tools/skill-size-audit.sh --top 10        # 10 largest only
bash tools/skill-size-audit.sh --json          # machine-readable
```

### 2. Actuator -- shrink

The [`kernel-split`](../../skills/engineering/kernel-split/skill.md)
skill (applied via [`tools/skill-partitioner`](../../tools/skill-partitioner))
splits a monolithic skill into a small activation-time **kernel** -- loaded
when the skill is selected -- plus an on-demand **reference** (a
`reference.md` companion) that loads only when a specific lookup is needed.

The kernel/reference boundary is drawn by keyword scoring on each section:
`auth`, `gate`, `verify`, `secret`, `never`, `must`, and similar signals push
sections into the kernel; `example`, `walkthrough`, `troubleshoot`, `catalog`
push them to the reference. Ambiguous sections land in a third file for human
review before `apply`.

> **Safety floor (non-negotiable) -- a RULE FOR THE SPLIT AUTHOR, not a
> property of the actuator.** Hard gates, "never" rules, and run-every-time
> decision inputs must stay in the kernel. A split that moves a gate out of the
> kernel is wrong, even if it scores a larger reduction.
>
> **The partitioner does NOT enforce this, and you must not rely on it to.**
> `tools/skill-partitioner` scans the full section body for hard-gate keywords
> only inside a heading matching `failure mode`. Every other section is scored
> on `heading + a 200-character preview`, so a `## Examples and edge cases`
> section scores -2 and goes to the reference no matter how many NEVER rules
> sit past character 200. `apply` adds no safety assertion. Verify the floor by
> reading the proposed kernel, every time.
>
> This was learned the hard way: progressive-harsh-review shipped a split that
> demoted its anti-rubber-stamping rules (the <=7 score-inflation cap, the
> REGRESSION flag, Operational-Risk veto eligibility) to the reference, where
> they loaded only on a path a rubber-stamping review never takes. They were
> moved back resident. See `reduction-history.md`.

### Test-suite machinery (added 2026-09-18)

Four pieces landed with the Phase-2A splits and are easy to mis-trust:

| Piece | What it does | Gotcha |
|---|---|---|
| `tools/test-tree-guard.sh` + `test/.test-artifacts` | Sweeps declared in-tree test artifacts before a run, then snapshots/verifies the tree and FAILS on any undeclared create or modify | A test may write inside the repo ONLY if its exact path is declared. `sweep` refuses traversal, absolute, tilde, and a glob in the first path component -- a bare `*` once wiped a working tree and reported "tree healed" |
| `test/.slow-bats` | Excludes named bats files from `--fast` | `--fast` is what the pre-push gate runs under `timeout 300`. A file listed here does NOT run pre-push |
| `bats tests/ (serial)` | Sixth suite; runs the 29 files under `tests/` | **Full-suite only, never `--fast`.** Runs SERIALLY -- `tests/` has proven cross-file interference and was never audited for `--jobs` |
| `bats -r` | Required for the `tests/` suite | `bats <dir>` does NOT recurse. Without `-r` it ran 22 top-level files, silently skipped 7 subdirectories including every kernel-split safety suite, and reported 381 tests green |

**Consequence worth stating plainly:** because `tests/` is excluded from
`--fast`, BOTH regulator suites -- `tests/harness/artifact-budgets.bats` and
`tests/engineering/kernel-split-context.bats` -- do **not** run in the pre-push
gate. They run in the full local suite and in CI. Do not read a green pre-push
as "budgets and ledgers verified."

### 3. Regulator -- guard

[`docs/harness/artifact-budgets.md`](artifact-budgets.md) plus
[`tests/harness/artifact-budgets.bats`](../../tests/harness/artifact-budgets.bats)
hold the line against regrowth. Byte-size budgets with a committed baseline
manifest catch a skill that shrinks today from ballooning again tomorrow.
`BUDGET_MODE=advisory` prints a warning; `BUDGET_MODE=strict` fails CI.

The context-budget bats suite
([`tests/engineering/kernel-split-context.bats`](../../tests/engineering/kernel-split-context.bats))
enforces the per-skill kernel byte budget for every skill that has been split.
Add a new row when you split another skill; do not remove or bump a row
without recording the reason in the test comment above it.

The loop then returns to the Sensor: measure, shrink, guard -- continuously,
every session and every commit.

## Reduction ledger

[`reduction-history.md`](reduction-history.md) is the single source of truth
for measured reductions. Every application of `kernel-split` appends a row
with before/after byte counts and the resulting percentage. Trust the ledger,
not any static graphic -- infographics can lag a split until re-exported.

The ledger contains the aggregate pre-simplification baseline and the `Applied`
split table. Append a row per split; do not reorder. Report **Retained**
(kernel + reference, recoverable at runtime) separately from **Deleted** (gone
from the skill entirely) -- conflating them once hid a real regression.

## Config precedence resolver (harness sibling)

[`tools/resolve-config.sh`](../../tools/resolve-config.sh) is a small
four-tier config resolver that lives beside the harness. Any script that
previously encoded its own env-var / dotfile / global-install fallback can
call `resolve-config get <kind> <key>` instead:

1. `SP_CONFIG_<KIND>_<KEY>` environment variable
2. `<nearest .git parent>/.codex-config/<kind>/<key>` (project-local)
3. Repos listed in `~/.codex/repos.txt` (repo-source)
4. `~/.codex/config/<kind>/<key>` (global install)

Valid kinds: `mcp`, `env`, `allowlist`, `hook`, `template`. Coverage:
`tests/tools/config-precedence.bats`.

## The savings have a ceiling, and we measure it honestly

Not every large skill is a good split candidate:

- Skills whose bulk is one monolithic section score near zero on the partitioner
  and cannot be auto-split without restructuring first.
- Skills whose "reference-looking" content is actually a run-every-time decision
  input must stay in the activation-time kernel even if the raw partitioner
  score suggests otherwise. The safety floor overrides the score.

Do not chase percentages past the safety floor. When the split does not clear
the 40% target after safety-correct curation, record the reason in the
reduction ledger's `Deferred` table under `Reason` and defer.

## Related docs

| Doc | What's in it |
|---|---|
| [`reduction-history.md`](reduction-history.md) | Per-split ledger and cumulative savings |
| [`artifact-budgets.md`](artifact-budgets.md) | Regulator: budget regression tests and rebaseline workflow |
| [`ip-audit-evidence.md`](ip-audit-evidence.md) | Scan call sites, aggregate block evidence, and the no-weakening decision |
