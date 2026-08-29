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

The [`spc-kernel-split`](../../skills/engineering/spc-kernel-split/skill.md)
skill (applied via [`tools/skill-partitioner`](../../tools/skill-partitioner))
splits a monolithic skill into a small resident **kernel** -- loaded on every
session -- plus an on-demand **reference** (a `reference.md` companion) that
loads only when a specific lookup is needed.

The kernel/reference boundary is drawn by keyword scoring on each section:
`auth`, `gate`, `verify`, `secret`, `never`, `must`, and similar signals push
sections into the kernel; `example`, `walkthrough`, `troubleshoot`, `catalog`
push them to the reference. Ambiguous sections land in a third file for human
review before `apply`.

> **Safety floor (non-negotiable):** hard gates, "never" rules, and
> run-every-time decision inputs always stay in the kernel. They are never
> demoted to the reference, regardless of size. A split that moves a gate out
> of the kernel is wrong, even if it scores a larger reduction.

### 3. Regulator -- guard

[`docs/harness/artifact-budgets.md`](artifact-budgets.md) plus
[`tests/harness/artifact-budgets.bats`](../../tests/harness/artifact-budgets.bats)
hold the line against regrowth. Byte-size budgets with a committed baseline
manifest catch a skill that shrinks today from ballooning again tomorrow.
`BUDGET_MODE=advisory` prints a warning; `BUDGET_MODE=strict` fails CI.

The context-budget bats suite
([`tests/engineering/spc-kernel-split-context.bats`](../../tests/engineering/spc-kernel-split-context.bats))
enforces the per-skill kernel byte budget for every skill that has been split.
Add a new row when you split another skill; do not remove or bump a row
without recording the reason in the test comment above it.

The loop then returns to the Sensor: measure, shrink, guard -- continuously,
every session and every commit.

## Reduction ledger

[`reduction-history.md`](reduction-history.md) is the single source of truth
for measured reductions. Every application of `spc-kernel-split` appends a row
with before/after byte counts and the resulting percentage. Trust the ledger,
not any static graphic -- infographics can lag a split until re-exported.

The ledger starts empty. Populate it as you apply the actuator.

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
  input must stay resident even if the raw partitioner score suggests otherwise.
  The safety floor overrides the score.

Do not chase percentages past the safety floor. When the split does not clear
the 40% target after safety-correct curation, record the reason in the
reduction ledger's `Note` column and defer.

## Related docs

| Doc | What's in it |
|---|---|
| [`reduction-history.md`](reduction-history.md) | Per-split ledger and cumulative savings |
| [`artifact-budgets.md`](artifact-budgets.md) | Regulator: budget regression tests and rebaseline workflow |
