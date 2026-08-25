#!/usr/bin/env bats
# Unit tests for tools/ship.sh -- exercises the pure sentinel-reading and
# body-generation paths without invoking `gh`, `git push`, or any network.
# Loaded via SHIP_TESTMODE=1 so main body of ship.sh is skipped.

setup() {
  TOOL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/ship.sh"
  WORK="$(mktemp -d)"
  export REPO_ROOT="$WORK"
  export SHIP_TESTMODE=1
}

teardown() {
  rm -rf "$WORK"
  unset REPO_ROOT SHIP_TESTMODE
}

_source_ship() {
  # shellcheck source=/dev/null
  source "$TOOL"
}

@test "_read_sentinel: missing file returns empty" {
  _source_ship
  run _read_sentinel "$WORK/.does-not-exist" "abc123"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_read_sentinel: matching PASS line returns score and verdict" {
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=9.2" > "$WORK/.code-review-cleared"
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "abc123"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^9\.2\ PASS$ ]]
}

@test "_read_sentinel: PASS_WITH_NITS accepted" {
  echo "v1|abc123|PASS_WITH_NITS|2026-04-01T00:00:00Z|min-score=8.5" > "$WORK/.code-review-cleared"
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "abc123"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^8\.5\ PASS_WITH_NITS$ ]]
}

@test "_read_sentinel: FAIL verdict returns empty (do not inject failed evidence)" {
  echo "v1|abc123|FAIL|2026-04-01T00:00:00Z|min-score=6.0" > "$WORK/.code-review-cleared"
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "abc123"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_read_sentinel: mismatched SHA returns empty" {
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=9.2" > "$WORK/.code-review-cleared"
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "different_sha"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_read_sentinel: takes the most-recent matching line when multiple exist" {
  cat > "$WORK/.code-review-cleared" <<EOF
v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=7.5
v1|other|PASS|2026-04-01T00:00:00Z|min-score=8.0
v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=9.2
EOF
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "abc123"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^9\.2\ PASS$ ]]
}

@test "_read_sentinel: malformed line (no min-score field) returns empty" {
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|" > "$WORK/.code-review-cleared"
  _source_ship
  run _read_sentinel "$WORK/.code-review-cleared" "abc123"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_generate_body: no sentinels present -> body contains just Summary + Test Plan" {
  _source_ship
  run _generate_body "abc123" "ran tools/test-all.sh --fast" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Summary"* ]]
  [[ "$output" == *"## Test Plan"* ]]
  [[ "$output" == *"ran tools/test-all.sh --fast"* ]]
  [[ ! "$output" == *"cr-battery evidence"* ]]
}

@test "_generate_body: cr-battery sentinel -> body contains evidence block" {
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=9.2" > "$WORK/.code-review-cleared"
  _source_ship
  run _generate_body "abc123" "smoke tested" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"cr-battery evidence"* ]]
  [[ "$output" == *"9.2/10"* ]]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"abc123"* ]]
}

@test "_generate_body: ticket URL is inserted at top of Summary" {
  _source_ship
  run _generate_body "abc123" "smoke" "https://github.com/x/y/issues/42"
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://github.com/x/y/issues/42"* ]]
}

@test "_generate_body: all three sentinels compose without collision" {
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=9.2" > "$WORK/.code-review-cleared"
  echo "v1|abc123|PASS|2026-04-01T00:00:00Z|min-score=8.7" > "$WORK/.llm-skill-review-cleared"
  echo "v1|abc123|PASS_WITH_NITS|2026-04-01T00:00:00Z|min-score=8.0" > "$WORK/.phr-cleared"
  _source_ship
  run _generate_body "abc123" "smoke" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"cr-battery evidence"* ]]
  [[ "$output" == *"llm-skill-review evidence"* ]]
  [[ "$output" == *"PHR evidence"* ]]
  [[ "$output" == *"9.2/10"* ]]
  [[ "$output" == *"8.7/10"* ]]
  [[ "$output" == *"8.0/10"* ]]
}

# --- _aggregate_check_state -------------------------------------------------
# Regression guard for the CI-bypass bug. ship.sh previously reduced check
# states with:
#     grep -qE '^(pending|in_progress|queued|)$'
# The empty final alternative is rejected by ugrep (a common Homebrew `grep`
# replacement on macOS) as "empty (sub)expression", exiting 2. The non-zero
# exit made that `elif` false, so a PR with checks still RUNNING fell through
# to "success" and ship.sh merged it without waiting for CI. Observed live on
# PR #1210 (2026-08-25). These tests pin every branch of the state machine.

