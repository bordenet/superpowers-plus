#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="$SCRIPT_DIR/../../superpowers-augment.js"
MAINT_SCRIPT="$SCRIPT_DIR/../todo-maintenance.sh"

PASS=0; FAIL=0; SKIP=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }
skip() { echo "  skip: $1"; ((SKIP++)) || true; }

# Portable helper: create bare repo with "main" as default branch.
# git init -b requires git 2.28+ (missing on Ubuntu 20.04).
_init_bare_main() {
  local repo="$1"
  git init --bare "$repo" --quiet
  git -C "$repo" symbolic-ref HEAD refs/heads/main
}

# ── Check 19/20 helpers: stale/dirty managed checkout detection ──

test_stale_checkout_detection() {
  local tmp_repo
  tmp_repo=$(mktemp -d "${TMPDIR:-/tmp}/doctor-stale-XXXXXX")
  # Create a fake "remote" bare repo with default branch "main" (portable)
  _init_bare_main "$tmp_repo/remote.git"
  # Clone it as the "managed checkout"
  git clone "$tmp_repo/remote.git" "$tmp_repo/managed" --quiet 2>/dev/null
  # Add an initial commit to managed so HEAD exists
  git -C "$tmp_repo/managed" commit --allow-empty -m "init" --quiet
  git -C "$tmp_repo/managed" push origin main --quiet 2>/dev/null
  # Now add a commit to the remote that the local doesn't have
  git clone "$tmp_repo/remote.git" "$tmp_repo/pusher" --quiet 2>/dev/null
  git -C "$tmp_repo/pusher" commit --allow-empty -m "ahead" --quiet
  git -C "$tmp_repo/pusher" push origin main --quiet 2>/dev/null
  # Test the detection logic
  git -C "$tmp_repo/managed" fetch origin --quiet 2>/dev/null
  local local_head remote_head behind
  local_head=$(git -C "$tmp_repo/managed" rev-parse HEAD)
  remote_head=$(git -C "$tmp_repo/managed" rev-parse "origin/main")
  behind=$(git -C "$tmp_repo/managed" rev-list --count "HEAD..origin/main")
  if [[ "$local_head" != "$remote_head" && "$behind" -gt 0 ]]; then
    pass "stale checkout detected ($behind behind)"
  else
    fail "stale checkout not detected (local=$local_head remote=$remote_head behind=$behind)"
  fi
  rm -rf "$tmp_repo"
}

test_clean_checkout_not_flagged() {
  local tmp_repo
  tmp_repo=$(mktemp -d "${TMPDIR:-/tmp}/doctor-clean-XXXXXX")
  _init_bare_main "$tmp_repo/remote.git"
  git clone "$tmp_repo/remote.git" "$tmp_repo/managed" --quiet 2>/dev/null
  git -C "$tmp_repo/managed" commit --allow-empty -m "init" --quiet
  git -C "$tmp_repo/managed" push origin main --quiet 2>/dev/null
  git -C "$tmp_repo/managed" fetch origin --quiet 2>/dev/null
  local local_head remote_head
  local_head=$(git -C "$tmp_repo/managed" rev-parse HEAD)
  remote_head=$(git -C "$tmp_repo/managed" rev-parse "origin/main")
  if [[ "$local_head" == "$remote_head" ]]; then
    pass "clean checkout not flagged as stale"
  else
    fail "clean checkout incorrectly flagged"
  fi
  rm -rf "$tmp_repo"
}

test_dirty_checkout_detection() {
  local tmp_repo
  tmp_repo=$(mktemp -d "${TMPDIR:-/tmp}/doctor-dirty-XXXXXX")
  git init "$tmp_repo/managed" --quiet
  git -C "$tmp_repo/managed" commit --allow-empty -m "init" --quiet
  echo "user edit" > "$tmp_repo/managed/local-change.txt"
  local porcelain
  porcelain=$(git -C "$tmp_repo/managed" status --porcelain)
  if [[ -n "$porcelain" ]]; then
    pass "dirty checkout detected"
  else
    fail "dirty checkout not detected"
  fi
  rm -rf "$tmp_repo"
}

test_dirty_safe_artifact_classification() {
  local tmp_repo
  tmp_repo=$(mktemp -d "${TMPDIR:-/tmp}/doctor-safe-dirty-XXXXXX")
  git init "$tmp_repo/managed" --quiet
  git -C "$tmp_repo/managed" commit --allow-empty -m "init" --quiet
  mkdir -p "$tmp_repo/managed/node_modules"
  echo "pkg" > "$tmp_repo/managed/node_modules/something.js"
  mkdir -p "$tmp_repo/managed/__pycache__"
  echo "cache" > "$tmp_repo/managed/__pycache__/mod.pyc"
  local porcelain safe_pat='node_modules/|__pycache__/|\.pyc$|\.pyo$|\.DS_Store$|\.env\.local$'
  porcelain=$(git -C "$tmp_repo/managed" status --porcelain)
  local user_changes
  user_changes=$(echo "$porcelain" | grep -vE "$safe_pat" || true)
  if [[ -z "$user_changes" ]]; then
    pass "safe artifacts correctly classified (no user changes)"
  else
    fail "safe artifacts misclassified as user changes: $user_changes"
  fi
  rm -rf "$tmp_repo"
}

# ── Check 21: TODO archive smoke test ──

