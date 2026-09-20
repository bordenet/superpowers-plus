# IP audit evidence

This record captures the Phase 2B decision on proprietary-content scanning. It
documents what runs, what the local audit log showed, and why this change set
does not weaken the policy.

## Scan points

| Lifecycle point | Scanner | Scope |
|---|---|---|
| Claude PreToolUse for `git push` | `pre-tool-use-internal-terms.sh` | Private local literal patterns against commits headed to GitHub |
| Pre-commit | `public-repo-ip-check.sh --staged-only` | Newly staged public-repository content |
| Review battery | `harsh-review.sh` | Current working, staged, and unpushed public-repository content |
| Pre-push gate 3 | `public-repo-ip-check.sh --range` | Commits in the push range |
| Pull-request CI | `pr-content-ip-scan.yml` | Pull-request title and body |

A single `git push` invokes one private-pattern PreToolUse scan and one
public-pattern pre-push scan. Pre-commit and review scans occur at earlier
lifecycle points; they are not duplicate subprocesses inside the push hook.
The scanners also use different pattern registries and input scopes, so a
shared scan-once cache would risk suppressing a required check.

## Local aggregate snapshot

**Methodology: the block below is verbatim stdout, pasted unedited.** It is not
transcribed, summarized, or rounded. An earlier revision of this table carried a
hand-tidied `Unknown` column (1,170 / 300 / 60 against actual 1,186 / 305 / 61)
while claiming to be a literal reading. In a document whose only job is to be
the evidentiary record, adjusted numbers are worse than wrong ones, because a
wrong number can be caught and a tidied one cannot. Paste the output; do not
retype it.

Note the tool keys rows by `(hook, exit)`, not by hook alone. To compare against
any per-hook figure, sum across that hook's exit codes.

Captured `2026-09-18T06:27:03Z` by
`python3 tools/hook-block-report.py --max-bytes 16777216`:

```text
hook	exit	fired_unadjudicated	unknown
red-autonomy	2	224	1300
internal-terms	2	80	337
git-identity	2	16	67
TOTAL	-	320	1704
excluded_lines	29101
files_read	1
truncated	no
```

`truncated=no` means the byte ceiling omitted none of the retained files; it
does not make an all-time retention claim. Later counts may be higher or lower,
because appends advance a bounded tail and rotation replaces retained
generations. This snapshot is therefore not reproducible after the fact — only
the method is. Re-run the command for a current reading rather than expecting
these figures.

No production path adjudicates a block as true or false. Legacy `TP` and `FP`
labels were written by the gate or accepted by the parser, not independently
reviewed, and are normalized to fired-but-unadjudicated. The snapshot therefore
contains no measured false-positive rate. Historical records also omit command
content by design, so the earlier 255 internal-terms blocks cannot be classified
retrospectively from this log alone.

Re-run the aggregation procedure locally without committing the source log.
The timestamped historical count cannot be reproduced from a changing log:

```bash
python3 tools/hook-block-report.py --max-bytes 16777216
```

## Decision

- Keep the private PreToolUse scan, public pre-push scan, and CI backstop.
- Do not add allowlist entries without a reproduced false positive and a
  regression test.
- Do not weaken policy based on self-labeled or unadjudicated historical records.
- Reconsider registry consolidation or scan-once-per-SHA only after the scopes
  can be proven equivalent and cache invalidation is tested.

The source audit log and local detail output remain uncommitted. Only this
timestamped aggregate belongs in repository documentation.
