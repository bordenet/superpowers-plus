---
name: hotfix-charter
source: superpowers-plus
augment_menu: true
auto_invoke: true
triggers:
  - "git checkout -b hotfix/"
  - "git checkout -B hotfix/"
  - "git switch -c hotfix/"
  - "git checkout -b fix/<TICKET-ID>-"
  - "git switch -c fix/<TICKET-ID>-"
  - "creating a hotfix"
  - "hotfix branch"
  - "production hotfix"
  - "shipping a hotfix"
  - "fix for prod"
  - "I need to hotfix"
  - "/sp-hotfix-charter"
anti_triggers:
  - "feature branch"
  - "refactor branch"
  - "experimental branch"
description: "Gates `hotfix/*` branches (and `fix/*` when `CHARTER_BRANCH_PREFIXES` is set) on a HOTFIX-CHARTER.md (symptom + diff budget + cr-battery pre-commit verdict + refactoring disposition). Prevents the incident-2026-1507 failure mode (a hotfix that grew to 73 files / +8,750 / -4,195 LOC because nobody asked 'is this the smallest thing that fixes the symptom?')."
summary: "Charter discipline for prod hotfixes: one-sentence symptom, explicit LOC budget, cr-battery on staged diff BEFORE first commit, recorded refactoring disposition. Enforced by tools/hotfix-charter-check.sh (pre-commit hook). Layered on top of unified-commit-gate, not a replacement."
coordination:
  group: commit-gates
  order: -10
  requires: []
  enables: ["unified-commit-gate"]
  internal: false
composition:
  consumes: [branch-context]
  produces: [hotfix-charter]
  capabilities: [gates-quality]
  priority: 50
---

# Hotfix Charter

> **Wrong skill?** Branch-naming sanity check → `git-branch-conventions`. Lint/test/IP gate at commit time → `unified-commit-gate`. Per-commit size cap → `pre-push-loc-gate` (`tools/pre-push-loc-gate.sh`). Adversarial code review → `code-review-battery`.

> **2026-06-10 incident calibration:** incident-2026-1507 MR grew to +8,750 / -4,195 LOC across 73 files on a hotfix branch because nobody captured the symptom upfront, set an LOC ceiling, or ran cr-battery on the staged diff before the first commit. This skill forces those three things at the moment the hotfix branch is created.

## When to Use

- The agent (or operator) runs `git checkout -b hotfix/...`. By default the hook gates the `hotfix/` prefix only; to also gate ticketed `fix/<TICKET-ID>-...` branches, set `CHARTER_BRANCH_PREFIXES="hotfix/ fix/"` (this then gates every `fix/*` branch — generic `fix/anything` feature work included, which normally runs through `branch-flow-gate`).
- A production bug needs a same-day fix (symptom is a behavior the customer can observe, NOT "let's redesign this properly")
- Skip when: feature work, refactors, experimental branches, documentation. Those have their own gates (`branch-flow-gate`, `unified-commit-gate`).

## The Charter Sections

The hotfix MUST start with a `HOTFIX-CHARTER.md` file at the repo root containing exactly these four sections:

```markdown
## Symptom (one sentence)

(What the customer sees. NOT what's broken in the architecture, NOT what
you'd ideally redesign. The observable bug: "Greeting clips at 700ms on
Azure-via-failover path.")

## Diff budget (LOC ceiling)

(An integer. The smallest change that fixes the symptom. incident-2026-1507 minimum
was ~80 LOC; the broken MR shipped at 12,945 LOC because nobody set
this number upfront. Examples: `80`, `200`, `500`. Anything > 500 needs
explicit PM sign-off in this section.)

## cr-battery pre-commit verdict

(Result of running cr-battery on the STAGED diff BEFORE the first commit
on this branch. Must be PASS or PASS_WITH_NITS at the project's quality
floor. The hook below refuses commits if this section reads anything else.
Re-run cr-battery and update this section if the staged diff changes.)

## Refactoring disposition

PARK — deferred extracting the duplicated `buildRetryPayload` helper (added twice in this diff); minimal-diff hotfix.
```

Replace the example with your real decision — do not paste it unedited. The rules:

- **Token.** The first non-blank body line contains exactly one of
  `REFACTOR_NOW` / `PARK` / `NONE` as a whole word — put it first, then one
  concrete reason. Only that first line is scanned for the token (backticked
  spans stripped), so a later reason line may say "none of the callers" freely.
- **Bias.** `NONE` for a clean fix; `PARK` when you actually spotted deferrable
  structure. `REFACTOR_NOW` only when the refactor *is* the fix or a true
  preparatory refactor.
- **Citation (`PARK` / `REFACTOR_NOW`).** Cite in backticks a symbol whose
  identifier run matches `[A-Za-z_][A-Za-z0-9_]{2,}` (no leading digit, 3+
  chars) and that appears in your staged added content. A bare (non-backticked)
  symbol, or a one-character "symbol" like `.`, fails.
- **Ceiling (`NONE`).** The staged diff must change at most
  `DISPOSITION_NONE_MAX_LINES` (default 30) lines, additions and deletions
  counted together.
