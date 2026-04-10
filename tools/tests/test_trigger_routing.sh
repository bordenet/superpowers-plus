#!/usr/bin/env bash
# test_trigger_routing.sh — Smoke test that critical trigger phrases route to the correct skills.
# Requires: installed superpowers with match-skills available.
# Skips gracefully if match-skills is not available.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="$SCRIPT_DIR/../../superpowers-augment.js"

PASS=0; FAIL=0; SKIP=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }
skip() { echo "  skip: $1"; ((SKIP++)) || true; }

# Skip in CI — requires personal skills directory (~/.agents/skills/) not present on CI runners.
if [[ "${CI:-}" == "true" ]]; then
  echo "SKIP: trigger routing tests require personal skills dir — not available in CI"
  exit 0
fi

# Check if match-skills is available
if ! node "$ADAPTER" match-skills "test" >/dev/null 2>&1; then
  echo "SKIP: match-skills not available (superpowers not installed?)"
  exit 0
fi

# assert_top_match <query> <expected_skill>
# Verifies that the given query routes to the expected skill as the #1 match.
assert_top_match() {
  local query="$1"
  local expected="$2"
  local result
  result=$(node "$ADAPTER" match-skills "$query" 2>/dev/null \
    | grep '| 1 |' \
    | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
  if [[ "$result" == "$expected" ]]; then
    pass "\"$query\" → $expected"
  else
    fail "\"$query\" → got '$result', expected '$expected'"
  fi
}

echo "── Trigger Routing Smoke Tests ──"

if node "$ADAPTER" find-skills superpowers | grep -q 'wiki-instruction-guard'; then
  pass 'wiki-instruction-guard stays auto-triggered with multiline triggers'
else
  fail 'wiki-instruction-guard missing from superpowers list (multiline trigger parsing broke)'
fi

# debate triggers (formerly design-triad)
assert_top_match "decision options with adversarial review" "debate"
assert_top_match "generate options compare and red team" "debate"
assert_top_match "debate the options" "debate"
assert_top_match "compare approaches" "debate"
assert_top_match "what's the best approach for retry logic placement" "thinking-orchestrator"
assert_top_match "where to store retry logic" "thinking-orchestrator"

# Other critical routing (add as regressions are found)
assert_top_match "I am stuck in a loop" "think-twice"
assert_top_match "create a plan and execute it" "plan-and-execute"

echo ""
echo "── Results: $PASS passed, $FAIL failed, $SKIP skipped ──"
[[ $FAIL -eq 0 ]]