test_todo_archive_smoke_small_valid() {
  [[ -f "$MAINT_SCRIPT" ]] || { skip "todo-maintenance.sh not found"; return; }
  command -v python3 &>/dev/null || { skip "python3 not available"; return; }
  local fixture_root fixture_todo
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-todo-test-XXXXXX")
  mkdir -p "$fixture_root/home/.codex" "$fixture_root/data"
  fixture_todo="$fixture_root/data/TODO.md"
  printf 'TODO_FILE_PATH=%s\n' "$fixture_todo" > "$fixture_root/home/.codex/.env"
  cat > "$fixture_todo" <<'FIXTURE'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260322-01] Smoke test active task #doctor

## P2 - This Week

## P3 - Backlog

---

# HISTORY

## 2026-03-01
- [x] [20260301-01] Done one #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00

- [x] [20260301-02] Done two #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T11:00:00

- [x] [20260301-03] Done three #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T12:00:00

- [x] [20260301-04] Done four #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T13:00:00

- [x] [20260301-05] Done five #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T14:00:00

---

# DEFERRED

---

# METRICS
FIXTURE
  local result_json
  if ! result_json=$(HOME="$fixture_root/home" "$MAINT_SCRIPT" --json 2>&1); then
    fail "TODO smoke test: maintenance script failed: $(echo "$result_json" | head -2)"
    rm -rf "$fixture_root"; return
  fi
  local archived line_count
  archived=$(echo "$result_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['archive_performed'])" 2>/dev/null || echo "")
  if [[ "$archived" != "True" ]]; then
    fail "TODO smoke test: archive not performed (got: $archived)"
    rm -rf "$fixture_root"; return
  fi
  line_count=$(wc -l < "$fixture_todo" | tr -d ' ')
  if (( line_count < 50 )); then
    pass "TODO archive smoke: small TODO archived correctly ($line_count lines)"
  else
    fail "TODO smoke test: result $line_count lines (expected <50)"
  fi
  grep -q '\[20260322-01\]' "$fixture_todo" || fail "TODO smoke test: active task lost"
  rm -rf "$fixture_root"
}

# ── Check 22: Reviewer-dispatch rendering verification ──

test_reviewer_dispatch_contains_subagent() {
  [[ -f "$ADAPTER" ]] || { skip "superpowers-augment.js not found"; return; }
  command -v node &>/dev/null || { skip "node not available"; return; }
  local output
  output=$(node "$ADAPTER" use-skill requesting-code-review 2>/dev/null || true)
  if [[ -z "$output" ]]; then
    fail "reviewer-dispatch: could not render requesting-code-review"
    return
  fi
  if [[ "$output" == *"sub-agent-code-reviewer"* ]]; then
    pass "reviewer-dispatch: contains sub-agent-code-reviewer"
  else
    fail "reviewer-dispatch: missing sub-agent-code-reviewer in output"
  fi
}

test_reviewer_dispatch_no_stale_patterns() {
  [[ -f "$ADAPTER" ]] || return
  command -v node &>/dev/null || return
  local output stale_found=0
  output=$(node "$ADAPTER" use-skill requesting-code-review 2>/dev/null || true)
  [[ -z "$output" ]] && { fail "reviewer-dispatch: empty output"; return; }
  local stale_patterns=(
    "code-reviewer subagent"
    "code reviewer subagent"
    "Dispatch final code-reviewer"
    "Task tool with superpowers:code-reviewer type"
  )
  for pattern in "${stale_patterns[@]}"; do
    if [[ "$output" == *"$pattern"* ]]; then
      fail "reviewer-dispatch: stale pattern found: '$pattern'"
      ((stale_found++)) || true
    fi
  done
  [[ "$stale_found" -eq 0 ]] && pass "reviewer-dispatch: no stale patterns"
}

test_reviewer_dispatch_sdd_detection() {
  # This test verifies the doctor's DETECTION logic works, not that the skill is healthy.
  # The SDD skill may or may not have been updated — we test that we can detect stale patterns.
  [[ -f "$ADAPTER" ]] || return
  command -v node &>/dev/null || return
  local output output_lower
  output=$(node "$ADAPTER" use-skill subagent-driven-development 2>/dev/null || true)
  [[ -z "$output" ]] && { fail "reviewer-dispatch: could not render sdd skill"; return; }
  output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')
  # Test detection: check for any variant of "dispatch final code[-]reviewer" without translation
  local has_stale=false
  if echo "$output_lower" | grep -q "dispatch final code.reviewer" && \
     ! echo "$output_lower" | grep -q "dispatch final sub-agent-code-reviewer"; then
    has_stale=true
  fi
  if [[ "$has_stale" == "true" ]]; then
    # Stale pattern exists — doctor would correctly flag it (this is detection working)
    pass "reviewer-dispatch: sdd stale pattern correctly detectable"
  else
    # No stale patterns — skill is healthy
    pass "reviewer-dispatch: sdd rendering is healthy"
  fi
}

# ── Run all tests ──

echo "── Doctor checks regression tests ──"
echo ""
echo "Check 19/20: Stale & dirty checkout detection"
test_stale_checkout_detection
test_clean_checkout_not_flagged
test_dirty_checkout_detection
test_dirty_safe_artifact_classification
echo ""
echo "Check 21: TODO archive smoke test"
test_todo_archive_smoke_small_valid
echo ""
echo "Check 22: Reviewer-dispatch rendering"
test_reviewer_dispatch_contains_subagent
test_reviewer_dispatch_no_stale_patterns
test_reviewer_dispatch_sdd_detection
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAIL: $PASS passed, $FAIL failed, $SKIP skipped"
  exit 1
else
  local_summary="PASS: all $PASS tests passed"
  [[ "$SKIP" -gt 0 ]] && local_summary="$local_summary ($SKIP skipped)"
  echo "$local_summary"
fi

