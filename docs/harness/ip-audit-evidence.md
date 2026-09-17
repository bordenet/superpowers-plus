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

At 2026-09-17T19:47:07Z, the bounded reporter read every byte in the retained
local window with a 16 MiB ceiling:

| Hook | Fired, unadjudicated | Unknown |
|---|---:|---:|
| red-autonomy | 140 | 1,170 |
| internal-terms | 50 | 300 |
| git-identity | 10 | 60 |
| **Total** | **200** | **1,530** |

The snapshot read one file, excluded 26,965 successful or out-of-schema lines,
and reported `truncated=no`. That flag means the byte ceiling omitted none of
the retained files; it does not make an all-time retention claim. Later counts
may be higher or lower because appends can advance a bounded tail and rotation
can replace retained generations.

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
