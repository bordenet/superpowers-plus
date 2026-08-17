# Workstreams — explain-like-im-five + llm-skill-review calibration handoff

Tracker for every finding from Claude's 2026-08-15 handoff (`claude/eli5-writing-skill-d08zzf`).
Working PR #1190 merged 2026-08-15. Follow-on: https://github.com/bordenet/superpowers-plus/pull/1200 (`cursor/handoff-cleanup-cve-1111` → `origin/dev`).
Source issue: https://github.com/bordenet/superpowers-plus/issues/1187 (still open; `gh` cannot close issues from this agent — human close after confirming ADR-003 closed the gate-floor complaint).

Status legend: `[ ]` open · `[~]` in progress · `[x]` done · `[-]` cancelled / superseded

---

## WS1 — `explain-like-im-five` skill (thread 1)

New writing-domain skill `/eli5` plus catalog updates (skill count 112→113).
Four independent `llm-skill-review` rounds: final **PASS WITH RISKS**, Prose/Design **7.18–7.40** (never cleared 9.0 floor). No `.llm-skill-review-cleared`.

- [x] [20260815-01] Land skill + catalog commits onto branch from `origin/dev`
- [x] [20260815-02] Open working PR with honest score/verdict disclosure (no fabricated sentinel)
- [x] [20260815-19] Fix broken "summarization skill" Wrong-skill redirect (no such skill exists)
- [x] [20260815-03] Human decision: merge authorized 2026-08-15 (promote private -> origin/dev -> staging -> main; prune to three identical tips)
- [x] [20260815-20] Re-run llm-skill-review + PHR + cr-battery; sentinels written via official runners (CRB PASS/8.0, PHR PASS/8.4, llm-skill-review PASS/8.6). Gate 6 still requires sentinel min-score >= 9.0 — ADR-003 is the policy path.

## WS2 — `--min-score` self-contradiction (thread 2)

- [x] [20260815-04] PR #1188 merged into `origin/dev` (2026-08-15) — definition now Prose/Design mean only
- [x] [20260815-18] Align `tools/run-llm-skill-review.sh` help/header + gate L169: drop leftover "combined score" wording

## WS3 — `repo-security-scan` history gap + requires contradiction (S0/S1)

- [x] [20260815-05] Required git-history secrets scan in Phase 1 (gitleaks preferred; uncapped `git log -p` fallback; never `head` truncate)
- [x] [20260815-06] Narrow Verification so "zero remaining issues" means HEAD + history (incomplete scan != clean)
- [x] [20260815-07] Resolve `requires` vs scan-only contradiction: keep `requires: []`, soften Phase 2 to conditional `security-upgrade` (not hard prerequisite); regenerate DAG
- [x] [20260815-21] History `-G` pattern parity with HEAD (TOKEN_RE + ASSIGN_RE); document shared-pattern subset honestly

## WS4 — `systematic-debugging` contradictions + cleanup (S1)

- [x] [20260815-08] `find-polluter.sh` word-split/glob bug — already fixed via PR #1189 on `origin/dev`
- [x] [20260815-09] Unify fix-attempt threshold to **2+** everywhere (Phase 4 / rationalizations / section heading)
- [x] [20260815-10] Deduplicate Companion Skills into one list
- [x] [20260815-11] Remove stale "condensed to 88 lines" claim from override rationale

## WS5 — `llm-skill-review` Evidence Schema + terminology (S1/S3)

- [x] [20260815-12] Add `reviewer` / `dimension` to Evidence Schema worked example in `reference.md`
- [x] [20260815-13] Replace stray `<combined-score>` placeholder with Prose/Design-mean wording

## WS6 — Gate pass-condition redesign (calibration follow-up)

- [x] [20260815-14] Write ADR-003 proposing pass on verdict + zero unresolved S0/S1 + evidence replay + non-vacuous proof (`docs/adr/003-llm-skill-review-gate-pass-condition.md`)
- [x] [20260815-15] Human checkpoint: promote/merge authorized 2026-08-15 (ADR-003 remains Proposed; Gate 6 floor unchanged this cycle)

