#!/usr/bin/env bats
# wiki-write-test.bats -- regression tests for tools/wiki-write.sh
#
# Initially seeded with the sp-bughunt #3 regression: the script invoked an
# undefined `log_warn` in its no-node skip branch, which under `set -euo
# pipefail` crashed with `log_warn: command not found` instead of degrading
# gracefully. The fix defines `log_warn` alongside `log_err` and `log_info`.
#
# RUN: bats tests/wiki-write-test.bats

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
  export REPO_ROOT
}

@test "wiki-write: log_warn is defined (sp-bughunt #3 regression)" {
  # Cheap structural check: log_warn must be defined alongside log_err and
  # log_info. Catches the original "function never declared" bug.
  local script="$REPO_ROOT/tools/wiki-write.sh"
  grep -q '^log_warn()' "$script"
}

@test "wiki-write: log_warn behaves like a stderr WARN logger (sp-bughunt #3)" {
  # Behavioral test: source ONLY the log_* helper definitions out of
  # wiki-write.sh (so we skip the global env-var checks that exit early),
  # then invoke log_warn directly. This exercises the exact callsite that
  # was broken pre-fix without trying to walk the full create/update flow.
  #
  # The earlier version of this test invoked wiki-write.sh end-to-end and
  # passed vacuously: the script exited at the scope-check before ever
  # reaching log_warn, so a regressed script (log_warn deleted again) would
  # still satisfy `status -ne 127`. Three sp-bughunt round-1 reviewers
  # independently caught the false-positive; this rewrite addresses it.
  local script="$REPO_ROOT/tools/wiki-write.sh"
  # Extract the three log_* function definitions (each is a single line in
  # this script: `log_NAME() { ... }`). The sed range matches lines starting
  # with `log_` followed by a parenthesis.
  local helpers
  helpers="$(sed -n '/^log_[a-z]*()/p' "$script")"
  [[ -n "$helpers" ]] || {
    echo "FAILED to extract log_* helpers from $script" >&2
    return 1
  }
  # VERBOSE must be defined for log_info; default it to 0 so the helper
  # definitions parse cleanly when sourced in isolation.
  run bash -c "VERBOSE=0; $helpers
  log_warn 'gate skipped' 2>&1 1>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[wiki-write] WARN: gate skipped"* ]]
}

@test "wiki-write: log_warn output prefix matches sibling helpers (sp-bughunt #3)" {
  # Tightens the contract: log_warn must use the same `[wiki-write] LEVEL:`
  # prefix as log_err and log_info. A future "fix" that names the function
  # but emits a different prefix would break grep-based log filtering.
  local script="$REPO_ROOT/tools/wiki-write.sh"
  grep -E "^log_warn\(\)\s*\{.*\[wiki-write\] WARN:" "$script"
}

# Regression coverage for a code-review-battery Guardian finding (wiki-gate
# hardening port): CONTENT_CHECK's exit 2 (environment error, e.g. missing
# python3) used to be folded into the same generic exit 5 (content
# violation) as a real exit 1, because the gate never captured $?. An agent
# hitting exit 5 with "fix slop/structure violations and retry" would try to
# edit prose for a failure that no amount of editing fixes. The extraction
# below pulls the exact gate block out of the real script (not a
# reimplementation) so a regression in the real logic fails this test.

_extract_content_check_gate() {
  # Lines from "AI slop and content quality gate" through its closing `fi`.
  sed -n '/^# AI slop and content quality gate/,/^fi$/p' "$REPO_ROOT/tools/wiki-write.sh"
}

@test "wiki-write: content-check exit 2 (env error) exits 2, not 5" {
  local script="$REPO_ROOT/tools/wiki-write.sh"
  local gate
  gate="$(_extract_content_check_gate)"
  [[ -n "$gate" ]] || {
    echo "FAILED to extract content-check gate from $script" >&2
    return 1
  }
  local fake_dir fake_check
  fake_dir="$(mktemp -d)"
  fake_check="$fake_dir/wiki-content-check.sh"
  printf '#!/bin/sh\nexit 2\n' > "$fake_check"
  chmod +x "$fake_check"
  # SCRIPT_DIR, not CONTENT_CHECK, is set: the extracted gate's own first
  # line reassigns CONTENT_CHECK from SCRIPT_DIR, so presetting CONTENT_CHECK
  # directly would just be overwritten and silently test nothing.
  run bash -c "
    set -euo pipefail
    log_err() { echo \"[wiki-write] ERR: \$*\" >&2; }
    log_info() { :; }
    log_warn() { :; }
    ACTION=create
    CONTENT_FILE=/dev/null
    SCRIPT_DIR='$fake_dir'
    $gate
  "
  [ "$status" -eq 2 ]
  [[ "$output" == *"environment error"* ]]
  rm -rf "$fake_dir"
}

@test "wiki-write: content-check exit 1 (real violation) still exits 5" {
  local gate
  gate="$(_extract_content_check_gate)"
  local fake_dir fake_check
  fake_dir="$(mktemp -d)"
  fake_check="$fake_dir/wiki-content-check.sh"
  printf '#!/bin/sh\nexit 1\n' > "$fake_check"
  chmod +x "$fake_check"
  run bash -c "
    set -euo pipefail
    log_err() { echo \"[wiki-write] ERR: \$*\" >&2; }
    log_info() { :; }
    log_warn() { :; }
    ACTION=create
    CONTENT_FILE=/dev/null
    SCRIPT_DIR='$fake_dir'
    $gate
  "
  [ "$status" -eq 5 ]
  [[ "$output" == *"fix slop/structure violations"* ]]
  rm -rf "$fake_dir"
}
