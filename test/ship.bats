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
