# Artifact Size Budget Regression Tests

Byte-size guards for always-on context and activation-time skill inventory.
Listings and SessionStart output tax every session. A `skill.md` body costs
context only after activation, but unchecked growth still makes the loaded
workflow expensive. These tests keep the two surfaces separate.

## What is measured

`Kind` determines how the measurement tool reads the artifact:
- `process-output` -- runs the command, captures stdout, measures byte count.
- `file` -- stats the path, measures byte count.
- `metric` -- runs a command that emits a JSON object, reads one numeric
  `json_key`, and compares that value to the row's baseline. This guards
  counts and rates as well as byte sizes. The existing `size_bytes` field is
  retained for manifest-schema compatibility.

`Host-only: Yes` means the artifact path does not exist in CI; the test is
skipped in CI and runs only on developer machines.

| Artifact class | Kind | Tolerance | Host-only |
|---|---|---|---|
| Augment core rule | file | 5% | Yes |
| Projected skill listing and counts | metric | 5% | No |
| Installed Claude listing and SessionStart payload | metric | 5% | Yes |

Repo metrics are committed and run in CI. Host-only metrics are also committed
as aggregate values, but the measurement tool skips them whenever `CI` is set.
The raw host listing and hook output are never committed.

Repo metrics fail closed. A failed command, invalid JSON, missing key,
non-numeric value, or non-finite value fails the run. The manifest also holds a
zero parse-failure ceiling and a floor on scanned skill files, so parser drift
cannot appear as a cost reduction. Host-only measurements retain MISS/skip
behavior only when skipped in CI. Once a required host metric is attempted,
acquisition failure remains blocking even in advisory mode.

The installed Augment bootstrap command is deferred because it writes host
session and skill-index state. It must expose a side-effect-free output mode
before this harness measures it.

## Files

| Path | Purpose |
|---|---|
| `tests/harness/artifact-baselines.json` | Committed baseline manifest |
| `tools/measure-artifact-sizes.sh` | Measurement + compare + rebaseline tool |
| `tools/resident-cost-report.py` | CI-safe repo projection and local host report |
| `tools/frontmatter-batch.js` | Batch bridge to the canonical frontmatter parser |
| `tools/optimization-baseline/resident-baseline-20260917.json` | Aggregate pre-simplification snapshot |
| `tests/harness/artifact-budgets.bats` | bats suite |

## Running locally

```bash
bats tests/harness/artifact-budgets.bats
bash tools/measure-artifact-sizes.sh --dry-run
python3 tools/resident-cost-report.py --repo --text
python3 tools/resident-cost-report.py --host --text
```

## Rebaseline workflow

Run this only as part of an intentional, reviewed change. Rebaseline before
committing the manifest update:

```bash
bash tools/measure-artifact-sizes.sh --rebaseline --reason "why the change"
```

Rebaseline refuses to replace any row that currently breaches its comparison
contract. For an intentional, separately reviewed contract change, authorize
that artifact ID explicitly:

```bash
bash tools/measure-artifact-sizes.sh --rebaseline \
  --allow-breach resident-listing-bytes \
  --reason "reviewed budget or integrity-contract change"
```

Repeat `--allow-breach <artifact-id>` for each reviewed breach. Every printed
`OVERRIDE` row must belong to the reviewed change; unrelated breaches still
abort the update. The flag does not override missing, malformed, or otherwise
unavailable measurements, which also abort the entire update.

The default updates repo rows only. It cannot bless unrelated drift in the
developer's mutable Claude installation. Rebaseline host-only rows only when
the host itself is the reviewed change:

```bash
bash tools/measure-artifact-sizes.sh --rebaseline --include-host \
  --reason "reviewed host installation change"
```

Then commit the updated `tests/harness/artifact-baselines.json`. Do NOT
rebaseline to silence a budget alert; fix the regression first.
Required acquisition errors abort before any manifest bytes or history change.
Artifact IDs must be non-empty strings and unique; malformed or duplicate IDs
abort before any measurement command runs.

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

Promote to `strict` only after the checklist below has seven consecutive days
of clean CI evidence.

## Drift catcher

The `drift catcher` bats test enumerates `~/.augment/rules/*.md` (when
present) and asserts every file has a manifest entry. The committed
`augment-core-rule` row activates this guard. A new rule without a manifest
entry fails locally; CI skips the check because the host directory is absent.

To add a new rule file to the manifest: measure it, then add an entry to
`tests/harness/artifact-baselines.json` under `artifacts`. Then run
`--rebaseline` to confirm sizes match.

## Adding a new artifact class

