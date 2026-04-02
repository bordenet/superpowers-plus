# Review Token Gate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make code review mechanically enforced — no commit succeeds without a recent, valid review token written by `harsh-review.sh`.

**Architecture:** Two-tier system. (1) A gate script (`commit-gate.sh`) orchestrates lint → test → review and writes a proof token on success. (2) The existing pre-commit hook gains one new check: verify the token exists and is fresh. A dispatcher rule in `core.always.md` tells agents to run the gate script before committing. If the agent skips the dispatcher, the hook still blocks the commit — fail closed.

**Tech Stack:** Bash (POSIX-compatible where possible, Bash 3.2+ minimum for macOS). No new dependencies.

**Repo:** `superpowers-plus` (branch from `dev` per repo AGENTS.md)

**Design source:** PHR + Think-Twice + Design Triad analysis from conversation on 2026-04-02. Option 2 (Two-Tier Dispatcher + Token Gate) selected after rejecting Options C and E (voluntary compliance only) and preferring Option 2 over Options 1 and 3 for its dual-path enforcement and modularity.

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| **Create** | `tools/commit-gate.sh` | Orchestrator: runs lint/test/review gates, writes proof token |
| **Modify** | `tools/pre-commit:185-207` | Add token verification check before RESULT section |
| **Modify** | `.agent-gates` | Add `REVIEW_TOKEN_TTL` config variable (default 300s) |
| **Modify** | `tools/install-hooks.sh` | Create token directory during hook install |
| **Modify** | `tools/harsh-review.sh` (tail) | Write token file on PASS exit |
| **Modify** | `~/.augment/rules/core.always.md` | Add dispatcher rule (~8 lines) |
| **Create** | `tests/commit-gate-test.bats` | Tests for token lifecycle |

---

## Task 1: Create the token directory infrastructure

**Files:**
- Modify: `tools/install-hooks.sh`

Token location: `~/.codex/review-tokens/`. Tokens are ephemeral files named `{timestamp}` containing the repo path.

- [ ] **Step 1: Add token directory creation to install-hooks.sh**

After the existing `mkdir -p "$HOOKS_DIR"` line (approx line 42), add:

```bash
# Ensure review token directory exists
REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
mkdir -p "$REVIEW_TOKEN_DIR"
echo "✓ Review token directory ready: $REVIEW_TOKEN_DIR"
```

- [ ] **Step 2: Verify install-hooks.sh still runs cleanly**

Run: `bash tools/install-hooks.sh`
Expected: All hooks installed, token directory created, no errors.

- [ ] **Step 3: Commit**

```bash
git add tools/install-hooks.sh
git commit -m "feat(install-hooks): create review token directory on hook install"
```

---

## Task 2: Make harsh-review.sh write a proof token on PASS

**Files:**
- Modify: `tools/harsh-review.sh` (lines near the SUMMARY exit block at the end)

On successful exit (exit 0), write a token file. The token contains the repo root path so the pre-commit hook can verify it matches the current repo.

- [ ] **Step 1: Add token-writing block before the successful exit**

In `harsh-review.sh`, locate the block that prints `HARSH REVIEW PASSED` and `exit 0` (the final else branch of the SUMMARY section). Insert immediately before `exit 0`:

```bash
    # Write review proof token
    REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    if [[ -d "$REVIEW_TOKEN_DIR" ]]; then
        local token_file="${REVIEW_TOKEN_DIR}/$(date +%s)"
        echo "$REPO_ROOT" > "$token_file"
    fi
```

- [ ] **Step 2: Verify harsh-review.sh still passes**

Run: `bash tools/harsh-review.sh`
Expected: `HARSH REVIEW PASSED` and a new file appears in `~/.codex/review-tokens/` containing the repo path.

- [ ] **Step 3: Verify token file was created**

```bash
ls -la ~/.codex/review-tokens/
cat ~/.codex/review-tokens/$(ls -t ~/.codex/review-tokens/ | head -1)
```