@test "_aggregate_check_state: all pass -> success" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tpass\t2s\turl')"
  [ "$status" -eq 0 ]
  [ "$output" = "success" ]
}

@test "_aggregate_check_state: a pending check -> running (never success)" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tpending\t0\turl')"
  [ "$status" -eq 0 ]
  [ "$output" = "running" ]
}

@test "_aggregate_check_state: in_progress -> running" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tin_progress\t0\turl')"
  [ "$output" = "running" ]
}

@test "_aggregate_check_state: queued -> running" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tqueued\t0\turl')"
  [ "$output" = "running" ]
}

@test "_aggregate_check_state: empty state column -> running" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\t\t0\turl')"
  [ "$output" = "running" ]
}

@test "_aggregate_check_state: a failing check -> failed" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tfail\t3s\turl')"
  [ "$output" = "failed" ]
}

@test "_aggregate_check_state: failure outranks a still-pending check" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpending\t0\turl\nLint\tfail\t3s\turl')"
  [ "$output" = "failed" ]
}

@test "_aggregate_check_state: gh's real 'cancel' bucket -> failed (not success)" {
  # REGRESSION: gh pr checks TSV column 2 emits the BUCKET, and gh's cancelled
  # bucket is "cancel", NOT "cancelled". The first version of this function
  # matched only "cancelled", so a genuinely cancelled check fell through the
  # denylist to "success" and ship.sh merged without passing CI -- the exact
  # failure this function exists to prevent.
  _source_ship
  run _aggregate_check_state "$(printf 'A\tcancel\t0\turl')"
  [ "$output" = "failed" ]
}

@test "_aggregate_check_state: cancel outranks a passing check" {
  _source_ship
  run _aggregate_check_state "$(printf 'A\tpass\t1s\turl\nB\tcancel\t0\turl')"
  [ "$output" = "failed" ]
}

@test "_aggregate_check_state: unknown/future bucket fails CLOSED to running" {
  # The aggregator is an allowlist: anything unrecognized must keep the poll
  # loop waiting (and eventually hit _POLL_TIMEOUT), never resolve to success.
  _source_ship
  run _aggregate_check_state "$(printf 'A\tfuturebucket\t0\turl')"
  [ "$output" = "running" ]
  run _aggregate_check_state "$(printf 'A\tpass\t1s\turl\nB\tstale\t0\turl')"
  [ "$output" = "running" ]
}

@test "_aggregate_check_state: cancelled/action_required/timed_out -> failed" {
  _source_ship
  run _aggregate_check_state "$(printf 'A\tcancelled\t0\turl')"
  [ "$output" = "failed" ]
  run _aggregate_check_state "$(printf 'A\taction_required\t0\turl')"
  [ "$output" = "failed" ]
  run _aggregate_check_state "$(printf 'A\ttimed_out\t0\turl')"
  [ "$output" = "failed" ]
}

@test "_aggregate_check_state: skipping counts as complete -> success" {
  _source_ship
  run _aggregate_check_state "$(printf 'Tests\tpass\t1s\turl\nLint\tskipping\t0\turl')"
  [ "$output" = "success" ]
}

@test "_aggregate_check_state: ALL checks skipping -> success (intentional)" {
  # Pinned decision, not an accident. gh buckets a skipped OR neutral check as
  # "skipping", and path-filtered workflows legitimately skip every check on a
  # docs-only PR. ship.sh mirrors branch protection rather than inventing a
  # stricter rule, so an all-skipped required set counts as satisfied. If that
  # is ever wrong for this repo, the fix is branch protection config, not a
  # divergent rule here. See the --required rationale in tools/ship.sh.
  _source_ship
  run _aggregate_check_state "$(printf 'A\tskipping\t0\turl\nB\tskipping\t0\turl')"
  [ "$output" = "success" ]
}

@test "_aggregate_check_state: no required checks found -> pending, never success" {
  # An empty required set means protection is missing/unreadable. That must
  # stall the poll loop into a timeout (exit 1), never resolve to a merge.
  _source_ship
  run _aggregate_check_state ""
  [ "$output" = "pending" ]
  run _aggregate_check_state "$(printf '\n\n')"
  [ "$output" = "pending" ]
}

@test "_aggregate_check_state: empty input -> pending" {
  _source_ship
  run _aggregate_check_state ""
  [ "$output" = "pending" ]
}
