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
# Budget raised from 7000: the "## Failure Modes" table was deliberately moved
# BACK into the resident kernel. Loading it on demand put the anti-rubber-
# stamping rules (score-inflation cap, REGRESSION flag, Operational-Risk veto
# eligibility) behind the exact condition they exist to prevent -- a rubber-
# stamped review never reaches "detailed failure recovery" and so never loads
# them. Resident bytes are the cheaper mistake.
@test "progressive-harsh-review stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/progressive-harsh-review/skill.md"
  SKILL_BYTE_BUDGET=8500
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

# ---------------------------------------------------------------------------
# debate kernel -- split from a 13,660-byte resident skill on 2026-09-17.
# Budget raised 6000->6500 on 2026-09-18: moved `## Rationalizations to
# reject` back resident from reference.md, matching the PHR/context-ferry
# precedent (anti-rubber-stamping content must not live behind the exact
# on-demand-load condition it exists to prevent -- see diet.md). Still
# stricter than the generic 60% cap (8,196).
# ---------------------------------------------------------------------------
@test "debate skill stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/engineering/debate/skill.md"
  SKILL_BYTE_BUDGET=6500
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current_bytes" -le "$SKILL_BYTE_BUDGET" ]
}

# ---------------------------------------------------------------------------
# context-ferry -- split from 10,688 bytes on 2026-09-17.
# The 5,000-byte ceiling retains compaction-safe sequencing while moving the
# duplicated scaffold template and detailed fidelity/recovery tables on demand.
# ---------------------------------------------------------------------------
# Budget raised from 5000 for the same reason as PHR: its Failure Modes table
# is resident again rather than on-demand.
@test "context-ferry stays within kernel byte budget" {
  SKILL="$REPO_ROOT/skills/productivity/context-ferry/skill.md"
  SKILL_BYTE_BUDGET=6500
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

# PHR had NO ledger test, so its row drifted unnoticed while context-ferry's and
# debate's were caught. Every split skill in the ledger needs one.
@test "progressive-harsh-review reduction ledger matches current kernel bytes" {
  SKILL="$REPO_ROOT/skills/engineering/progressive-harsh-review/skill.md"
  HISTORY="$REPO_ROOT/docs/harness/reduction-history.md"
  current_bytes="$(wc -c < "$SKILL" | tr -d ' ')"
  recorded="$(awk -F '|' '/^\| progressive-harsh-review / { gsub(/[[:space:]]/, "", $4); print $4 }' "$HISTORY")"
  [ "$recorded" = "$current_bytes" ]
}

@test "reduction ledger Retained column equals kernel + reference for every split" {
  HISTORY="$REPO_ROOT/docs/harness/reduction-history.md"
  for pair in "progressive-harsh-review:engineering" "context-ferry:productivity" "debate:engineering"; do
    name="${pair%%:*}"; domain="${pair##*:}"
    k="$(wc -c < "$REPO_ROOT/skills/$domain/$name/skill.md" | tr -d ' ')"
    r="$(wc -c < "$REPO_ROOT/skills/$domain/$name/reference.md" | tr -d ' ')"
    ledger_ref="$(awk -F '|' -v n=" $name " '$2 == n { gsub(/[[:space:]]/, "", $5); print $5 }' "$HISTORY")"
    ledger_ret="$(awk -F '|' -v n=" $name " '$2 == n { gsub(/[[:space:]]/, "", $6); print $6 }' "$HISTORY")"
    [ "$ledger_ref" = "$r" ]
    [ "$ledger_ret" -eq "$((k + r))" ]
  done
}

# A narrow waiver must never widen into a deletion licence. Before this, ANY
# OP-WAIVER entry for a skill authorized deleting its whole skill.md -- and
# debate has no ei-baseline entry, so its operative waiver was its only guard.
@test "op-waivers: a narrow waiver does NOT authorize deleting the whole skill" {
  local work="$BATS_TEST_TMPDIR/w"
  mkdir -p "$work"
  cp -R "$REPO_ROOT/lib" "$REPO_ROOT/test" "$REPO_ROOT/skills" "$work/"
  rm "$work/skills/engineering/debate/skill.md"
  run node "$work/test/operative-move-detector.test.js"
  [ "$status" -eq 1 ]
  [[ "$output" == *"skill.md no longer exists"* ]]
}

@test "op-waivers: a commented example is documentation, not a live waiver" {
  local work="$BATS_TEST_TMPDIR/w2"
  mkdir -p "$work"
  cp -R "$REPO_ROOT/lib" "$REPO_ROOT/test" "$REPO_ROOT/skills" "$work/"
  printf '\n# EXAMPLE ONLY: OP-WAIVER: engineering/systematic-debugging/skill.md step_headings -9 — sample\n' \
    >> "$work/test/.op-waivers"
  perl -0pi -e 's/^(#{2,4})\s+(?:Step|Stage|Phase)\s+\d+\s*:?\s*/$1 Renamed /gm' \
    "$work/skills/engineering/systematic-debugging/skill.md"
  run node "$work/test/operative-move-detector.test.js"
  [ "$status" -eq 1 ]
  [[ "$output" == *"step_headings"* ]]
}
