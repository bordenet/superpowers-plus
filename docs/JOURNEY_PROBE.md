# Journey Probe

`tools/journey-probe.sh` measures whether daily coding journeys activate the
expected skills and how much model context they consume. P1g establishes the
harness contract; a future authenticated P1g run will establish the baseline.
Run the same fixtures after Phase 2, then compare the two JSONL files.

The default mode calls the authenticated `claude` CLI and can consume paid
tokens. The validation, listing, dry-run, saved-stream parsing, and comparison
modes are offline. Live mode is deliberately bounded by a per-run timeout,
turn limit, and `--max-budget-usd` cap. The default budget cap is USD 0.50 per
run.

Current evidence is fake-Claude-only. No authenticated P1g baseline has been
captured, so the Phase 2 live comparison gate is unsatisfied. CI exercises the
live-mode control path with a local fake `claude` executable, plus all offline
paths; it makes no authenticated, paid-model, or network calls.

## Fixture contract

Prompt fixtures live in `test/fixtures/journeys/`. Each file must:

1. Use a name in the form `J<number>[suffix]-<slug>.txt`.
2. Have a unique journey ID.
3. Start with `# expect: skill-name[,skill-name]`.
4. Contain a non-empty prompt after the metadata line.

The probe refuses the complete fixture corpus if any fixture is malformed. J8
through J11 are required:

| Journey | Daily-driver behavior | Expected skill |
|---|---|---|
| J8 | Compare two implementation approaches | `debate` |
| J9 | Review an implementation plan | `progressive-harsh-review` |
| J10 | Capture context for a fresh session | `context-ferry` |
| J11 | Audit a public repository for proprietary terms | `public-repo-ip-audit` |

Every fixture-backed invocation first copies each source `.txt` file once into
a private temporary directory. The directory mode is `0700`; snapshot files
are `0400`. The run inventory opens each complete snapshot once. Expectation
metadata, SHA-256 identity, and the encoded prompt body are derived from that
single byte buffer. The live path does not reopen the snapshot to construct the
prompt, so edits to the source or snapshot after discovery cannot change the
sent prompt or its recorded identity. Snapshots are removed after success,
validation or stream failure, and timeout.

Validate fixtures without calling a model:

```bash
bash tools/journey-probe.sh --lint-fixtures
bash tools/journey-probe.sh --list
```

## Capture a baseline

Use the same model identifier, controlled configuration directory, Claude CLI
version, permission mode, fixture commit, journey set, repeat count, timeout,
turn limit, and budget cap for both phases. A pinned model identifier is
preferable to a moving alias. Live and dry-run modes require an explicit
`--config-dir`. The source root may not be a symlink. The harness opens that
root without following symlinks, copies the complete regular-file tree into a
private temporary directory, and seals the copy with `0500` directory and
`0400` file modes. It fingerprints and passes that exact copy to Claude through
`CLAUDE_CONFIG_DIR`. Replacing and restoring the source path during a run
cannot change what Claude reads or preserve a false fingerprint match.

The identity is split across a fixed partition:

- `treatment_skill_fingerprint` covers exactly `skills/sp-debate`,
  `skills/sp-phr`, and `skills/context-ferry` beneath `--config-dir`, including
  every file in those directories. These are the skills exercised by J8-J10.
- `control_config_fingerprint` covers everything else beneath `--config-dir`
  and binds the fixed treatment-path list into the digest. A caller cannot move
  another changed path into the treatment partition.

All three treatment directories must exist, and symlinks or special files
anywhere in the controlled configuration fail closed. The private copy includes
hidden authentication files so an authenticated local run uses the same
credentials without exposing their contents in results. The copy is deleted
after success, failure, or timeout. The harness fingerprints both partitions
before and after every run, rejecting a capture if either part of the private
copy changes while measurement is in progress.

`--verbose` retains raw stream-json next to the results file for audit or
parser replay. Capture metadata, including the timestamp, is created in memory
for every run and copied into the result record. With `--verbose`, the same
metadata is also persisted in a create-only `.meta.json` sidecar beside each raw
stream. Without `--verbose`, no raw stream or sidecar is written. Replay
requires a persisted sidecar and does not consult the current fixture corpus,
so later fixture edits cannot silently relabel an old capture or regenerate
its timestamp.

