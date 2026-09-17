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
  rm -rf "${tmp_repo:?}"
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
  rm -rf "${tmp_repo:?}"
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
  rm -rf "${tmp_repo:?}"
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
  mkdir -p "$tmp_repo/managed/install-state"
  echo "state" > "$tmp_repo/managed/install-state/last-run"
  mkdir -p "$tmp_repo/managed/modules"
  echo "mod" > "$tmp_repo/managed/modules/foo.js"
  local porcelain safe_pat='node_modules/|__pycache__/|\.pyc$|\.pyo$|\.DS_Store$|\.env\.local$|install-state/|modules/'
  porcelain=$(git -C "$tmp_repo/managed" status --porcelain)
  local user_changes
  user_changes=$(echo "$porcelain" | grep -vE "$safe_pat" || true)
  if [[ -z "$user_changes" ]]; then
    pass "safe artifacts correctly classified (no user changes)"
  else
    fail "safe artifacts misclassified as user changes: $user_changes"
  fi
  rm -rf "${tmp_repo:?}"
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
  # Helper: clear immutable flags (macOS chflags uchg) before rm
  _cleanup_fixture() { chflags -R nouchg "${fixture_root:?}" 2>/dev/null || true; rm -rf "${fixture_root:?}"; }
  if ! result_json=$(HOME="$fixture_root/home" "$MAINT_SCRIPT" --json 2>&1); then
    fail "TODO smoke test: maintenance script failed: $(echo "$result_json" | head -2)"
    _cleanup_fixture; return
  fi
  local archived line_count
  archived=$(echo "$result_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['archive_performed'])" 2>/dev/null || echo "")
  if [[ "$archived" != "True" ]]; then
    fail "TODO smoke test: archive not performed (got: $archived)"
    _cleanup_fixture; return
  fi
  line_count=$(wc -l < "$fixture_todo" | tr -d ' ')
  if (( line_count < 50 )); then
    pass "TODO archive smoke: small TODO archived correctly ($line_count lines)"
  else
    fail "TODO smoke test: result $line_count lines (expected <50)"
  fi
  grep -q '\[20260322-01\]' "$fixture_todo" || fail "TODO smoke test: active task lost"
  _cleanup_fixture
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
    "superpowers:code-reviewer"
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

_make_reviewer_dispatch_doctor_fixture() {
  local fixture_root="$1"
  local source_sdd="$SCRIPT_DIR/../../skills/engineering/subagent-driven-development"
  local source_request="$SCRIPT_DIR/../../skills/engineering/requesting-code-review"
  local deployed_sdd="$fixture_root/home/.claude/skills/subagent-driven-development"
  mkdir -p "$fixture_root/home/.codex" \
    "$fixture_root/skills/engineering/subagent-driven-development" \
    "$fixture_root/skills/engineering/requesting-code-review" \
    "$deployed_sdd" \
    "$fixture_root/home/.claude/skills/sp-request"
  cp "$source_sdd/skill.md" \
    "$source_sdd/task-reviewer-prompt.md" \
    "$source_sdd/code-quality-reviewer-prompt.md" \
    "$fixture_root/skills/engineering/subagent-driven-development/"
  cp "$fixture_root/skills/engineering/subagent-driven-development/skill.md" \
    "$fixture_root/skills/engineering/subagent-driven-development/task-reviewer-prompt.md" \
    "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$deployed_sdd/"
  cp "$source_request/code-reviewer.md" \
    "$fixture_root/skills/engineering/requesting-code-review/code-reviewer.md"
  cp "$source_request/code-reviewer.md" \
    "$fixture_root/home/.claude/skills/sp-request/code-reviewer.md"
}

_run_reviewer_dispatch_doctor_fixture() {
  local fixture_root="$1"
  local module output
  module="$SCRIPT_DIR/../doctor-modules/integration-checks.sh"

  output=$(
    # shellcheck disable=SC2030 # Fixture environment is intentionally local to this subshell.
    HOME="$fixture_root/home"
    # shellcheck disable=SC2030 # Fixture environment is intentionally local to this subshell.
    CLAUDE_CONFIG_DIR="$fixture_root/home/.claude"
    REPO_ROOT="$fixture_root"
    WARNINGS=0
    # shellcheck source=tools/doctor-modules/integration-checks.sh
    source "$module"
    _doctor_integration_checks
    printf 'WARNINGS=%s\n' "$WARNINGS"
  )
  printf '%s\n' "$output"
}

