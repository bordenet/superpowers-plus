#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CONDUCTOR="$REPO_ROOT/skills/engineering/debug-conductor/skill.md"
CHAIN_CONTROLLER="$REPO_ROOT/skills/productivity/autonomous-chain-controller/skill.md"

HELPERS=(
  timeline-trace-investigator
  llm-behavior-investigator
  state-consistency-investigator
  infra-config-investigator
  reproduction-experiment-investigator
  evidence-adjudicator
)

@test "debug-conductor helpers are references, not standalone skills" {
  local helper reference
  for helper in "${HELPERS[@]}"; do
    reference="$REPO_ROOT/skills/engineering/debug-conductor/references/$helper.md"
    [ -f "$reference" ]
    [ ! -e "$REPO_ROOT/skills/engineering/$helper/skill.md" ]
    ! grep -q '^name:' "$reference"
    ! grep -q '^source:' "$reference"
  done
}

@test "debug-conductor Phase 3 dispatches every investigator by exact reference path" {
  local phase_three helper
  phase_three=$(sed -n '/^### Phase 3:/,/^### Phase 4:/p' "$CONDUCTOR")

  for helper in \
    timeline-trace-investigator \
    llm-behavior-investigator \
    state-consistency-investigator \
    infra-config-investigator \
    reproduction-experiment-investigator; do
    [[ "$phase_three" == *"\`references/$helper.md\`"* ]]
  done

  [[ "$phase_three" != *'references/<investigator-name>.md'* ]]
}

@test "debug-conductor Phase 5 dispatches adjudication by exact reference path" {
  local phase_five
  phase_five=$(sed -n '/^### Phase 5:/,/^### Phase 6:/p' "$CONDUCTOR")
  [[ "$phase_five" == *'`references/evidence-adjudicator.md`'* ]]
}

@test "debug-conductor never dispatches the retired adjudicator skill name" {
  ! grep -Fq 'dispatch `evidence-adjudicator`' "$CONDUCTOR"
}

@test "autonomous chain treats adjudication as internal to debug-conductor" {
  local distributed_chain
  distributed_chain=$(grep -F '| Distributed incident |' "$CHAIN_CONTROLLER")

  [[ "$distributed_chain" == *'debug-conductor -> failure-autopsy'* ]]
  [[ "$distributed_chain" != *'-> evidence-adjudicator'* ]]
}
