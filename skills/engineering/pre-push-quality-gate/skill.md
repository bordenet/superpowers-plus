---
name: pre-push-quality-gate
source: superpowers-plus
triggers: ["git push", "push to", "pushing", "ready to push", "about to push", "push branch", "push origin", "push remote"]
anti_triggers: ["review PR", "deploy to", "merge to main"]
description: "Mandatory quality gate before ANY git push. Auto-detects repo toolchain (Biome/ESLint, tsc, vitest/jest) and runs lint+typecheck+test. Output must be shown in conversation. No push without proof."
summary: "Use when: about to push code to any remote. Blocks push until lint/typecheck/test pass."
coordination:
  group: push-gates
  order: 1
  requires: []
  enables: ["push-authorization-gate"]
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [lint-results, test-results]
  capabilities: [gates-quality]
  priority: 30
---

# Pre-Push Quality Gate

> **Source:** `superpowers-plus`
> **Created:** 2026-04-01 after 4 avoidable CI failures across 3 repos in 2 days

## When to Use

- Before ANY `git push` to any remote (Azure DevOps, GitHub, GitLab)
- After amending commits (re-run -- amended code is untested code)
- After resolving merge conflicts
- Especially under time pressure (that is when mistakes happen)

## The Problem This Solves

Agents run `git push` without verifying lint/typecheck/test locally. CI catches the error 2-5 minutes later. Human reviews a broken build. Agent pushes a fix. Another CI cycle. Multiply by 3+ occurrences = unacceptable.

**Instructional skills ("please run lint") do not work.** This skill requires PROOF.

## ENFORCEMENT: Show Output or Do Not Push

The agent MUST show the actual terminal output of each gate in the conversation.
Claiming "I ran lint" without visible output is a VIOLATION.

```
REQUIRED before git push:

1. Show lint output     (exit code 0, in conversation)
2. Show typecheck output (exit code 0, in conversation)
3. Show test output     (pass count, in conversation)
4. If any gate fails    -> fix, re-run ALL gates, show output again
```

## Step 0: Code Review Sentinel (runs automatically via git hook)

The pre-push git hook checks for `.code-review-cleared` before allowing any push with code changes.

| Condition | Hook behavior |
|-----------|--------------|
| Docs/root-metadata only (`.md`, `.txt`, `.rst`, `.gitignore`, `.gitattributes`, `.editorconfig`, `README`, `CHANGELOG`, `LICENSE`, `.env.example`) — **excluding** `AGENTS.md` and `CLAUDE.md` which are policy files treated as code | Sentinel not required, push allowed |
| Config files present (`.json`, `.yaml`, `.toml`, `.sh`, `.py`, `.ts`, `.js`, etc.) | Treated as **code** — sentinel required |
| Code changes present, sentinel missing | **Push blocked** — run `code-review-battery` first |
| Code changes present, sentinel SHA ≠ pushed commit SHA | **Push blocked** — commits made after review; re-run battery |
| Code changes present, sentinel format not `v1` | **Push blocked** — delete `.code-review-cleared`, re-run battery |
| Code changes present, verdict not PASS/PASS_WITH_NITS | **Push blocked** — fix Critical/Important findings first |
| Code changes present, sentinel valid | ✅ Gate 1 passed |

**You do not manually invoke this step** — the hook runs it automatically on every `git push`. What you DO need to do: **run `code-review-battery` and let it write `.code-review-cleared` before you push code changes.** If you push and the hook blocks you, that means you forgot the battery.

## Step 1: Detect Repo Toolchain

```bash
# Check package.json scripts
cat package.json | grep -E '"(lint|typecheck|tsc|test|format)"' 2>/dev/null
# Check config files
ls biome.json biome.jsonc .eslintrc* tsconfig.json vitest.config.* jest.config.* 2>/dev/null
```

| Tool | Lint Command | Typecheck | Test |
|------|-------------|-----------|------|
| Biome + tsc + vitest | `npx biome check .` | `pnpm run typecheck` | `pnpm test` |
| ESLint + tsc + jest | `npx eslint .` | `npx tsc --noEmit` | `npx jest` |
| Shell only | `shellcheck *.sh` | N/A | `bats test/` |

## Step 2: Auto-Fix First, Then Verify

```bash
# Fix what can be auto-fixed
npx biome check --write .              # safe fixes
npx biome check --write --unsafe .     # unsafe fixes (optional chain, etc.)

# Then verify ZERO errors remain
npx biome check .                      # MUST exit 0
```

## Step 3: Typecheck

```bash
pnpm run typecheck    # or: npx tsc --noEmit
# MUST show zero errors in files you changed
# Pre-existing errors in untouched files: note them, proceed
```

## Step 4: Test

```bash
pnpm test -- --run    # or: npx vitest run
# MUST show all tests passing
# Infrastructure-only failures (missing env/Docker): note the skip
```

