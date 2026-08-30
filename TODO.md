# Resume — 2026-08-17 (read this, then stop)

This was the 2026-08-15 Claude handoff (`claude/eli5-writing-skill-d08zzf`): eli5 skill, llm-skill-review calibration, repo-security-scan history scan, Gate 6 v2 (ADR-003), guidance-regression (ADR-004). **That work is on GitHub.** The only unmerged code is the CVE pin + tracker catch-up.

Status legend: `[ ]` open · `[~]` in progress · `[x]` done · `[-]` cancelled / superseded

## Laptop: pick this up

```bash
git fetch origin
git checkout cursor/handoff-cleanup-cve-1111   # or: gh pr checkout 1200
git status -sb   # should be even with origin/cursor/handoff-cleanup-cve-1111
```

| Item | State |
|---|---|
| Working PR | https://github.com/bordenet/superpowers-plus/pull/1200 → `origin/dev` (CI was green on `2b34d21`; this resume-doc commit will move the tip — re-check checks on the PR) |
| Branch | `cursor/handoff-cleanup-cve-1111` — pin `@hono/node-server` 2.1.0 + hermetic `use-skill` CLI test + this resume card |
| Protected tips | `origin/dev` `88552b6` · `origin/staging`/`origin/main` `10f251d`. Trees identical (`git diff-tree --quiet`). SHAs differ only by promotion merges. After #1200 merges, promote if you want the three tips identical again. |
| Remotes | Only `dev`, `staging`, `main`, and this PR branch. Stale `fix/history-scan-*` remotes deleted 2026-08-17. |

**Push timeout:** local pre-push Gate 1 (`tools/test-all.sh --fast`) is ~115s; the full 7-gate hook needs **5 minutes**, not a 2-minute shell timeout.

## Your next clicks (this agent cannot do these)

- [ ] [20260817-09] **Merge PR #1200** into `origin/dev`
- [ ] [20260817-05] **Dismiss the GitHub Dependabot/`@hono/node-server` alert** after #1200 is on `dev` (API 403 from cloud agents)
- [ ] [20260817-04] **Close issue #1187** if ADR-003 + the merged calibration PRs answer the gate-floor complaint (`gh` cannot close issues from this agent)
- [ ] [20260817-07] **Promote `dev → staging → main`** after #1200 merges. Needs a fresh "approve push" in the session that does it.

Source issue (still open): https://github.com/bordenet/superpowers-plus/issues/1187

---

## What already landed (do not re-do)

| Work | Where |
|---|---|
| WS1 eli5 `/eli5` | #1190 |
| WS2 `--min-score` = Prose/Design mean | #1188 |
| WS3+WS8 repo-security-scan history scan | #1190 then #1197; promoted #1198/#1199 |
| WS4 systematic-debugging 2+ / companions | #1189 + #1190 |
| WS5 llm-skill-review Evidence Schema | #1190 |
| WS6 ADR-003 Gate 6 v2 (Accepted) | #1193 (`ac17f42b`); E4 envelope-bound-to-HEAD `c1456557` |
| WS7 ADR-004 guidance-regression v0 (Accepted) | #1193 |
| WS10 gate6-floor test branch | **Superseded — do not merge.** ADR-003 deleted `LLM_SKILL_REVIEW_MIN`. Lesson that survived: a bats harness that redefines a production constant in its own preamble voids the coverage it appears to provide. |
| CVE pin `@hono/node-server` 2.1.0 | PR #1200 (unmerged) |
| Stale remote prune | Done 2026-08-17 (`fix/history-scan-hardening`, `fix/history-scan-hardening-v2`) |

Gate 6 pass is now: verdict `PASS` or `PASS_WITH_RISKS`, unresolved S0/S1 = 0, findings have `severity`, `clean_dimensions.length >= 1`, evidence replay, `--no-envelope` only with PASS. Mean is sentinel metadata (`mean=`), not a 9.0 floor.

---

## WS8 notes (already on `origin/dev`)

Recovered as `fix/history-scan-hardening-v2` → **PR #1197**. Do not look for the old remotes; they were deleted.

- [x] [20260815-22] `ASSIGN_RE` `[[:space:]]` (BSD/macOS `git log -G` rejects `\s`; glibc accepts `\s` — string-level pin because CI cannot discriminate)
- [x] [20260815-23] `gitleaks git .` (not deprecated `detect`)
- [x] [20260815-24] `-m` on fallback and gitleaks `--log-opts="--all -m"`
- [x] [20260815-25] `-v` on gitleaks
- [x] [20260815-26] non-git and shallow-clone hard-fail
- [x] [20260815-27] `test/repo-security-scan-history.bats` extracts the skill's own fenced blocks
- [x] [20260815-28] line-anchored `grep -cE '^\+.*<tok>'` (not a vacuous substring)
- [x] [20260815-35] preferred gitleaks path is blind to merge-introduced-then-deleted without `-m`; fallback only degrades
- [x] [20260815-36] `-m` ~2.14x diff surface; documented in the skill
- [x] [20260815-37] test 9 control runs the `-m`-less command directly

Gate 6 is a **local** `.git/hooks/pre-push` hook. No CI workflow invokes it.

---

## HISTORY

### 2026-08-15
- [x] [20260815-01]–[20260815-03]/[19]/[20] eli5 skill + working PR #1190 + re-review (llm mean 8.6; floor was still 9.0 then)
- [x] [20260815-04]/[18] `--min-score` Prose/Design-only (#1188)
- [x] [20260815-05]–[07]/[21] repo-security-scan history completeness + pattern parity + requires/prose
- [x] [20260815-08] #1189 find-polluter
- [x] [20260815-09]–[11] systematic-debugging threshold / companions / rationale
- [x] [20260815-12]–[13] llm-skill-review Evidence Schema + terminology
- [x] [20260815-14]/[16] ADR-003 / ADR-004 written as Proposed
- [x] [20260815-31] sub-floor exception resolved by ADR-003
- [x] [20260815-32] E4 envelope binding fixed on #1193
- [-] [20260815-29]/[30] original machine-local history-scan branch / score of `cd18d676` — superseded by #1197

### 2026-08-17
- [x] [20260817-01] History-scan hardening recovered as PR #1197 and promoted (#1198/#1199)
- [x] [20260817-02] ADR-003 Gate 6 v2 + ADR-004 guidance-regression accepted and implemented (PR #1193)
- [x] [20260817-03] Pin MCP transitive `@hono/node-server` 1.19.14 → 2.1.0 (`overrides`)
- [x] [20260817-08] Hermeticize `test/use-skill-cli.test.js`; add it to CI node-tests
- [x] [20260817-06] Pruned stale remotes `fix/history-scan-hardening` and `fix/history-scan-hardening-v2`; local leftover feature checkouts gone