1. **Measure the artifact** to get `size_bytes` and `sha256`:
   ```bash
   # File:
   wc -c < ~/.augment/rules/my-new-rule.always.md
   shasum -a 256 ~/.augment/rules/my-new-rule.always.md | awk '{print $1}'

   # Process output (use only a documented read-only command):
   your-tool --print-only | wc -c
   your-tool --print-only | shasum -a 256 | awk '{print $1}'
   ```
2. Add an entry to `tests/harness/artifact-baselines.json`:
   - `id`: unique kebab-case identifier
   - `kind`: `process-output`, `file`, or `metric`
   - `command` + `json_key`: required for `metric`; stdout must be a JSON object
   - `comparison`: optional `maximum` (default), `minimum`, or `exact`
   - `size_bytes`, `sha256`: from step 1
   - `tolerance`: fraction (e.g. `0.05` for 5%)
   - `host_only`: `true` if the path/command is not available in CI
3. For a new metric source or parser path, add a deterministic fixture assertion
   to `tests/harness/artifact-budgets.bats`. Existing source keys need no per-row
   test because the measure script evaluates every manifest row.
4. Run `bats tests/harness/artifact-budgets.bats` locally to confirm the new row passes.
5. Commit the manifest, implementation, fixture, and docs together.

## Resident-cost report contract

`--repo` recursively scans `skills/**/skill.md` and is safe for CI. It reports
the projected listing bytes/tokens, automatic/manual/internal counts, maximum
description and skill sizes, descriptions over 250 characters, duplicate
frontmatter names, and parse failures. `coordination.internal` remains counted
in the listing because it is repository metadata, not a Claude visibility
control. Only `disable-model-invocation` removes an entry from resident cost.
All metadata is parsed through `lib/frontmatter.js`.

`--host` scans the installed Claude skills and commands plus enabled plugin
skills, including symlinked skill directories; inode ancestry prevents symlink
cycles. It groups recorded SessionStart outputs by hook event ID, decodes
`hookSpecificOutput.additionalContext`, and reports injected context bytes and
estimated tokens. Raw stdout bytes remain diagnostic only. Transcript files
are inspected newest-first and read backward in chunks. The scan fails closed
if it exceeds 2,048 files, 32 MiB read, or five seconds; the time limit is
owned by the parent process, which terminates the scan worker. Older history is
skipped once it cannot contain a newer event. Router metrics use a separate
one-second worker and sample at most the latest 1,000 records / 1 MiB; the
report exposes sampled records, bytes read, and whether the window truncated
history. The report never executes installed hooks.

Host discovery resolves `CLAUDE_HOME_OVERRIDE/.claude`, then
`CLAUDE_CONFIG_DIR`, then `$HOME/.claude`. Enabled plugins require a valid
registry entry and existing install path; malformed frontmatter or incomplete
plugin discovery fails the report instead of appearing as a cost reduction.

The committed fixture deliberately uses `dot-claude/`, not `.claude/`, so repo
skill discovery cannot mistake fixture skills for live project skills. Tests
copy it to an isolated temporary home before exercising `--host`.

## Troubleshooting

**CI job is red (strict mode breach):**
1. Check whether the size increase is intentional (new skill, expanded rule file).
2. If intentional and reviewed: rebaseline with `--allow-breach <artifact-id>`
   for each breached row, inspect every `OVERRIDE` line, then commit.
3. If not intentional: identify what grew (`--dry-run`), revert the bloat, push.
4. Do NOT rebaseline to silence an alert for unreviewed growth.

**Host transcript scan hits a resource limit:**
Start a fresh Claude Code session, let SessionStart finish, and rerun the host
report; the newer event usually lets the scanner skip older large transcripts.
If discovery still exceeds the file or time limit, move the oldest closed-session
`.jsonl` files from the Claude config's `projects/` directory to a private backup
outside `projects/`, then rerun. Do not delete the active session, commit the
backup, or raise the scanner limits; the bounds are fail-closed by design.

**Drift catcher fails locally:**
A rule file in `~/.augment/rules/` has no manifest entry. Follow "Adding a
new artifact class" above to add it, then commit.

**Advisory run passes but size seems wrong:**
Run `bash tools/measure-artifact-sizes.sh --dry-run` locally. Compare the
printed sizes against the baseline and budget columns.

## Advisory to strict promotion checklist

- [ ] At least seven consecutive days of CI runs are linked below
- [ ] Every linked run contains zero advisory budget breaches
- [ ] No pending rebaselines in flight on any open PR
- [ ] Flip `BUDGET_MODE` to `strict` in the workflow env

Advisory mode exits successfully even when it reports a breach. Promotion is
therefore manual and evidence-based; a green CI badge alone is insufficient.
Acquisition errors still fail CI. The Bats comparison prints each row to the CI
log so advisory breaches remain visible.

| Date | CI run | Budget breaches | Reviewer |
|---|---|---:|---|
| _none recorded_ | | | |
