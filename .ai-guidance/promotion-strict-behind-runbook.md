# Runbook: Promotion PR Stuck on `BEHIND` Despite Green Checks

## Symptom

On a promotion PR (`dev→staging`, `staging→main`, or a back-sync PR `main→staging` / `main→dev`), all 4 required checks (Node.js Tests, Quality Checks, Security Scan, Shell Tests) show SUCCESS, but `mergeStateStatus` stays `BEHIND` indefinitely, and `gh pr merge` refuses with "head branch is not up to date with the base branch."

## Root cause

`dev`/`staging`/`main` never fast-forward from each other — every promotion is a merge commit. The `strict` required-status-checks setting demands the head branch already contain the base's tip before merging. On a small diff (~4 commits) this was observed to self-resolve within about a minute of checks completing. On a larger diff (~28 commits) it stayed stuck for 20+ minutes with no sign of resolving. This diagnosis is based on direct observation during the 2026-07-12 promotion cycle, not GitHub documentation — treat the specific timing numbers as anecdotal, not a guarantee.

## Confirmed NOT to help

- `gh pr merge <N> --merge --admin` — GitHub's GraphQL API rejects this outright with `4 of 4 required status checks are expected`; admin override does not bypass this specific gate.
- Closing and recreating the PR — the new PR hits the identical stuck state.
- GitHub merge queue — not available for this repo. Confirmed by testing `POST /repos/bordenet/superpowers-plus/rulesets` with a `merge_queue` rule (rejected) versus a plain `deletion` rule on the same endpoint (succeeded), isolating the failure to `merge_queue` specifically. This matches GitHub's documented restriction: merge queue requires an organization-owned repository; `superpowers-plus` is owned by a personal user account (verify with `gh api repos/bordenet/superpowers-plus --jq .owner.type` → `User`).

## Precondition

The fix below requires admin-level access to the repo's branch protection settings. If `gh api -X PATCH .../protection/required_status_checks` returns `403` or `404`, that's a permissions problem, not a recurrence of the original symptom — check `gh auth status` and your repo role before assuming the fix doesn't apply.

## Working fix

Resolve `<branch>` to the PR's **base** branch (not head) for the scenario you're in:

| Scenario | `<branch>` = |
|---|---|
| `dev → staging` PR | `staging` |
| `staging → main` PR | `main` |
| back-sync `main → staging` PR | `staging` |
| back-sync `main → dev` PR | `dev` |

Use `tools/promotion-strict-toggle.sh` — do not hand-type raw `gh api PATCH` calls. The script verifies each change via read-back before trusting it, and writes a timestamped sentinel while `strict` is disabled so a forgotten restore is machine-detectable rather than silent (see "Enforcement" below).

1. **Check for competing open PRs against the same base** — this fix has a race window (see below), so confirm you're not stepping on other in-flight work:
   ```bash
   gh pr list --repo bordenet/superpowers-plus --state open --base <branch>
   ```
   If another PR (not yours) targets the same base, **do not proceed** — merging with `strict` off could let that other PR land without being rebased onto the latest base. Wait, or coordinate with whoever owns that PR first.

2. **Disable strict:**
   ```bash
   tools/promotion-strict-toggle.sh disable <branch>
   ```
   Refuses to write its sentinel (exits 1) if a read-back after the PATCH doesn't confirm `strict=false` — you'll see the failure immediately rather than assuming it worked.

3. **Merge:**
   ```bash
   gh pr merge <N> --repo bordenet/superpowers-plus --merge
   ```

4. **Restore strict — run this even if step 3 failed.** If the merge in step 3 errors out for any reason (network blip, a competing PR raced in, etc.), do not leave `strict` disabled — restore it immediately, diagnose the merge failure separately, and re-run from step 1 once resolved:
   ```bash
   tools/promotion-strict-toggle.sh restore <branch>
   ```
   Refuses to clear its sentinel (exits 1) if a read-back doesn't confirm `strict=true` — re-run this step if it fails, do not walk away.

At any point, `tools/promotion-strict-toggle.sh status` lists which branches currently have `strict` disabled and how long ago, flagging anything past 30 minutes as `STALE`.

## What this does and doesn't change

This only removes the "head must already be ahead of base" ordering requirement. The 4 required checks themselves are untouched and must show SUCCESS for the merge to succeed at all — this fix has never been observed to let an actually-failing check through.

## Enforcement

`tools/claude-hooks/session-start-rules-integrity.sh` calls `tools/promotion-strict-toggle.sh status` on every session start and blocks (exit 2) if any branch has been left with `strict=false` past the 30-minute TTL. This closes the original gap: a skipped or failed restore no longer sits silently — the next session start surfaces it as an integrity failure. Tests: `test/promotion-strict-toggle.bats` (the script itself) and `tests/claude-guardrails-test.bats` items 3f-3h (the hook wiring).

## Known gaps (not yet solved)

- This whole workaround is a symptom-level fix, not a root-cause fix. The actual root cause (GitHub's `strict` recompute apparently scaling poorly with diff size on this specific repo/plan) is unconfirmed against GitHub's own documentation or support.
- The 30-minute TTL is a judgment call, not a measured threshold — there's no historical baseline for how long `strict` recompute normally takes at various diff sizes in this repo.
