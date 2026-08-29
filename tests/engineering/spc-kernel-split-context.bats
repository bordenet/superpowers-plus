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

# ---------------------------------------------------------------------------
# llm-skill-review kernel -- regression guard only.
# Pinned at post-split baseline (18,603 bytes; pre-split: 19,754 bytes).
# 60% reduction target (11,852 bytes) not yet achieved -- tracked as follow-up.
# This test only prevents the kernel from growing LARGER than the post-split size.
# Bumping SKILL_BYTE_BUDGET requires a comment explaining why the kernel grew.
# ---------------------------------------------------------------------------
@test "llm-skill-review kernel stays within byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/llm-skill-review/skill.md"
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  SKILL_BYTE_BUDGET=19500
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}
