# Hook Block Audit

The red-autonomy, internal-terms, and git-identity hooks write audit records to `~/.claude/hooks/hook-audit.log`. Classified block and malformed-input records include two fields used for review:

- `class=TP|FP|unknown` records true positive (TP), false positive (FP), or unknown (not yet adjudicated).
- `sid=<session>` groups records from the same sanitized Claude Code or Augment session. Missing identifiers use `sid=-`.

The hooks initially assign `TP` when an existing policy condition blocks an action. Dependency failures and malformed input that reach audit logging use `unknown`. A hook cannot establish that its own decision was a false positive, so `FP` is reserved for local post-review classification. The reporter retains each accepted record's real nonzero exit code; this includes exit 5 from malformed internal-terms and git-identity input.

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

The reporter accepts only regular files. It opens supplied paths nonblocking and refuses final-component symlinks before reading, so a FIFO or symlink cannot turn a bounded report into an unbounded wait or an unintended read. The default report reads at most the last 1 MiB of the log, plus one preceding byte to verify the first record boundary, and emits deterministic tab-separated counts:

```text
hook	exit	TP	FP	unknown
red-autonomy	2	3	0	1
internal-terms	2	1	0	0
internal-terms	5	0	0	1
git-identity	2	2	0	0
git-identity	5	0	0	1
TOTAL	-	6	0	3
ignored_lines	4
truncated	no
```

Use `--max-bytes` to select a smaller bounded tail. The hard limit is 16 MiB. Exit 2 records may omit `class` for legacy compatibility and are then counted as `unknown`. Other nonzero exits are accepted only when they contain an explicit class and `reason=malformed-input`. Format-invalid, duplicate-field, and unsupported records are counted under `ignored_lines`; their contents are never echoed.

The parser validates record format and field allowlists. It does not authenticate records or prove that a hook emitted them. Anyone who can modify the local log can add or alter a format-valid record, classification, or count.

Aggregate counts are suitable for a committed report. Do not commit the source audit log.

## Local Detail Review

Use detail mode only on the local machine:

```bash
python3 tools/hook-block-report.py --details
```

Detail mode prints a `LOCAL ONLY - DO NOT COMMIT DETAIL OUTPUT` warning and only the parsed timestamp, hook, exit code, class, session identifier, reason, tool name, recognized input key names, and unknown-key count. It never prints an unparsed log line.

To adjudicate a suspected false positive, copy the log to a local temporary file, change only that record's `class` field to `FP`, and report against the copy:

```bash
cp ~/.claude/hooks/hook-audit.log /tmp/hook-audit.review.log
python3 tools/hook-block-report.py --log /tmp/hook-audit.review.log --details
```

Keep the review copy and detailed output local. Only the aggregate TP, FP, and unknown counts should enter version control.
