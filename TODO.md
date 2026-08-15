# Workstreams — explain-like-im-five + llm-skill-review calibration handoff

Tracker for every finding from Claude's 2026-08-15 handoff (`claude/eli5-writing-skill-d08zzf`).
Working PR: https://github.com/bordenet/superpowers-plus/pull/1190 (`cursor/handoff-todo-workstreams-1111` → `origin/dev`).
Source issue: https://github.com/bordenet/superpowers-plus/issues/1187

Status legend: `[ ]` open · `[~]` in progress · `[x]` done · `[-]` cancelled / superseded

---

## WS1 — `explain-like-im-five` skill (thread 1)

New writing-domain skill `/eli5` plus catalog updates (skill count 112→113).
Four independent `llm-skill-review` rounds: final **PASS WITH RISKS**, Prose/Design **7.18–7.40** (never cleared 9.0 floor). No `.llm-skill-review-cleared`.

- [x] [20260815-01] Land skill + catalog commits onto branch from `origin/dev`
- [x] [20260815-02] Open working PR with honest score/verdict disclosure (no fabricated sentinel)
- [x] [20260815-19] Fix broken "summarization skill" Wrong-skill redirect (no such skill exists)
- [ ] [20260815-03] Human decision: merge as PASS WITH RISKS after Gate 6 policy call (see WS6), or hold
- [~] [20260815-20] Re-run llm-skill-review + PHR + cr-battery on this PR; clear sentinels only via official runners

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
- [ ] [20260815-15] Human checkpoint before changing Gate 6 enforcement machinery

## WS7 — Guidance-regression fixtures for prompt-only skills

- [x] [20260815-16] Write scoped design note as ADR-004 Proposed (`docs/adr/004-prompt-only-skill-guidance-regression.md`)
- [ ] [20260815-17] Human checkpoint before building fixture infrastructure

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

---

## DEFERRED (human checkpoints)

- [20260815-03] Merge/hold eli5 under current Gate 6 vs after ADR-003 acceptance
- [20260815-15] Gate 6 enforcement change — needs ADR-003 Accepted
- [20260815-17] Guidance-regression fixture runner — needs ADR-004 Accepted
- [20260815-20] Sentinel clearance after multi-gate re-review (in progress)