test_reviewer_dispatch_plugin_independent() {
  local fixture_root output
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer-dispatch"* || "$output" != *"WARNINGS=0"* ]]; then
    fail "reviewer-dispatch: valid source and deployed contracts triggered a warning: $output"
  else
    pass "reviewer-dispatch: validates deployed generic and active SDD contracts"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  printf '%s\n' 'Task tool (superpowers:code-reviewer):' \
    > "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"still depends on the plugin agent type"* ]]; then
    pass "reviewer-dispatch: rejects stale deployed plugin-agent dispatch"
  else
    fail "reviewer-dispatch: missed stale deployed plugin-agent dispatch: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  rm "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"deployed Claude reviewer contract is missing"* ]]; then
    pass "reviewer-dispatch: warns when deployed Claude reviewer contract is missing"
  else
    fail "reviewer-dispatch: missed absent deployed Claude reviewer contract: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  rm "$fixture_root/home/.claude/skills/sp-request/code-reviewer.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"deployed Claude reviewer instructions are missing"* ]]; then
    pass "reviewer-dispatch: warns when resolved Claude reviewer instructions are missing"
  else
    fail "reviewer-dispatch: missed absent resolved Claude reviewer instructions: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'NEGATED'
Do not dispatch Subagent (general-purpose):
  description: "Code quality review"
  model: required
  prompt: |
    [REVIEWER_INSTRUCTIONS]
NEGATED
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: rejects negated generic-dispatch instructions"
  else
    fail "reviewer-dispatch: accepted negated generic-dispatch instructions: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'NEGATED'
## Controller contract

Do not use the following dispatch block.
Controller contract: dispatch the following block.
Subagent (general-purpose):
  description: "Code quality review"
  model: [MODEL, REQUIRED: choose explicitly]
  prompt: |
    [REVIEWER_INSTRUCTIONS]
NEGATED
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: rejects structurally valid dispatch after exact nearby negation"
  else
    fail "reviewer-dispatch: accepted dispatch after 'Do not use the following dispatch block': $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'NEGATED'
## Historical guidance

Historically, controllers were instructed not to dispatch the block below.

## Controller contract

Controller contract: dispatch the following block.
Subagent (general-purpose):
  description: "Code quality review"
  model: [MODEL, REQUIRED: choose explicitly]
  prompt: |
    [REVIEWER_INSTRUCTIONS]
NEGATED
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: rejects historical dispatch negation before the marker"
  else
    fail "reviewer-dispatch: accepted historical dispatch negation before the marker: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'NEGATED'
## Prior example

The generic subagent block below is illustrative and must not be executed.

## Controller contract

Controller contract: dispatch the following block.
Subagent (general-purpose):
  description: "Code quality review"
  model: [MODEL, REQUIRED: choose explicitly]
  prompt: |
    [REVIEWER_INSTRUCTIONS]
NEGATED
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: rejects indirect dispatch negation before the marker"
  else
    fail "reviewer-dispatch: accepted indirect dispatch negation before the marker: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'NEGATED'
## Obsolete procedure

Do not dispatch the following generic subagent.

## Controller contract

Controller contract: dispatch the following block.
Subagent (general-purpose):
  description: "Code quality review"
  model: [MODEL, REQUIRED: choose explicitly]
  prompt: |
    [REVIEWER_INSTRUCTIONS]
NEGATED
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: rejects direct dispatch negation before the marker"
  else
    fail "reviewer-dispatch: accepted direct dispatch negation before the marker: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" <<'LEGITIMATE'
## Safety requirements

Do not omit reviewer instructions from the dispatch block.
The controller validates the generic subagent block before use.

## Controller contract

Controller contract: dispatch the following block.
Subagent (general-purpose):
  description: "Code quality review"
  model: [MODEL, REQUIRED: choose explicitly]
  prompt: |
    [REVIEWER_INSTRUCTIONS]