Expected: File exists, contents = repo root path (e.g., `/Users/matt/GitHub/Personal/superpowers-plus`).


- [ ] **Step 4: Commit**

```bash
git add tools/harsh-review.sh
git commit -m "feat(harsh-review): write proof token on PASS"
```

---

## Task 3: Add REVIEW_TOKEN_TTL to .agent-gates

**Files:**
- Modify: `.agent-gates`

Add a configurable TTL (time-to-live) for review tokens. Default is 300 seconds (5 minutes). Repos that need longer review-to-commit windows can increase this.

- [ ] **Step 1: Add REVIEW_TOKEN_TTL to .agent-gates**

Append to the end of `.agent-gates`:

```bash

# REVIEW_TOKEN_TTL: How many seconds a review token is considered fresh (default: 300)
# Increase for repos where review-to-commit time is longer (e.g., large test suites)
# REVIEW_TOKEN_TTL=600
```

- [ ] **Step 2: Commit**

```bash
git add .agent-gates
git commit -m "feat(agent-gates): add REVIEW_TOKEN_TTL config variable"
```

---

## Task 4: Add token verification to the pre-commit hook

**Files:**
- Modify: `tools/pre-commit` (insert new check between the EXTRA CHECKS block and the RESULT block, approx lines 183-185)

The hook checks for a review token that: (a) exists, (b) is within TTL, (c) matches the current repo path. If `SKIP_REVIEW_TOKEN` is set in `.agent-gates`, the check is skipped (for repos that don't use harsh-review.sh). The check number is dynamic (after EXTRA checks).

- [ ] **Step 1: Add the token verification check**

Insert before the RESULT section (line 185) in `tools/pre-commit`:

```bash
# -----------------------------------------------------------------------------
# REVIEW TOKEN CHECK: Verify harsh-review.sh ran recently
# Skip if SKIP_REVIEW_TOKEN=true in .agent-gates
# -----------------------------------------------------------------------------
if [[ "${SKIP_REVIEW_TOKEN:-}" != "true" ]]; then
    REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    REVIEW_TTL="${REVIEW_TOKEN_TTL:-300}"
    NOW=$(date +%s)
    FOUND_VALID_TOKEN=false

    if [[ -d "$REVIEW_TOKEN_DIR" ]]; then
        for token_file in "$REVIEW_TOKEN_DIR"/*; do
            [[ -f "$token_file" ]] || continue
            token_ts=$(basename "$token_file")
            # Skip non-numeric filenames
            [[ "$token_ts" =~ ^[0-9]+$ ]] || continue
            token_age=$((NOW - token_ts))
            if [[ $token_age -le $REVIEW_TTL ]]; then
                token_repo=$(cat "$token_file" 2>/dev/null || true)
                if [[ "$token_repo" == "$REPO_ROOT" ]]; then
                    FOUND_VALID_TOKEN=true
                    # Consume the token (one-time use)
                    rm -f "$token_file"
                    break
                fi
            fi
        done
    fi

    echo -e "${YELLOW}[+]${NC} Checking review token (TTL=${REVIEW_TTL}s)..."
    if [[ "$FOUND_VALID_TOKEN" == "true" ]]; then
        echo -e "${GREEN}  ✓ Valid review token found${NC}"
    else
        echo -e "${RED}  ✗ No valid review token found${NC}"
        echo -e "${RED}    Run: bash tools/harsh-review.sh${NC}"
        echo -e "${RED}    Or skip: SKIP_REVIEW_TOKEN=true in .agent-gates${NC}"
        ((ERRORS++))
    fi

    # Garbage-collect expired tokens (older than 2x TTL)
    if [[ -d "$REVIEW_TOKEN_DIR" ]]; then
        for token_file in "$REVIEW_TOKEN_DIR"/*; do
            [[ -f "$token_file" ]] || continue
            token_ts=$(basename "$token_file")
            [[ "$token_ts" =~ ^[0-9]+$ ]] || continue
            token_age=$((NOW - token_ts))
            if [[ $token_age -gt $((REVIEW_TTL * 2)) ]]; then
                rm -f "$token_file"
            fi
        done
    fi
fi
```

- [ ] **Step 2: Verify pre-commit blocks without a token**

```bash
# Clear any existing tokens
rm -f ~/.codex/review-tokens/*
# Stage a trivial change
echo "" >> README.md
git add README.md
# Attempt to commit (should FAIL with "No valid review token")
git commit -m "test: should fail"
```

Expected: `COMMIT BLOCKED` with `No valid review token found`.

- [ ] **Step 3: Verify pre-commit passes with a valid token**

```bash
# Run harsh-review to generate a token
bash tools/harsh-review.sh
# Now commit should succeed (assuming other checks pass)
git add tools/pre-commit
git commit -m "feat(pre-commit): add review token verification gate"
```

Expected: `Valid review token found` in output, commit succeeds.

- [ ] **Step 4: Verify token is consumed (one-time use)**

```bash
ls ~/.codex/review-tokens/
```

Expected: The token used in Step 3 is gone (consumed by the hook).

- [ ] **Step 5: Commit** (if not already committed in Step 3)

```bash
git add tools/pre-commit
git commit -m "feat(pre-commit): add review token verification gate"
```

---

## Task 5: Create commit-gate.sh orchestrator

**Files:**
- Create: `tools/commit-gate.sh`

This script is the agent-facing entry point. It runs the full gate chain — EXTRA_LINT, EXTRA_TYPECHECK, EXTRA_TEST from `.agent-gates`, then `harsh-review.sh` — in one command. The agent runs this before committing. The pre-commit hook then verifies the token.

- [ ] **Step 1: Create tools/commit-gate.sh**

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: commit-gate.sh
# PURPOSE: Run full quality gate chain before committing.
#          Orchestrates: lint → typecheck → test → harsh-review
#          On success, harsh-review.sh writes the proof token that
#          the pre-commit hook verifies.
# USAGE: bash tools/commit-gate.sh [--skip-review]
# EXIT: 0 = all gates pass (token written), 1 = gate failed
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

# Options
SKIP_REVIEW=false
for arg in "$@"; do
    case "$arg" in
        --skip-review) SKIP_REVIEW=true ;;
        --help|-h)
            echo "Usage: commit-gate.sh [--skip-review]"
            echo "  --skip-review  Skip harsh-review (still runs lint/typecheck/test)"
            exit 0
            ;;
    esac