## Step 5: Amend If Auto-Fix Changed Files

```bash
git diff --stat
# If files changed from auto-fix:
git add -u
git commit --amend --no-edit
```

Do NOT create a separate "fix lint" commit. Amend.

## Step 5.5: URL Validation (if diff contains URLs)

Run this step after Step 5 (amend) so the check targets the final SHA that will be pushed. Check all `http://` and `https://` URLs added or changed in the diff. Fabricated URLs break user trust and cause silent failures.

```bash
# Determine merge base — detached HEAD (CI), tracking branch, repo config, or error
_tracking=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
_config=$(git config branch.integration-base 2>/dev/null)
_is_detached=$(git symbolic-ref HEAD 2>/dev/null || echo "DETACHED")
_shallow=false
_base=""

if [[ "$_is_detached" == "DETACHED" ]]; then
  # CI / detached HEAD: use FETCH_HEAD if present (set by git fetch in CI).
  # actions/checkout with fetch-depth:1 sets FETCH_HEAD but the common ancestor
  # may not be in the shallow history — merge-base will fail. Check for both.
  if git rev-parse --verify FETCH_HEAD >/dev/null 2>&1; then
    _base=$(git merge-base HEAD FETCH_HEAD 2>/dev/null)
    if [[ -z "$_base" ]] && git rev-parse --is-shallow-repository 2>/dev/null | grep -q true; then
      # Shallow clone with FETCH_HEAD present but no common ancestor in history.
      _shallow=true
    fi
  elif git rev-parse --is-shallow-repository 2>/dev/null | grep -q true; then
    # Shallow clone with no FETCH_HEAD at all.
    _shallow=true
  else
    _base=$(git merge-base HEAD HEAD^ 2>/dev/null)
  fi
elif [[ -n "$_tracking" ]]; then
  _base=$(git merge-base HEAD "$_tracking" 2>/dev/null)
elif [[ -n "$_config" ]]; then
  _base=$(git merge-base HEAD "$_config" 2>/dev/null)
else
  echo "⚠ URL validation skipped: no tracking branch or branch.integration-base config."
  echo "  Fix: git config branch.integration-base origin/main"
fi

if [[ "$_shallow" == "true" ]]; then
  git diff HEAD^..HEAD 2>/dev/null | grep -oE 'https?://[^[:space:]"'"'"'>)]+' | sort -u
elif [[ -n "$_base" ]]; then
  git diff "${_base}"..HEAD | grep -oE 'https?://[^[:space:]"'"'"'>)]+' | sort -u
fi

# For each non-trivial URL (exclude localhost, placeholder.*, example.com, 127.*):
curl -o /dev/null -s -w '%{http_code}\n' --max-time 8 '<url>'
```

| HTTP status | Action |
|-------------|--------|
| 2xx | ✅ OK — URL is reachable |
| 3xx | ⚠️ Verify redirect destination is correct |
| 4xx / 5xx | ❌ BLOCK — remove or fix URL before pushing |
| Timeout / no response | ❌ BLOCK — remove or fix URL before pushing |

**No URLs in diff → skip this step.**

## Step 6: Show Summary, Then Push

```
Quality gate passed:
  [x] Lint:      biome check -- 0 errors (output shown above)
  [x] Typecheck: tsc --noEmit -- 0 errors (output shown above)
  [x] Tests:     vitest -- N/N passing (output shown above)

Ready to push branch X to remote Y. Proceed?
```

Only AFTER this summary AND human approval: `git push`.

## Rationalization Prevention

| Excuse | Response |
|--------|----------|
| "I already ran lint earlier" | Code changed since. Run again. Show output. |
| "It's just formatting" | Biome rejects formatting. CI will fail. Run it. |
| "Biome passed so types are fine" | Biome does not check types. Run tsc. |
| "Tests take too long" | Lint + typecheck take 5 seconds. Run at minimum those two. |
| "I'll fix it in the next push" | CI doesn't accept IOUs. Fix now. |

## Minimum Viable Check (absolute floor)

If you think you can skip the full gate:

```bash
npx biome check . && npx tsc --noEmit
```

Two commands. 10 seconds. Non-negotiable. If either fails, fix before pushing.

## Incident Record

| Date | What Happened |
|------|---------------|
| 2026-03-31 | Pushed without running Biome. CI caught 18 lint errors. |
| 2026-03-31 | Pushed after script-generated JSON. Biome not re-run after file write. |
| 2026-03-31 | Ran Biome but not tsc. CI failed on TS4111 type errors. |
| 2026-04-01 | Ran tsc+vitest but skipped Biome. CI failed on 2 formatting errors. |
| 2026-04-01 | Pushed without Biome. Optional chain + formatting errors broke CI. |