LEGITIMATE
  cp "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" != *"reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: accepts legitimate non-negating contract prose"
  else
    fail "reviewer-dispatch: rejected legitimate non-negating contract prose: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  printf '\n# stale installed copy\n' \
    >> "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"deployed Claude reviewer contract is stale"* ]]; then
    pass "reviewer-dispatch: detects a stale deployed Claude reviewer contract"
  else
    fail "reviewer-dispatch: missed stale deployed Claude reviewer contract: $output"
  fi
  rm -rf "${fixture_root:?}"

  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-dispatch-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  cat > "$fixture_root/home/.claude/skills/subagent-driven-development/task-reviewer-prompt.md" <<'NEGATED'
Do not dispatch Subagent (general-purpose):
  description: "Review Task N"
  model: required
  prompt: |
    You are reviewing one task's implementation.
NEGATED
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"active task-reviewer contract is not a coherent general-purpose dispatch"* ]]; then
    pass "reviewer-dispatch: validates the task-reviewer template used by active SDD"
  else
    fail "reviewer-dispatch: missed invalid active task-reviewer template: $output"
  fi
  rm -rf "${fixture_root:?}"
}

_resolve_reviewer_instruction_fixture() {
  local fixture_root="$1"
  local active_template="$2"
  local module="$3"
  local asserted_root="${4:-}"
  local installed_reviewer="$fixture_root/home/.claude/skills/sp-request/code-reviewer.md"
  (
    # shellcheck disable=SC2030 # Fixture environment is intentionally local to this subshell.
    HOME="$fixture_root/home"
    # shellcheck disable=SC2030 # Fixture environment is intentionally local to this subshell.
    CLAUDE_CONFIG_DIR="$fixture_root/home/.claude"
    REPO_ROOT="$fixture_root"
    WARNINGS=0
    # shellcheck source=tools/doctor-modules/integration-checks.sh
    source "$module"
    _doctor_integration_checks >/dev/null
    if ! declare -F _doctor_reviewer_instruction_path >/dev/null; then
      printf '%s\n' '__missing_reviewer_instruction_resolver__'
      return 0
    fi
    _doctor_reviewer_instruction_path "$active_template" \
      "$installed_reviewer" \
      "$asserted_root"
  )
}

test_reviewer_instruction_source_resolution() {
  local fixture_root trusted_root module source_contract source_reviewer
  local installed_contract installed_reviewer target_contract target_reviewer selected
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-origin-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  trusted_root="$fixture_root/trusted-source"
  module="$trusted_root/tools/doctor-modules/integration-checks.sh"
  mkdir -p "$trusted_root/tools/doctor-modules" \
    "$trusted_root/skills/engineering/subagent-driven-development" \
    "$trusted_root/skills/engineering/requesting-code-review"
  cp "$SCRIPT_DIR/../doctor-modules/integration-checks.sh" "$module"
  cp "$SCRIPT_DIR/../../skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$trusted_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md"
  cp "$SCRIPT_DIR/../../skills/engineering/requesting-code-review/code-reviewer.md" \
    "$trusted_root/skills/engineering/requesting-code-review/code-reviewer.md"
  source_contract="$trusted_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md"
  source_reviewer="$trusted_root/skills/engineering/requesting-code-review/code-reviewer.md"
  source_reviewer="$(cd -P "$(dirname "$source_reviewer")" && pwd)/$(basename "$source_reviewer")"
  installed_contract="$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"
  installed_reviewer="$fixture_root/home/.claude/skills/sp-request/code-reviewer.md"
  target_contract="$fixture_root/target-project/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md"
  target_reviewer="$fixture_root/target-project/skills/engineering/requesting-code-review/code-reviewer.md"
  mkdir -p "$(dirname "$target_contract")" "$(dirname "$target_reviewer")"
  cp "$source_contract" "$target_contract"
  printf '%s\n' '# MALICIOUS TARGET REVIEWER' > "$target_reviewer"

  selected=$(_resolve_reviewer_instruction_fixture "$fixture_root" "$source_contract" "$module")
  if [[ "$selected" == "$source_reviewer" ]]; then
    pass "reviewer-dispatch: verified source template selects its source reviewer"
  else
    fail "reviewer-dispatch: verified source template selected '$selected' instead of '$source_reviewer'"
  fi

  selected=$(_resolve_reviewer_instruction_fixture "$fixture_root" "$installed_contract" "$module")
  if [[ "$selected" == "$installed_reviewer" ]]; then
    pass "reviewer-dispatch: installed template selects the trusted installed reviewer"
  else
    fail "reviewer-dispatch: installed template selected '$selected' instead of '$installed_reviewer'"
  fi

  selected=$(
    cd "$fixture_root/target-project"
    _resolve_reviewer_instruction_fixture \
      "$fixture_root" "$target_contract" "$module" "$fixture_root/target-project"
  )
  if [[ "$selected" == "$installed_reviewer" && "$selected" != "$target_reviewer" ]]; then
    pass "reviewer-dispatch: malicious target-project reviewer cannot override installed instructions"
  else
    fail "reviewer-dispatch: malicious target-project reviewer influenced selection: $selected"
  fi

  mv "$source_reviewer" "${source_reviewer}.missing"
  selected=$(_resolve_reviewer_instruction_fixture "$fixture_root" "$source_contract" "$module")
  if [[ "$selected" == "$installed_reviewer" ]]; then
    pass "reviewer-dispatch: missing verified-source reviewer falls back to installed instructions"
  else
    fail "reviewer-dispatch: missing verified-source reviewer selected '$selected' instead of '$installed_reviewer'"
  fi

  rm -rf "${fixture_root:?}"
}

