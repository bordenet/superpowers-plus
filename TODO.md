# Workstreams — explain-like-im-five + llm-skill-review calibration handoff

Tracker for every finding from Claude's 2026-08-15 handoff (`claude/eli5-writing-skill-d08zzf`).
Working PR branch: `cursor/handoff-todo-workstreams-1111` (base `origin/dev`).
Source issue: https://github.com/bordenet/superpowers-plus/issues/1187

Status legend: `[ ]` open · `[~]` in progress · `[x]` done · `[-]` cancelled / superseded

---

## WS1 — `explain-like-im-five` skill (thread 1)

New writing-domain skill `/eli5` plus catalog updates (skill count 112→113).
Four independent `llm-skill-review` rounds: final **PASS WITH RISKS**, Prose/Design **7.18–7.40** (never cleared 9.0 floor). No `.llm-skill-review-cleared`.

- [x] [20260815-01] Land skill + catalog commits onto branch rebased from `origin/dev`
- [x] [20260815-02] Open working PR with honest score/verdict disclosure (no fabricated sentinel)
- [ ] [20260815-03] Human decision: merge as PASS WITH RISKS after Gate 6 policy call (see WS6), or hold

## WS2 — `--min-score` self-contradiction (thread 2)

- [x] [20260815-04] PR #1188 merged into `origin/dev` (2026-08-15) — definition now Prose/Design mean only

## WS3 — `repo-security-scan` history gap + `requires` edge (S0/S1)

- [x] [20260815-05] Add required git-history secrets scan to Phase 1 (gitleaks `--log-opts=--all` with portable `git log -p` fallback)
- [x] [20260815-06] Narrow Verification so "zero remaining issues" means HEAD + history
- [x] [20260815-07] Set `coordination.requires: ["security-upgrade"]` and regenerate `docs/skill-dependency-graph.md`

## WS4 — `systematic-debugging` contradictions + cleanup (S1)

- [x] [20260815-08] `find-polluter.sh` word-split/glob bug — already fixed via PR #1189 on `origin/dev`
- [x] [20260815-09] Unify fix-attempt threshold to **2+** everywhere (Phase 4 / rationalizations / section heading)
- [x] [20260815-10] Deduplicate Companion Skills into one list
- [x] [20260815-11] Remove stale "condensed to 88 lines" claim from override rationale

## WS5 — `llm-skill-review` Evidence Schema + terminology (S1/S3)

- [x] [20260815-12] Add `reviewer` / `dimension` to Evidence Schema worked example in `reference.md`
- [x] [20260815-13] Replace stray `<combined-score>` placeholder with Prose/Design-mean wording

## WS6 — Gate pass-condition redesign (calibration follow-up)

Calibration: three already-merged core skills scored below eli5 and hit REJECT under the same process. A self-typed 9.0 floor nothing cross-checks is how defects went unnoticed.

- [x] [20260815-14] Write ADR proposing pass on **verdict + zero unresolved S0/S1 + evidence-replay success**, with Prose/Design score as metadata (see `docs/adr/003-llm-skill-review-gate-pass-condition.md`)
- [ ] [20260815-15] Human checkpoint before changing Gate 6 enforcement machinery

## WS7 — Behavioral fixtures for prompt-only skills (deferred design)

- [x] [20260815-16] Write scoped design note (`docs/adr/004-prompt-only-skill-behavioral-fixtures.md`)
- [ ] [20260815-17] Human checkpoint before building fixture infrastructure

---

## HISTORY

### 2026-08-15
- [x] [20260815-01] Cherry-picked eli5 skill commits onto `cursor/handoff-todo-workstreams-1111` from `origin/dev`
- [x] [20260815-04] Confirmed #1188 merged
- [x] [20260815-05]–[20260815-07] repo-security-scan history + requires + DAG
- [x] [20260815-08] Confirmed #1189 merged (find-polluter)
- [x] [20260815-09]–[20260815-11] systematic-debugging threshold / companions / rationale
- [x] [20260815-12]–[20260815-13] llm-skill-review Evidence Schema + terminology
- [x] [20260815-14] ADR-003 gate pass-condition proposal
- [x] [20260815-16] ADR-004 behavioral fixtures design note

---

## DEFERRED (human checkpoints)

- [20260815-03] Merge/hold eli5 under current Gate 6 vs after ADR-003 acceptance
- [20260815-15] Gate 6 enforcement change — needs ADR-003 Accepted
- [20260815-17] Prompt-only behavioral fixture runner — needs ADR-004 Accepted