## WS7 — Guidance-regression fixtures for prompt-only skills

- [x] [20260815-16] Write scoped design note as ADR-004 Proposed (`docs/adr/004-prompt-only-skill-guidance-regression.md`)
- [x] [20260815-17] Human checkpoint: promote/merge authorized 2026-08-15 (ADR-004 remains Proposed; fixture runner not built this cycle)

---

## WS8 — `repo-security-scan` history-scan hardening (Claude, 2026-08-15 evening)

Delta on top of WS3. Original branch `fix/history-scan-hardening` was machine-local. Recovered and landed as `fix/history-scan-hardening-v2` → **PR #1197** (merged to `origin/dev` 2026-08-17, `88552b6`), promoted **#1198** `dev→staging` / **#1199** `staging→main`. Leftover remote `origin/fix/history-scan-hardening` is older WIP (skill diff vs `origin/dev` empty); prune when convenient. `origin/fix/history-scan-hardening-v2` is an ancestor of `origin/dev`.

Four defects found in WS3's merged version, each verified by executing the shipped command:

- [x] [20260815-22] `ASSIGN_RE` used `\s`, which `git log -G` does not accept on BSD/macOS regcomp — history scan matched ZERO assignment-class secrets there while HEAD scan matched fine. Changed to `[[:space:]]` (works both engines, both platforms). **Platform-specific, not universal: glibc/Linux accepts `\s`.**
- [x] [20260815-23] `gitleaks detect --source .` — `detect` deprecated and unlisted on 8.30.1; changed to `gitleaks git .`
- [x] [20260815-24] No `-m` on either path → secrets introduced in a merge resolution missed. Added to fallback AND to the preferred gitleaks path via `--log-opts="--all -m"` (the first pass hardened only the fallback)
- [x] [20260815-25] No `-v` on gitleaks → prints a bare count, nothing to triage
- [x] [20260815-26] Added preconditions: non-git and shallow-clone both hard-fail with remedy (CI default is `fetch-depth: 1`, which made both paths report clean while scanning nothing)
- [x] [20260815-27] New `test/repo-security-scan-history.bats` (14 cases). EXTRACTS and runs the skill's own fenced blocks rather than transcribing them; registered in `.github/workflows/test.yml`
- [x] [20260815-28] Fixed vacuous regression test: test 9 passed with `-m` removed (bare substring matched the deletion line; a `*"+"*` glob was also vacuous). Now line-anchored `grep -cE '^\+.*<tok>'` against the skill's own pipeline. Verified: fails when `-m` stripped.