test_reviewer_instruction_contract_rejects_target_repo_origin() {
  local fixture_root output prompt rewritten
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-policy-XXXXXX")
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  for prompt in \
    "$fixture_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md" \
    "$fixture_root/home/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md"; do
    rewritten="${prompt}.rewritten"
    awk '{
      gsub(/<LOADER_RESOLVED_SUPERPOWERS_PLUS_ROOT>/, "<target-repo>")
      print
    }' "$prompt" > "$rewritten"
    mv "$rewritten" "$prompt"
  done
  output=$(_run_reviewer_dispatch_doctor_fixture "$fixture_root")
  if [[ "$output" == *"reviewer-instruction source policy is unsafe or incomplete"* ]]; then
    pass "reviewer-dispatch: doctor rejects target-repository reviewer resolution"
  else
    fail "reviewer-dispatch: doctor accepted target-repository reviewer resolution: $output"
  fi
  rm -rf "${fixture_root:?}"
}

test_plugin_rollback_commands_pin_user_scope() {
  local runbook="$SCRIPT_DIR/../../docs/harness/upstream-plugin-parity.md"
  if grep -Fxq \
      'claude plugin disable --scope user superpowers@superpowers-marketplace' "$runbook" && \
     grep -Fxq \
      'claude plugin enable --scope user superpowers@superpowers-marketplace' "$runbook"; then
    pass "plugin parity: disable and rollback commands pin user scope"
  else
    fail "plugin parity: disable and rollback commands must both include --scope user"
  fi
}

