#!/usr/bin/env bats
# Behavioral invariants for debate. Assertions exercise the resident kernel's
# real section-loader block so kernel-splitting cannot hide broken references.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SKILL="$REPO_ROOT/skills/engineering/debate/skill.md"
  REFERENCE="$REPO_ROOT/skills/engineering/debate/reference.md"
  SECTION_LOADER="$REPO_ROOT/tools/section-loader.sh"
  FIXTURES="$REPO_ROOT/test/skill-invocation-fixtures.json"
  TMPDIR_="$(mktemp -d)"
  CORPUS="$(mktemp)"
  cat "$SKILL" > "$CORPUS"
  if [[ -r "$REFERENCE" ]]; then
    cat "$REFERENCE" >> "$CORPUS"
  fi
}

teardown() {
  rm -f "$CORPUS"
  rm -rf "$TMPDIR_"
}

render_debate_loader() {
  local skill_file="$1"
  local section="$2"
  local script_file="$3"

  awk '
    /<!-- kernel-split-reference-loader:start -->/ { in_block = 1; next }
    in_block && /^```bash$/ { next }
    in_block && /^```$/ { exit }
    in_block { print }
  ' "$skill_file" \
    | sed "s|_section='<section heading>'|_section='$section'|" \
    > "$script_file"
}

install_managed_loader() {
  local home_dir="$1"
  mkdir -p "$home_dir/.codex/superpowers-plus/tools"
  cp "$SECTION_LOADER" "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
  chmod +x "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
}

install_debate_fixture() {
  local home_dir="$1"
  local layout="$2"
  local reference_source="${3:-$REFERENCE}"
  local install_dir skill_file

  case "$layout" in
    agents)
      install_dir="$home_dir/.agents/skills/sp-debate"
      skill_file="$install_dir/SKILL.md"
      ;;
    codex)
      install_dir="$home_dir/.codex/skills/sp-debate"
      skill_file="$install_dir/skill.md"
      ;;
    claude)
      install_dir="$home_dir/.claude/skills/sp-debate"
      skill_file="$install_dir/skill.md"
      ;;
    *)
      printf 'unknown install layout: %s\n' "$layout" >&2
      return 2
      ;;
  esac

  mkdir -p "$install_dir"
  cp "$SKILL" "$skill_file"
  cp "$reference_source" "$install_dir/reference.md"
  install_managed_loader "$home_dir"
  INSTALLED_SKILL="$skill_file"
}

@test "debate requires three genuine implementable options" {
  grep -Eq 'minimum (THREE|three)|>=3 genuinely distinct|≥3 genuinely distinct' "$CORPUS"
  grep -Eq 'not superficial variations|Genuinely different' "$CORPUS"
  grep -Eq 'Implementable|implementable' "$CORPUS"
}

@test "debate keeps author and reviewer separated without recursive reviewers" {
  grep -Eq 'Author.*Reviewer|author.*reviewer' "$CORPUS"
  grep -Eq 'Sub-agent|sub-agent|separated reviewer' "$CORPUS"
  grep -Fq "Do NOT invoke \`progressive-harsh-review\` or \`quantitative-decision-gate\`" "$CORPUS"
}

@test "debate requires fix verification and a bounded second review" {
  grep -Eq 'Minimum 2 full review rounds|minimum two full review rounds' "$CORPUS"
  grep -Eq 'Verify fixes landed|verify fixes landed' "$CORPUS"
  grep -Eq '3 rounds completed|three rounds completed' "$CORPUS"
  grep -Eq 'Do NOT.*beyond 3 rounds|do not.*beyond three rounds' "$CORPUS"
}

@test "debate emits a compact decision record with unresolved risks" {
  grep -Eq 'decision-record|decision record' "$CORPUS"
  grep -Eq 'Options considered|options considered' "$CORPUS"
  grep -Eq 'Edge-case catalog|edge-case catalog' "$CORPUS"
  grep -Eq 'Open risks|open risks' "$CORPUS"
}

@test "debate loads Comparison protocol from the source checkout" {
  script_file="$TMPDIR_/source-loader.sh"
  render_debate_loader "$SKILL" "Comparison protocol" "$script_file"

  run env HOME="$TMPDIR_/empty-home" bash -c "cd '$REPO_ROOT' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Comparison protocol"* ]]
}

@test "debate loads Comparison protocol from the installed sp-debate alias" {
  install_home="$TMPDIR_/installed-home"
  consumer="$TMPDIR_/consumer"
  mkdir -p "$consumer"
  install_debate_fixture "$install_home" agents
  script_file="$TMPDIR_/installed-loader.sh"
  render_debate_loader \
    "$INSTALLED_SKILL" \
    "Comparison protocol" \
    "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Comparison protocol"* ]]
}

@test "debate executes every supported installed reference layout" {
  for layout in claude codex agents; do
    install_home="$TMPDIR_/$layout-home"
    consumer="$TMPDIR_/$layout-consumer"
    mkdir -p "$consumer"
    install_debate_fixture "$install_home" "$layout"
    script_file="$TMPDIR_/$layout-loader.sh"
    render_debate_loader "$INSTALLED_SKILL" "Comparison protocol" "$script_file"

    run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
    [ "$status" -eq 0 ]
    [[ "$output" == "## Comparison protocol"* ]]
  done
}

