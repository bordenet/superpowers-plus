---
name: unified-commit-gate
source: superpowers-plus
triggers: ["/sp-commit", "before commit", "ready to commit", "about to commit", "git commit", "committing", "push this", "before push", "commit gate", "commit:gate"]
anti_triggers: ["review PR", "review this PR", "output looks wrong", "debug this"]
description: "Unified pre-commit quality gate: lint/build/test, style, adversarial code review, language audit, and IP scan. Replaces loading all 5 individual gates. Deep-dive: load the individual gate skill."
summary: "Use when: about to commit code. Runs all 5 gates in sequence. Deep-dive into any gate: use-skill <gate-name>."
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

# Unified Commit Gate

**Run all 5 gates in order before every `git commit` or `git push`. Do NOT commit between gates.**

If any gate fails and the fix is non-obvious, load the individual deep-dive skill: `use-skill <gate-name>`.

---

## Gate 1: Pre-Commit Checks (lint → build → test)

```bash
# If .sh files are staged — run first:
~/.codex/superpowers-plus/tools/dangerous-pattern-scan.sh

# Lint (zero errors required)
npm run lint       # or: pnpm lint, biome check .

# Typecheck (zero errors required)
npm run typecheck  # or: tsc --noEmit

# Tests (all pass, or only pre-existing failures)
npm test           # or: vitest --run
```

**Show output for all commands.** Claiming "it passes" without output is a violation.
**Gate fails?** → Fix, re-run all three. Your fixes are new code and need their own pass. Deep-dive: `use-skill pre-commit-gate`.

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
SENTINEL="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')/.code-review-cleared"
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