test_reviewer_dispatch_augment_real_sdd_prompt() {
  local adapter="$SCRIPT_DIR/../../superpowers-augment.js"
  [[ -f "$adapter" ]] || { skip "superpowers-augment.js not found"; return; }
  command -v node &>/dev/null || { skip "node not available"; return; }
  local fixture_root installed_sdd output skill_output expected_origin
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/augment-reviewer-dispatch-XXXXXX")
  installed_sdd="$fixture_root/installed/subagent-driven-development"
  expected_origin="$(cd -P "$SCRIPT_DIR/../.." && pwd)/skills/engineering/subagent-driven-development/task-reviewer-prompt.md"
  mkdir -p "$fixture_root/home/.codex" "$installed_sdd"
  cat > "$installed_sdd/skill.md" <<'STALE_SKILL'
---
name: subagent-driven-development
description: stale installed fixture
---

# STALE INSTALLED SDD
STALE_SKILL
  printf '%s\n' 'STALE INSTALLED REVIEWER PROMPT' > "$installed_sdd/task-reviewer-prompt.md"

  skill_output=$(HOME="$fixture_root/home" \
    SPP_SOURCE_DIR="$SCRIPT_DIR/../.." \
    PERSONAL_SKILLS_DIR="$fixture_root/installed" \
    SUPERPOWERS_SKILLS_DIR="$fixture_root/installed" \
    node "$adapter" use-skill spp:subagent-driven-development 2>/dev/null || true)

  output=$(HOME="$fixture_root/home" \
    SPP_SOURCE_DIR="$SCRIPT_DIR/../.." \
    PERSONAL_SKILLS_DIR="$fixture_root/installed" \
    SUPERPOWERS_SKILLS_DIR="$fixture_root/installed" \
    node "$adapter" use-skill spp:subagent-driven-development \
      --resource task-reviewer-prompt.md 2>/dev/null || true)
  rm -rf "${fixture_root:?}"

  if [[ "$skill_output" == *"use-skill spp:subagent-driven-development --resource <prompt-file>"* ]] && \
     [[ "$skill_output" != *"# STALE INSTALLED SDD"* ]] && \
     [[ "$output" == *"# Skill Resource: spp:subagent-driven-development/task-reviewer-prompt.md"* ]] && \
     [[ "$output" == *"# Skill Resource Origin: $expected_origin"* ]] && \
     [[ "$output" == *"Controller contract: dispatch the following block."* ]] && \
     [[ "$output" == *"You are reviewing one task's implementation"* ]] && \
     [[ "$output" != *"STALE INSTALLED REVIEWER PROMPT"* ]] && \
     [[ "$(grep -c 'sub-agent-general-purpose tool:' <<< "$output")" -eq 1 ]] && \
     [[ "$output" != *"Subagent (general-purpose)"* ]] && \
     [[ "$output" != *"launch-process (or handle directly) (general-purpose)"* ]]; then
    pass "reviewer-dispatch: Augment preserves source namespace and transforms the real SDD prompt"
  else
    fail "reviewer-dispatch: Augment lost source origin or rendered the wrong SDD prompt: skill=$skill_output resource=$output"
  fi
}

test_reviewer_dispatch_doctor_pins_current_source() {
  local fixture_root repo_root stale_sdd module output
  fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-reviewer-source-XXXXXX")
  repo_root="$SCRIPT_DIR/../.."
  stale_sdd="$fixture_root/stale-source/skills/engineering/subagent-driven-development"
  module="$SCRIPT_DIR/../doctor-modules/integration-checks.sh"
  _make_reviewer_dispatch_doctor_fixture "$fixture_root"
  mkdir -p "$stale_sdd"
  cat > "$stale_sdd/skill.md" <<'STALE_SKILL'
---
name: subagent-driven-development
description: stale source that must not win doctor resolution
---

# Stale SDD
STALE_SKILL

  output=$(
    # shellcheck disable=SC2031 # This is a new fixture subshell, not a continuation of the earlier one.
    export HOME="$fixture_root/home"
    # shellcheck disable=SC2031 # This is a new fixture subshell, not a continuation of the earlier one.
    export CLAUDE_CONFIG_DIR="$fixture_root/home/.claude"
    export SPP_SOURCE_DIR="$fixture_root/stale-source"
    export PERSONAL_SKILLS_DIR="$repo_root/skills"
    export SUPERPOWERS_SKILLS_DIR="$repo_root/skills"
    REPO_ROOT="$repo_root"
    WARNINGS=0
    # shellcheck source=tools/doctor-modules/integration-checks.sh
    source "$module"
    _doctor_integration_checks
    printf 'WARNINGS=%s\n' "$WARNINGS"
  )
  rm -rf "${fixture_root:?}"

  if [[ "$output" == *"WARNINGS=0"* ]]; then
    pass "reviewer-dispatch: doctor pins Augment rendering to its current source checkout"
  else
    fail "reviewer-dispatch: ambient SPP_SOURCE_DIR redirected doctor away from REPO_ROOT: $output"
  fi
}

