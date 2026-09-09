# Refactoring Disposition Checkpoint — Design Record

> **Status: IMPLEMENTED** on branch `feat/refactoring-disposition` (PR into
> `origin/dev`). This is the "why", not the spec — for exact behavior read
> `tools/hotfix-charter-check.sh` and `test/hotfix-charter-check.bats`. Adapted
> from an earlier version in a private downstream fork (referenced for
> provenance only).

## 1. Problem

AI coding agents (Sonnet-class especially) reliably *add* complexity —
duplicate blocks, new branches, parallel helpers — instead of refactoring to
keep it minimal. Independent 2025 analyses point the same way: GitClear's
code-churn study (rising duplicate-block rate, falling moved-line rate in
AI-assisted repos), and METR's RCT, which found developers *feel* faster with
AI even where measured task time rose. The canonical local incident is
**incident-2026-1507**: a hotfix branch that grew to +8,750 / -4,195 LOC across
73 files because nobody asked "is this the smallest change, and does it leave
the code simpler than we found it?"

The ecosystem already has **minimal-diff enforcers** (`systematic-debugging`
Phase 4 `ONE change, no "while I'm here" improvements`; `scope-tripwire`;
`hotfix-charter`; `blast-radius-check`) and a **reactive cleanup** skill
(`cognitive-complexity-refactoring`, which fires after the fact — a
complexity-lint error, or an explicit "refactor this"). Nothing made the agent
*record a deliberate decision* about refactoring at the moment it fixes a bug.
This checkpoint adds that decision — a **Refactoring Disposition** — to the
artifacts those skills already produce, and enforces it mechanically where
enforcement already exists.

## 2. Scope

**In:**

- A recorded decision — `REFACTOR_NOW` / `PARK` / `NONE` plus one concrete
  reason — added to the hotfix charter (mechanically enforced) and the
  `systematic-debugging` wrap-up (advisory).
- One mechanical, language-agnostic check added to the existing
  `tools/hotfix-charter-check.sh` pre-commit hook.
- One advisory reviewer signal ("delete-or-explain") folded into the
  `code-review-battery` Design Critic's Factoring & Composition lens. This
  covers the **feature path** — see §4.2 for why it does not backstop the
  hotfix path.

**Out (deliberately not built):**

- No language-specific complexity-delta or clone-detection tooling. The
  backtick-citation grep is the only mechanical primitive, and it is
  language-agnostic.
- No new skill, gate, reviewer persona, or decision "receipt".
- No change to `scope-tripwire` (owns *scope*) or
  `cognitive-complexity-refactoring` (owns *executing* a refactor). This
  checkpoint owns only the *decision*.
- This repo has no `surgical-fix` skill; advisory coverage is
  `systematic-debugging` plus the Design Critic only. That asymmetry is
  intentional.
- The pre-existing `--no-verify` / `ALLOW_NO_CHARTER=1` bypasses (see §5).

## 3. The disposition contract

One of three tokens plus a reason:

| Token | Meaning | Requirement |
|-------|---------|-------------|
| `REFACTOR_NOW` | You refactored-for-simplicity as part of this change. | Cite the refactored symbol in backticks; it must appear in the staged added content. |
| `PARK` | You saw a refactoring opportunity and deliberately deferred it. | Cite the parked symbol in backticks; it must appear in the staged added content. |
| `NONE` | Nothing structural worth refactoring. | No citation, but only valid when the staged diff changes at most `DISPOSITION_NONE_MAX_LINES` lines (added + deleted). |

**Bias:** default `NONE` for a clean fix, `PARK` when you actually spotted
deferrable structure. `REFACTOR_NOW` is legitimate only when the refactor *is*
the fix or a true preparatory refactor. The checkpoint records a decision; it
never forces a refactor.

**Why backtick citations:** the verifier matches the backticked token as a
literal substring against the staged added lines, with a 3-char identifier
floor. This is a cheap deterministic forcing function, not a proof — a short
citation like `` `get` `` can collide with `getUser` in the diff. Its job is
to make a bare `PARK` cost one real reference to something *in this diff*; a
`PARK`/`REFACTOR_NOW` whose citation is absent fails. A deferral of out-of-diff
cleanup is therefore a `NONE` plus a follow-up issue, not a `PARK`.