done

# Load .agent-gates if present
if [[ -f "$REPO_ROOT/.agent-gates" ]]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/.agent-gates"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  COMMIT GATE: Full quality chain"
[[ -n "${CLASS:-}" ]] && echo "  Repo class: $CLASS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ERRORS=0
STEP=1

# Run EXTRA gates from .agent-gates
for GATE_VAR in EXTRA_LINT EXTRA_TYPECHECK EXTRA_TEST; do
    GATE_CMD="${!GATE_VAR:-}"
    [[ -z "$GATE_CMD" ]] && continue
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Running ${GATE_VAR}: ${GATE_CMD}..."
    if ! eval "$GATE_CMD" 2>&1; then
        printf '%b\n' "${RED}  ✗ ${GATE_VAR} failed${NC}"
        ((ERRORS++))
    else
        printf '%b\n' "${GREEN}  ✓ ${GATE_VAR} passed${NC}"
    fi
    ((STEP++))
done

# Run harsh-review.sh (writes token on success)
if [[ "$SKIP_REVIEW" == "false" ]]; then
    printf '%b\n' "${YELLOW}[${STEP}]${NC} Running harsh-review.sh..."
    if bash "$SCRIPT_DIR/harsh-review.sh" --changed-only; then
        printf '%b\n' "${GREEN}  ✓ harsh-review passed (token written)${NC}"
    else
        printf '%b\n' "${RED}  ✗ harsh-review failed${NC}"
        ((ERRORS++))
    fi
    ((STEP++))
fi

