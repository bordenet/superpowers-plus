# Artifact Size Budget Regression Tests

Byte-size guards for the always-on artifacts loaded into every agent session.
Each artifact consumes resident context window on every LLM call; unchecked
growth silently taxes every session. These tests catch regressions before
they accumulate.

## What is measured

`Kind` determines how the measurement tool reads the artifact:
- `process-output` -- runs the command, captures stdout, measures byte count.
- `file` -- stats the path, measures byte count.

`Host-only: Yes` means the artifact path does not exist in CI; the test is
skipped in CI and runs only on developer machines.

| Artifact class | Kind | Tolerance | Host-only |
|---|---|---|---|
| Bootstrap payload | process-output | 10% | No (MISS-skips if tool absent) |
| Per-host rule files (`~/.augment/rules/*.md`, `~/.claude/*`) | file | 5% each | Yes |

The manifest ships empty of host-specific rows. Populate it on your machine
with `--rebaseline` (see below) so drift is caught against your own baseline.

## Files

| Path | Purpose |
|---|---|
| `tests/harness/artifact-baselines.json` | Committed baseline manifest |
| `tools/measure-artifact-sizes.sh` | Measurement + compare + rebaseline tool |
| `tests/harness/artifact-budgets.bats` | bats suite |

## Running locally

```bash
bats tests/harness/artifact-budgets.bats
bash tools/measure-artifact-sizes.sh --dry-run
```

## Rebaseline workflow

Run this only when an intentional, reviewed size change has been merged:

```bash
bash tools/measure-artifact-sizes.sh --rebaseline --reason "why the change"
```

Then commit the updated `tests/harness/artifact-baselines.json`. Do NOT
rebaseline to silence a budget alert -- fix the bloat first.

The `--rebaseline` flag requires an interactive terminal (stdin tty check) to
prevent CI pipelines from accidentally overwriting committed baselines.
`FORCE_REBASELINE=1` bypasses the tty check and is only for automated tests
that specifically validate the rebaseline mechanism itself, not for general
scripted rebaselining in CI.

## BUDGET_MODE

| Value | Behavior | Default location |
|---|---|---|
| `strict` | Non-zero exit on any budget breach | Local (script default) |
| `advisory` | Prints warning, exits 0 | CI while gaining confidence |

Override per invocation:

```bash
BUDGET_MODE=advisory bats tests/harness/artifact-budgets.bats
BUDGET_MODE=advisory bash tools/measure-artifact-sizes.sh
```

Promote to `strict` in CI once several runs have gone clean.

## Drift catcher

The `drift catcher` bats test enumerates `~/.augment/rules/*.md` (when
present) and asserts every file has a manifest entry. If a new rule file is
added without a corresponding manifest entry, the test fails locally. It is
skipped in CI where the host directory is absent.

To add a new rule file to the manifest: measure it, then add an entry to
`tests/harness/artifact-baselines.json` under `artifacts`. Then run
`--rebaseline` to confirm sizes match.

## Adding a new artifact class

1. **Measure the artifact** to get `size_bytes` and `sha256`:
   ```bash
   # File:
   wc -c < ~/.augment/rules/my-new-rule.always.md
   shasum -a 256 ~/.augment/rules/my-new-rule.always.md | awk '{print $1}'

   # Process output:
   node $HOME/.codex/superpowers-augment/superpowers-augment.js bootstrap | wc -c
   node $HOME/.codex/superpowers-augment/superpowers-augment.js bootstrap | shasum -a 256 | awk '{print $1}'
   ```
2. Add an entry to `tests/harness/artifact-baselines.json`:
   - `id`: unique kebab-case identifier
   - `kind`: `process-output` or `file`
   - `size_bytes`, `sha256`: from step 1
   - `tolerance`: fraction (e.g. `0.05` for 5%)
   - `host_only`: `true` if the path/command is not available in CI
3. Add a `@test "<id> within budget"` block to `tests/harness/artifact-budgets.bats`.
4. Run `bats tests/harness/artifact-budgets.bats` locally to confirm the new test passes.
5. Commit both files together.

## Troubleshooting

**CI job is red (strict mode breach):**
1. Check whether the size increase is intentional (new skill, expanded rule file).
2. If intentional: rebaseline, commit, push.
3. If not intentional: identify what grew (`--dry-run`), revert the bloat, push.
4. Do NOT rebaseline to silence an alert for unreviewed growth.

**Drift catcher fails locally:**
A rule file in `~/.augment/rules/` has no manifest entry. Follow "Adding a
new artifact class" above to add it, then commit.

**Advisory run passes but size seems wrong:**
Run `bash tools/measure-artifact-sizes.sh --dry-run` locally. Compare the
printed sizes against the baseline and budget columns.

## Advisory to strict promotion checklist

- [ ] CI job green in advisory mode for at least a week
- [ ] Zero budget breaches across all advisory CI runs
- [ ] No pending rebaselines in flight on any open PR
- [ ] Flip `BUDGET_MODE` to `strict` in the workflow env
