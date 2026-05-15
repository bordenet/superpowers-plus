#!/usr/bin/env bats
# claude-guardrails-test.bats — parity harness for the Claude Code guardrails
# program (items 1-12). Grows one test per hook PR. All 50 tests must be
# green before the program is declared complete.
#
# DEPENDENCIES: bats-core >=1.8.0, jq, git, python3, claude CLI (>=2.1.116)
#
# RUN: bats tests/claude-guardrails-test.bats
# EXIT: 0 = all shipped tests pass, non-zero = regression

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
  export REPO_ROOT
  INSTALLER="$REPO_ROOT/setup/install-claude-guardrails.sh"
  export INSTALLER

  # Record which Claude Code CLI version this run tested against.
  local claude_ver
  claude_ver="$(claude --version 2>/dev/null | grep -oE '[0-9]+([.][0-9]+){2}' | head -1 || echo 'absent')"
  echo "# parity test against claude CLI = $claude_ver" >&3
  echo "$claude_ver" > "${BATS_FILE_TMPDIR}/claude-version.txt"

  # Fail hard if bats-core is too old (< 1.8.0 lacks BATS_FILE_TMPDIR).
  [[ -n "${BATS_FILE_TMPDIR:-}" ]] || {
    echo "bats-core >= 1.8.0 required (BATS_FILE_TMPDIR missing)" >&2
    return 1
  }
}

teardown_file() {
  cp "${BATS_FILE_TMPDIR}/claude-version.txt" \
     "${BATS_FILE_TMPDIR}/../parity-last-cli-version.txt" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Helper: create a throw-away HOME dir so the installer has no side-effects
# ---------------------------------------------------------------------------
_fresh_home() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.claude" "$tmp/.config/claude-hooks"
  echo "$tmp"
}

# ---------------------------------------------------------------------------
# Item 11 tests
# ---------------------------------------------------------------------------

# 11d — kill switch (P3): SUPERPOWERS_CLAUDE_GUARDRAILS=0 must block all writes
@test "item 11d: kill switch (SUPERPOWERS_CLAUDE_GUARDRAILS=0) blocks all writes" {
  local fake_home
  fake_home="$(_fresh_home)"

  SUPERPOWERS_CLAUDE_GUARDRAILS=0 HOME="$fake_home" \
    run bash "$INSTALLER"

  [ "$status" -eq 0 ]

  # Nothing must have been written to ~/.claude/hooks/ or ~/.claude/settings.json
  local hook_count settings_exists
  hook_count="$(find "$fake_home/.claude/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
  settings_exists=0
  [[ -f "$fake_home/.claude/settings.json" ]] && settings_exists=1

  [ "$hook_count" -eq 0 ] || {
    echo "Kill switch ON but $hook_count hook(s) were written"
    return 1
  }
  [ "$settings_exists" -eq 0 ] || {
    echo "Kill switch ON but settings.json was written"
    return 1
  }

  rm -rf "$fake_home"
}

# 11c — bypass clause present in every shipped hook (build-time gate)
@test "item 11c: bypass clause present in every shipped hook script" {
  local h missing=0
  for h in "$REPO_ROOT/tools/claude-hooks/"*.sh; do
    [[ -f "$h" ]] || continue
    if ! grep -q 'CLAUDE_HOOKS_BYPASS' "$h"; then
      echo "MISSING bypass clause: $h"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ]
}

# 11b — idempotency: install twice, settings.json hash must not change
# (PR-1: with empty spec, the merge is a no-op; tests the idempotency path)
@test "item 11b: re-running installer is idempotent (empty spec, kill switch OFF)" {
  local fake_home before after
  fake_home="$(_fresh_home)"
  # First run
  SUPERPOWERS_CLAUDE_GUARDRAILS=1 HOME="$fake_home" \
    bash "$INSTALLER" >/dev/null 2>&1 || true
  # Capture settings hash (may not exist if claude CLI absent — that's OK)
  if [[ -f "$fake_home/.claude/settings.json" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      before="$(sha256sum "$fake_home/.claude/settings.json" | cut -d' ' -f1)"
    else
      before="$(shasum -a 256 "$fake_home/.claude/settings.json" | cut -d' ' -f1)"
    fi
    # Second run
    SUPERPOWERS_CLAUDE_GUARDRAILS=1 HOME="$fake_home" \
      bash "$INSTALLER" >/dev/null 2>&1 || true
    if command -v sha256sum >/dev/null 2>&1; then
      after="$(sha256sum "$fake_home/.claude/settings.json" | cut -d' ' -f1)"
    else
      after="$(shasum -a 256 "$fake_home/.claude/settings.json" | cut -d' ' -f1)"
    fi
    [ "$before" = "$after" ] || {
      echo "settings.json changed on second run: $before -> $after"
      return 1
    }
  fi
  rm -rf "$fake_home"
}

# PR-1 — installer wired into install.sh
@test "PR-1: install.sh --upgrade calls install-claude-guardrails.sh (kill switch ON)" {
  # Structural gate: install.sh must have an install_claude_guardrails call site
  # (leading whitespace distinguishes a call from the function definition line).
  grep -qE '^\s+install_claude_guardrails\b' "$REPO_ROOT/install.sh" || {
    echo "install.sh is missing an install_claude_guardrails call site"
    return 1
  }

  # Behavioral gate: the guardrails installer creates hook .sh files when invoked directly.
  # (install.sh --upgrade cannot run hermetically because upgrade_existing requires a live
  # .codex/superpowers git repo; item 11a covers the installer's full artifact creation.)
  local fake_home
  fake_home="$(_fresh_home)"
  SUPERPOWERS_CLAUDE_GUARDRAILS=1 HOME="$fake_home" \
    XDG_CONFIG_HOME="$fake_home/.config" \
    bash "$INSTALLER" >/dev/null 2>&1 || true

  local hook_count
  hook_count="$(find "$fake_home/.claude/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$hook_count" -gt 0 ]] || {
    echo "Expected hook .sh files to be installed but found none"
    return 1
  }

  rm -rf "$fake_home"
}

@test "PR-1: install.sh --upgrade with kill switch OFF leaves ~/.claude/hooks absent" {
  local fake_home
  fake_home="$(_fresh_home)"
  # Remove the pre-created hooks dir so we can test it stays absent
  rm -rf "$fake_home/.claude/hooks"

  SUPERPOWERS_CLAUDE_GUARDRAILS=0 HOME="$fake_home" \
    XDG_CONFIG_HOME="$fake_home/.config" \
    bash "$REPO_ROOT/install.sh" --upgrade >/dev/null 2>&1 || true

  local hook_count
  hook_count="$(find "$fake_home/.claude/hooks" -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$hook_count" -eq 0 ] || {
    echo "Kill switch OFF but $hook_count hook script(s) were installed"
    return 1
  }

  rm -rf "$fake_home"
}

