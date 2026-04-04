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

  # Dispatch-specific anchors (must match actual skill dispatch lines, not free-floating tokens)
  assert_contains "$request_output" "Dispatch \`code-review-battery\`" "requesting-code-review should dispatch via code-review-battery"
  assert_contains "$request_output" "via \`sub-agent-code-reviewer\`" "requesting-code-review should route reviewers via sub-agent-code-reviewer"
  # Stale patterns — aligned with doctor-checks.sh _doctor_reviewer_dispatch (lines 1092-1095)
  assert_not_contains "$request_output" "code-reviewer subagent" "requesting-code-review left legacy code-reviewer subagent wording"
  assert_not_contains "$request_output" "code reviewer subagent" "requesting-code-review left legacy code reviewer subagent wording"
  assert_not_contains "$request_output" "Dispatch final code-reviewer" "requesting-code-review contains stale final-reviewer pattern"
  assert_not_contains "$request_output" "Task tool with superpowers:code-reviewer type" "requesting-code-review fell back to legacy Task tool mapping"

  assert_contains "$sdd_output" "Dispatch final sub-agent-code-reviewer for entire implementation" "subagent-driven-development should translate final reviewer graph label"
  assert_not_contains "$sdd_output" "dispatch final code reviewer for entire implementation" "subagent-driven-development left legacy code reviewer wording"
  assert_not_contains "$sdd_output" "Dispatch final code reviewer subagent for entire implementation" "subagent-driven-development left legacy code reviewer subagent wording"

  echo "PASS: code reviewer dispatch translation"
}

main "$@"