Preview the run first. This does not call `claude`:

```bash
journey_model="${CLAUDE_MODEL:?Set CLAUDE_MODEL to a pinned model ID}"
journey_config_dir="${CLAUDE_CONFIG_DIR:?Set CLAUDE_CONFIG_DIR to the controlled config directory}"
bash tools/journey-probe.sh \
  --dry-run \
  --journeys J8,J9,J10,J11 \
  --repeat 3 \
  --model "$journey_model" \
  --config-dir "$journey_config_dir"
```

Run P1g from an authenticated local shell:

```bash
journey_model="${CLAUDE_MODEL:?Set CLAUDE_MODEL to a pinned model ID}"
journey_config_dir="${CLAUDE_CONFIG_DIR:?Set CLAUDE_CONFIG_DIR to the controlled config directory}"
journey_results="${TMPDIR:-/tmp}/p1g-results.jsonl"
bash tools/journey-probe.sh \
  --journeys J8,J9,J10,J11 \
  --repeat 3 \
  --model "$journey_model" \
  --config-dir "$journey_config_dir" \
  --results-file "$journey_results" \
  --permission-mode manual \
  --max-budget-usd 0.50 \
  --verbose
```

The output path must not already exist. This prevents a new run from appending
to an older sample. The harness uses `umask 077`, writes results, streams,
stderr logs, and metadata with owner-only access, and invokes Claude with
`--no-session-persistence`. Raw transcripts can still contain prompts, tool
output, and local paths; keep them out of Git unless they have been reviewed
and sanitized. Result records and sidecars contain only the two configuration
fingerprints, not the raw configuration path.

The per-run `--timeout` uses one monotonic deadline for stream reads, child
exit-status collection, and graceful process-group cleanup. A small supervisor
stays as the unreaped group leader until cleanup, which prevents PGID reuse and
lets the harness terminate descendants after either a successful or nonzero
Claude exit. Graceful termination consumes only time remaining before the run
deadline. If that deadline has expired, cleanup sends `SIGKILL` immediately and
allows at most 0.5 seconds beyond the deadline for kernel reaping.

## Result fields

Each JSONL record contains:

- `schema_version`: parser and comparison contract version.
- `timestamp`: UTC capture time from the run's in-memory metadata; when
  `--verbose` is used, the immutable raw-stream sidecar preserves that same
  value for replay.
- `fixture_sha256`: SHA-256 of the complete immutable fixture snapshot,
  including its expectation line and prompt body.
- `expected_skills`, `actual_skills_main`, and `actual_skills_subagent`.
- `missing_skills` and `unexpected_skills`.
- `verdict`: `PASS`, `PASS_WITH_NITS`, or `FAIL`.
- `quality`: expected count, unique actual count, matched count, recall, and
  precision.
- `reported_usage`: the terminal result event's four usage counters.
- `cost.context_tokens`: input + cache-creation input + cache-read input.
- `cost.output_tokens`: generated output tokens.
- `cost.total_tokens`: context + output tokens.
- `observed_usage`: assistant-event counters split by main thread and
  subagent. These are diagnostic and are not added to `reported_usage`.
- `observed_model`: the concrete model reported by the single init event.
- `requested_model`: the optional value passed to `--model`, retained so a
  moving alias is visible next to the concrete model.
- `control_config_fingerprint`: privacy-safe SHA-256 identity of all controlled
  configuration outside the fixed J8-J10 treatment directories, including the
  partition definition.
- `treatment_skill_fingerprint`: privacy-safe SHA-256 identity of the fixed
  J8-J10 treatment directories and their contents.
- `claude_cli_version` and `permission_mode`.
- `max_budget_usd`, `max_turns`, and `timeout_sec`.
- `num_turns`, `wall_time_sec`, `repeat_index`, `repeat_count`, and
  `exit_status`.