# ---------------------------------------------------------------------------
# Fixture helpers for PR-2 tests
# ---------------------------------------------------------------------------

# Create a git repo with a github.com remote and one "unpushed" commit.
# Sets REPO, UPSTREAM_BASE, PAT_FILE in the caller's scope.
# The commit message contains the string passed as $1.
_fixture_repo_with_commit() {
  local commit_msg="${1:-safe commit}"
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@test.com"
  git -C "$REPO" config user.name "Test"
  # Base commit (simulates the upstream)
  git -C "$REPO" commit -q --allow-empty -m "base"
  # Create a local branch that acts as the upstream tracking ref
  git -C "$REPO" branch upstream-base
  git -C "$REPO" branch --set-upstream-to=upstream-base HEAD 2>/dev/null \
    || git -C "$REPO" branch --set-upstream-to=upstream-base master 2>/dev/null \
    || git -C "$REPO" branch --set-upstream-to=upstream-base main 2>/dev/null || true
  # Add the "unpushed" commit with our content
  git -C "$REPO" commit -q --allow-empty -m "$commit_msg"
  # Set github.com remote (non-functional URL; hook only checks the URL string)
  git -C "$REPO" remote add origin "https://github.com/testuser/testrepo.git"
}

# Create a minimal AGENTS.md identity table in $REPO.
_fixture_agents_identity() {
  local repo="$1" expected_email="${2:-bordenet@users.noreply.github.com}"
  cat > "$repo/AGENTS.md" <<AGENTS_EOF
# AI Agent Guidelines
| Context | Email | Git User |
|---------|-------|----------|
| github.com/* | $expected_email | testuser |
| Work repos | work@example.com | workuser |
AGENTS_EOF
}

# Create a minimal JSONL transcript file.
# $1 = last user message text (empty = no user message with approval)
_fixture_transcript() {
  local msg="${1:-hello world}"
  TPATH="$(mktemp).jsonl"
  printf '{"role":"assistant","content":"I will help."}\n' > "$TPATH"
  printf '{"role":"user","content":"%s"}\n' "$msg" >> "$TPATH"
}

# ---------------------------------------------------------------------------
# Item 4 — CLAUDE.md imperative coverage
# ---------------------------------------------------------------------------

@test "item 4: every CLAUDE.md imperative is mapped to a hook or deferred" {
  run bash "$BATS_TEST_DIRNAME/helpers/assert-imperative-coverage.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"item 4 PASS"* ]]
}

# ---------------------------------------------------------------------------
# Item 1 — PreToolUse internal-terms scan
# ---------------------------------------------------------------------------

@test "item 1: internal-terms scan blocks push to github.com" {
  _fixture_repo_with_commit "contains callbox-internal-secret-codename in commit message"
  PAT_FILE="$(mktemp)"
  echo "callbox-internal-secret-codename" > "$PAT_FILE"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-internal-terms.sh"
  CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$PAT_FILE" \
    run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"%s"}' "$REPO")"
  rm -f "$PAT_FILE"; rm -rf "$REPO"
  [ "$status" -eq 2 ]
  [[ "$output" == *"internal-terms detected"* ]] || [[ "${lines[*]}" == *"internal-terms detected"* ]]
}

@test "item 1: internal-terms scan allows push with no pattern match" {
  _fixture_repo_with_commit "safe commit with nothing to hide"
  PAT_FILE="$(mktemp)"
  echo "super-secret-term-xyz" > "$PAT_FILE"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-internal-terms.sh"
  CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$PAT_FILE" \
    run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"%s"}' "$REPO")"
  rm -f "$PAT_FILE"; rm -rf "$REPO"
  [ "$status" -eq 0 ]
}

@test "item 1: bypass clause (CLAUDE_HOOKS_BYPASS=1) allows everything" {
  CLAUDE_HOOKS_BYPASS=1 run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-internal-terms.sh" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Item 2 — PreToolUse git identity verification
# ---------------------------------------------------------------------------

@test "item 2: git-identity blocks commit with wrong email" {
  _fixture_repo_with_commit "test commit"
  _fixture_agents_identity "$REPO" "bordenet@users.noreply.github.com"
  git -C "$REPO" config user.email "wrong@example.com"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-git-identity.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"%s"}' "$REPO")"
  rm -rf "$REPO"
  [ "$status" -eq 2 ]
  [[ "$output" == *"identity mismatch"* ]] || [[ "${lines[*]}" == *"identity mismatch"* ]]
}

@test "item 2: git-identity allows commit with correct email" {
  _fixture_repo_with_commit "test commit"
  _fixture_agents_identity "$REPO" "bordenet@users.noreply.github.com"
  git -C "$REPO" config user.email "bordenet@users.noreply.github.com"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-git-identity.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"%s"}' "$REPO")"
  rm -rf "$REPO"
  [ "$status" -eq 0 ]
}

@test "item 2: git-identity allows when no AGENTS.md anywhere in tree" {
  local bare_repo
  # Use /tmp explicitly to ensure the temp dir is not under ~/git (workspace root),
  # which would cause the hook's directory walker to find ~/git/AGENTS.md.
  bare_repo="$(TMPDIR=/tmp mktemp -d)"
  git -C "$bare_repo" init -q
  git -C "$bare_repo" config user.email "wrong@example.com"
  git -C "$bare_repo" config user.name "Wrong User"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-git-identity.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"%s"}' "$bare_repo")"
  rm -rf "$bare_repo"
  [ "$status" -eq 0 ]
  [[ "$output" != *"identity mismatch"* ]] || {
    echo "Fail-open fired 'identity mismatch' unexpectedly: $output"
    return 1
  }
}

# ---------------------------------------------------------------------------
# Item 10 — PreToolUse RED-autonomy gate
# ---------------------------------------------------------------------------

@test "item 10: RED-autonomy blocks git push without approval" {
  _fixture_transcript "please help me with the code"
  CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"transcript_path":"%s","session_id":"test-session-noap","cwd":"/tmp"}' "$TPATH")"
  rm -f "$TPATH"
  [ "$status" -eq 2 ]
  [[ "$output" == *"RED action without explicit approval"* ]] || [[ "${lines[*]}" == *"RED action without explicit approval"* ]]
}

@test "item 10: RED-autonomy transcript token is reusable (phrase persists in transcript)" {
  local fake_home
  fake_home="$(_fresh_home)"

  _fixture_transcript "approve push"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh"
  local input
  input="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin feature/x"},"transcript_path":"%s","session_id":"test-session-approved","cwd":"/tmp"}' "$TPATH")"

  # First invocation: approval phrase in transcript → allow
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" <<<"$input"
  [ "$status" -eq 0 ]

  # Second invocation: phrase still in transcript → allow (transcript tokens are reusable)
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" <<<"$input"
  rm -f "$TPATH"
  rm -rf "$fake_home"
  [ "$status" -eq 0 ]
}

@test "item 10: RED-autonomy file-based token is single-use (consumed-hash anti-replay)" {
  local fake_home
  fake_home="$(_fresh_home)"

  _fixture_transcript "no approval here"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh"
  local input
  input="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin feature/x"},"transcript_path":"%s","session_id":"test-session-filetoken","cwd":"/tmp"}' "$TPATH")"

  # Write a file-based approval token
  mkdir -p "$fake_home/.claude/session-env"
  echo "push" > "$fake_home/.claude/session-env/test-session-filetoken.push-approval"

  # First invocation: file token present → allow (and token consumed, file deleted)
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" <<<"$input"
  [ "$status" -eq 0 ]

  # Consumed-hash file must now exist in the new consumed/ directory
  [ -f "$fake_home/.claude/consumed/test-session-filetoken.consumed-approvals.txt" ]

  # Write a NEW file-based token (simulating a replay attempt)
  echo "push" > "$fake_home/.claude/session-env/test-session-filetoken.push-approval"

  # Second invocation: token hash already in consumed file → block with "already consumed"
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" <<<"$input"
  rm -f "$TPATH"
  rm -rf "$fake_home"
  [ "$status" -eq 2 ]
  [[ "$output" == *"already consumed"* ]]
}

@test "item 10: RED-autonomy fail-open when session_id is absent" {
  local fake_home
  fake_home="$(_fresh_home)"
  _fixture_transcript "approve push"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh"
  # Omit session_id entirely from the hook input
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"transcript_path":"%s","cwd":"/tmp"}' "$TPATH")"
  rm -f "$TPATH"
  [ "$status" -eq 0 ]
  # No consumed-approvals file should be written when session_id is absent
  local consumed_count
  consumed_count="$(find "$fake_home/.claude" -name '*.consumed-approvals.txt' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$consumed_count" -eq 0 ] || {
    echo "BUG: consumed-approvals file written with empty session_id"
    return 1
  }
  rm -rf "$fake_home"
}

@test "item 10: RED-autonomy path-traversal session_id sanitized to fail-open" {
  local fake_home
  fake_home="$(_fresh_home)"
  _fixture_transcript "approve push"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh"
  # session_id of all-special chars ("../..") sanitizes to "" (empty) → must fail-open.
  # "../../evil" would sanitize to "evil" (non-empty) and take the normal approval path — wrong test.
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"transcript_path":"%s","session_id":"../../","cwd":"/tmp"}' "$TPATH")"
  rm -f "$TPATH"
  [ "$status" -eq 0 ]
  # No consumed-approvals file should be written when session_id sanitizes to empty
  local consumed_count
  consumed_count="$(find "$fake_home/.claude" -name '*.consumed-approvals.txt' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$consumed_count" -eq 0 ] || {
    echo "BUG: consumed-approvals file written with empty-sanitized session_id"
    return 1
  }
  rm -rf "$fake_home"
}

@test "item 10: is_red_action matches second pattern in multi-line file" {
  local fake_home pat_file
  fake_home="$(_fresh_home)"
  pat_file="$(mktemp)"
  # Matching pattern is NOT on line 1 — exercises grep -f multi-line handling (B1 fix)
  printf '# comment\nno-match-pattern\ngit push\n' > "$pat_file"
  _fixture_transcript "no approval here"
  local hook="$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh"
  HOME="$fake_home" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$pat_file" \
    run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"transcript_path":"%s","session_id":"multi-test","cwd":"/tmp"}' "$TPATH")"
  rm -f "$pat_file" "$TPATH"; rm -rf "$fake_home"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Item 11a — fresh install produces all PR-2 hook artifacts
# ---------------------------------------------------------------------------

@test "item 11a: fresh install produces all shipped hook artifacts (PR-2 through PR-5)" {
  local fake_home
  fake_home="$(_fresh_home)"
  SUPERPOWERS_CLAUDE_GUARDRAILS=1 HOME="$fake_home" \
    XDG_CONFIG_HOME="$fake_home/.config" \
    bash "$INSTALLER" >/dev/null 2>&1 || true

  local missing=0
  for hook in \
      pre-tool-use-internal-terms.sh \
      pre-tool-use-git-identity.sh \
      pre-tool-use-red-autonomy.sh \
      session-start-rules-integrity.sh \
      pre-compact-reinject.sh \
      post-tool-use-verify.sh \
      subagent-stop-claims-evidence.sh; do
    [[ -f "$fake_home/.claude/hooks/$hook" ]] || {
      echo "MISSING: $hook"
      missing=1
    }
  done
  rm -rf "$fake_home"
  [ "$missing" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Item 3 — SessionStart rules-file integrity
# ---------------------------------------------------------------------------

# Helper: create a fake rules dir with a dangling symlink
_fixture_dangling_rule() {
  RULES_DIR_TMP="$(mktemp -d)"
  ln -s "$RULES_DIR_TMP/nonexistent-target.md" "$RULES_DIR_TMP/dangling.md"
  echo "$RULES_DIR_TMP"
}

@test "item 3a: SessionStart blocks on dangling symlink in rules dir" {
  local rules_dir hook_input fake_home
  rules_dir="$(_fixture_dangling_rule)"
  fake_home="$(_fresh_home)"
  mkdir -p "$fake_home/.augment"
  # Symlink the fake rules dir into the fake home
  ln -s "$rules_dir" "$fake_home/.augment/rules"

  local hook="$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh"
  hook_input="$(printf '{"hook_event_name":"SessionStart","session_id":"test","cwd":"%s","matcher":"startup"}' "$REPO_ROOT")"
  HOME="$fake_home" run bash "$hook" <<<"$hook_input"

  rm -rf "$rules_dir" "$fake_home"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DANGLING:"* ]] || [[ "${lines[*]}" == *"DANGLING:"* ]]
}

@test "item 3b: SessionStart passes when rules files are intact" {
  local fake_home rules_dir
  fake_home="$(_fresh_home)"
  rules_dir="$fake_home/.augment/rules"
  mkdir -p "$rules_dir"
  # Real file (not a dangling symlink)
  echo "# test rule" > "$rules_dir/test-rule.md"

  local hook="$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh"
  hook_input="$(printf '{"hook_event_name":"SessionStart","session_id":"test","cwd":"%s","matcher":"startup"}' "$REPO_ROOT")"
  HOME="$fake_home" run bash "$hook" <<<"$hook_input"

  rm -rf "$fake_home"
  [ "$status" -eq 0 ]
  [[ "$output" == *"integrity OK"* ]] || [[ "${lines[*]}" == *"integrity OK"* ]]
}

@test "item 3c: SessionStart blocks (exit 2) and reports MISSING when rules dir absent" {
  local fake_home
  fake_home="$(_fresh_home)"
  # .augment/rules/ does not exist

  local hook="$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh"
  hook_input="$(printf '{"hook_event_name":"SessionStart","session_id":"test","cwd":"%s","matcher":"startup"}' "$REPO_ROOT")"
  HOME="$fake_home" run bash "$hook" <<<"$hook_input"

  rm -rf "$fake_home"
  [ "$status" -eq 2 ]
  [[ "$output" == *"MISSING:"* ]] || [[ "${lines[*]}" == *"MISSING:"* ]]
}

@test "item 3e: SessionStart blocks (exit 2) and reports WARNING when rules dir has no .md files" {
  local fake_home
  fake_home="$(_fresh_home)"
  mkdir -p "$fake_home/.augment/rules"
  # Dir exists but contains no .md files
  touch "$fake_home/.augment/rules/not-a-rule.txt"

  local hook="$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh"
  hook_input="$(printf '{"hook_event_name":"SessionStart","session_id":"test","cwd":"%s","matcher":"startup"}' "$REPO_ROOT")"
  HOME="$fake_home" run bash "$hook" <<<"$hook_input"

  rm -rf "$fake_home"
  [ "$status" -eq 2 ]
  [[ "$output" == *"WARNING:"* ]] || [[ "${lines[*]}" == *"WARNING:"* ]]
}

@test "item 3d: SessionStart bypass clause (CLAUDE_HOOKS_BYPASS=1) exits 0" {
  CLAUDE_HOOKS_BYPASS=1 run bash "$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh" \
    <<<"$(printf '{"hook_event_name":"SessionStart","session_id":"test","cwd":"/tmp","matcher":"startup"}')"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Item 9 — PreCompact CLAUDE.md re-inject
# ---------------------------------------------------------------------------

@test "item 9a: PreCompact re-injects CLAUDE.md top 50 lines" {
  local ws
  ws="$(mktemp -d)"
  printf '# Test CLAUDE.md\nsome content\n' > "$ws/CLAUDE.md"

  local hook="$REPO_ROOT/tools/claude-hooks/pre-compact-reinject.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreCompact","session_id":"test-session","trigger":"auto","cwd":"%s"}' "$ws")"

  rm -rf "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE.md (top 50 lines)"* ]] || [[ "${lines[*]}" == *"CLAUDE.md (top 50 lines)"* ]]
  [[ "$output" == *"Test CLAUDE.md"* ]] || [[ "${lines[*]}" == *"Test CLAUDE.md"* ]]
}

@test "item 9b: PreCompact uses workspace fallback CLAUDE.md when cwd has none" {
  local ws fake_home
  # Use an isolated tmpdir with no CLAUDE.md in the walk path but a workspace fallback
  ws="$(TMPDIR=/tmp mktemp -d)"
  fake_home="$(_fresh_home)"
  mkdir -p "$fake_home/git"
  printf '# Workspace CLAUDE.md\nfallback content\n' > "$fake_home/git/CLAUDE.md"

  local hook="$REPO_ROOT/tools/claude-hooks/pre-compact-reinject.sh"
  HOME="$fake_home" run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreCompact","session_id":"test-session","trigger":"auto","cwd":"%s"}' "$ws")"

  rm -rf "$ws" "$fake_home"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE.md (top 50 lines)"* ]] || [[ "${lines[*]}" == *"CLAUDE.md (top 50 lines)"* ]]
  [[ "$output" == *"fallback content"* ]] || [[ "${lines[*]}" == *"fallback content"* ]]
}

@test "item 9b2: PreCompact emits no-CLAUDE.md message when none found anywhere" {
  local ws fake_home
  # Fake HOME with no ~/git/CLAUDE.md, cwd in /tmp (no CLAUDE.md in walk path)
  ws="$(TMPDIR=/tmp mktemp -d)"
  fake_home="$(_fresh_home)"

  local hook="$REPO_ROOT/tools/claude-hooks/pre-compact-reinject.sh"
  HOME="$fake_home" run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreCompact","session_id":"test-session","trigger":"auto","cwd":"%s"}' "$ws")"

  rm -rf "$ws" "$fake_home"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no CLAUDE.md found"* ]] || [[ "${lines[*]}" == *"no CLAUDE.md found"* ]]
}

@test "item 9c: PreCompact includes scope file content when present" {
  local ws fake_home scope_dir
  ws="$(mktemp -d)"
  fake_home="$(_fresh_home)"
  scope_dir="$fake_home/.claude/session-env"
  mkdir -p "$scope_dir"
  echo "task: implement PR-3 hooks" > "$scope_dir/test-session-123.scope.txt"

  local hook="$REPO_ROOT/tools/claude-hooks/pre-compact-reinject.sh"
  HOME="$fake_home" run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PreCompact","session_id":"test-session-123","trigger":"auto","cwd":"%s"}' "$ws")"

  rm -rf "$ws" "$fake_home"
  [ "$status" -eq 0 ]
  [[ "$output" == *"implement PR-3 hooks"* ]] || [[ "${lines[*]}" == *"implement PR-3 hooks"* ]]
}

@test "item 9d: PreCompact bypass clause (CLAUDE_HOOKS_BYPASS=1) exits 0" {
  CLAUDE_HOOKS_BYPASS=1 run bash "$REPO_ROOT/tools/claude-hooks/pre-compact-reinject.sh" \
    <<<"$(printf '{"hook_event_name":"PreCompact","session_id":"test","trigger":"auto","cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Item 5 — slash-menu mirror
# ---------------------------------------------------------------------------

@test "item 5: slash-menu mirror produces one command per skill" {
  local aug_dir cmd_dir
  aug_dir="$(mktemp -d)"
  cmd_dir="$(mktemp -d)"

  # Create two minimal SKILL.md entries in the Augment menu dir
  for skill in foo bar; do
    mkdir -p "$aug_dir/$skill"
    printf -- '---\nname: %s\ndescription: "Do %s things"\n---\n\nBody.\n' \
      "$skill" "$skill" > "$aug_dir/$skill/SKILL.md"
  done

  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"

  [ "$status" -eq 0 ]
  [ -f "$cmd_dir/foo.md" ]
  [ -f "$cmd_dir/bar.md" ]
  grep -q "Invoke the \`foo\` skill" "$cmd_dir/foo.md"
  grep -q 'description: "Do foo things"' "$cmd_dir/foo.md"

  rm -rf "$aug_dir" "$cmd_dir"
}

@test "item 5: slash-menu mirror skips gracefully when source dir absent" {
  local cmd_dir
  cmd_dir="$(mktemp -d)"
  AUGMENT_MENU_DIR="/no/such/dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"
  rm -rf "$cmd_dir"
  [ "$status" -eq 0 ]
}

@test "item 5: install_claude_commands_mirror wired into install.sh" {
  grep -qE '^\s+install_claude_commands_mirror\b' "$REPO_ROOT/install.sh" || {
    echo "install.sh is missing an install_claude_commands_mirror call site"
    return 1
  }
}

@test "item 5: slash-menu mirror prunes stale managed commands" {
  local aug_dir cmd_dir
  aug_dir="$(mktemp -d)"
  cmd_dir="$(mktemp -d)"

  # Create two skills
  mkdir -p "$aug_dir/foo" "$aug_dir/bar"
  printf -- '---\nname: "foo"\ndescription: "Do foo things"\n---\n\nBody.\n' > "$aug_dir/foo/SKILL.md"
  printf -- '---\nname: "bar"\ndescription: "Do bar things"\n---\n\nBody.\n' > "$aug_dir/bar/SKILL.md"

  # Mirror both skills
  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"
  [ "$status" -eq 0 ]
  [ -f "$cmd_dir/foo.md" ]
  [ -f "$cmd_dir/bar.md" ]

  # Remove bar skill and re-run mirror
  rm -rf "$aug_dir/bar"
  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"
  [ "$status" -eq 0 ]

  # foo.md should still exist; bar.md should be pruned
  [ -f "$cmd_dir/foo.md" ]
  [ ! -f "$cmd_dir/bar.md" ]

  rm -rf "$aug_dir" "$cmd_dir"
}

@test "item 5: slash-menu mirror does not prune user-created commands" {
  local aug_dir cmd_dir
  aug_dir="$(mktemp -d)"
  cmd_dir="$(mktemp -d)"

  # Create a user-written command (description: only, no source: marker)
  printf -- '---\ndescription: "User custom command"\n---\n\nDo something custom.\n' \
    > "$cmd_dir/user-cmd.md"

  # Run mirror with no skills
  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"
  [ "$status" -eq 0 ]

  # User command must survive — it has no source: "claude-commands-mirror" marker
  [ -f "$cmd_dir/user-cmd.md" ]

  rm -rf "$aug_dir" "$cmd_dir"
}

@test "item 5: slash-menu mirror --what-if does not write or delete files" {
  local aug_dir cmd_dir
  aug_dir="$(mktemp -d)"
  cmd_dir="$(mktemp -d)"

  mkdir -p "$aug_dir/foo"
  printf -- '---\nname: "foo"\ndescription: "Do foo things"\n---\n\nBody.\n' \
    > "$aug_dir/foo/SKILL.md"

  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh" --what-if
  [ "$status" -eq 0 ]

  # --what-if must not write any command file
  [ ! -f "$cmd_dir/foo.md" ]

  rm -rf "$aug_dir" "$cmd_dir"
}

@test "item 5: slash-menu mirror skips when claude skills-dir entry exists for same name" {
  local aug_dir cmd_dir skills_dir
  aug_dir="$(mktemp -d)"
  cmd_dir="$(mktemp -d)"
  skills_dir="$(mktemp -d)"

  # Augment menu has skill named "foo"
  mkdir -p "$aug_dir/foo"
  printf -- '---\nname: foo\ndescription: "Augment version"\n---\n\nBody.\n' \
    > "$aug_dir/foo/SKILL.md"

  # ~/.claude/skills/foo/ already exists (e.g., overlay installed it there)
  mkdir -p "$skills_dir/foo"

  AUGMENT_MENU_DIR="$aug_dir" CLAUDE_COMMANDS_DIR="$cmd_dir" CLAUDE_SKILLS_DIR="$skills_dir" \
    run bash "$REPO_ROOT/tools/claude-commands-mirror.sh"
  [ "$status" -eq 0 ]

  # Command file must NOT be written — skills-dir entry takes precedence
  [ ! -f "$cmd_dir/foo.md" ]

  rm -rf "$aug_dir" "$cmd_dir" "$skills_dir"
}

# ---------------------------------------------------------------------------
# Item 6 — UserPromptSubmit skill router
# ---------------------------------------------------------------------------

@test "item 6: skill-router advises on matching prompt" {
  local skills_dir cache_dir
  skills_dir="$(mktemp -d)"
  cache_dir="$(mktemp -d)"

  # Create a minimal skill.md for brainstorming
  mkdir -p "$skills_dir/brainstorming"
  printf -- '---\nname: brainstorming\ndescription: "Use this before any creative work — exploring user intent and design"\n---\n\nBody.\n' \
    > "$skills_dir/brainstorming/skill.md"

  CODEX_SKILLS_DIR="$skills_dir" \
  CLAUDE_SKILL_ROUTER_CACHE="$cache_dir/skill-router-cache.json" \
  CLAUDE_HOOKS_BYPASS=0 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"Help me brainstorm a new feature","cwd":"/tmp"}')"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Likely match: brainstorming"* ]]

  rm -rf "$skills_dir" "$cache_dir"
}

@test "item 6: skill-router exits 0 and emits nothing for empty prompt" {
  local skills_dir cache_dir
  skills_dir="$(mktemp -d)"
  cache_dir="$(mktemp -d)"

  CODEX_SKILLS_DIR="$skills_dir" \
  CLAUDE_SKILL_ROUTER_CACHE="$cache_dir/skill-router-cache.json" \
  CLAUDE_HOOKS_BYPASS=0 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"","cwd":"/tmp"}')"

  [ "$status" -eq 0 ]
  [ -z "$output" ]

  rm -rf "$skills_dir" "$cache_dir"
}

@test "item 6: skill-router exits 0 when SKILLS_DIR absent (never blocks)" {
  # Verifies the 'never blocks' contract: a missing skills dir must not cause exit 1.
  local cache_dir
  cache_dir="$(mktemp -d)"

  CODEX_SKILLS_DIR="/nonexistent-skills-dir-$$" \
  CLAUDE_SKILL_ROUTER_CACHE="$cache_dir/skill-router-cache.json" \
  CLAUDE_HOOKS_BYPASS=0 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"hello","cwd":"/tmp"}')"

  [ "$status" -eq 0 ]

  rm -rf "$cache_dir"
}

@test "item 6: skill-router bypass clause (CLAUDE_HOOKS_BYPASS=1) exits 0" {
  CLAUDE_HOOKS_BYPASS=1 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"brainstorm something","cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "item 6: skill-router rebuilds cache when skill.md is newer" {
  local skills_dir cache_dir cache_file
  skills_dir="$(mktemp -d)"
  cache_dir="$(mktemp -d)"
  cache_file="$cache_dir/skill-router-cache.json"

  mkdir -p "$skills_dir/myskill"
  printf -- '---\nname: myskill\ndescription: "A test skill"\n---\nBody.\n' \
    > "$skills_dir/myskill/skill.md"

  # First run — builds cache
  CODEX_SKILLS_DIR="$skills_dir" CLAUDE_SKILL_ROUTER_CACHE="$cache_file" CLAUDE_HOOKS_BYPASS=0 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"use myskill now","cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
  [ -f "$cache_file" ]
  local mtime1
  # Portable mtime: Linux uses stat -c '%Y'; macOS uses stat -f '%m'
  mtime1="$(stat -c '%Y' "$cache_file" 2>/dev/null || stat -f '%m' "$cache_file")"

  # Touch skill.md to be newer than cache, then run again
  sleep 1
  touch "$skills_dir/myskill/skill.md"
  CODEX_SKILLS_DIR="$skills_dir" CLAUDE_SKILL_ROUTER_CACHE="$cache_file" CLAUDE_HOOKS_BYPASS=0 \
    run bash "$REPO_ROOT/tools/claude-hooks/user-prompt-submit-skill-router.sh" \
    <<<"$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"use myskill now","cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
  local mtime2
  # Portable mtime: Linux uses stat -c '%Y'; macOS uses stat -f '%m'
  mtime2="$(stat -c '%Y' "$cache_file" 2>/dev/null || stat -f '%m' "$cache_file")"

  # Cache must have been regenerated (newer mtime)
  [ "$mtime2" -gt "$mtime1" ]

  rm -rf "$skills_dir" "$cache_dir"
}

@test "item 6: skill-router wired into settings-hooks-spec.json (UserPromptSubmit)" {
  python3 -c "
import json, sys
with open('$REPO_ROOT/claude-config/settings-hooks-spec.json') as f:
    spec = json.load(f)
hooks = spec.get('hooks', {})
if 'UserPromptSubmit' not in hooks:
    print('UserPromptSubmit missing from settings-hooks-spec.json')
    sys.exit(1)
cmds = [h.get('command','') for blk in hooks['UserPromptSubmit'] for h in blk.get('hooks',[])]
if not any('user-prompt-submit-skill-router' in c for c in cmds):
    print('user-prompt-submit-skill-router not in UserPromptSubmit hooks')
    sys.exit(1)
"
}

# ---------------------------------------------------------------------------
# Item 7 — PostToolUse verify
# ---------------------------------------------------------------------------

@test "item 7: PostToolUse verify surfaces commit summary" {
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  echo "hello" > "$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -q -m "initial"
  local hook="$REPO_ROOT/tools/claude-hooks/post-tool-use-verify.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m hi"},"tool_response":{"exit_code":0},"cwd":"%s"}' "$repo")"
  rm -rf "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 file changed"* ]] || [[ "$output" == *"insertion"* ]]
}

@test "item 7: PostToolUse verify bypass clause (CLAUDE_HOOKS_BYPASS=1) exits 0" {
  local hook="$REPO_ROOT/tools/claude-hooks/post-tool-use-verify.sh"
  CLAUDE_HOOKS_BYPASS=1 run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m hi"},"tool_response":{"exit_code":0},"cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
}

@test "item 7: PostToolUse verify wired into settings-hooks-spec.json (PostToolUse)" {
  python3 -c "
import json, sys
with open('$REPO_ROOT/claude-config/settings-hooks-spec.json') as f:
    spec = json.load(f)
hooks = spec.get('hooks', {})
if 'PostToolUse' not in hooks:
    print('PostToolUse missing from settings-hooks-spec.json')
    sys.exit(1)
cmds = [h.get('command','') for blk in hooks['PostToolUse'] for h in blk.get('hooks',[])]
if not any('post-tool-use-verify' in c for c in cmds):
    print('post-tool-use-verify not in PostToolUse hooks')
    sys.exit(1)
"
}

@test "item 7: PostToolUse verify surfaces push-verified message" {
  local repo
  repo="$(mktemp -d)"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"
  git -C "$repo" commit -q --allow-empty -m "base"
  # Use a local branch as the tracking ref pointing at HEAD so @{u}..HEAD = 0 commits
  git -C "$repo" branch -q upstream-ref
  git -C "$repo" branch --set-upstream-to=upstream-ref HEAD 2>/dev/null || true
  local hook="$REPO_ROOT/tools/claude-hooks/post-tool-use-verify.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"tool_response":{"exit_code":0},"cwd":"%s"}' "$repo")"
  rm -rf "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"push verified"* ]] || [[ "$output" == *"ahead of remote"* ]]
}

@test "item 7: PostToolUse verify skips output when tool exit code is non-zero" {
  local hook="$REPO_ROOT/tools/claude-hooks/post-tool-use-verify.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m hi"},"tool_response":{"exit_code":1},"cwd":"/tmp"}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Item 8 — SubagentStop claims-evidence
# ---------------------------------------------------------------------------

@test "item 8: claims-evidence flags unpaired 'fixed' claim" {
  local tpath
  tpath="$(mktemp).jsonl"
  printf '{"role":"assistant","content":"I fixed the bug. Tests pass."}\n' > "$tpath"
  local hook="$REPO_ROOT/tools/claude-hooks/subagent-stop-claims-evidence.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"SubagentStop","transcript_path":"%s","stop_hook_active":false}' "$tpath")"
  rm -f "$tpath"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unpaired claims:"* ]]
  [[ "$output" == *"fixed"* ]]
}

@test "item 8: claims-evidence reports clean when evidence is paired" {
  local tpath
  tpath="$(mktemp).jsonl"
  printf '{"role":"assistant","content":"I fixed the bug.\\n```\\nexit 0\\n```\\n"}\n' > "$tpath"
  local hook="$REPO_ROOT/tools/claude-hooks/subagent-stop-claims-evidence.sh"
  run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"SubagentStop","transcript_path":"%s","stop_hook_active":false}' "$tpath")"
  rm -f "$tpath"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all claims paired with evidence"* ]]
}

@test "item 8: claims-evidence bypass clause (CLAUDE_HOOKS_BYPASS=1) exits 0" {
  local hook="$REPO_ROOT/tools/claude-hooks/subagent-stop-claims-evidence.sh"
  CLAUDE_HOOKS_BYPASS=1 run bash "$hook" \
    <<<"$(printf '{"hook_event_name":"SubagentStop","transcript_path":"/tmp/nonexistent.jsonl","stop_hook_active":false}')"
  [ "$status" -eq 0 ]
}

@test "item 8: claims-evidence wired into settings-hooks-spec.json (SubagentStop)" {
  python3 -c "
import json, sys
with open('$REPO_ROOT/claude-config/settings-hooks-spec.json') as f:
    spec = json.load(f)
hooks = spec.get('hooks', {})
if 'SubagentStop' not in hooks:
    print('SubagentStop missing from settings-hooks-spec.json')
    sys.exit(1)
cmds = [h.get('command','') for blk in hooks['SubagentStop'] for h in blk.get('hooks',[])]
if not any('subagent-stop-claims-evidence' in c for c in cmds):
    print('subagent-stop-claims-evidence not in SubagentStop hooks')
    sys.exit(1)
"
}

@test "scalar merge: skillListingBudgetFraction written when absent" {
  local tmp_settings
  tmp_settings="$(mktemp)"
  echo '{"hooks":{}}' > "$tmp_settings"
  local tmp_spec
  tmp_spec="$(mktemp)"
  echo '{"skillListingBudgetFraction":0.05,"hooks":{}}' > "$tmp_spec"
  SETTINGS_JSON="$tmp_settings" SPEC_JSON="$tmp_spec" \
    SUPERPOWERS_CLAUDE_GUARDRAILS=1 SUPERPOWERS_CLAUDE_GUARDRAILS_BYPASS_CLAUSE=1 \
    run python3 - "$tmp_settings" "$tmp_spec" <<'PY'
import json, sys, os
target_path, spec_path = sys.argv[1], sys.argv[2]
with open(target_path) as f: target = json.load(f)
with open(spec_path)   as f: spec   = json.load(f)
for key, val in spec.items():
    if key.startswith('_') or key == 'hooks':
        continue
    if isinstance(val, bool):
        target.setdefault(key, val)
    elif isinstance(val, (int, float)):
        existing = target.get(key)
        if isinstance(existing, (int, float)):
            target[key] = max(existing, val)
        else:
            target[key] = val
    else:
        if key not in target:
            target[key] = val
with open(target_path, 'w') as f: json.dump(target, f)
PY
  result="$(python3 -c "import json; d=json.load(open('$tmp_settings')); print(d.get('skillListingBudgetFraction'))")"
  rm -f "$tmp_settings" "$tmp_spec"
  [ "$result" = "0.05" ]
}

@test "scalar merge: max() never lowers a user-raised numeric value" {
  local tmp_settings
  tmp_settings="$(mktemp)"
  echo '{"skillListingBudgetFraction":0.10,"hooks":{}}' > "$tmp_settings"
  local tmp_spec
  tmp_spec="$(mktemp)"
  echo '{"skillListingBudgetFraction":0.05,"hooks":{}}' > "$tmp_spec"
  python3 - "$tmp_settings" "$tmp_spec" <<'PY'
import json, sys
target_path, spec_path = sys.argv[1], sys.argv[2]
with open(target_path) as f: target = json.load(f)
with open(spec_path)   as f: spec   = json.load(f)
for key, val in spec.items():
    if key.startswith('_') or key == 'hooks':
        continue
    if isinstance(val, bool):
        target.setdefault(key, val)
    elif isinstance(val, (int, float)):
        existing = target.get(key)
        if isinstance(existing, (int, float)):
            target[key] = max(existing, val)
        else:
            target[key] = val
    else:
        if key not in target:
            target[key] = val
with open(target_path, 'w') as f: json.dump(target, f)
PY
  result="$(python3 -c "import json; d=json.load(open('$tmp_settings')); print(d.get('skillListingBudgetFraction'))")"
  rm -f "$tmp_settings" "$tmp_spec"
  [ "$result" = "0.1" ]
}

@test "scalar merge: boolean spec value not coerced to int via bool-subclass-of-int" {
  local tmp_settings
  tmp_settings="$(mktemp)"
  echo '{"hooks":{}}' > "$tmp_settings"
  local tmp_spec
  tmp_spec="$(mktemp)"
  echo '{"testBoolKey":true,"hooks":{}}' > "$tmp_spec"
  python3 - "$tmp_settings" "$tmp_spec" <<'PY'
import json, sys
target_path, spec_path = sys.argv[1], sys.argv[2]
with open(target_path) as f: target = json.load(f)
with open(spec_path)   as f: spec   = json.load(f)
for key, val in spec.items():
    if key.startswith('_') or key == 'hooks':
        continue
    if isinstance(val, bool):
        target.setdefault(key, val)
    elif isinstance(val, (int, float)):
        existing = target.get(key)
        if isinstance(existing, (int, float)):
            target[key] = max(existing, val)
        else:
            target[key] = val
    else:
        if key not in target:
            target[key] = val
with open(target_path, 'w') as f: json.dump(target, f)
PY
  # Must be boolean true, not integer 1
  result="$(python3 -c "import json; d=json.load(open('$tmp_settings')); v=d.get('testBoolKey'); print(type(v).__name__, v)")"
  rm -f "$tmp_settings" "$tmp_spec"
  [ "$result" = "bool True" ]
}

@test "settings-hooks-spec.json contains skillListingBudgetFraction at 0.05 or higher" {
  python3 -c "
import json, sys
with open('$REPO_ROOT/claude-config/settings-hooks-spec.json') as f:
    spec = json.load(f)
v = spec.get('skillListingBudgetFraction')
if v is None:
    print('skillListingBudgetFraction missing from spec')
    sys.exit(1)
if not isinstance(v, (int, float)) or v < 0.05:
    print(f'skillListingBudgetFraction={v} is below minimum 0.05')
    sys.exit(1)
"
}