@test "debate installed reference outranks a complete malicious current-project tuple" {
  install_home="$TMPDIR_/malicious-home"
  consumer="$TMPDIR_/malicious-consumer"
  consumer_skill="$consumer/skills/engineering/debate"
  malicious_marker="$TMPDIR_/debate-project-loader.executed"
  mkdir -p "$consumer_skill" "$consumer/tools"
  git -C "$consumer" init -q
  install_debate_fixture "$install_home" claude
  cp "$SKILL" "$consumer_skill/skill.md"
  cat > "$consumer_skill/reference.md" <<'MD'
# Poison project reference

## Comparison protocol

PROJECT-DEBATE-REFERENCE-POISON
MD
  grep -Fq 'PROJECT-DEBATE-REFERENCE-POISON' "$consumer_skill/reference.md"
  cat > "$consumer/tools/section-loader.sh" <<'SH'
#!/usr/bin/env bash
: "${MALICIOUS_MARKER:?}"
: > "$MALICIOUS_MARKER"
printf 'PROJECT-LOADER-EXECUTED\n'
SH
  chmod +x "$consumer/tools/section-loader.sh"
  script_file="$TMPDIR_/malicious-loader.sh"
  render_debate_loader "$INSTALLED_SKILL" "Comparison protocol" "$script_file"

  run env \
    HOME="$install_home" \
    MALICIOUS_MARKER="$malicious_marker" \
    bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Comparison protocol"* ]]
  [[ "$output" == *"Compare Complexity"* ]]
  [[ "$output" != *"PROJECT-DEBATE-REFERENCE-POISON"* ]]
  [[ "$output" != *"PROJECT-LOADER-EXECUTED"* ]]
  [ ! -e "$malicious_marker" ]
}

@test "debate skips brainstorming only when low-stakes and reversible" {
  grep -Fq \
    'Skip brainstorming only when the decision is both low-stakes and reversible.' \
    "$REFERENCE"
}

@test "debate split preserves P1d operative counts across kernel and reference" {
  counts="$(node -e '
    const fs = require("fs");
    const text = fs.readFileSync(process.argv[1], "utf8");
    const steps = (text.match(/^#{2,4}\s+(Step|Stage|Phase)\s+\d+/gim) || []).length;
    const stops = (text.match(/⛔/g) || []).length;
    process.stdout.write(String(steps) + " " + String(stops));
  ' "$CORPUS")"
  read -r step_headings stop_markers <<< "$counts"

  [ "$step_headings" -ge 5 ]
  [ "$stop_markers" -ge 5 ]
}

@test "debate canonical Claude reference wins over divergent optional copies" {
  install_home="$TMPDIR_/divergent-home"
  consumer="$TMPDIR_/divergent-consumer"
  stale_agents="$TMPDIR_/stale-agents.md"
  stale_codex="$TMPDIR_/stale-codex.md"
  mkdir -p "$consumer"
  git -C "$consumer" init -q
  sed 's/Compare Complexity/Compare STALE-AGENTS, Complexity/' "$REFERENCE" > "$stale_agents"
  sed 's/Compare Complexity/Compare STALE-CODEX, Complexity/' "$REFERENCE" > "$stale_codex"
  install_debate_fixture "$install_home" agents "$stale_agents"
  install_debate_fixture "$install_home" codex "$stale_codex"
  install_debate_fixture "$install_home" claude "$REFERENCE"
  script_file="$TMPDIR_/divergent-loader.sh"
  render_debate_loader "$INSTALLED_SKILL" "Comparison protocol" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Comparison protocol"* ]]
  [[ "$output" != *"STALE-AGENTS"* ]]
  [[ "$output" != *"STALE-CODEX"* ]]
}

@test "debate Comparison protocol preserves all six criteria" {
  install_home="$TMPDIR_/criteria-home"
  consumer="$TMPDIR_/criteria-consumer"
  mkdir -p "$consumer"
  install_debate_fixture "$install_home" claude
  script_file="$TMPDIR_/criteria-loader.sh"
  render_debate_loader \
    "$INSTALLED_SKILL" \
    "Comparison protocol" \
    "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  for criterion in \
    Complexity \
    Testability \
    Maintainability \
    Risk \
    "Fit with existing patterns" \
    Reversibility
  do
    [[ "$output" == *"$criterion"* ]]
  done
}

@test "debate installed loader fails on an unknown section" {
  install_home="$TMPDIR_/missing-home"
  consumer="$TMPDIR_/missing-consumer"
  mkdir -p "$consumer"
  install_debate_fixture "$install_home" claude
  script_file="$TMPDIR_/missing-loader.sh"
  render_debate_loader \
    "$INSTALLED_SKILL" \
    "Not a debate section" \
    "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"section not found: Not a debate section"* ]]
}

@test "debate invocation fixture records independent review" {
  debate_entry="$(node -e '
    const fixture = require(process.argv[1]);
    process.stdout.write(JSON.stringify(fixture.skills.debate));
  ' "$FIXTURES")"

  [[ "$debate_entry" != *"auto-seed"* ]]
  [[ "$debate_entry" == *"independent"* ]]
}

@test "debate fixture preserves P2A assertions and review metadata for P1h merge" {
  run node -e '
    const fixture = require(process.argv[1]).skills.debate;
    const expected = [
      "Produce a minimum three genuinely distinct, implementable options.",
      "Author and reviewer must be separate.",
      "Complete a minimum two full review rounds and no more than three."
    ];
    if (JSON.stringify(fixture.expected_substrings) !== JSON.stringify(expected)) process.exit(1);
    if (fixture.verified_by !== "independent P2A llm-skill-review") process.exit(1);
    if (fixture.verified_at !== "2026-09-17") process.exit(1);
    if (!/P1h.*retain.*P2A/i.test(fixture.merge_requirement || "")) process.exit(1);
  ' "$FIXTURES"

  [ "$status" -eq 0 ]
}