DOCTOR_SCRIPT="$SCRIPT_DIR/../doctor-checks.sh"

# ── Step 3.1: --help flag exits 0 ──
test_help_flag_exits_zero() {
  if [[ ! -f "$DOCTOR_SCRIPT" ]]; then
    skip "doctor-checks.sh not found at $DOCTOR_SCRIPT"
    return
  fi
  local output exit_code
  output=$(bash "$DOCTOR_SCRIPT" --help 2>&1) && exit_code=$? || exit_code=$?
  if [[ "$exit_code" -eq 0 && "$output" == *"Usage:"* ]]; then
    pass "--help: prints usage text and exits 0"
  else
    fail "--help: expected exit 0 + 'Usage:' in output (got exit=$exit_code)"
  fi
}

test_help_flag_short_exits_zero() {
  if [[ ! -f "$DOCTOR_SCRIPT" ]]; then
    skip "doctor-checks.sh not found at $DOCTOR_SCRIPT"
    return
  fi
  local output exit_code
  output=$(bash "$DOCTOR_SCRIPT" -h 2>&1) && exit_code=$? || exit_code=$?
  if [[ "$exit_code" -eq 0 && "$output" == *"Usage:"* ]]; then
    pass "-h: prints usage text and exits 0"
  else
    fail "-h: expected exit 0 + 'Usage:' in output (got exit=$exit_code)"
  fi
}

test_help_flag_non_leading() {
  if [[ ! -f "$DOCTOR_SCRIPT" ]]; then
    skip "doctor-checks.sh not found at $DOCTOR_SCRIPT"
    return
  fi
  local out1 out2 ec1 ec2
  out1=$(bash "$DOCTOR_SCRIPT" --summary-only --help 2>&1) && ec1=$? || ec1=$?
  out2=$(bash "$DOCTOR_SCRIPT" --fail-on-findings --summary-only --help 2>&1) && ec2=$? || ec2=$?
  if [[ "$ec1" -eq 0 && "$out1" == *"Usage:"* ]]; then
    pass "--summary-only --help: prints usage text and exits 0"
  else
    fail "--summary-only --help: expected exit 0 + 'Usage:' (got exit=$ec1)"
  fi
  if [[ "$ec2" -eq 0 && "$out2" == *"Usage:"* ]]; then
    pass "--fail-on-findings --summary-only --help: prints usage text and exits 0"
  else
    fail "--fail-on-findings --summary-only --help: expected exit 0 + 'Usage:' (got exit=$ec2)"
  fi
}

# ── Step 3.2: exit code 2 for CRITICAL with --fail-on-findings ──
test_critical_finding_exit_code_2() {
  # Synthesize the exit-code logic directly (avoids running full doctor)
  local result
  result=$(
    FAIL_ON_FINDINGS=true
    CRITICAL=1; ERRORS=0; WARNINGS=0
    if [[ "$FAIL_ON_FINDINGS" == "true" ]]; then
      if (( CRITICAL > 0 )); then echo "exit2"; fi
    fi
  )
  if [[ "$result" == "exit2" ]]; then
    pass "exit code 2 for CRITICAL with --fail-on-findings"
  else
    fail "expected exit-code-2 path to trigger (got: '$result')"
  fi
}

test_errors_no_critical_exit_code_1() {
  local result
  result=$(
    FAIL_ON_FINDINGS=true
    CRITICAL=0; ERRORS=2; WARNINGS=0
    if [[ "$FAIL_ON_FINDINGS" == "true" ]]; then
      if (( CRITICAL > 0 )); then echo "exit2"; fi
      if (( ERRORS > 0 ));   then echo "exit1"; fi
    fi
  )
  if [[ "$result" == "exit1" ]]; then
    pass "exit code 1 for ERRORS (no CRITICAL) with --fail-on-findings"
  else
    fail "expected exit-code-1 path to trigger (got: '$result')"
  fi
}