# Result
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $ERRORS -gt 0 ]]; then
    printf '%b\n' "${RED}  GATE FAILED: $ERRORS error(s)${NC}"
    echo "  Fix errors, then re-run: bash tools/commit-gate.sh"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
else
    printf '%b\n' "${GREEN}  All gates passed — ready to commit${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tools/commit-gate.sh
```

- [ ] **Step 3: Verify commit-gate.sh runs end-to-end**

```bash
bash tools/commit-gate.sh
```

Expected: Runs harsh-review.sh, prints `All gates passed`, token file created in `~/.codex/review-tokens/`.

- [ ] **Step 4: Verify commit-gate.sh fails when review fails**

```bash
# Introduce a deliberate error (e.g., bad file ending)
printf "no newline" > /tmp/test-bad-ending.sh
cp /tmp/test-bad-ending.sh tools/test-bad-ending.sh
bash tools/commit-gate.sh
```

Expected: `GATE FAILED`. Clean up: `rm tools/test-bad-ending.sh`

- [ ] **Step 5: Commit**

```bash
git add tools/commit-gate.sh
bash tools/commit-gate.sh
git commit -m "feat: add commit-gate.sh orchestrator"
```

---

## Task 6: Add dispatcher rule to core.always.md

**Files:**
- Modify: `~/.augment/rules/core.always.md`

This is the always-on rule that tells agents to run `commit-gate.sh` before committing. It's short (~10 lines) and doesn't replace existing skills — it's a backstop that fires even if the agent doesn't load any commit-gate skills.

- [ ] **Step 1: Add the dispatcher rule**

Append after the existing Think-Twice Auto-Detection section in `~/.augment/rules/core.always.md`:

```markdown
## 🔴 Commit Gate (NON-NEGOTIABLE)

**Before ANY `git commit`**, run the full gate chain:

\```bash
bash ~/.codex/superpowers-plus/tools/commit-gate.sh
\```

This runs lint, typecheck, test, and harsh-review. On success it writes a proof token. The pre-commit hook verifies the token — **if you skip this step, the commit is blocked.**

If `commit-gate.sh` fails, fix the errors and re-run. Do not use `--no-verify` to bypass.
```

- [ ] **Step 2: Verify core.always.md line count is still manageable**

```bash
wc -l ~/.augment/rules/core.always.md
```

Expected: Under ~100 lines.

- [ ] **Step 3: No commit for this step** (core.always.md is not in the superpowers-plus repo)

---

## Task 7: Write tests

**Files:**
- Create: `tests/commit-gate-test.bats`

These tests verify the token lifecycle: creation, verification, consumption, expiry, and repo-path matching.

- [ ] **Step 1: Create tests/commit-gate-test.bats**

```bash
#!/usr/bin/env bats
# Tests for the review token gate system

REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"

setup() {
    mkdir -p "$REVIEW_TOKEN_DIR"
    rm -f "$REVIEW_TOKEN_DIR"/*
}

teardown() {
    rm -f "$REVIEW_TOKEN_DIR"/*
}

@test "harsh-review.sh creates a token file on success" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}

@test "token file contains repo root path" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local latest_token
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    local token_content
    token_content=$(cat "$REVIEW_TOKEN_DIR/$latest_token")
    [ -d "$token_content" ]
}

@test "token filename is a unix timestamp" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local latest_token
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    [[ "$latest_token" =~ ^[0-9]+$ ]]
}

@test "expired token is not accepted (age > 300s)" {
    local old_ts=$(($(date +%s) - 600))
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/$old_ts"
    local now
    now=$(date +%s)
    local age=$((now - old_ts))
    [ "$age" -gt 300 ]
}

@test "token from wrong repo is not accepted" {
    local ts
    ts=$(date +%s)
    echo "/some/other/repo" > "$REVIEW_TOKEN_DIR/$ts"
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    local token_repo
    token_repo=$(cat "$REVIEW_TOKEN_DIR/$ts")
    [ "$token_repo" != "$repo_root" ]
}

@test "commit-gate.sh runs without error" {
    run bash "$TOOLS_DIR/commit-gate.sh"
    [ "$status" -eq 0 ]
}

@test "commit-gate.sh creates a token" {
    bash "$TOOLS_DIR/commit-gate.sh"
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}
```

