# Skill Router Precision

`tools/router-precision.py` measures the Claude UserPromptSubmit skill router
from local metrics and transcript JSONL files. It reports aggregate values and
never prints prompt text.

## Run the report

```bash
python3 tools/router-precision.py
```

The defaults are:

- Metrics: `~/.claude/hooks/skill-router-metrics.jsonl`
- Transcripts: `~/.claude/projects/`

Use explicit paths for fixtures or a non-default Claude data directory:

```bash
python3 tools/router-precision.py \
  --metrics /path/to/skill-router-metrics.jsonl \
  --transcripts /path/to/transcripts
```

Pass `--json` for machine-readable output. Run `--help` for parser-limit
overrides.

## Metric definitions

| Metric | Definition |
|--------|------------|
| Hint rate | Prompts with at least one hint divided by valid metrics records. |
| Hints per prompt | Total emitted hints divided by valid metrics records. |
| Precision | Evaluable top suggestions followed by invocation of that skill in the same user turn, divided by all evaluable top suggestions. |
| Automatic matched invocations | Correct suggestions where the prompt did not explicitly request a skill. |
| Explicit matched invocations | Correct suggestions where the prompt used the suggested skill's canonical slash name or a published alias, or requested that same name with `use`, `invoke`, `run`, or `load`. Unrelated slash commands and filesystem paths remain automatic. |

A suggestion is evaluable only when its metrics record has a safe `session_id`
and `prompt_sha256`, the matching transcript is available, no transcript line
was skipped, and the prompt hash matches a user turn. Older records still
contribute to hint rate and hints per prompt even when they cannot contribute
to precision.

## Router controls

| Variable | Default | Validation |
|----------|---------|------------|
| `CLAUDE_SKILL_ROUTER_MAX_HINTS` | `1` | Accepts `1`, `2`, or `3`; any other value falls back to `1`. |
| `CLAUDE_SKILL_ROUTER_MIN_SCORE` | `0.55` | Accepts a finite integer or decimal from `0` to `10`; invalid or out-of-range values fall back to `0.55`. |
| `CLAUDE_SKILL_ROUTER_METRICS` | `~/.claude/hooks/skill-router-metrics.jsonl` | Overrides the local metrics path. |
| `CLAUDE_HOOKS_BYPASS` | `0` | Set to `1` to disable the hook. |

The `0.55` score floor is bracketed by a versioned 12-skill regression corpus
and the installed 118-skill corpus used during calibration. Raw IDF made one
rare incidental term score `1.278` in the installed corpus. A
description-only match with one lexical signal is therefore discounted to
35%, or `0.447` for that observed case. The weakest retained two-signal
inflection fixture scores about `0.695`. A non-generic skill-name segment is
stronger than a description-only overlap. Generic name segments such as
`test` and `debug` may add weight after independent intent qualifies, but
they do not count toward that qualification. Exact full-name matches remain
strong intent evidence.

Published positive triggers add one non-stacking score boost. Eligible
triggers are multi-word, non-command phrases of at most 160 characters; the
cache retains at most 16 per skill. Exact contiguous phrases receive at most
`2.25` points. An adjacent reversed form of a two-word trigger receives `1.25`
points after narrow morphology normalization, allowing `test failure` to
match `failing test` without turning longer triggers into unordered token
bags. Recalibrate from observed `score`, `runner_up`, and precision data
instead of raising the threshold for one isolated false positive.

Skills with `coordination.internal: true` or
`disable-model-invocation: true` are excluded when the router cache is built.
Changing either exclusion rule requires a cache schema version bump so an old
cache cannot continue suggesting newly excluded skills.

Cache v4 also records the count and SHA-256 digest of the sorted source-skill
directory names. It does not retain those names or paths. The hook compares
that inventory on every run so adding, deleting, or renaming a `skill.md`
source invalidates the cache even when no surviving file has a newer mtime.