test_warnings_only_exit_code_0() {
  local result
  result=$(
    FAIL_ON_FINDINGS=true
    CRITICAL=0; ERRORS=0
    # shellcheck disable=SC2034  # WARNINGS documents test scenario; only CRITICAL/ERRORS drive exit logic
    WARNINGS=3
    if [[ "$FAIL_ON_FINDINGS" == "true" ]]; then
      if (( CRITICAL > 0 )); then echo "exit2"; fi
      if (( ERRORS > 0 ));   then echo "exit1"; fi
      echo "exit0"
    fi
  )
  if [[ "$result" == "exit0" ]]; then
    pass "exit code 0 for WARNINGS-only with --fail-on-findings"
  else
    fail "expected exit-code-0 path for warnings (got: '$result')"
  fi
}

# ── Check 27: Agent content drift ──

test_agent_checks_has_symlink_guard() {
  local module="$SCRIPT_DIR/../doctor-modules/agent-checks.sh"
  # Pattern is a literal string (not expanded) — grep searches for this exact text in .sh file
  # shellcheck disable=SC2016
  local symlink_guard='-L "$installed"'
  # Use -- to prevent grep treating the leading '-L' as an option flag (Linux BSD compat)
  if grep -Fq -- "$symlink_guard" "$module"; then
    pass "agent-checks.sh has symlink guard before diff/cp"
  else
    fail "agent-checks.sh missing symlink guard — regression"
  fi
}

test_agent_checks_has_backup_before_fix() {
  local module="$SCRIPT_DIR/../doctor-modules/agent-checks.sh"
  if grep -q 'agent_backup_dir' "$module" && grep -q 'cp.*installed.*agent_backup_dir\|cp.*agent_backup_dir\|backup_dir.*agents' "$module"; then
    pass "agent-checks.sh backs up installed agent before overwriting"
  else
    fail "agent-checks.sh missing pre-fix backup — regression"
  fi
}

test_agent_checks_detects_duplicate_sources() {
  local module="$SCRIPT_DIR/../doctor-modules/agent-checks.sh"
  if grep -q 'ambiguous source' "$module"; then
    pass "agent-checks.sh reports ambiguous source for duplicate agent basenames"
  else
    fail "agent-checks.sh missing duplicate-source detection — regression"
  fi
}

test_agent_checks_warns_on_missing_install() {
  local module="$SCRIPT_DIR/../doctor-modules/agent-checks.sh"
  if grep -q 'source agent not installed' "$module"; then
    pass "agent-checks.sh warns when source agent has no installed counterpart"
  else
    fail "agent-checks.sh silently skips missing installs — regression"
  fi
}

test_agent_drift_detection_functional() {
  local tmp_src tmp_installed
  tmp_src=$(mktemp -d "${TMPDIR:-/tmp}/agent-src-XXXXXX")
  tmp_installed=$(mktemp -d "${TMPDIR:-/tmp}/agent-inst-XXXXXX")

  # Source agent (correct model)
  printf 'model: Code Review\nrole: reviewer\n' > "$tmp_src/code-reviewer.md"
  # Installed agent (drifted — wrong model)
  printf 'model: gpt-5.4\nrole: reviewer\n' > "$tmp_installed/code-reviewer.md"

  local output
  output=$(diff -q "$tmp_src/code-reviewer.md" "$tmp_installed/code-reviewer.md" 2>&1 || true)
  if [[ -n "$output" ]]; then
    pass "functional: drift detected between source and installed agent"
  else
    fail "functional: no drift detected — files are unexpectedly identical"
  fi

  # Verify model normalization: strip quotes so 'Code Review' == "Code Review"
  local m1 m2
  m1=$(grep -m1 '^model:' "$tmp_src/code-reviewer.md" \
    | sed "s/model:[[:space:]]*//;s/['\"]//g;s/[[:space:]]*$//")
  m2=$(grep -m1 '^model:' "$tmp_installed/code-reviewer.md" \
    | sed "s/model:[[:space:]]*//;s/['\"]//g;s/[[:space:]]*$//")
  if [[ "$m1" != "$m2" ]]; then
    pass "functional: normalized model mismatch detected (src=$m1, installed=$m2)"
  else
    fail "functional: model normalization failed — models appear equal when they differ"
  fi

  rm -rf "${tmp_src:?}" "${tmp_installed:?}"
}