**Two surface forms:**

- **Enforced (`hotfix-charter`):** a `## Refactoring disposition` section whose
  first non-blank body line opens with exactly one token, then the reason. The
  hook reads the token from that line only (backtick spans stripped), so a
  later reason line may contain the word "none" freely.
- **Advisory (`systematic-debugging`):** a `Refactoring-Disposition:` line in
  the fix commit message (or the `investigation-state` note). No heading, no
  hook — honor-system, and unmeasured (see §5).

## 4. What shipped

### 4.1 The verifier (`tools/hotfix-charter-check.sh`)

The hook already gated `HOTFIX-CHARTER.md` on branches matching a
`CHARTER_BRANCH_PREFIXES` prefix (default `hotfix/`). Enforcement is only as
real as the per-clone `.git/hooks/pre-commit` wiring — the hook does not
self-install. It now requires a fourth `## Refactoring disposition` section and
checks:

- **Token:** the first non-blank body line contains exactly one of
  `REFACTOR_NOW` / `PARK` / `NONE` as a whole word (backtick spans stripped
  first, so `` `LogLevel.NONE` `` is not miscounted). Zero or two-plus → exit 1.
- **Citation (`PARK` / `REFACTOR_NOW`):** a backticked token in the body
  matching `[A-Za-z_][A-Za-z0-9_]{2,}` (3+ chars, no leading digit) must appear
  as a substring in the staged added content. The charter file is excluded (a
  symbol named only in the charter cannot self-satisfy). Added content is
  extracted by `@@`-hunk state, not the `--- `/`+++ ` file header, so a real
  added line beginning `++ ` is not dropped. A deletion-only hotfix has no
  added content — then the citation-shape check is the only gate.
- **Ceiling (`NONE`):** `git diff --cached --numstat --no-renames` (charter
  excluded), added + deleted, must be `<= DISPOSITION_NONE_MAX_LINES`
  (default 30). Counting deletions and renames means a deletion- or move-heavy
  hotfix — which is refactoring — cannot hide under `NONE`. Binary blobs are
  not line-counted.

**Env vars:**

- `REQUIRE_DISPOSITION` — `0`/`false`/`no`/`off` (any case, space-tolerant)
  skips *only* the disposition check and prints a `WARNING`; the three original
  sections still enforce. A truthy-looking value still enforces (opposite
  polarity to `ALLOW_NO_CHARTER`). This is the sanctioned recovery for a
  legitimately large-but-flat or deletion-heavy hotfix — **not**
  `ALLOW_NO_CHARTER=1`, which drops every check.
- `DISPOSITION_NONE_MAX_LINES` — the ceiling (default 30). A non-integer or
  out-of-range value exits 2, validated once up front on every disposition
  path — the same "env error" class as detached HEAD, so a typo blocks the
  emergency commit until you fix it or `unset` it.

The `0/1/2` exit-code contract is unchanged: a disposition content problem is
exit 1; a malformed `DISPOSITION_NONE_MAX_LINES` or a failed `git diff` is
exit 2.

### 4.2 Skill prose

- **`hotfix-charter/skill.md`:** fourth charter section in the template, plus
  the enforcement list, env-override list, a How-to-Apply step, a Rollout
  note, and a Failure Modes table.
- **`systematic-debugging/skill.md`:** Phase 4 gains a "Record the refactoring
  disposition" item — advisory, honor-system — glossing the shared vocabulary
  and pointing at `hotfix-charter`, without weakening the "ONE change" rule.
- **`code-review-battery` Design Critic:** a delete-or-explain bullet under
  dimension 1 (Factoring & Composition) — a diff that adds a path duplicating
  or superseding code it leaves in place is accretion. A bullet, not a new
  numbered dimension, so the "4 dimensions" enumerations in `PRD.md` and the
  coverage matrix stay accurate. **This is feature-path only:** on `hotfix/*`
  and `fix/[A-Z]+-[0-9]+` branches `code-review-battery` runs Bug Fix Mode,
  where the Design Critic is suppressed by default unless the diff has
  API-change signals. So on the hotfix path the mechanical ceiling plus the
  mandatory human review (`progressive-code-review-gate`) are the backstop, not
  the Design Critic. A **ticketed `fix/[A-Z]+-[0-9]+` branch is the weakest
  case**: Bug Fix Mode suppresses the Design Critic there too, and the
  disposition hook does not gate it by default (§5) — so unless
  `CHARTER_BRANCH_PREFIXES` is extended, only the human reviewer is left.

