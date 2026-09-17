#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

skill_count() {
  find "$REPO_ROOT/skills" -name skill.md -not -path '*/_adapters/*' | wc -l | tr -d ' '
}

@test "README skill totals match the source skill count" {
  local actual
  actual=$(skill_count)

  grep -Fq "**$actual skills** across 9 domains" "$REPO_ROOT/README.md"
  grep -Fq "superpowers-plus contributes $actual skills" "$REPO_ROOT/README.md"
  grep -Fq "All $actual skills with typed edges" "$REPO_ROOT/README.md"
}

@test "generated and curated skill docs declare the source skill count" {
  local actual
  actual=$(skill_count)

  grep -Fq "SKILL-COUNT: $actual" "$REPO_ROOT/docs/SKILLS.md"
  grep -Fq "$actual skills total." "$REPO_ROOT/docs/SKILL_TAXONOMY.md"
  grep -Fq "all $actual skills" "$REPO_ROOT/docs/skill-dependency-graph.md"
}