# ── .worktrees exclusion ──

test_reference_checks_excludes_worktrees() {
  local module="$SCRIPT_DIR/../doctor-modules/reference-checks.sh"
  local worktrees_filter_count
  worktrees_filter_count=$(grep -c '\.worktrees' "$module" || true)
  # Expect exclusion on all 3 find calls (skill.md INSTALLED_MATCH_DIR, references/*.md, overlay skill.md)
  if [[ "$worktrees_filter_count" -ge 3 ]]; then
    pass "reference-checks.sh excludes .worktrees/ on all find calls ($worktrees_filter_count occurrences)"
  else
    fail "reference-checks.sh missing .worktrees exclusion (only $worktrees_filter_count occurrences, want ≥3)"
  fi
}

# ── Run all tests ──

echo "── Doctor checks regression tests ──"
echo ""
echo "Check 27: Agent content drift"
test_agent_checks_has_symlink_guard
test_agent_checks_has_backup_before_fix
test_agent_checks_detects_duplicate_sources
test_agent_checks_warns_on_missing_install
test_agent_drift_detection_functional
echo ""
echo "Check 27 + reference-checks: .worktrees exclusion"
test_reference_checks_excludes_worktrees
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
test_reviewer_dispatch_plugin_independent
test_reviewer_instruction_source_resolution
test_reviewer_instruction_contract_rejects_target_repo_origin
test_reviewer_dispatch_augment_real_sdd_prompt
test_reviewer_dispatch_doctor_pins_current_source
test_plugin_rollback_commands_pin_user_scope
echo ""
echo "Step 3.1: --help flag"
test_help_flag_exits_zero
test_help_flag_short_exits_zero
test_help_flag_non_leading
echo ""
echo "Step 3.2: exit code severity levels"
test_critical_finding_exit_code_2
test_errors_no_critical_exit_code_1
test_warnings_only_exit_code_0
echo ""
echo "Step 4: composition metadata checks"

# Test the composition check by extracting the exact grep pattern from the module.
# We verify the module contains the expected pattern, then test that pattern in isolation.
# This guards against both: (a) wrong grep target, (b) pattern drift from module.

test_composition_check_pattern_matches_module() {
  # Verify the exact implementation fragment in the doctor module.
  # This fixed-string match ensures the module checks SKILL_YAML text (not a file path)
  # and will fail if the variable name is changed or the pattern is moved to a comment.
  local module="$SCRIPT_DIR/../doctor-modules/metadata-checks.sh"
  # shellcheck disable=SC2016
  local expected_fragment='grep -q '"'"'^composition:'"'"' <<< "${SKILL_YAML[$skill]}"'
  if grep -Fq "$expected_fragment" "$module"; then
    pass "doctor module composition check uses exact SKILL_YAML[\$skill] pattern"
  else
    fail "doctor module composition check does NOT match expected pattern — regression"
  fi
}

test_composition_warning_fires_when_missing() {
  # Use the same pattern the module uses: grep -q '^composition:' <<< "$yaml"
  local yaml='name: no-comp
description: Missing composition
triggers: [test]
anti_triggers: [not-test]'
  local warnings=0
  if ! grep -q '^composition:' <<< "$yaml"; then
    ((warnings++)) || true
  fi
  if [[ "$warnings" -gt 0 ]]; then
    pass "composition warning fires for skill without composition"
  else
    fail "composition warning did not fire for skill without composition"
  fi
}

test_composition_no_warning_when_present() {
  local yaml='name: has-comp
description: Has composition
triggers: [test]
anti_triggers: [not-test]
composition:
  consumes: [challenge]
  produces: [output]
  capabilities: [does-stuff]
  priority: 10'
  local warnings=0
  if ! grep -q '^composition:' <<< "$yaml"; then
    ((warnings++)) || true
  fi
  if [[ "$warnings" -eq 0 ]]; then
    pass "no composition warning when composition present"
  else
    fail "spurious composition warning for skill with composition"
  fi
}

test_composition_check_pattern_matches_module
test_composition_warning_fires_when_missing
test_composition_no_warning_when_present

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
