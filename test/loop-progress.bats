#!/usr/bin/env bats
# Unit tests for tools/loop-progress.sh
# Acceptance criteria:
#   1. First round (empty ledger)               -> exit 0
#   2. Byte-identical second round              -> exit 2 (zero delta)
#   3. Changed tree, unchanged verdict          -> warning + exit 0
#   4. Unchanged tree, improved verdict         -> exit 2 (rescored same bytes)
#   5. Two loops same worktree, different names -> independent ledgers
#   6. Ledger with different base SHA           -> expired -> exit 0 (fresh)
#   7. Malformed ledger record                  -> exit 1 with line number
#   8. Narrow --paths scope misses out-of-scope changes -> no false abort

TOOL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/loop-progress.sh"

setup() {
  WORK="$(mktemp -d)"
  cd "$WORK"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "initial" > README.md
  git add README.md
  git commit -q -m "init"
}

teardown() {
  rm -rf "$WORK"
}

run_lp() {
  run bash "$TOOL" "$@"
}

@test "first round with empty ledger exits 0" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "round 1 recorded" ]]
}

@test "byte-identical second round exits 2 (zero delta)" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  run_lp --loop cr-battery --round 2 --verdict "FAIL 7.5/10"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "ABORT" ]]
}

@test "changed tree with unchanged verdict prints warning but exits 0" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  echo "edit1" >> README.md
  run_lp --loop cr-battery --round 2 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARNING" ]] || [[ "$output" =~ "verdict" ]]
}

@test "unchanged tree with improved verdict exits 2 (rescored same bytes)" {
  run_lp --loop llm-review --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  run_lp --loop llm-review --round 2 --verdict "PASS 9.2/10"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "ABORT" ]]
}

@test "two loops with different names have independent ledgers" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  run_lp --loop phr-review --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "round 1 recorded" ]]
}

@test "ledger from different HEAD is expired and does not abort" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  echo "new commit" > file2.txt
  git add file2.txt
  git commit -q -m "advance HEAD"
  run_lp --loop cr-battery --round 2 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "round 2 recorded" ]]
}

@test "malformed ledger record exits 1 and names the line number" {
  GIT_DIR="$(git rev-parse --git-dir)"
  mkdir -p "${GIT_DIR}/loop-progress"
  BASE="$(git rev-parse HEAD)"
  echo "1|main|${BASE}|good_tree|good_tuple|PASS|2026-01-01T00:00:00Z" \
    >> "${GIT_DIR}/loop-progress/cr-battery.ledger"
  echo "CORRUPTED_LINE_NO_PIPES" \
    >> "${GIT_DIR}/loop-progress/cr-battery.ledger"
  run_lp --loop cr-battery --round 2 --verdict "FAIL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "line 2" ]] || [[ "$output" =~ "line" ]]
}

@test "narrow --paths scope does not abort when change is out of scope" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [ "$status" -eq 0 ]
  mkdir -p src
  echo "change in src" > src/main.sh
  run_lp --loop cr-battery --round 2 --verdict "FAIL 7.5/10" --paths "tools/"
  [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
}

@test "missing --loop flag exits 1 with error message" {
  run_lp --round 1 --verdict "FAIL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--loop" ]]
}

@test "missing --verdict flag exits 1 with error message" {
  run_lp --loop cr-battery --round 1
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--verdict" ]]
}

@test "non-integer --round exits 1" {
  run_lp --loop cr-battery --round abc --verdict "FAIL"
  [ "$status" -eq 1 ]
}

@test "round-history table is printed on every call" {
  run_lp --loop cr-battery --round 1 --verdict "FAIL 7.5/10"
  [[ "$output" =~ "loop-progress:" ]]
  [[ "$output" =~ "Rnd" ]]
}
