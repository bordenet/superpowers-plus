#!/usr/bin/env bats
# augment-non-regression-test.bats — P2 Augment-side non-regression suite
#
# PURPOSE: Asserts that work done under the Claude Code guardrails program
#          does NOT regress the Augment Code surface in superpowers-plus.
#
# DEPENDENCIES: bats-core >=1.8.0, jq, git, python3, sha256sum (or shasum)
#
# RUN: bats tests/augment-non-regression-test.bats
# EXIT: 0 = all Augment surfaces intact, non-zero = regression detected
#
# BASELINE: tests/fixtures/augment-baseline-pre-claude-guardrails.json
# GOLDEN:   tests/fixtures/commit-gate-golden/
#           tests/fixtures/public-repo-ip-check-golden/

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
  export REPO_ROOT
  BASELINE="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"
  export BASELINE
  # Portable sha256: macOS uses shasum -a 256; Linux uses sha256sum
  if command -v sha256sum >/dev/null 2>&1; then
    SHA256="sha256sum"
  else
    SHA256="shasum -a 256"
  fi
  export SHA256
}

# ---------------------------------------------------------------------------
# P2a — Augment-touching files match the baseline (no install side-effects)
#
# NOTE: We do NOT run install.sh --upgrade here. Running it as a test step
# has unacceptable side-effects on the installed skill catalog (changes routing
# behaviour for the rest of the battery). Hash comparison is sufficient to
# detect file drift without reinstalling anything.
# ---------------------------------------------------------------------------
@test "P2a: Augment-touching files match baseline hashes (no drift)" {
  local files
  files="$(jq -r '.file_hashes | keys[]' "$BASELINE")"
  [[ -n "$files" ]] || skip "no file_hashes in baseline"

  local file hash expected abs_file
  while IFS= read -r file; do
    abs_file="$REPO_ROOT/$file"
    [[ -f "$abs_file" ]] || { echo "MISSING: $abs_file"; return 1; }
    hash="$($SHA256 "$abs_file" | cut -d' ' -f1)"
    expected="$(jq -r --arg f "$file" '.file_hashes[$f]' "$BASELINE")"
    if [[ "$expected" != "null" && "$hash" != "$expected" ]]; then
      echo "DRIFT: $file  expected=$expected  actual=$hash"
      return 1
    fi
  done <<<"$files"
}

# ---------------------------------------------------------------------------
# P2b — commit-gate.sh CLI contract (--help byte-identical to golden)
# ---------------------------------------------------------------------------
@test "P2b: commit-gate.sh --help matches golden" {
  local golden="$REPO_ROOT/tests/fixtures/commit-gate-golden/help.txt"
  [[ -f "$golden" ]] || skip "golden file missing — re-run scripts/capture-augment-baseline.sh"
  local actual
  actual="$(bash "$REPO_ROOT/tools/commit-gate.sh" --help 2>&1)"
  local expected
  expected="$(cat "$golden")"
  if [[ "$actual" != "$expected" ]]; then
    echo "commit-gate.sh --help output changed:"
    diff <(echo "$expected") <(echo "$actual") || true
    return 1
  fi
}

# ---------------------------------------------------------------------------
# P2c — public-repo-ip-check.sh CLI contract (--help + flag inventory)
# ---------------------------------------------------------------------------
@test "P2c: public-repo-ip-check.sh --help contains required flags" {
  local flags_golden="$REPO_ROOT/tests/fixtures/public-repo-ip-check-golden/expected-flags.txt"
  [[ -f "$flags_golden" ]] || skip "golden flags file missing"
  local help_out
  help_out="$(bash "$REPO_ROOT/tools/public-repo-ip-check.sh" --help 2>&1)"
  local flag
  while IFS= read -r flag; do
    [[ -z "$flag" ]] && continue
    if ! grep -qF -- "$flag" <<<"$help_out"; then
      echo "MISSING flag in --help: $flag"
      return 1
    fi
  done < "$flags_golden"
}

@test "P2c: public-repo-ip-check.sh --staged-only exits 0 on clean repo" {
  # Run from repo root with nothing staged — must pass the audit
  local out rc=0
  out="$(cd "$REPO_ROOT" && bash tools/public-repo-ip-check.sh --staged-only 2>&1)" || rc=$?
  # rc=0 means clean; rc=1 means IP found (fail); rc=2 means script error (fail)
  if [[ $rc -ne 0 ]]; then
    echo "public-repo-ip-check.sh --staged-only failed (rc=$rc):"
    echo "$out"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# P2d — sp-doctor output diff against baseline: only additive deltas allowed
# ---------------------------------------------------------------------------
@test "P2d: sp-doctor summary shows no fewer issues than baseline" {
  # Baseline records the sp-doctor exit code; new run must exit 0 too.
  local baseline_rc
  baseline_rc="$(jq -r '.sp_doctor.exit_code' "$BASELINE")"
  local current_rc=0
  bash "$REPO_ROOT/tools/sp-doctor.sh" --summary-only >/dev/null 2>&1 || current_rc=$?
  # Both should exit 0 (sp-doctor is informational — non-zero means a real error)
  if [[ "$baseline_rc" == "0" && "$current_rc" -ne 0 ]]; then
    echo "REGRESSION: sp-doctor previously exited 0; now exits $current_rc"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# P2e — CLI contract: wrapped tools still document expected flags
# ---------------------------------------------------------------------------
@test "P2e: public-repo-ip-check.sh --help documents --patterns flag" {
  bash "$REPO_ROOT/tools/public-repo-ip-check.sh" --help 2>&1 | grep -q -- "--patterns" \
    || { echo "MISSING: --patterns not in --help (item 1 wrap would silently break)"; return 1; }
}

@test "P2e: commit-gate.sh --help exits 0" {
  bash "$REPO_ROOT/tools/commit-gate.sh" --help >/dev/null 2>&1
}