**Corrections to earlier claims in this session (recorded so they don't propagate):**
- The `\s` defect is BSD/macOS-only, NOT universal. CI is ubuntu-latest, where the behavioral test cannot discriminate — hence the string-level pin.
- Merge-introduced-then-deleted secrets are NOT "invisible to every phase": the deletion diff surfaces the token on a `-` line (0 added/1 deleted without `-m`; 2 added/1 deleted with). Residual gap is narrower — introduced AND removed within merge commits.
- "Gate 6 blocks all skill pushes" — it is a LOCAL `.git/hooks/pre-push` hook. No CI workflow invokes it.

## WS10 — Gate 6 floor had zero test coverage (Claude, 2026-08-15)

Branch `fix/gate6-floor-test-coverage`, pushed 2026-08-16. **SUPERSEDED — do not merge.** ADR-003 deleted `LLM_SKILL_REVIEW_MIN` from Gate 6 entirely, so these tests target a constant that no longer exists and conflict with the merged version of the same bats file. Recorded because the underlying lesson outlives the code.

- [x] [20260815-34] `test/pre-push-llm-skill-review-gate.bats` redefined `LLM_SKILL_REVIEW_MIN="9.2"` in its own generated harness preamble, **shadowing** the production constant. Proof: setting production to `0.0` left all 29 tests green. Fixtures (8.5/9.2/9.8) also never straddled the real 9.0. Harness now sources the literal from production and derives fixtures from it; added a guard test asserting harness value == production value. Verified 30/30 at 9.0; production at 0.0 now FAILS.

## WS8 addenda — round-2 review corrections (2026-08-15)

- [x] [20260815-35] Retraction over-corrected. On the **preferred gitleaks path** a merge-introduced-then-deleted secret IS genuinely invisible without `-m` (0 findings vs 2). Only the `git log -G` fallback degrades rather than going blind (0 added/1 deleted). Both the bats header and the skill comment restated a flat "never sees"/"invisible here" — corrected in both artifacts, not just the commit message.
- [x] [20260815-36] Priced `-m`: ~2.14x diff surface (31.6→67.6MB on a 39%-merge repo) and one finding per parent diff, so duplicates on triage. Documented in the skill.
- [x] [20260815-37] Test 9 control assertion was a no-op — it sed-ed `-m` out of a file that already lacked it under regression, comparing the file to itself. Now runs the `-m`-less command directly.

## HANDOFF — resume state (READ FIRST)

**Updated 2026-08-17 (cleanup pass).** WS1–WS8 and ADR-003/004 are on GitHub. Open follow-on: PR #1200. Tips at start of this pass: `origin/dev` `88552b6` (merge #1197); `origin/staging` and `origin/main` `10f251d` (merge #1199). Trees of the three protected tips were identical (`git diff-tree --quiet` exit 0) before the CVE pin; SHAs differ only by promotion merges.

**Why some earlier pushes did not land:** not a gate rejection. Pre-push Gate 1 (`tools/test-all.sh --fast`) takes **115s measured** and passes; adding the other six gates exceeds a 2-minute shell timeout. Allow **5 minutes** per push. This still holds.

| Branch | State as of 2026-08-17 cleanup |
|---|---|
| `fix/gate6-floor-test-coverage` | Pushed. **Superseded — do not merge as-is.** |
| `cursor/accept-adr-003-004-1111` (PR #1193) | **Merged to `dev`** at `ac17f42b`, including the E4 fix. |
| `fix/history-scan-hardening-v2` (PR #1197) | **Merged to `dev`.** Promoted via #1198/#1199. |
| `origin/fix/history-scan-hardening` | Leftover older WIP remote. Skill diff vs `origin/dev` empty. Prune when convenient. |
| `cursor/handoff-cleanup-cve-1111` | This pass: pin `@hono/node-server` 2.1.0 + tracker catch-up. |

**`fix/gate6-floor-test-coverage` is superseded.** ADR-003 removed the numeric floor from Gate 6 entirely — `LLM_SKILL_REVIEW_MIN` no longer exists in `tools/pre-push-llm-skill-review-gate.sh`. The branch's whole subject is a floor that is gone, so its `test/pre-push-llm-skill-review-gate.bats` changes have no target and conflict with the merged version. Only this tracker was salvaged from it. The durable lesson survives even though the code did not: **a bats harness that redefines a production constant in its own generated preamble silently voids the coverage it appears to provide.** Worth checking for elsewhere.

## WS9 — Residual human / ops

- [-] [20260815-29] **Push `fix/history-scan-hardening`** — superseded. Original machine-local branch was recovered as `fix/history-scan-hardening-v2` and merged via PR #1197.
- [-] [20260815-30] **Honest score for HEAD `cd18d676`** — superseded. That SHA is not `origin/dev`; the history-scan skill on `origin/dev` is the #1197 tree. Gate 6 no longer floor-compares a mean (ADR-003).
- [x] [20260815-31] **Sub-floor exception mechanism — RESOLVED by ADR-003 (merged, `ac17f42b`).** Gate 6 no longer floor-compares a mean; `LLM_SKILL_REVIEW_MIN` is gone. No bypass, no `--no-verify`, no constant edit needed.
- [x] [20260815-32] **E4 — envelope not bound to the diff — CONFIRMED AND FIXED on PR #1193 (`c1456557`).** Verified exploitable end to end: an unreviewed edit to `skills/engineering/llm-skill-review/skill.md` cleared Gate 6 via a copied envelope, because the resulting sentinel names the *new* commit and satisfies the staleness check. Envelopes now carry `head_sha` checked against the commit being cleared, and at least one `clean_dimensions` entry must carry replayable evidence. The same defect class was found and fixed in the sibling internal toolkit's two sentinel writers, where an empty envelope was the documented quick-start.
- [x] [20260815-33] **Dependabot #1186 / `@hono/node-server` path traversal** — pin `2.1.0` via `mcp/package.json` `overrides` (GHSA-frvp-7c67-39w9; 1.19.14 was in range and vulnerable). Lockfile + `npm audit` 0 vulnerabilities. GitHub Dependabot alert close still needs a human (this agent cannot dismiss alerts).
- [ ] [20260817-04] **Human: close issue #1187** if ADR-003 + the merged calibration PRs answer it; this agent cannot close issues (`gh` is read-only for issues).
- [ ] [20260817-05] **Human: dismiss the open Dependabot/GitHub alert** for `@hono/node-server` after this pin is on `origin/dev` (API 403 from this agent).
- [ ] [20260817-06] **Prune leftover remote `origin/fix/history-scan-hardening`** (older WIP; skill diff vs `origin/dev` empty). Branch-delete is a RED action; needs an explicit prune approval, not bundled with a feature-branch push.
- [ ] [20260817-07] **Promote this CVE pin `dev → staging → main`** after it merges to `origin/dev`. Promotion needs a fresh "approve push" in the session that does it (authorization does not survive compaction/handoff).

---

## HISTORY

### 2026-08-15
- [x] [20260815-01] Landed eli5 skill commits onto `cursor/handoff-todo-workstreams-1111` from `origin/dev`
- [x] [20260815-02] Opened working PR #1190 with honest eli5 score disclosure
- [x] [20260815-04] Confirmed #1188 merged
- [x] [20260815-05]–[20260815-07]/[20260815-21] repo-security-scan history completeness + pattern parity + requires/prose fix + DAG
- [x] [20260815-08] Confirmed #1189 merged (find-polluter)
- [x] [20260815-09]–[20260815-11] systematic-debugging threshold / companions / rationale
- [x] [20260815-12]–[20260815-13] llm-skill-review Evidence Schema + terminology
- [x] [20260815-14] ADR-003 gate pass-condition proposal (revised after PHR REJECT: severity schema, non-vacuous proof, S0 waiver rules)
- [x] [20260815-16] ADR-004 guidance-regression fixtures (Proposed; renamed from overclaimed "behavioral")
- [x] [20260815-18] Fixed leftover "combined score" in run-llm-skill-review.sh + pre-push gate message
- [x] [20260815-19] Fixed eli5 broken summarization-skill redirect
- [x] [20260815-20] Multi-gate re-review: fixed S0 truncation/parity, S2 path, S3 dup section, ADR PHR gaps; wrote CRB/PHR/llm-skill-review sentinels (llm mean 8.6 < Gate 6 floor 9.0)

### 2026-08-17
- [x] [20260817-01] History-scan hardening recovered as PR #1197 and promoted (#1198/#1199)
- [x] [20260817-02] ADR-003 Gate 6 v2 + ADR-004 guidance-regression accepted and implemented (PR #1193)
- [x] [20260817-03] Pin MCP transitive `@hono/node-server` 1.19.14 → 2.1.0 (`overrides`); tracker catch-up for WS8/WS9 stale claims
- [x] [20260817-08] Hermeticize `test/use-skill-cli.test.js` known-skill case; add it to CI node-tests (was local-`test-all.sh`-only and required `~/.codex/skills`)
