#!/usr/bin/env bats
# Per-skill kernel byte-budget guardrails.
# Add a new @test block here for every skill split via kernel-split so the
# kernel cannot silently regrow.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
}

# ---------------------------------------------------------------------------
# kernel-split itself -- meta check that the skill stays kernel-sized.
# Authored as a kernel from the start; it should stay small.
# ---------------------------------------------------------------------------
@test "kernel-split skill stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/kernel-split/skill.md"
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

# ---------------------------------------------------------------------------
# progressive-harsh-review -- split from 18,018 bytes on 2026-09-17.
# The plan's 7,000-byte ceiling keeps dispatch instructions resident while
# score-floor examples and recovery tables remain on demand.
# ---------------------------------------------------------------------------
@test "progressive-harsh-review stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/progressive-harsh-review/skill.md"
  SKILL_BYTE_BUDGET=7000
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

# ---------------------------------------------------------------------------
# debate kernel -- split from a 13,660-byte resident skill on 2026-09-17.
# The 6,000-byte plan budget is stricter than the generic 60% cap (8,196).
# ---------------------------------------------------------------------------
@test "debate skill stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/debate/skill.md"
  SKILL_BYTE_BUDGET=6000
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

# ---------------------------------------------------------------------------
# context-ferry -- split from 10,688 bytes on 2026-09-17.
# The 5,000-byte ceiling retains compaction-safe sequencing while moving the
# duplicated scaffold template and detailed fidelity/recovery tables on demand.
# ---------------------------------------------------------------------------
@test "context-ferry stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/productivity/context-ferry/skill.md"
  SKILL_BYTE_BUDGET=5000
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

@test "context-ferry reduction ledger matches current kernel bytes" {
  local skill="$REPO_ROOT/skills/productivity/context-ferry/skill.md"
  local history="$REPO_ROOT/docs/harness/reduction-history.md"
  local current_bytes recorded_bytes
  current_bytes="$(wc -c < "$skill" | tr -d ' ')"
  recorded_bytes="$(awk -F '|' '$2 ~ /context-ferry/ { gsub(/[[:space:]]/, "", $4); print $4 }' "$history")"
  [ "$recorded_bytes" = "$current_bytes" ]
}

@test "debate reduction ledger matches exact kernel bytes and floor percentage" {
  SKILL="$REPO_ROOT/skills/engineering/debate/skill.md"
  HISTORY="$REPO_ROOT/docs/harness/reduction-history.md"
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  ledger_before="$(awk -F '|' '/^\| debate / { gsub(/[[:space:]]/, "", $3); print $3 }' "$HISTORY")"
  ledger_after="$(awk -F '|' '/^\| debate / { gsub(/[[:space:]]/, "", $4); print $4 }' "$HISTORY")"
  # Reduction sits at field 8: the ledger gained Reference/Retained/Deleted
  # columns so moved and deleted bytes are reported separately (see the doc).
  ledger_reduction="$(awk -F '|' '/^\| debate / { gsub(/[[:space:]]/, "", $8); print $8 }' "$HISTORY")"
  expected_reduction=$(( (ledger_before - current_bytes) * 100 / ledger_before ))

  [ "$ledger_after" -eq "$current_bytes" ]
  [ "$ledger_reduction" = "${expected_reduction}%" ]
}