- **Reason.** The hook does not check it is meaningful — a body of just `PARK`
  plus a backticked symbol passes. Writing a real reason is yours and the
  reviewer's job.
- **Structure.** An `## ` (h2) heading closes the section; keep no other h2 in
  the body.

## Enforcement: tools/hotfix-charter-check.sh

The pre-commit hook at `tools/hotfix-charter-check.sh` (wire into `.git/hooks/pre-commit`) reads the current branch name and, if it matches a `CHARTER_BRANCH_PREFIXES` prefix (default `hotfix/`):

1. Checks that `HOTFIX-CHARTER.md` exists at the repo root
2. Parses each of the four sections (case-sensitive PREFIX-match)
3. Refuses the commit if any section is missing OR if the cr-battery section doesn't contain `PASS` or `PASS_WITH_NITS`
4. Enforces the `## Refactoring disposition` template exactly as shown above — the token rule, the citation rule, and the `NONE` change-line ceiling. It does not judge whether the reason is meaningful.
5. Bypass: `ALLOW_NO_CHARTER=1 git commit ...` (prints WARNING)

**Env overrides:**
- `ALLOW_NO_CHARTER=1` — bypass the whole hook (prints WARNING, no audit trail)
- `CHARTER_BRANCH_PREFIXES` — space-separated gating prefixes (default `hotfix/`)
- `REQUIRE_DISPOSITION` — set `0`/`false`/`no`/`off` to skip ONLY the disposition check (rollout hatch; prints a WARNING); the three original sections still enforce. A truthy-looking value still enforces. Default on. For a legitimately large-but-flat or deletion-heavy hotfix, use this — not `ALLOW_NO_CHARTER=1`, which drops every check.
- `DISPOSITION_NONE_MAX_LINES=N` — max total changed lines (added + deleted) allowed with a `NONE` disposition (default `30`); a non-integer value exits 2

**Exit codes** (unchanged contract):
- 0: Branch not gated, OR charter valid with PASS/PASS_WITH_NITS
- 1: Charter missing, section missing, bad verdict, OR disposition problem
- 2: Git/env error (detached HEAD, not in repo, non-integer `DISPOSITION_NONE_MAX_LINES`) — fails CLOSED

## Layering with peer skills

This skill runs FIRST (`order: -10`), then `unified-commit-gate` (`order: 0`) handles lint/test/review. `hotfix-charter` does NOT replace `unified-commit-gate`; it runs BEFORE it.

## How to Apply

On the FIRST turn after `git checkout -b hotfix/...` (or a `fix/...` branch when `CHARTER_BRANCH_PREFIXES` gates it):

1. **Capture the symptom** in one sentence (customer-observable behavior, NOT architecture)
2. **Set a diff budget** (smallest LOC ceiling that fixes the symptom; default 200)
3. **Sketch the minimum diff** (don't redesign, don't refactor)
4. **Run cr-battery** on the STAGED diff; write verdict to HOTFIX-CHARTER.md
5. **Record the refactoring disposition** — first line opens with one token (`NONE` for a clean fix, `PARK` if you spotted deferrable structure), then one concrete reason. If you `PARK`/`REFACTOR_NOW`, cite in backticks a real symbol from your staged diff. If the hotfix legitimately changes more than `DISPOSITION_NONE_MAX_LINES` lines of flat, un-refactorable structure, or is mostly a deletion, set `REQUIRE_DISPOSITION=0` for that commit and note it in the MR — never `ALLOW_NO_CHARTER=1`, which drops the entire charter gate.
6. **Commit** — on a gated branch the hook verifies all four sections and that the verdict is PASS/PASS_WITH_NITS
   - If hook rejects: fix the failing section (missing heading or non-PASS verdict) and re-run cr-battery on the staged diff before retrying the commit. If cr-battery fails a second time, do not loop — escalate to human with both verdict outputs.

**Rollout:** a `hotfix/*` branch created before this section existed fails its next commit until you add `## Refactoring disposition`. `REQUIRE_DISPOSITION=0` is the transition hatch for a hotfix already in flight.

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| `... must open with EXACTLY ONE ... (found N on the first line)` | The first body line has no token, or a bare uppercase `PARK`/`NONE`/`REFACTOR_NOW` sits in the reason | Put exactly one token first; lowercase any token-word in the reason ("none of the callers") |
| `no cited symbol from '## Refactoring disposition' appears in the staged diff` | `PARK`/`REFACTOR_NOW` cites a symbol your diff never touched, or you pasted the template example unedited | Cite a real identifier from your added lines, or record `NONE` plus a follow-up issue for out-of-diff cleanup |
| `a NONE disposition is capped at N` | The change (added + deleted) exceeds the ceiling but has nothing to refactor-cite | `REQUIRE_DISPOSITION=0` for this commit + an MR note — never `ALLOW_NO_CHARTER=1` |
| Whole hook bypassed silently | `git commit --no-verify`, or `ALLOW_NO_CHARTER=1` (git design limit / documented bypass) | Out of scope for this skill; call the bypass out in the MR description |

If diff grows past budget: update the `## Diff budget` section with the new ceiling and a one-line rationale, then re-run cr-battery on the updated staged diff before retrying.