Verdict rules are deterministic:

- `PASS`: successful result, every expected skill observed, no unexpected
  skill observed.
- `PASS_WITH_NITS`: successful result and full expected-skill recall, with one
  or more unexpected skills.
- `FAIL`: an unsuccessful result or at least one missing expected skill.

The parser rejects malformed JSON, malformed usage counters, streams without
exactly one first-position init event and non-empty model, streams without
exactly one terminal result event, and internally inconsistent result records.
Replay a saved transcript and its adjacent metadata sidecar without calling a
model:

```bash
journey_raw_stream="${JOURNEY_RAW_STREAM:?Set JOURNEY_RAW_STREAM to a saved raw JSONL stream}"
bash tools/journey-probe.sh \
  --parse-stream "$journey_raw_stream"
```

Optional `--journey`, `--fixture`, and `--expected` values are assertions
against the sidecar. They never replace its capture metadata.

## Phase 2 comparison

Capture Phase 2 with the same command and a new output path, then compare:

```bash
journey_p1g_results="${JOURNEY_P1G_RESULTS:?Set JOURNEY_P1G_RESULTS to the baseline JSONL file}"
journey_phase2_results="${JOURNEY_PHASE2_RESULTS:?Set JOURNEY_PHASE2_RESULTS to the Phase 2 JSONL file}"
bash tools/journey-probe.sh --compare \
  "$journey_p1g_results" \
  "$journey_phase2_results"
```

The comparison enforces the Phase 2 gate and prints a report. Verdict order is
`FAIL < PASS_WITH_NITS < PASS`. For each of J8, J9, and J10, Phase 2 must:

1. Produce at least `PASS_WITH_NITS` on every treatment repeat. Any treatment
   `FAIL` is a regression, including `FAIL` compared with a baseline `FAIL`.
2. Produce an equal-or-better verdict at every matching repeat index.
3. Have strictly lower median context tokens.
4. Have worst-case context tokens less than or equal to the baseline worst
   case.

J11 is reported when present but is not part of this Phase 2 daily-driver gate.
The comparison prints the human table and a final machine-readable line such
as:

```text
MACHINE_VERDICT {"gate":"phase2-j8-j10","reasons":[],"verdict":"PASS"}
```

A comparable regression emits `"verdict":"REGRESSION"`, lists stable reason
codes, and exits nonzero. J8-J10 must all be present, and the treatment skill
fingerprint must differ so an unchanged installation cannot satisfy the gate.

The comparison stops before scoring if either file has duplicate, truncated,
or incomplete repeat indices relative to its recorded repeat count, or if the
inputs differ in journey set, run count, schema, fixture SHA-256, expected
skills, fixture name, control-configuration fingerprint, Claude CLI version,
requested or observed model, permission mode, timeout, turn limit, or budget
cap. The treatment fingerprint is the only identity allowed to differ, and it
must be uniform within each result file. Fix any control mismatch instead of
treating the samples as comparable.

## Offline tests and CI

The focused suite uses a fail-if-invoked fake for offline modes and a
deterministic stream-producing fake for live-mode control-path tests. It covers
argument handling, private storage, immutable verbose sidecars, non-verbose
in-memory timestamps, split fingerprints, single-read fixture snapshots,
between-phase mutation, FIFO/socket/device/symlink rejection, config-root
replacement, Git isolation, stream validation, success/nonzero descendant
cleanup, one-deadline timeouts, and the Phase 2 pass/fail boundaries without
real credentials, network access, or paid tokens:

```bash
bats test/journey-probe.bats
bash tools/ci-bats-discovery.sh --lint
bash tools/fence-scan.sh docs/JOURNEY_PROBE.md
```

`test/journey-probe.bats` is discovered automatically by the repository's Bats
runner. It needs no CI policy exception or environment entry.

Review routing remains an integration prerequisite. Before P1g is committed,
the P1h router change must make `tools/review.sh` classify
`test/fixtures/**` as code-review-battery input. Until that change is present,
reviewers must include the journey fixture files manually; this branch does not
modify the shared review router.
