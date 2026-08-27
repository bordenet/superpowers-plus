#!/usr/bin/env bats
# Per-skill kernel byte-budget guardrails.
# Add a new @test block here for every skill split via spc-kernel-split so the
# kernel cannot silently regrow.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
}

# ---------------------------------------------------------------------------
# spc-kernel-split itself -- meta check that the skill stays kernel-sized.
# Authored as a kernel from the start; it should stay small.
# ---------------------------------------------------------------------------
@test "spc-kernel-split skill stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/spc-kernel-split/skill.md"
  SKILL_BYTE_BUDGET=8000
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

# ---------------------------------------------------------------------------
# pr-triage-gate -- kernel guardrail for the sibling gate skill.
# ---------------------------------------------------------------------------
@test "pr-triage-gate skill stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/pr-triage-gate/skill.md"
  SKILL_BYTE_BUDGET=6000
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}
