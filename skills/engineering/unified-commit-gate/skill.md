---
name: unified-commit-gate
source: superpowers-plus
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

## When to Use

**Before `git commit`:** Run Gates 1–4 (lint/build/test, style, code review, language audit). **Before `git push` (Push Mode):** same gates plus sentinel check and proof-of-output requirement.

**Gate applicability:**
- **Before commit:** Gates 1 (lint/build/test), 2 (style), 3 (code review), 4 (language audit). Skip Gates 2 and 4 when no applicable file types are staged — you control invocation, nothing is automatic. Each invocation re-evaluates; results are not cached across invocations.
- **Before push (Push Mode):** All gates apply, plus sentinel check and proof-of-output requirement (see Push Mode section below). Gate 5 (IP audit) runs once per remote you push to; if pushing to multiple remotes, run Gate 5 once per remote. Skipped for confirmed private remotes — when in doubt, run the audit anyway.

**Not for:** code-review-only analysis (use `progressive-code-review-gate` directly instead). Debugging a single gate failure (load that gate's individual skill).

If any gate fails and the fix is non-obvious, load the individual deep-dive skill: `use-skill <gate-name>`.

## Push Mode

When invoked at push time (`git push`, `/sp-push`), all gates apply plus:

1. **Show output** — every gate result must appear in the conversation. "It passed" without visible output is a violation.
2. **Sentinel check** — before pushing any branch with code changes, verify `.code-review-cleared` exists for HEAD:

```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.code-review-cleared"
HEAD=$(git rev-parse HEAD 2>/dev/null)
cat "$SENTINEL" 2>/dev/null | grep -q "sha:${HEAD}" && echo "CLEARED" || echo "NOT CLEARED — run code-review-battery first"
```

| Sentinel state | Action |
|---|---|
| Valid for HEAD | Proceed to push |
| Missing or wrong SHA | Run `code-review-battery`, then push |
| Docs-only push (`.md`, `.txt`, `.rst`, `.gitignore`, `.editorconfig`, `README`, `CHANGELOG`, `LICENSE`, `.env.example`) | Sentinel not required |

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

**Show output for all commands**, including the shell scan. Claiming "it passes" without output is a violation.
**Gate fails?** → Fix, then re-run lint → typecheck → test in sequence (not just the failing step). Your fixes are new code and need their own full pass. Deep-dive: `use-skill pre-commit-gate`.

---

## Gate 2: Style Enforcement (shell scripts only)

**Run only when `.sh` files are staged.** Skip this gate if no shell scripts changed.

```bash
shellcheck -S warning <script.sh>   # zero warnings
bash -n <script.sh>                 # zero syntax errors
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

Check sentinel first:
```bash
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo .)/.code-review-cleared"
cat "$SENTINEL" 2>/dev/null && git diff --quiet && git diff --cached --quiet && echo "CLEARED"
```

If sentinel is valid for HEAD and worktree is clean → skip dispatch. Otherwise dispatch `sub-agent-code-reviewer` with the diff and instruction to read full source files.

**Verdict mapping:** Critical → FAIL | Important (≥2) → FAIL | Important (1) → PASS_WITH_NITS | Minor → PASS_WITH_NITS | Clean → PASS

**On FAIL:** Fix MUST-FIX and SHOULD-FIX, then full re-review. Cap at 5 rounds — stop and tell the human at Round 5.
**On PASS_WITH_NITS:** Fix nits, targeted re-review (affected files + original reviewers only).
**Gate fails?** Deep-dive: `use-skill progressive-code-review-gate`.

---

## Gate 4: Language Audit (user-facing content only)

**Run when staged changes include `.md` files, skill files, README, or wiki content.** Skip for pure code changes.

```bash
git diff --cached --name-only | grep -E '\.(md)$'
# For each matched file:
node ~/.codex/superpowers-plus/scripts/slop-dictionary.js scan-profanity <FILE.md>
```

**HARD GATE** — any profanity match blocks the commit. Fix and re-scan. Context-dependent terms (e.g., "kill process", "abort") are not flagged.

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
| Claiming gate passes without showing output | Violation — every gate requires visible tool output |
| Committing between gates | All 5 gates run as a single atomic sequence |
| Skipping Gate 3 for "small changes" | Size doesn't determine risk — all code commits get reviewed |
| Not re-running gates after fixing a failure | Fixes are new code — restart from Gate 1 |
| Updating ticket to "Done" before CI passes | Wait for build result, then update |
