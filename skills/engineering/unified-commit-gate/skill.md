---
name: unified-commit-gate
source: superpowers-plus
augment_menu: true
triggers: ["/sp-commit", "/sp-push", "before commit", "ready to commit", "about to commit", "git commit", "committing", "push this", "before push", "commit gate", "commit:gate", "git push", "ready to push", "about to push", "push branch", "push origin", "push remote"]
anti_triggers: ["review PR", "review this PR", "output looks wrong", "debug this"]
description: "Unified quality gate for commit and push: lint/build/test, style, adversarial code review, language audit, and IP scan. For push: adds sentinel check and proof-of-output requirement. Replaces all 5 individual gate skills plus pre-push-quality-gate."
summary: "Use when: about to commit or push code. Runs all 5 gates; push mode adds sentinel check and proof-of-output requirement. Deep-dive into any gate: use-skill <gate-name>."
coordination:
  group: commit-gates
  order: 0
  requires: []
  enables: []
  escalates_to: [pre-commit-gate, enforce-style-guide, progressive-code-review-gate, professional-language-audit, public-repo-ip-audit]
  internal: false
composition:
  consumes: [code-changes]
  produces: [commit-clearance]
  capabilities: [gates-quality]
  priority: 30
---

> **Wrong skill?** Single gate deep-dive → load that gate's individual skill (`pre-commit-gate`, `progressive-code-review-gate`, etc.). Presenting results to human → `verification-before-completion`. Reviewing someone else's PR → `providing-code-review`.

# Unified Commit Gate

## Strategy before execution

Before every automated review or test/check pass, resolve a snapshot-bound
REUSE, WAIT, RUN_MINIMAL, REVIEW_REQUIRED or STOP decision at its supported
execution/dispatch boundary. Reuse valid coverage or join its active producer.
Missing/stale decisions refuse; unknown coverage stays conservative. No model
calls or recursive checks inside strategy. Status/HEAD changes, clean reviews
and score targets alone never justify another expensive pass.

## When to Use

**Before `git commit`:** Run Gates 1–4 (lint/build/test, style, code review, language audit). **Before `git push` (Push Mode):** same gates plus sentinel check and proof-of-output requirement.

**Gate applicability:**
- **Before commit:** Gates 1 (lint/build/test), 2 (style), 3 (code review), 4 (language audit). Skip Gates 2 and 4 when no applicable file types are staged — you control invocation, nothing is automatic. Each invocation re-evaluates applicability; passing validation is reused for unchanged tested content and context. A second skill or commit does not require a second execution.
- **Before push (Push Mode):** All gates apply, plus sentinel check and proof-of-output requirement (see Push Mode section below). Gate 5 (IP audit) runs once per remote you push to; if pushing to multiple remotes, run Gate 5 once per remote. Skipped for confirmed private remotes — when in doubt, run the audit anyway.

