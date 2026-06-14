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
description: "Gates `hotfix/*` and `fix/<TICKET-ID>-*` branches on a HOTFIX-CHARTER.md (symptom + diff budget + cr-battery pre-commit verdict). Prevents the incident-2026-1507 failure mode (a hotfix that grew to 73 files / +8,750 / -4,195 LOC because nobody asked 'is this the smallest thing that fixes the symptom?')."
summary: "Charter discipline for prod hotfixes: one-sentence symptom, explicit LOC budget, cr-battery on staged diff BEFORE first commit. Enforced by tools/hotfix-charter-check.sh (pre-commit hook). Layered on top of unified-commit-gate, not a replacement."
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

- The agent (or operator) runs `git checkout -b hotfix/...` or `git checkout -b fix/<TICKET-ID>-...` (NOTE: only `fix/<TICKET-ID>-` prefix gates; generic `fix/anything` branches do NOT trigger the charter requirement -- those are feature work and run through `branch-flow-gate` instead)
- A production bug needs a same-day fix (symptom is a behavior the customer can observe, NOT "let's redesign this properly")
- Skip when: feature work, refactors, experimental branches, documentation. Those have their own gates (`branch-flow-gate`, `unified-commit-gate`).

## The Three Charter Sections

The hotfix MUST start with a `HOTFIX-CHARTER.md` file at the repo root containing exactly these three sections:

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
```

## Enforcement: tools/hotfix-charter-check.sh

The pre-commit hook at `tools/hotfix-charter-check.sh` (wire into `.git/hooks/pre-commit`) reads the current branch name and, if it matches `hotfix/*` or `fix/<TICKET-ID>-*`:

1. Checks that `HOTFIX-CHARTER.md` exists at the repo root
2. Parses each of the three sections (case-sensitive PREFIX-match)
3. Refuses the commit if any section is missing OR if the cr-battery section doesn't contain `PASS` or `PASS_WITH_NITS`
4. Bypass: `ALLOW_NO_CHARTER=1 git commit ...` (prints WARNING)

**Exit codes:**
- 0: Branch not gated, OR charter valid with PASS/PASS_WITH_NITS
- 1: Charter missing, section missing, OR bad verdict
- 2: Git error (detached HEAD, not in repo) — fails CLOSED

## Layering with peer skills

This skill runs FIRST (`order: -10`), then `unified-commit-gate` (`order: 0`) handles lint/test/review. `hotfix-charter` does NOT replace `unified-commit-gate`; it runs BEFORE it.

## How to Apply

On the FIRST turn after `git checkout -b hotfix/...` or `git checkout -b fix/<TICKET-ID>-...`:

1. **Capture the symptom** in one sentence (customer-observable behavior, NOT architecture)
2. **Set a diff budget** (smallest LOC ceiling that fixes the symptom; default 200)
3. **Sketch the minimum diff** (don't redesign, don't refactor)
4. **Run cr-battery** on the STAGED diff; write verdict to HOTFIX-CHARTER.md
5. **Commit** — the hook verifies all sections and verdict is PASS/PASS_WITH_NITS
   - If hook rejects: fix the failing section (missing heading or non-PASS verdict) and re-run cr-battery on the staged diff before retrying the commit.

If diff grows past budget: update the `## Diff budget` section with the new ceiling and a one-line rationale, then re-run cr-battery on the updated staged diff before retrying.