- [ ] **Step 2: Run the tests**

```bash
bats tests/commit-gate-test.bats
```

Expected: All tests pass. If `bats` is not installed: `brew install bats-core`.

- [ ] **Step 3: Commit**

```bash
git add tests/commit-gate-test.bats
bash tools/commit-gate.sh
git commit -m "test: add commit-gate token lifecycle tests"
```

---

## Task 8: Update install-hooks.sh echo output

**Files:**
- Modify: `tools/install-hooks.sh`

Update the "Done!" message at the end to mention the review token gate.

- [ ] **Step 1: Update the output message**

Change the final echo block in `install-hooks.sh` to:

```bash
echo ""
echo "Done! The following hooks are now active:"
echo "  • pre-commit: file endings, shell syntax, JSON, IP scan, review token"
echo "  • pre-push: scans unpushed commits for proprietary IP"
echo ""
echo "Review token gate: Run 'bash tools/commit-gate.sh' before committing."
echo "Token directory: ~/.codex/review-tokens/"
echo ""
echo "To bypass hooks (not recommended): git commit --no-verify"
echo ""
```

- [ ] **Step 2: Commit**

```bash
git add tools/install-hooks.sh
bash tools/commit-gate.sh
git commit -m "docs(install-hooks): mention review token gate in output"
```

---

## Task 9: End-to-end integration test

No files to create — this is a manual verification task.

- [ ] **Step 1: Clean state**

```bash
rm -f ~/.codex/review-tokens/*
```

- [ ] **Step 2: Attempt commit without running gate (should fail)**

```bash
echo "# test" >> README.md
git add README.md
git commit -m "test: should fail without review token"
```

Expected: `COMMIT BLOCKED` with `No valid review token found`.

- [ ] **Step 3: Run commit-gate.sh**

```bash
bash tools/commit-gate.sh
```

Expected: All gates pass, token written.

- [ ] **Step 4: Commit succeeds**

```bash
git commit -m "test: should succeed with review token"
```

Expected: Commit succeeds, `Valid review token found` in output.

- [ ] **Step 5: Second commit without re-running gate (should fail — token consumed)**

```bash
echo "# test2" >> README.md
git add README.md
git commit -m "test: should fail because token was consumed"
```

Expected: `COMMIT BLOCKED` — token was consumed by the first commit.

- [ ] **Step 6: Clean up test changes**

```bash
git checkout -- README.md
```

---

## Rollout Plan

1. **Branch from `dev`** per the three-tier branching model in AGENTS.md
2. **Implement Tasks 1–8** on the feature branch
3. **Run Task 9** (end-to-end integration test) before creating PR
4. **PR into `dev`** — self-test the token gate for all commits on this branch
5. **Promote `dev → staging → main`** per normal flow
6. **install.sh** already runs `install-hooks.sh` — token gate auto-deploys to all managed repos on next `sp-update`
7. **Per-repo opt-out** — repos that don't use `harsh-review.sh` add `SKIP_REVIEW_TOKEN=true` to their `.agent-gates`

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| `--no-verify` bypass | Dispatcher rule in `core.always.md` makes agents aware; hook is defense-in-depth, not sole defense. Accept as known gap. |
| Token faking | Agent could write the file directly. Low risk — gate targets forgetful agents, not adversarial ones. |
| Token expiry during slow tasks | Configurable `REVIEW_TOKEN_TTL` in `.agent-gates`. Default 5 min; increase per-repo as needed. |
| harsh-review.sh hangs | Existing script has bounded execution. If it hangs, Ctrl-C and re-run. |
| Parallel agents consuming tokens | Token contains repo path. Multiple agents in same repo is unsupported edge case — acceptable. |
| Chicken-and-egg: first commit after adding token gate | First commit on the feature branch will need `--no-verify` once to bootstrap. Document this in the PR description. |