**Not for:** code-review-only analysis (use `progressive-code-review-gate` directly instead). Debugging a single gate failure (load that gate's individual skill).

If any gate fails and the fix is non-obvious, load the individual deep-dive skill: `use-skill <gate-name>`.

## Push Mode

When invoked at push time (`git push`, `/sp-push`), all gates apply plus:

1. **Use existing evidence first.** Record the tested content/context, suite,
   producer and log. Invoke the authoritative runner; it reuses a valid PASS or
   waits for an equivalent active run. Do not invoke raw sub-suites to evade reuse.
2. **Check actual review clearance.** Use the repository's native read-only
   parser/readiness tool, not a guessed sentinel format or HEAD-only grep.
   In superpowers-plus, `tools/push-readiness.sh --json` resolves the real gate
   scope. A valid content-scoped clearance survives a tree-identical merge or
   amend. Route only missing/invalidated review classes with `tools/review.sh`.
   Never write a sentinel directly or treat a blocked readiness report as PASS.

3. **Gate 5 (IP audit)** runs once per remote target. Run it for each remote you push to. Skip for confirmed private remotes — when in doubt, run it.

---

## Gate 1: Pre-Commit Checks (lint → build → test)

```bash
# If .sh files are staged — run first (show output):
~/.codex/superpowers-plus/tools/dangerous-pattern-scan.sh

# Lint (zero errors required)
npm run lint       # or: pnpm lint, biome check .

# Typecheck (zero errors required)
npm run typecheck  # or: tsc --noEmit

# Tests (all pass, or only pre-existing failures)
npm test           # or: vitest --run
```

**Retain evidence for all required checks.** A cached result must identify the successful producer, tested inputs/context and log. Do not re-execute a passing suite merely to print fresh output.
**Gate fails?** -> Fix the defect, then validate the changed inputs through lint -> typecheck -> test. Existing unaffected evidence remains valid; the runner must invalidate affected coverage. Deep-dive: `use-skill pre-commit-gate`.

### Post-Conflict Trap

**If you resolved conflicts this session:**

After any rebase, merge, cherry-pick, or `git stash pop` that produced conflicts, **typecheck is mandatory even if all tests pass**. TypeScript test runners (Vitest, Jest) transpile on the fly using esbuild — they do not invoke `tsc`. A missing constant, a deleted export, or a renamed symbol will not surface in `npm test`; it will only surface in `tsc --noEmit`. The same principle applies to other compiled languages: run the build/type check step explicitly — don't rely on the test runner alone. Run in this order after conflict resolution:

```bash
git diff --check && git diff --cached --check  # no conflict markers remain
npm run lint       # or: pnpm run lint
npm run typecheck  # or: tsc --noEmit   -- MANDATORY -- cannot be skipped
npm test           # or: vitest --run
```

Do not push after "tests pass" alone. Lint → typecheck → test are all mandatory after conflict resolution.

---

## Gate 2: Style Enforcement (shell scripts only)

**Run only when `.sh` files are staged.** Skip this gate if no shell scripts changed.

```bash
shellcheck -S warning "<script.sh>"   # zero warnings
bash -n "<script.sh>"                 # zero syntax errors
```

Each shell script MUST have: `#!/usr/bin/env bash`, `set -euo pipefail`, `-h|--help`, `-v|--verbose`, `--what-if` (for destructive scripts), ≤400 lines.

**Gate fails?** Fix violations, re-run shellcheck. Deep-dive: `use-skill enforce-style-guide`.

---

## Gate 3: Adversarial Code Review

```bash
# Gather the diff
git diff --staged        # pre-commit
git diff @{u}..HEAD      # pre-push unpushed commits
```

Check the native content-scoped readiness result first. Reuse valid review
clearance across unchanged commits/merges; missing or invalidated coverage requires
the correctly routed independent review. Do not duplicate a reviewer another skill
already dispatched for the same snapshot.

**Verdict mapping:** Critical → FAIL | Important (≥2) → FAIL | Important (1) → PASS_WITH_NITS | Minor → PASS_WITH_NITS | Clean → PASS

**On FAIL:** Fix MUST-FIX and SHOULD-FIX, then delta review of the fixes and affected paths by the original reviewer. Cap at 5 rounds — stop and tell the human at Round 5.
**On PASS_WITH_NITS:** Fix nits, targeted re-review (affected files + original reviewers only).
**Gate fails?** Deep-dive: `use-skill progressive-code-review-gate`.

---

Apply `human-comms-hygiene` when drafting commits, PRs, issues, comments, or
team messages: lead with the action or material change, keep customer symptoms
ahead of causes, and preserve evidence and required disclosures. Existing
verification and publication-authorization requirements still apply.

## Gate 4: Language Audit (user-facing content only)

**Run when staged changes include `.md` files, skill files, README, or wiki content.** Skip for pure code changes.

```bash
git diff --cached --name-only | grep -E '\.(md)$'
# For each matched file:
node ~/.codex/superpowers-plus/scripts/slop-dictionary.js scan-profanity "<FILE.md>"
```

**HARD GATE** — any profanity match blocks the commit. Fix and re-scan. Context-dependent terms (e.g., "kill process", "abort") are not flagged.

**PR title/body scan (before creating or updating a PR):** a PR's title and description are API metadata, not git-tracked files — the staged-file scan above never sees them. Write the intended title + body to a temp file and scan before `gh pr create`, and again before merging if the description was edited afterward:

```bash
printf '%s\n%s\n' "<PR TITLE>" "<PR BODY>" > /tmp/pr-desc.txt
node ~/.codex/superpowers-plus/scripts/slop-dictionary.js scan-ai-process-refs /tmp/pr-desc.txt
```

For `gh pr create --fill`, scan the resulting title/body before requesting
review or merging: `gh pr view --json title,body --jq '.title + "\n" + .body'`
can supply the text. Prefer an explicitly written description.

The scanner runs in every repository, including this one. Exit 0 means no
lexical candidates. File-read or pattern-loading errors always block publication,
even when the exit code is 1. Only a completed scan listing candidate matches
permits occurrence-by-occurrence review under
`human-comms-hygiene`; exit 2 means empty input and blocks publication.
Rewrite process narration. Retain a matched tool/skill name only when that
occurrence is the actual subject or a relevant product reference; record the
reason in local review evidence, not in the PR. Do not claim the lexical scan
passed when it returned matches. A mixed sentence must still lose its process
justification. No blanket repository or permanent phrase exemptions. Any
unresolved candidate blocks publication; factual and profanity gates remain.


**Gate fails?** Deep-dive: `use-skill professional-language-audit`.

---

## Gate 5: IP Audit (public repos only)

**Run only when target remote is public.** Check first:
```bash
git remote -v
# public hosting (github.com, codeberg.org, etc.) → run gate
# private hosting (self-hosted GitLab, Azure DevOps, etc.) → SKIP this gate
```

Build org-specific patterns (see `use-skill public-repo-ip-audit` for pattern registry guidance):
```bash
PATTERNS="TICKET-[0-9]+|YourCompany|wiki\.internal\.yourco\.net|dev\.azure\.com/YourOrg"
git ls-files -z | xargs -0 grep -lnE "$PATTERNS"   # working tree
git diff --staged | grep -nE "$PATTERNS"             # staged changes
git log -p origin/main..HEAD | grep -nE "$PATTERNS" # unpushed commits
```

Any match → **HARD BLOCK**. Fix and re-scan. Design docs and planning docs NEVER go in public repos.

**Recovery after a block:**
- **Single commit:** `git reset HEAD^ --soft` (un-commit, keep staged), remove or redact violations. Re-run Gate 5; if still blocked, repeat fix → re-scan until Gate 5 is clean before restarting from Gate 1.
- **Multi-commit:** Identify the offending commit: `git log -p origin/main..HEAD | grep -nE "$PATTERNS"`. Use `git rebase -i origin/main` to edit only the affected commit, amend the fix, complete the rebase. Re-run Gate 5 after rebasing before pushing. See `use-skill public-repo-ip-audit` for step-by-step guidance.

**Gate fails?** Deep-dive: `use-skill public-repo-ip-audit`.

---

## Post-Commit: Build Verification

**Do NOT update ticket status until ALL builds pass.**

```bash
# Check CI pipeline for your PR — all checks must pass
# NOT just "merge enabled" — that only confirms conflict-free, not builds
```

---

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Claiming a gate passes without evidence | Identify its real producer, inputs/context and log |
| Committing between gates | All 5 gates run as a single atomic sequence |
| Skipping Gate 3 for "small changes" | Size doesn't determine risk — all code commits get reviewed |
| Not re-running gates after fixing a failure | Fixes are new code — restart from Gate 1 |
| Updating ticket to "Done" before CI passes | Wait for build result, then update |
| Skipping typecheck after conflict resolution | Post-Conflict Trap — transpilers skip tsc; tests pass while type errors exist. Run lint → typecheck → test explicitly after every rebase, merge, cherry-pick, or stash-pop conflict |