## Parsing limits

The analyzer streams JSONL and does not load complete files. Defaults:

| Limit | Default |
|-------|---------|
| Metrics bytes | 64 MiB |
| Bytes per transcript | 16 MiB |
| Aggregate transcript bytes | 64 MiB |
| Bytes per JSONL line | 1 MiB |
| Metrics records | 100,000 |
| Transcript files | 1,000 |
| Directory entries scanned | 10,000 |
| Transcript directory depth | 4 |

The JSON and human reports expose independent `metrics_byte_limit` and
`metrics_record_limit` flags. The first means the metrics byte budget stopped
the read; the second means another valid record existed after the configured
record count was reached. Either flag means the metrics input was truncated.

Malformed, non-object, and overlong lines are skipped and counted. Any skipped
transcript line makes that transcript unevaluable because the missing line may
contain an invocation or user-turn boundary. Transcript symlinks are not
followed. A transcript that exceeds the per-file budget is excluded from
precision instead of being partially classified. The analyzer parses and
releases one transcript at a time, stops at the aggregate byte budget, and
reports either limit in `skipped`. Session IDs must contain only letters,
numbers, periods, underscores, and hyphens, with a maximum length of 128
characters. These checks prevent a metrics record from escaping the transcript
root or causing unbounded parsing or retained memory.

The prompt join mirrors the hook's normalization: trailing newlines are
removed before the first 4,096 characters are hashed. Claude system, metadata,
sidechain, and tool-result user records do not open a new human turn.

## Privacy and retention

The router does not write raw prompts or arbitrary prompt terms to its metrics
file. Each record contains `ts`, `rebuilt`, `status`, `hints`, `session_id`,
`prompt_sha256`, `suggested`, `score`, `runner_up`, `matched_terms`,
`explicit_aliases`, `threshold`, and `max_hints`. The `matched_terms` array
contains at most five terms from the published skill name/token vocabulary or
published positive trigger phrases. It never records arbitrary prompt terms.
Terms are capped at 64 characters, aliases at 160 characters, and published
slash aliases at 16 entries. Telemetry opens the destination without following
symlinks, rejects non-regular files without blocking, and sets the open
descriptor to mode `0600` because session-linked routing telemetry is still
sensitive operational data.

The analyzer reads prompt text only to verify the digest and classify an
invocation. It emits aggregate counts, never prompt text or transcript paths.
It does not contact a network service.

## Install drift is a real risk to every number above

**PHR round 1 (2026-09-18) found this happening on the machine that hosts this
repo, not hypothetically.** The schema above describes what the REPO's hook
(`tools/claude-hooks/user-prompt-submit-skill-router.sh`) writes. The
INSTALLED hook that actually runs (typically `~/.claude/hooks/user-prompt-submit-skill-router.sh`)
can be an older copy that writes fewer fields -- confirmed live: a 550-line
installed hook writing only `{hints, rebuilt, status, ts}` against a 986-line
repo hook that writes the full 13-field schema. Every hinted record then fails
the `suggested is None` / `session_id is None` / `prompt_sha256 is None` checks
in `analyze()`, `evaluable_suggestions` is permanently 0, and `Precision`
reports `n/a` forever -- indistinguishable from "not enough data yet" unless
you know to look for it.

As of this fix, that failure is no longer silent: a new `schema_incomplete_hints`
counter appears in the `Skipped:` line, and when it accounts for the total
precision failure (hinted_prompts > 0, evaluable_suggestions == 0,
schema_incomplete_hints > half of hinted_prompts) the tool prints an explicit
stderr warning naming install drift as the likely cause and pointing at the
repo hook to diff against. Re-sync the installed hook from the repo copy to
restore real measurement; this doc does not do that for you.

Retain router metrics only for the active calibration window. Delete or rotate
the local file within 30 days, or immediately after the routing decision is
made if that occurs sooner. The tool does not delete data automatically.