### 4.3 Tests

`test/hotfix-charter-check.bats` grew from 13 to 48 cases: token counts
(0 / 2 / 3), the first-line rule, the identifier-shape citation filter,
self-satisfaction exclusion, the churn ceiling at exactly N and N+1, deletion-
and rename-heavy diffs, the `-- `/`++ ` diff-line adjacency, a CRLF charter,
the colon and parenthesized heading forms, the `CHARTER_BRANCH_PREFIXES`
override, `REQUIRE_DISPOSITION` truthy/`0`, and non-integer / overflow
`DISPOSITION_NONE_MAX_LINES` on both paths.

## 5. Risks & limitations

- **Rote-`NONE` residual.** The churn ceiling deters "changed 200 lines,
  disposition `NONE`", but a diff just under the ceiling can still rote-`NONE`.
  On the hotfix path the ceiling is the only automated check on this; the
  mandatory human review (`progressive-code-review-gate` /
  `requesting-code-review`) is the non-deterministic backstop, since the Design
  Critic is suppressed in Bug Fix Mode (§4.2).
- **Deletion-only hotfix defeats the citation content-check.** With no added
  content the citation-shape check is the only gate — `PARK` plus any 3+char
  backticked string passes. A large deletion is refactoring; the honest call is
  `REQUIRE_DISPOSITION=0` for that commit plus an MR note (§4.1), not a
  hand-waved `PARK`.
- **Advisory tier is honor-system *and* unmeasured.** `systematic-debugging`
  has no hook, and nothing looks for `Refactoring-Disposition:` in debug-fix
  commits — adoption there is unknowable. Only `hotfix-charter` (the
  incident-2026-1507 population) is mechanically enforced.
- **Pre-existing bypasses unchanged.** `--no-verify` and `ALLOW_NO_CHARTER=1`
  still skip the whole hook.
- **`fix/<TICKET-ID>-*` is not gated by default** — only `hotfix/`. Gating
  ticketed `fix/` branches needs `CHARTER_BRANCH_PREFIXES="hotfix/ fix/"`,
  which then gates every `fix/*`. Pre-existing; the skill and hook header now
  state it. Combined with §4.2, a ticketed `fix/` branch is the least-covered
  case.
- **Outcome is not observable at pre-commit time.** §1's goal (less accretion)
  has no direct signal.
  - **Owner:** the engineer running the `staging → main` batch review
    (`AGENTS.md` §"Git Workflow" — "batch review approval" — and
    `merge-authorization-gate`). No new cadence.
  - **What to pull:** the disposition-token mix from merged
    `HOTFIX-CHARTER.md` files, and a grep of merged-PR descriptions for
    `REQUIRE_DISPOSITION=0` / `ALLOW_NO_CHARTER=1` mentions.
  - **Caveat:** hotfix charters are branch-root working files often removed or
    squashed before merge, so the charter-history source may capture little;
    the PR-description grep is the more reliable half. If both come up empty
    across two release windows, the measurement is not working — say so rather
    than assume success.
  - **Baseline:** the first reading. **Revisit trigger:** `NONE` > 60% of
    dispositions over a window, or a bypass note in more than 1 in 5 hotfix
    PRs → raise the ceiling, sharpen the skill prose, or reconsider the
    checkpoint.

## 6. Pointers

- Verifier + tests: `tools/hotfix-charter-check.sh`,
  `test/hotfix-charter-check.bats`
- Skills: `skills/engineering/hotfix-charter/`,
  `skills/engineering/systematic-debugging/`,
  `skills/engineering/code-review-battery/reviewers/design-critic.md`
- Layers with: `scope-tripwire` (scope), `cognitive-complexity-refactoring`
  (executing a refactor), `unified-commit-gate` (runs after this at commit
  time)
