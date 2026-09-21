# Hook Block Audit

The red-autonomy, internal-terms, and git-identity hooks write audit records to `~/.claude/hooks/hook-audit.log`. Block and malformed-input records include two fields used for review:

- `class=fired|unknown` distinguishes a policy gate that fired from a malformed or dependency-failure event.
- `sid=<session>` groups records from the same sanitized Claude Code or Augment session. Missing identifiers use `sid=-`.

`fired` is deliberately not called a true positive. A gate cannot adjudicate its
own decision, and no production path can prove a false positive. Legacy
`class=TP` and `class=FP` records are therefore normalized to
fired-but-unadjudicated by the reporter. Dependency failures and malformed input
use `unknown`. The reporter retains each accepted record's real nonzero exit
code; this includes exit 5 from malformed internal-terms and git-identity input.

This metadata does not change which actions the hooks allow or block. Red-autonomy still fails closed on malformed input. Internal-terms and git-identity retain their existing malformed-input exit statuses.

## Privacy Boundary

Ordinary block records contain the hook name, exit status, reason, classification, and sanitized session identifier. They do not contain command text, matched content, repository paths, or email addresses.

Malformed-input records add only:

- `tool=<sanitized-tool-name>`
- `input_keys=<sorted-recognized-top-level-key-names>`
- `unknown_keys=<count>`

The recognized key allowlist is `conversation_id`, `cwd`, `session_id`, `tool_input`, `tool_name`, and `transcript_path`. Other key names are never logged; `unknown_keys` records only their count. No raw input values are logged beyond the sanitized session identifier and tool name. Commands, matched content, paths, email addresses, unknown key names, and all other values are omitted. Invalid JSON that cannot be inspected uses `tool=-`, `input_keys=-`, `unknown_keys=0`, and `sid=-`.

## Aggregate Report

Run the report from the repository root:

```bash
python3 tools/hook-block-report.py
```

The reporter reads retained generations in chronological order: `.2`, `.1`,
then the live log. It accepts only regular files, opens paths nonblocking, and
refuses final-component symlinks, so a FIFO or symlink cannot turn a bounded
report into an unbounded wait or unintended read. The default applies one 1 MiB
ceiling across the combined retained window, plus one preceding byte to verify
the first record boundary. If append or rotation changes the generation set
during the read, the reporter fails and asks for a retry instead of mixing two
snapshots. A successful run emits deterministic tab-separated counts:

```text
hook	exit	fired_unadjudicated	unknown
red-autonomy	2	3	1
internal-terms	2	1	0
internal-terms	5	0	1
git-identity	2	2	0
git-identity	5	0	1
TOTAL	-	6	3
excluded_lines	4
files_read	3
truncated	no
```

Use `--max-bytes` to select a smaller combined tail. The hard limit is 16 MiB.
Exit 2 records may omit `class` for legacy compatibility and are then counted as
`unknown`. Other nonzero exits are accepted only when they contain an explicit
class and `reason=malformed-input`. Successful records and lines outside the
block-event schema are counted under `excluded_lines`; their contents are never
echoed. `truncated=no` means the byte ceiling omitted none of the retained files.
It does not claim that older, already-rotated history still exists.

The parser validates record format and field allowlists. It does not authenticate records or prove that a hook emitted them. Anyone who can modify the local log can add or alter a format-valid record, classification, or count.

Timestamped aggregate counts are suitable for a committed report. A later run
may be higher or lower: appends can advance a byte-bounded tail, and rotation
can replace retained generations. Do not commit the source audit log.

## Local Detail Review

Use detail mode only on the local machine:

```bash
python3 tools/hook-block-report.py --details
```

Detail mode prints a `LOCAL ONLY - DO NOT COMMIT DETAIL OUTPUT` warning and only
the parsed timestamp, hook, exit code, normalized class, session identifier,
reason, tool name, recognized input key names, and unknown-key count. It never
prints an unparsed log line.

Use that metadata to locate the original local session and reproduce a suspected
false positive. A false-positive claim requires the reproduction and a regression
test; editing the hook's self-reported class is not adjudication. Keep session
details and source logs local. Commit only timestamped aggregates and the
reproduction-safe conclusion.
