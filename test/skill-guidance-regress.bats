#!/usr/bin/env bats
# ADR-004 v0 guidance-regression suite.

@test "skill-guidance-regress: all pilot fixtures pass" {
  run "$BATS_TEST_DIRNAME/../tools/skill-guidance-regress.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"passed"* ]]
  [[ "$output" != *" failed, "* ]] || true
  [[ "$output" == *", 0 failed"* ]]
}
