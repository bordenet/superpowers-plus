#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="$SCRIPT_DIR/../../superpowers-augment.js"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$label"
}

main() {
  local request_output sdd_output
  request_output=$(node "$ADAPTER" use-skill requesting-code-review)
  sdd_output=$(node "$ADAPTER" use-skill subagent-driven-development)

  assert_contains "$request_output" "Dispatch sub-agent-code-reviewer" "requesting-code-review should dispatch sub-agent-code-reviewer"
  assert_contains "$request_output" "Use sub-agent-code-reviewer tool" "requesting-code-review should map Task tool to sub-agent-code-reviewer"
  assert_not_contains "$request_output" "Dispatch code-reviewer subagent" "requesting-code-review left legacy code-reviewer subagent wording"
  assert_not_contains "$request_output" "launch-process (or handle directly) with superpowers:code-reviewer type" "requesting-code-review fell back to generic Task tool mapping"

  assert_contains "$sdd_output" "Dispatch final sub-agent-code-reviewer for entire implementation" "subagent-driven-development should translate final reviewer graph label"
  assert_not_contains "$sdd_output" "dispatch final code reviewer for entire implementation" "subagent-driven-development left legacy code reviewer wording"
  assert_not_contains "$sdd_output" "Dispatch final code reviewer subagent for entire implementation" "subagent-driven-development left legacy code reviewer subagent wording"

  echo "PASS: code reviewer dispatch translation"
}

main "$@"
